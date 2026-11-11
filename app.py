import os
import re
from functools import wraps

import mysql.connector
from flask import (Flask, render_template, request, jsonify, session,
                   redirect, url_for, flash)
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

from db import get_connection  # db.py carga el .env

app = Flask(__name__)
# La clave firma la sesión del usuario. Va en el .env (SECRET_KEY).
app.secret_key = os.getenv("SECRET_KEY", "clave-solo-para-desarrollo")

BASE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(BASE, "uploads"), exist_ok=True)

SERVICIOS = {"impresion", "copiado", "diseno", "engargolado"}
ERROR_A1 = "Debe adjuntar el archivo digital para registrar el pedido."
ERROR_A2 = "Complete el tipo de servicio y la forma de entrega."


def error(mensaje, codigo=400):
    return jsonify(ok=False, error=mensaje), codigo


# ----------------------------------------------------------------------
# Acceso del cliente: registro, inicio de sesión y cierre de sesión (RF-10, RF-14)
# ----------------------------------------------------------------------
def solo_cliente(vista):
    """Solo deja pasar a un cliente con sesión iniciada."""
    @wraps(vista)
    def envoltura(*args, **kwargs):
        if session.get("rol") != "cliente":
            return redirect(url_for("cliente_login"))
        return vista(*args, **kwargs)
    return envoltura


def validar_registro(d, clave, confirmar):
    """Devuelve un mensaje de error, o None si los datos son correctos."""
    if not (d["nombre"] and d["usuario"] and d["correo"] and clave and confirmar):
        return "Complete todos los campos."
    if len(d["nombre"]) > 100:
        return "El nombre no puede pasar de 100 caracteres."
    if not re.fullmatch(r"[A-Za-z0-9._-]{3,50}", d["usuario"]):
        return "El usuario debe tener de 3 a 50 caracteres: letras, números, punto, guion o guion bajo."
    if len(d["correo"]) > 100 or not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", d["correo"]):
        return "Ingrese un correo electrónico válido."
    if len(clave) < 6:
        return "La contraseña debe tener mínimo 6 caracteres."
    if clave != confirmar:
        return "Las contraseñas no coinciden."
    return None


@app.route("/")
def inicio():
    destino = "cliente_menu" if session.get("rol") == "cliente" else "cliente_login"
    return redirect(url_for(destino))


@app.route("/cliente/registro", methods=["GET", "POST"])
def cliente_registro():
    """Crea la cuenta de un cliente nuevo y guarda su contraseña con hash."""
    datos = {"nombre": "", "usuario": "", "correo": ""}
    mensaje = None
    if request.method == "POST":
        datos = {k: (request.form.get(k) or "").strip() for k in datos}
        datos["correo"] = datos["correo"].lower()
        clave = request.form.get("password") or ""
        mensaje = validar_registro(datos, clave, request.form.get("confirmar") or "")
        if not mensaje:
            conn = get_connection()
            try:
                cur = conn.cursor(dictionary=True)
                cur.execute("SELECT usuario, correo FROM usuario WHERE usuario = %s OR correo = %s",
                            (datos["usuario"], datos["correo"]))
                for fila in cur.fetchall():
                    if fila["usuario"].lower() == datos["usuario"].lower():
                        mensaje = "Ese usuario ya está registrado."
                    elif fila["correo"].lower() == datos["correo"]:
                        mensaje = "Ese correo ya está registrado."
                if not mensaje:
                    cur.execute(
                        "INSERT INTO usuario (rol, nombre, usuario, correo, password_hash) "
                        "VALUES ('cliente', %s, %s, %s, %s)",
                        (datos["nombre"], datos["usuario"], datos["correo"],
                         generate_password_hash(clave)))
                    conn.commit()
                    flash("Cuenta creada correctamente. Inicia sesión para continuar.", "ok")
                    return redirect(url_for("cliente_login"))
            except mysql.connector.IntegrityError:
                conn.rollback()
                mensaje = "Ese usuario o correo ya está registrado."
            except mysql.connector.Error as e:
                conn.rollback()
                print("Error al registrar usuario:", e)
                mensaje = "No se pudo crear la cuenta. Intente de nuevo."
            finally:
                conn.close()
    return render_template("cliente_registro.html", error=mensaje, datos=datos)


