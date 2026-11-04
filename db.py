import os
import mysql.connector
from dotenv import load_dotenv

# Lee los datos de conexión del archivo .env
load_dotenv()


def get_connection():
    """Abre y devuelve una conexión a la base de datos MySQL."""
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME", "punto_escolar"),
    )