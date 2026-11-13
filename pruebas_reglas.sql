-- =====================================================================
-- PRUEBAS DE LAS REGLAS DE LA BASE DE DATOS · Punto Escolar
-- Úsalo DESPUÉS de ejecutar datos_prueba.sql.
--
-- CÓMO USARLO EN WORKBENCH (importante):
--   NO ejecutes todo el archivo de golpe. Cada prueba de la PARTE A debe
--   FALLAR a propósito, y Workbench se detiene en el primer error.
--   Haz esto con cada prueba, una por una:
--     1. Haz clic dentro de la línea del INSERT / UPDATE / DELETE.
--     2. Pulsa Ctrl + Enter (ejecuta solo esa sentencia).
--     3. Mira el panel "Output" de abajo: debe salir el ERROR indicado.
--   Si en una prueba de la PARTE A NO sale error, esa regla no está funcionando.
--
-- NOTA: un intento fallido también "gasta" un número de folio (así funciona
-- MySQL). Cuando termines, vuelve a ejecutar datos_prueba.sql para dejar
-- los folios del 1 al 10 limpios.
-- =====================================================================
USE punto_escolar;

-- =====================================================================
-- PARTE A: ESTAS PRUEBAS DEBEN DAR ERROR
-- =====================================================================

-- A1. Solo un cliente puede registrar pedidos (el usuario 1 es empleado).
--     Error esperado: "Solo un cliente puede registrar un pedido"
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tamano_hojas)
VALUES (1, 'impresion', 'digital', FALSE, 1, 'Carta');

-- A2. El estado no puede saltarse pasos (el folio 3 está pendiente).
--     Error esperado: "RN-01: el estado solo puede avanzar pendiente, listo, entregado"
UPDATE pedido SET estado = 'entregado' WHERE id_pedido = 3;

-- A3. El estado no puede retroceder (el folio 2 está listo).
--     Error esperado: "RN-01: ..."
UPDATE pedido SET estado = 'pendiente' WHERE id_pedido = 2;

-- A4. Un pedido ya entregado no se puede cancelar (el folio 1 está entregado).
--     Error esperado: "RN-03: solo se puede cancelar un pedido pendiente"
DELETE FROM pedido WHERE id_pedido = 1;

-- A5. Un pedido con USB no admite archivo digital (el folio 2 es USB).
--     Error esperado: "RN-06: un pedido con entrega en USB no admite archivo digital"
INSERT INTO archivo (id_pedido, nombre, formato, ruta)
VALUES (2, 'intruso.pdf', 'pdf', 'uploads/pedido_2_intruso.pdf');

-- A6. El archivo solo se elimina si el pedido está entregado (el folio 3 está pendiente).
--     Error esperado: "RN-02: el archivo solo se puede eliminar si el pedido esta entregado"
DELETE FROM archivo WHERE id_pedido = 3;

-- A7. Un pedido tiene como máximo un archivo (el folio 1 ya tiene uno).
--     Error esperado: "Duplicate entry '1' for key 'archivo.id_pedido'"
INSERT INTO archivo (id_pedido, nombre, formato, ruta)
VALUES (1, 'otro.pdf', 'pdf', 'uploads/pedido_1_otro.pdf');

-- A8. Impresión sin modo (color/B-N) ni número de copias.
--     Error esperado: "Check constraint 'chk_servicio_color' is violated"
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, tamano_hojas)
VALUES (2, 'impresion', 'digital', 'Carta');

-- A9. Número de copias en cero.
--     Error esperado: "Check constraint 'chk_num_copias' is violated"
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tamano_hojas)
VALUES (2, 'copiado', 'digital', FALSE, 0, 'Carta');

-- A10. Engargolado sin color de pastas.
--      Error esperado: "Check constraint 'chk_servicio_engargolado' is violated"
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, tipo_engargolado, tamano_hojas)
VALUES (2, 'engargolado', 'usb', 'Espiral', 'Carta');

-- A11. Usuario repetido (empleado1 ya existe).
--      Error esperado: "Duplicate entry 'empleado1' for key 'usuario.usuario'"
INSERT INTO usuario (rol, nombre, usuario, correo, password_hash)
VALUES ('cliente', 'Repetido', 'empleado1', 'otro@example.com', 'x');

-- A12. Correo repetido (martha.silva@example.com ya existe).
--      Error esperado: "Duplicate entry 'martha.silva@example.com' for key 'usuario.correo'"
INSERT INTO usuario (rol, nombre, usuario, correo, password_hash)
VALUES ('cliente', 'Repetida', 'otra.persona', 'martha.silva@example.com', 'x');

-- A13. Pedido de un cliente que no existe.
--      Error esperado: "Cannot add or update a child row: a foreign key constraint fails"
--      (o "Solo un cliente puede registrar un pedido", según el orden en que MySQL lo detecte)
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tamano_hojas)
VALUES (99, 'impresion', 'digital', FALSE, 1, 'Carta');

-- =====================================================================
-- PARTE B: ESTAS PRUEBAS SÍ DEBEN FUNCIONAR (sin error)
-- Cambian los datos: al terminar, vuelve a ejecutar datos_prueba.sql.
-- =====================================================================

-- B1. El folio 3 (pendiente) pasa a listo y el cliente recibe un aviso.
UPDATE pedido SET estado = 'listo' WHERE id_pedido = 3;
SELECT mensaje, leida FROM notificacion WHERE id_pedido = 3;   -- debe salir 1 fila: "Tu pedido 3 ya está listo."

-- B2. El archivo de un pedido ENTREGADO sí se puede eliminar (folio 1).
DELETE FROM archivo WHERE id_pedido = 1;
SELECT COUNT(*) AS archivos_del_folio_1 FROM archivo WHERE id_pedido = 1;   -- debe salir 0

-- B3. Un pedido PENDIENTE sí se puede cancelar (folio 10, USB).
--     Su aviso para los empleados se borra solo (en cascada).
DELETE FROM pedido WHERE id_pedido = 10;
SELECT COUNT(*) AS pedido_10 FROM pedido WHERE id_pedido = 10;               -- debe salir 0
SELECT COUNT(*) AS avisos_del_10 FROM notificacion WHERE id_pedido = 10;     -- debe salir 0