@app.route("/cliente/login", methods=["GET", "POST"])
def cliente_login():
    """Inicio de sesión del cliente (con correo o usuario y contraseña)."""
    if session.get("rol") == "cliente":
        return redirect(url_for("cliente_menu"))
    ident = ""
    mensaje = None
    if request.method == "POST":
        ident = (request.form.get("ident") or "").strip()
        clave = request.form.get("password") or ""
        if not ident or not clave:
            mensaje = "Ingrese su correo o usuario y su contraseña."
        else:
            conn = get_connection()
            try:
                cur = conn.cursor(dictionary=True)
                cur.execute(
                    "SELECT id_usuario, nombre, password_hash FROM usuario "
                    "WHERE rol = 'cliente' AND (correo = %s OR usuario = %s)", (ident, ident))
                u = cur.fetchone()
            finally:
                conn.close()
            try:
                valido = bool(u) and check_password_hash(u["password_hash"], clave)
            except ValueError:
                valido = False
            if valido:
                session.clear()
                session["id_usuario"] = u["id_usuario"]
                session["nombre"] = u["nombre"]
                session["rol"] = "cliente"
                return redirect(url_for("cliente_menu"))
            mensaje = "Correo o usuario, o contraseña, incorrectos."
    return render_template("cliente_login.html", error=mensaje, ident=ident)


@app.route("/cliente/logout")
def cliente_logout():
    session.clear()
    return redirect(url_for("cliente_login"))


# ----------------------------------------------------------------------
# Interfaz del cliente (CU-03 Registrar Pedido)
# ----------------------------------------------------------------------
MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
NOMBRE_SERVICIO = {"impresion": "Impresión", "copiado": "Copiado",
                   "diseno": "Diseño", "engargolado": "Engargolado"}


def fecha_corta(f):
    return f"{f.day} {MESES[f.month - 1]}"


def preparar_pedido(p):
    """Arma los textos que se muestran en la tarjeta de un pedido."""
    s = p["servicio"]
    tam = (p["tamano_hojas"] or "").lower()
    if s in ("impresion", "copiado"):
        n = p["num_copias"] or 1
        partes = [f"{n} copia{'s' if n != 1 else ''}", tam, "a color" if p["es_color"] else "B y N"]
    elif s == "diseno":
        partes = [p["tipo_diseno"] or "", tam]
    else:
        partes = [f"{p['tipo_engargolado'] or ''} {(p['color_pastas'] or '').lower()}".strip(), tam]
    desc = (p["descripcion"] or "").strip() or "Sin descripción"
    if len(desc) > 60:
        desc = desc[:57] + "..."
    return {"folio": p["folio"], "servicio": s, "servicio_nombre": NOMBRE_SERVICIO[s],
            "estado": p["estado"], "desc": desc,
            "detalle": " · ".join(x for x in partes if x), "fecha": fecha_corta(p["fecha_registro"])}


@app.route("/cliente/menu")
@solo_cliente
def cliente_menu():
    """Menú principal del cliente: estado de sus pedidos (RF-05, RF-18) y avisos (RF-04)."""
    id_cliente = session["id_usuario"]
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(
            """SELECT id_pedido AS folio, servicio, estado, es_color, num_copias, tipo_diseno,
                      tipo_engargolado, tamano_hojas, color_pastas, descripcion, fecha_registro
               FROM pedido WHERE id_cliente = %s
               ORDER BY fecha_registro DESC, id_pedido DESC""", (id_cliente,))
        pedidos = [preparar_pedido(p) for p in cur.fetchall()]
        cur.execute(
            """SELECT mensaje, fecha_envio, leida FROM notificacion WHERE id_usuario = %s
               ORDER BY fecha_envio DESC, id_notificacion DESC LIMIT 10""", (id_cliente,))
        notifs = [{"mensaje": n["mensaje"], "fecha": fecha_corta(n["fecha_envio"]), "leida": n["leida"]}
                  for n in cur.fetchall()]
    finally:
        conn.close()
    resumen = {"pendientes": sum(p["estado"] == "pendiente" for p in pedidos),
               "listos": sum(p["estado"] == "listo" for p in pedidos)}
    return render_template("cliente.html", nombre=session["nombre"], pedidos=pedidos, resumen=resumen,
                           notifs=notifs, hay_sin_leer=any(not n["leida"] for n in notifs))


