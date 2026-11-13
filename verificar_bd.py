"""Compara la base de datos REAL (la de tu MySQL) con el diagrama de Punto Escolar.

Uso:   python verificar_bd.py
No modifica nada: solo lee la estructura y te dice qué coincide y qué no.
"""
from db import get_connection

# Lo que dice el diagrama: tabla -> {columna: (tipo, llave)}   llave: PK, UK o ""
DIAGRAMA = {
    "usuario": {
        "id_usuario": ("int", "PK"), "rol": ("enum", ""), "nombre": ("varchar", ""),
        "usuario": ("varchar", "UK"), "correo": ("varchar", "UK"), "password_hash": ("varchar", ""),
    },
    "pedido": {
        "id_pedido": ("int", "PK"), "id_cliente": ("int", ""), "servicio": ("enum", ""),
        "estado": ("enum", ""), "tipo_entrega": ("enum", ""), "es_color": ("tinyint", ""),
        "tipo_diseno": ("varchar", ""), "tipo_engargolado": ("varchar", ""),
        "tamano_hojas": ("varchar", ""), "color_pastas": ("varchar", ""),
        "descripcion": ("text", ""), "fecha_registro": ("timestamp", ""),
    },
    "archivo": {
        "id_archivo": ("int", "PK"), "id_pedido": ("int", "UK"), "nombre": ("varchar", ""),
        "formato": ("varchar", ""), "ruta": ("varchar", ""), "fecha_recepcion": ("timestamp", ""),
    },
    "notificacion": {
        "id_notificacion": ("int", "PK"), "id_pedido": ("int", ""), "id_usuario": ("int", ""),
        "mensaje": ("varchar", ""), "fecha_envio": ("timestamp", ""), "leida": ("tinyint", ""),
    },
}
VALORES_ENUM = {
    ("usuario", "rol"): {"cliente", "empleado"},
    ("pedido", "servicio"): {"impresion", "copiado", "diseno", "engargolado"},
    ("pedido", "estado"): {"pendiente", "listo", "entregado"},
    ("pedido", "tipo_entrega"): {"digital", "usb"},
}
LLAVES_FORANEAS = {
    ("pedido", "id_cliente"): ("usuario", "id_usuario"),
    ("archivo", "id_pedido"): ("pedido", "id_pedido"),
    ("notificacion", "id_pedido"): ("pedido", "id_pedido"),
    ("notificacion", "id_usuario"): ("usuario", "id_usuario"),
}
# Columnas que la aplicación usa y que el diagrama no dibuja
EXTRAS_QUE_USA_LA_APP = {("pedido", "num_copias")}
TRIGGERS = {"trg_pedido_bi", "trg_pedido_ai", "trg_pedido_bu", "trg_pedido_au",
            "trg_pedido_bd", "trg_archivo_bi", "trg_archivo_bd"}
LLAVE = {"pri": "PK", "uni": "UK"}


def txt(x):
    """MySQL a veces devuelve bytes en lugar de texto."""
    if isinstance(x, (bytes, bytearray)):
        x = x.decode()
    return str(x).lower()


def leer(cur, consulta):
    cur.execute(consulta)
    return [{k: txt(v) if v is not None else None for k, v in f.items()} for f in cur.fetchall()]


def comparar(columnas, fks, triggers):
    """Devuelve (aciertos, avisos, errores) como listas de texto."""
    ok, avisos, errores = [], [], []
    real = {}
    for f in columnas:
        real.setdefault(f["t"], {})[f["c"]] = f

    for tabla, cols in DIAGRAMA.items():
        if tabla not in real:
            errores.append(f"Falta la tabla {tabla}.")
            continue
        malas = 0
        for col, (tipo, llave) in cols.items():
            f = real[tabla].get(col)
            if not f:
                errores.append(f"{tabla}.{col}: no existe en tu base de datos.")
                malas += 1
                continue
            if f["d"] != tipo:
                errores.append(f"{tabla}.{col}: el diagrama pide {tipo} y tu base tiene {f['d']}.")
                malas += 1
            if llave and LLAVE.get(f["k"]) != llave:
                errores.append(f"{tabla}.{col}: debería ser {llave} y no lo es.")
                malas += 1
            valores = VALORES_ENUM.get((tabla, col))
            if valores and f["d"] == "enum":
                reales = set(f["ct"][5:-1].replace("'", "").split(","))
                if reales != valores:
                    errores.append(f"{tabla}.{col}: valores {sorted(reales)}, el diagrama pide {sorted(valores)}.")
                    malas += 1
        for col in real[tabla]:
            if col not in cols:
                if (tabla, col) in EXTRAS_QUE_USA_LA_APP:
                    avisos.append(f"{tabla}.{col}: no sale en el diagrama, pero la app lo necesita. Se deja.")
                else:
                    avisos.append(f"{tabla}.{col}: está en tu base pero no en el diagrama.")
        if not malas:
            ok.append(f"Tabla {tabla}: columnas y llaves coinciden con el diagrama.")

    reales_fk = {(f["t"], f["c"]): (f["rt"], f["rc"]) for f in fks}
    for (t, c), destino in LLAVES_FORANEAS.items():
        if reales_fk.get((t, c)) == destino:
            ok.append(f"Relación {t}.{c} -> {destino[0]}.{destino[1]} existe.")
        else:
            errores.append(f"Falta la relación (llave foránea) {t}.{c} -> {destino[0]}.{destino[1]}.")

    for falta in sorted(TRIGGERS - {t["n"] for t in triggers}):
        errores.append(f"Falta el trigger {falta} (reglas de negocio).")
    if not TRIGGERS - {t["n"] for t in triggers}:
        ok.append("Los 7 triggers de reglas de negocio existen.")
    return ok, avisos, errores


def main():
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        columnas = leer(cur, """SELECT table_name AS t, column_name AS c, data_type AS d,
                                       column_type AS ct, column_key AS k
                                FROM information_schema.columns WHERE table_schema = DATABASE()""")
        fks = leer(cur, """SELECT table_name AS t, column_name AS c, referenced_table_name AS rt,
                                  referenced_column_name AS rc
                           FROM information_schema.key_column_usage
                           WHERE table_schema = DATABASE() AND referenced_table_name IS NOT NULL""")
        triggers = leer(cur, """SELECT trigger_name AS n FROM information_schema.triggers
                                WHERE trigger_schema = DATABASE()""")
    finally:
        conn.close()

    ok, avisos, errores = comparar(columnas, fks, triggers)
    for x in ok:
        print("  [OK]       " + x)
    for x in avisos:
        print("  [AVISO]    " + x)
    for x in errores:
        print("  [DIFERENTE]" + " " + x)
    print()
    if errores:
        print(f"Resultado: {len(errores)} diferencia(s) con el diagrama. Revisa las líneas [DIFERENTE].")
    else:
        print("Resultado: tu base de datos coincide con el diagrama.")


if __name__ == "__main__":
    main()
