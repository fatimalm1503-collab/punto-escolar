import os
from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename
from db import get_connection

app = Flask(__name__)

BASE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(BASE, "uploads"), exist_ok=True)

# Sin login por ahora: se usa un cliente de prueba (Martha Silva, id 2 en schema.sql)
CLIENTE_DEMO_ID = 2

SERVICIOS = {"impresion", "copiado", "diseno", "engargolado"}
ERROR_A1 = "Debe adjuntar el archivo digital para registrar el pedido."
ERROR_A2 = "Complete el tipo de servicio y la forma de entrega."


def error(mensaje, codigo=400):
    return jsonify(ok=False, error=mensaje), codigo


@app.route("/")
def menu_cliente():
    """Menu principal del cliente (CU-03, pantallas de registro)."""
    return render_template("cliente.html")


@app.route("/pedido", methods=["POST"])
def registrar_pedido():
    """CU-03 Registrar Pedido: valida, guarda pedido y archivo en una transaccion."""
    f = request.form

    def dato(nombre):
        valor = (f.get(nombre) or "").strip()
        return valor or None

    servicio = dato("servicio")
    entrega = dato("tipo_entrega")
    if servicio not in SERVICIOS or entrega not in ("digital", "usb"):
        return error(ERROR_A2)  # A2: datos obligatorios incompletos

    archivo = request.files.get("archivo")
    if entrega == "digital" and (archivo is None or not archivo.filename):
        return error(ERROR_A1)  # A1 / RN-07: digital exige archivo

    es_color = num_copias = tipo_diseno = tipo_engargolado = color_pastas = None
    tamano = dato("tamano_hojas")

    if servicio in ("impresion", "copiado"):
        if dato("es_color") not in ("0", "1") or not (dato("num_copias") or "").isdigit():
            return error(ERROR_A2)
        es_color = dato("es_color") == "1"
        num_copias = int(dato("num_copias"))
        if num_copias < 1:
            return error(ERROR_A2)
    elif servicio == "diseno":
        tipo_diseno = dato("tipo_diseno")
        if not tipo_diseno:
            return error(ERROR_A2)
    else:  # engargolado
        tipo_engargolado = dato("tipo_engargolado")
        color_pastas = dato("color_pastas")
        if not (tipo_engargolado and color_pastas and tamano):
            return error(ERROR_A2)

    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias,
                                   tipo_diseno, tipo_engargolado, tamano_hojas, color_pastas, descripcion)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (CLIENTE_DEMO_ID, servicio, entrega, es_color, num_copias,
             tipo_diseno, tipo_engargolado, tamano, color_pastas, dato("descripcion")),
        )
        folio = cur.lastrowid  # id_pedido = folio (RF-02)

        if entrega == "digital":
            nombre = secure_filename(archivo.filename) or "archivo"
            ruta = f"uploads/pedido_{folio}_{nombre}"
            archivo.save(os.path.join(BASE, ruta))
            formato = nombre.rsplit(".", 1)[-1].lower()[:10] if "." in nombre else "n/a"
            cur.execute(
                "INSERT INTO archivo (id_pedido, nombre, formato, ruta) VALUES (%s, %s, %s, %s)",
                (folio, nombre, formato, ruta),
            )
        conn.commit()

        # Se lee de vuelta de la BD lo que realmente se guardo
        cur.execute("SELECT id_pedido AS folio, estado FROM pedido WHERE id_pedido = %s", (folio,))
        fila = cur.fetchone()
        return jsonify(ok=True, folio=fila["folio"], estado=fila["estado"])
    except Exception as e:
        conn.rollback()
        print("Error al registrar pedido:", e)
        return error("No se pudo registrar el pedido. Intente de nuevo.", 500)
    finally:
        conn.close()


@app.route("/empleado")
def lista_empleado():
    """Vista minima del empleado: lista de pedidos (lectura de la BD)."""
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """SELECT id_pedido AS folio, servicio, estado, tipo_entrega, fecha_registro
               FROM pedido ORDER BY fecha_registro DESC, id_pedido DESC"""
        )
        return render_template("empleado.html", pedidos=cur.fetchall())
    finally:
        conn.close()


if __name__ == "__main__":
    app.run(debug=True)
