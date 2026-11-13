-- =====================================================================
-- DATOS DE PRUEBA · Punto Escolar
-- Úsalo cuando las tablas estén vacías (o para reiniciar los datos de prueba).
--
-- ADVERTENCIA: lo primero que hace es VACIAR las 4 tablas (usuario, pedido,
-- archivo, notificacion) y reiniciar sus folios/ids desde 1. Si ya tienes
-- cuentas o pedidos que quieras conservar, no lo ejecutes.
--
-- Cuentas de prueba (contraseñas REALES, ya cifradas):
--   Empleados:  empleado1    / empleado123      laura.gomez  / empleado123
--   Clientes:   martha.silva / cliente123       juan.perez   / cliente123
-- (La app ya no usa un cliente fijo: cada cliente entra con su propia cuenta.)
-- =====================================================================
USE punto_escolar;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE notificacion;
TRUNCATE TABLE archivo;
TRUNCATE TABLE pedido;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Usuarios (ids fijos: 1 empleado, 2 Martha, 3 Juan, 4 empleada)
INSERT INTO usuario (id_usuario, rol, nombre, usuario, correo, password_hash) VALUES
    (1, 'empleado', 'Empleado Mostrador', 'empleado1',    'empleado1@example.com',    'pbkdf2:sha256:1000000$3D4MuJs6GECMvwew$f59b3360d27b1ad28bd236826a3888d4adb2fcef97469f575dca1b496c3d8394'),
    (2, 'cliente',  'Martha Silva',       'martha.silva', 'martha.silva@example.com', 'pbkdf2:sha256:1000000$07KOsggmOdDjhGx5$30df00e919df569ffd60262138803c115d9ea616a7d179df8798cf9588e2cdc8'),
    (3, 'cliente',  'Juan Pérez',         'juan.perez',   'juan.perez@example.com',   'pbkdf2:sha256:1000000$07KOsggmOdDjhGx5$30df00e919df569ffd60262138803c115d9ea616a7d179df8798cf9588e2cdc8'),
    (4, 'empleado', 'Laura Gómez',        'laura.gomez',  'laura.gomez@example.com',  'pbkdf2:sha256:1000000$3D4MuJs6GECMvwew$f59b3360d27b1ad28bd236826a3888d4adb2fcef97469f575dca1b496c3d8394');

-- 2. Pedidos (los folios salen 1 a 8, en este orden). Todos nacen 'pendiente'
--    por trigger; más abajo se avanzan de estado como lo haría un empleado.
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tipo_diseno, tipo_engargolado, tamano_hojas, color_pastas, descripcion, fecha_registro) VALUES
    -- Folio 1: impresión, digital, B/N
    (2, 'impresion',   'digital', FALSE, 20,   NULL,         NULL,        'Carta',  NULL,    'Tarea de matemáticas',                 NOW() - INTERVAL 3 DAY),
    -- Folio 2: engargolado, USB
    (2, 'engargolado', 'usb',     NULL,  NULL, NULL,         'Espiral',   'Carta',  'Azul',  'Tarea final de 80 hojas',              NOW() - INTERVAL 2 DAY),
    -- Folio 3: diseño, digital
    (2, 'diseno',      'digital', NULL,  NULL, 'Invitación', NULL,        'Carta',  NULL,    'Invitación de cumpleaños',             NOW() - INTERVAL 1 DAY),
    -- Folio 4: copiado, USB, color
    (3, 'copiado',     'usb',     TRUE,  10,   NULL,         NULL,        'Carta',  NULL,    'Copias a color',                       NOW() - INTERVAL 20 HOUR),
    -- Folio 5: impresión, digital, color
    (3, 'impresion',   'digital', TRUE,  5,    NULL,         NULL,        'Carta',  NULL,    'Cartel para exposición de biología',   NOW() - INTERVAL 8 HOUR),
    -- Folio 6: engargolado, digital
    (3, 'engargolado', 'digital', NULL,  NULL, NULL,         'Térmico',   'Oficio', 'Negro', 'Tesina para entregar el viernes',      NOW() - INTERVAL 5 HOUR),
    -- Folio 7: diseño, digital
    (2, 'diseno',      'digital', NULL,  NULL, 'Cartel',     NULL,        'A4',     NULL,    'Cartel para el evento de la escuela',  NOW() - INTERVAL 2 HOUR),
    -- Folio 8: impresión, USB, B/N
    (2, 'impresion',   'usb',     FALSE, 40,   NULL,         NULL,        'Carta',  NULL,    'Apuntes de historia',                  NOW() - INTERVAL 30 MINUTE);

-- 3. Archivos (solo los pedidos con entrega digital: 1, 3, 5, 6 y 7)
INSERT INTO archivo (id_pedido, nombre, formato, ruta) VALUES
    (1, 'tarea_matematicas.pdf', 'pdf',  'uploads/pedido_1_tarea_matematicas.pdf'),
    (3, 'invitacion.docx',       'docx', 'uploads/pedido_3_invitacion.docx'),
    (5, 'cartel_biologia.pdf',   'pdf',  'uploads/pedido_5_cartel_biologia.pdf'),
    (6, 'tesina.pdf',            'pdf',  'uploads/pedido_6_tesina.pdf'),
    (7, 'cartel_evento.png',     'png',  'uploads/pedido_7_cartel_evento.png');

-- 4. Estados: el folio 1 ya fue entregado; los folios 2 y 5 están listos;
--    el resto sigue pendiente. (Al pasar a 'listo' el trigger notifica al cliente.)
UPDATE pedido SET estado = 'listo'     WHERE id_pedido IN (1, 2, 5);
UPDATE pedido SET estado = 'entregado' WHERE id_pedido = 1;

-- 5. Comprobación rápida
SELECT id_pedido AS folio, servicio, tipo_entrega, estado FROM pedido ORDER BY id_pedido;
