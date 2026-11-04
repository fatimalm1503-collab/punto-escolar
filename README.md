# Punto Escolar

Sistema web de gestión de pedidos para la papelería y centro de impresión "Punto Escolar".

## Objetivo

Organizar y gestionar los pedidos de servicios (impresión, copiado, diseño y engargolado) realizados por los clientes, y dar seguimiento a su estado hasta la entrega.

## Usuarios

- **Cliente:** registra un pedido, elige la forma de entrega de su archivo (digital o USB) y recibe una notificación cuando su pedido está listo.
- **Empleado:** consulta los pedidos recibidos, cambia su estado (pendiente, listo, entregado) y notifica al cliente.

## Tecnologías

- Python 3.13 con Flask
- MySQL 8
- HTML, CSS y JavaScript
- `mysql-connector-python` y `python-dotenv`

## Estructura

```
punto-escolar/
├── app.py            # servidor Flask y rutas
├── db.py             # conexión a la base de datos
├── schema.sql        # creación de la BD (tablas, triggers y datos de prueba)
├── probar_bd.py      # prueba rápida de conexión
├── requirements.txt
├── .env.example      # plantilla de configuración
└── templates/
    ├── cliente.html  # CU-03 Registrar Pedido
    └── empleado.html # lista de pedidos (vista mínima)
```

## Cómo ejecutar el proyecto

### 1. Requisitos

Python 3.13, MySQL 8 con MySQL Workbench, y Git o GitHub Desktop.

### 2. Clonar el repositorio

```
git clone https://github.com/USUARIO/punto-escolar.git
```

(o *File → Clone repository* en GitHub Desktop). Cambia `USUARIO` por el dueño del repositorio.

### 3. Instalar las dependencias

```
python -m pip install -r requirements.txt
```

### 4. Crear el archivo `.env`

Copia `.env.example`, renómbralo a `.env` y escribe tu contraseña de MySQL en `DB_PASSWORD`. Este archivo no se sube a GitHub.

### 5. Crear la base de datos

1. Abre MySQL Workbench y entra a tu conexión local.
2. *File → Open SQL Script* y elige `schema.sql`.
3. Pulsa el rayo (⚡) para ejecutarlo.

> El script borra y vuelve a crear la base `punto_escolar`. Ejecútalo solo para reiniciar los datos.

### 6. Probar la conexión

```
python probar_bd.py
```

Debe imprimir los 4 pedidos de prueba.

### 7. Iniciar la aplicación

```
python app.py
```

Abre en el navegador:

- Cliente: http://127.0.0.1:5000
- Empleado (lista de pedidos): http://127.0.0.1:5000/empleado

Para ver la vista del cliente desde un celular en la misma red Wi-Fi, ejecuta `flask run --host 0.0.0.0` y entra con la IP de la computadora y el puerto 5000.

## Prueba de funcionamiento

1. Entra a http://127.0.0.1:5000 y pulsa **Registrar pedido**.
2. Completa los 3 pasos (para entrega digital, adjunta un archivo).
3. Verifica que aparece el folio y el estado "Pendiente".
4. En MySQL Workbench ejecuta `SELECT * FROM punto_escolar.pedido;` y comprueba la fila nueva.
5. Abre `/empleado` y verifica que el pedido aparece en la lista.

## Alcance actual y pendientes

- Hecho: conexión a MySQL, registro de pedidos (CU-03), lista de pedidos del empleado.
- Sin login por ahora: los pedidos se registran con un cliente de prueba (Martha Silva, `id_usuario = 2`).
- Pendiente: inicio de sesión y registro de usuarios, detalle del pedido y cambio de estado (CU-07), eliminar archivo, notificaciones en pantalla, cancelar pedido.
