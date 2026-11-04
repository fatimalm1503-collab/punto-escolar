from db import get_connection

conn = get_connection()
cur = conn.cursor(dictionary=True)
cur.execute("SELECT id_pedido, servicio, estado FROM pedido")
for fila in cur.fetchall():
    print(fila)
cur.close()
conn.close()