@app.route("/pedido/<int:folio>/cancelar", methods=["POST"])
def cancelar_pedido(folio):
    """RF-17 / RN-03: el cliente solo puede cancelar su pedido si está pendiente."""
    if session.get("rol") != "cliente":
        return error("Su sesión terminó. Inicie sesión de nuevo.", 401)
    id_cliente = session["id_usuario"]
    ruta = None
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT estado FROM pedido WHERE id_pedido = %s AND id_cliente = %s", (folio, id_cliente))
        fila = cur.fetchone()
        if not fila:
            flash("El pedido no existe.", "err")
            return error("El pedido no existe.", 404)
        if fila["estado"] != "pendiente":
            flash("Solo se puede cancelar un pedido pendiente.", "err")
            return error("Solo se puede cancelar un pedido pendiente.", 409)
        cur.execute("SELECT ruta FROM archivo WHERE id_pedido = %s", (folio,))
        archivo = cur.fetchone()
        ruta = archivo["ruta"] if archivo else None
        # Se borra el pedido; su archivo y notificaciones se eliminan en cascada (ON DELETE CASCADE)
        cur.execute("DELETE FROM pedido WHERE id_pedido = %s AND id_cliente = %s AND estado = 'pendiente'",
                    (folio, id_cliente))
        if cur.rowcount != 1:
            conn.rollback()
            flash("Solo se puede cancelar un pedido pendiente.", "err")
            return error("Solo se puede cancelar un pedido pendiente.", 409)
        conn.commit()
    except mysql.connector.Error as e:
        conn.rollback()
        print("Error al cancelar pedido:", e)
        flash("No se pudo cancelar el pedido. Intente de nuevo.", "err")
        return error("No se pudo cancelar el pedido.", 500)
    finally:
        conn.close()

    if ruta:  # también se borra el archivo guardado en el servidor
        carpeta = os.path.join(BASE, "uploads")
        destino = os.path.abspath(os.path.join(BASE, ruta))
        if destino.startswith(carpeta + os.sep) and os.path.isfile(destino):
            try:
                os.remove(destino)
            except OSError:
                pass
    flash(f"Pedido #{folio} cancelado correctamente.", "ok")
    return jsonify(ok=True)


@app.route("/cliente/notificaciones/leer", methods=["POST"])
def notificaciones_leer():
    """Marca como leídas las notificaciones del cliente al abrir la campana."""
    if session.get("rol") != "cliente":
        return error("Su sesión terminó.", 401)
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE notificacion SET leida = TRUE WHERE id_usuario = %s AND leida = FALSE",
                    (session["id_usuario"],))
        conn.commit()
    finally:
        conn.close()
    return jsonify(ok=True)


@app.route("/pedido", methods=["POST"])
def registrar_pedido():
    """CU-03 Registrar Pedido: valida, guarda pedido y archivo en una transacción."""
    if session.get("rol") != "cliente":
        return error("Su sesión terminó. Inicie sesión de nuevo.", 401)
    id_cliente = session["id_usuario"]
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
            (id_cliente, servicio, entrega, es_color, num_copias,
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

        cur.execute("SELECT id_pedido AS folio, estado FROM pedido WHERE id_pedido = %s", (folio,))
        fila = cur.fetchone()
        return jsonify(ok=True, folio=fila["folio"], estado=fila["estado"])
    except Exception as e:
        conn.rollback()
        print("Error al registrar pedido:", e)
        return error("No se pudo registrar el pedido. Intente de nuevo.", 500)
    finally:
        conn.close()


# ----------------------------------------------------------------------
# Empleado: vista mínima temporal. PENDIENTE: login propio del empleado (RN-05).
# ----------------------------------------------------------------------
@app.route("/empleado")
def lista_empleado():
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
