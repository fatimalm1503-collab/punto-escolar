-- =====================================================================
-- DATOS DE PRUEBA · Punto Escolar  (versión completa)
-- Llena LAS 4 TABLAS (usuario, pedido, archivo, notificacion) con datos
-- que cubren todos los casos, y al final comprueba que todo esté en orden.
--
-- ADVERTENCIA: lo primero que hace es VACIAR las 4 tablas y reiniciar sus
-- folios/ids desde 1. Si tienes cuentas o pedidos que quieras conservar,
-- no lo ejecutes.
--
-- CUENTAS DE PRUEBA (contraseñas reales, ya cifradas):
--   Empleados:  empleado1    / empleado123     (Empleado Mostrador)
--               laura.gomez  / empleado123     (Laura Gómez)
--   Clientes:   martha.silva / cliente123      (Martha Silva)
--               juan.perez   / cliente123      (Juan Pérez)
--               ana.torres   / cliente123      (Ana Torres)
--
-- QUÉ CUBRE:
--   usuario      2 empleados y 3 clientes.
--   pedido       10 pedidos: los 4 servicios, entrega digital y USB,
--                color y blanco y negro, y los 3 estados.
--   archivo      6 archivos (uno por cada pedido digital). Los archivos reales
--                vienen en la carpeta uploads/ para probar "Descargar archivo".
--   notificacion se crean SOLAS por los triggers: aviso USB a cada empleado
--                y aviso "listo" al cliente. Algunas quedan leídas y otras no.
-- =====================================================================
USE punto_escolar;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE notificacion;
TRUNCATE TABLE archivo;
TRUNCATE TABLE pedido;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. USUARIOS  (ids fijos: 1 y 4 empleados; 2, 3 y 5 clientes)
-- ---------------------------------------------------------------------
INSERT INTO usuario (id_usuario, rol, nombre, usuario, correo, password_hash) VALUES
    (1, 'empleado', 'Empleado Mostrador', 'empleado1',    'empleado1@example.com',    'pbkdf2:sha256:1000000$3D4MuJs6GECMvwew$f59b3360d27b1ad28bd236826a3888d4adb2fcef97469f575dca1b496c3d8394'),
    (2, 'cliente',  'Martha Silva',       'martha.silva', 'martha.silva@example.com', 'pbkdf2:sha256:1000000$07KOsggmOdDjhGx5$30df00e919df569ffd60262138803c115d9ea616a7d179df8798cf9588e2cdc8'),
    (3, 'cliente',  'Juan Pérez',         'juan.perez',   'juan.perez@example.com',   'pbkdf2:sha256:1000000$07KOsggmOdDjhGx5$30df00e919df569ffd60262138803c115d9ea616a7d179df8798cf9588e2cdc8'),
    (4, 'empleado', 'Laura Gómez',        'laura.gomez',  'laura.gomez@example.com',  'pbkdf2:sha256:1000000$3D4MuJs6GECMvwew$f59b3360d27b1ad28bd236826a3888d4adb2fcef97469f575dca1b496c3d8394'),
    (5, 'cliente',  'Ana Torres',         'ana.torres',   'ana.torres@example.com',   'pbkdf2:sha256:1000000$07KOsggmOdDjhGx5$30df00e919df569ffd60262138803c115d9ea616a7d179df8798cf9588e2cdc8');

-- ---------------------------------------------------------------------
-- 2. PEDIDOS  (los folios salen del 1 al 10, en este orden)
--    Todos nacen 'pendiente' por trigger; más abajo se avanzan de estado.
--    Los pedidos con USB generan, por trigger, un aviso para cada empleado.
-- ---------------------------------------------------------------------
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tipo_diseno, tipo_engargolado, tamano_hojas, color_pastas, descripcion, fecha_registro) VALUES
    -- Folio 1: impresión, digital, B/N                    -> terminará ENTREGADO
    (2, 'impresion',   'digital', FALSE, 20,   NULL,         NULL,        'Carta',  NULL,    'Tarea de matemáticas',                NOW() - INTERVAL 3 DAY),
    -- Folio 2: engargolado, USB                           -> terminará LISTO
    (2, 'engargolado', 'usb',     NULL,  NULL, NULL,         'Espiral',   'Carta',  'Azul',  'Tarea final de 80 hojas',             NOW() - INTERVAL 2 DAY),
    -- Folio 3: diseño, digital                            -> queda PENDIENTE
    (2, 'diseno',      'digital', NULL,  NULL, 'Invitación', NULL,        'Carta',  NULL,    'Invitación de cumpleaños',            NOW() - INTERVAL 1 DAY),
    -- Folio 4: copiado, USB, a color                      -> queda PENDIENTE
    (3, 'copiado',     'usb',     TRUE,  10,   NULL,         NULL,        'Carta',  NULL,    'Copias a color',                      NOW() - INTERVAL 20 HOUR),
    -- Folio 5: impresión, digital, a color                -> terminará LISTO
    (3, 'impresion',   'digital', TRUE,  5,    NULL,         NULL,        'Carta',  NULL,    'Cartel para exposición de biología',  NOW() - INTERVAL 8 HOUR),
    -- Folio 6: engargolado, digital                       -> queda PENDIENTE
    (3, 'engargolado', 'digital', NULL,  NULL, NULL,         'Térmico',   'Oficio', 'Negro', 'Tesina para entregar el viernes',     NOW() - INTERVAL 5 HOUR),
    -- Folio 7: diseño, digital                            -> queda PENDIENTE
    (2, 'diseno',      'digital', NULL,  NULL, 'Cartel',     NULL,        'A4',     NULL,    'Cartel para el evento de la escuela', NOW() - INTERVAL 2 HOUR),
    -- Folio 8: impresión, USB, B/N                        -> queda PENDIENTE
    (2, 'impresion',   'usb',     FALSE, 40,   NULL,         NULL,        'Carta',  NULL,    'Apuntes de historia',                 NOW() - INTERVAL 30 MINUTE),
    -- Folio 9: copiado, digital, B/N                      -> terminará ENTREGADO
    (5, 'copiado',     'digital', FALSE, 100,  NULL,         NULL,        'Carta',  NULL,    'Copias de formularios',               NOW() - INTERVAL 6 HOUR),
    -- Folio 10: diseño, USB                               -> queda PENDIENTE
    (5, 'diseno',      'usb',     NULL,  NULL, 'Logotipo',   NULL,        'Carta',  NULL,    'Logotipo para un negocio familiar',   NOW() - INTERVAL 10 MINUTE);

-- ---------------------------------------------------------------------
-- 3. ARCHIVOS  (solo los pedidos con entrega digital: 1, 3, 5, 6, 7 y 9)
--    Los archivos reales están en la carpeta uploads/ del proyecto.
-- ---------------------------------------------------------------------
INSERT INTO archivo (id_pedido, nombre, formato, ruta) VALUES
    (1, 'tarea_matematicas.pdf', 'pdf',  'uploads/pedido_1_tarea_matematicas.pdf'),
    (3, 'invitacion.docx',       'docx', 'uploads/pedido_3_invitacion.docx'),
    (5, 'cartel_biologia.pdf',   'pdf',  'uploads/pedido_5_cartel_biologia.pdf'),
    (6, 'tesina.pdf',            'pdf',  'uploads/pedido_6_tesina.pdf'),
    (7, 'cartel_evento.png',     'png',  'uploads/pedido_7_cartel_evento.png'),
    (9, 'formularios.pdf',       'pdf',  'uploads/pedido_9_formularios.pdf');

-- ---------------------------------------------------------------------
-- 4. ESTADOS: avanzan como lo haría un empleado (solo pendiente -> listo -> entregado).
--    Al pasar a 'listo', el trigger avisa al cliente.
--    Folios 1 y 9 -> entregado | folios 2 y 5 -> listo | el resto sigue pendiente.
-- ---------------------------------------------------------------------
UPDATE pedido SET estado = 'listo'     WHERE id_pedido IN (1, 2, 5, 9);
UPDATE pedido SET estado = 'entregado' WHERE id_pedido IN (1, 9);

-- ---------------------------------------------------------------------
-- 5. AVISOS LEÍDOS: algunos ya vistos y otros sin leer, para probar la campana.
--    - empleado1 ya vio todos sus avisos de USB.
--    - Los avisos "listo" de los pedidos ya entregados (1 y 9) están leídos.
--    Quedan SIN LEER: los avisos de laura.gomez y los "listo" de los folios 2 y 5.
-- ---------------------------------------------------------------------
UPDATE notificacion SET leida = TRUE WHERE id_usuario = 1;
UPDATE notificacion SET leida = TRUE WHERE id_pedido IN (1, 9);

-- =====================================================================
-- 6. VERIFICACIÓN AUTOMÁTICA
--    Muestra una sola tabla. Todas las filas deben decir OK en "resultado".
--    Si alguna dice FALLA, mándame esa fila.
-- =====================================================================
SELECT prueba, esperado, obtenido, IF(esperado = obtenido, 'OK', 'FALLA') AS resultado
FROM (
    SELECT  1 AS orden, 'Usuarios en total'                            AS prueba,  5 AS esperado, (SELECT COUNT(*) FROM usuario) AS obtenido
    UNION ALL SELECT  2, 'Empleados',                                        2, (SELECT COUNT(*) FROM usuario WHERE rol = 'empleado')
    UNION ALL SELECT  3, 'Clientes',                                         3, (SELECT COUNT(*) FROM usuario WHERE rol = 'cliente')
    UNION ALL SELECT  4, 'Pedidos en total',                                10, (SELECT COUNT(*) FROM pedido)
    UNION ALL SELECT  5, 'Pedidos pendientes',                               6, (SELECT COUNT(*) FROM pedido WHERE estado = 'pendiente')
    UNION ALL SELECT  6, 'Pedidos listos',                                   2, (SELECT COUNT(*) FROM pedido WHERE estado = 'listo')
    UNION ALL SELECT  7, 'Pedidos entregados',                               2, (SELECT COUNT(*) FROM pedido WHERE estado = 'entregado')
    UNION ALL SELECT  8, 'Servicios distintos (impresion, copiado, diseno, engargolado)', 4, (SELECT COUNT(DISTINCT servicio) FROM pedido)
    UNION ALL SELECT  9, 'Pedidos con entrega digital',                      6, (SELECT COUNT(*) FROM pedido WHERE tipo_entrega = 'digital')
    UNION ALL SELECT 10, 'Pedidos con entrega USB',                          4, (SELECT COUNT(*) FROM pedido WHERE tipo_entrega = 'usb')
    UNION ALL SELECT 11, 'Clientes que tienen pedidos',                      3, (SELECT COUNT(DISTINCT id_cliente) FROM pedido)
    UNION ALL SELECT 12, 'Archivos en total',                                6, (SELECT COUNT(*) FROM archivo)
    UNION ALL SELECT 13, 'Pedidos digitales SIN archivo (debe ser 0)',       0, (SELECT COUNT(*) FROM pedido p WHERE p.tipo_entrega = 'digital' AND NOT EXISTS (SELECT 1 FROM archivo a WHERE a.id_pedido = p.id_pedido))
    UNION ALL SELECT 14, 'Pedidos USB CON archivo (debe ser 0)',             0, (SELECT COUNT(*) FROM pedido p WHERE p.tipo_entrega = 'usb' AND EXISTS (SELECT 1 FROM archivo a WHERE a.id_pedido = p.id_pedido))
    UNION ALL SELECT 15, 'Avisos USB para empleados (4 pedidos x 2 empleados)', 8, (SELECT COUNT(*) FROM notificacion n JOIN usuario u ON u.id_usuario = n.id_usuario WHERE u.rol = 'empleado')
    UNION ALL SELECT 16, 'Avisos "listo" para clientes (folios 1, 2, 5 y 9)', 4, (SELECT COUNT(*) FROM notificacion n JOIN usuario u ON u.id_usuario = n.id_usuario WHERE u.rol = 'cliente')
    UNION ALL SELECT 17, 'Avisos leídos',                                    6, (SELECT COUNT(*) FROM notificacion WHERE leida = TRUE)
    UNION ALL SELECT 18, 'Avisos sin leer',                                  6, (SELECT COUNT(*) FROM notificacion WHERE leida = FALSE)
    UNION ALL SELECT 19, 'Triggers (reglas de negocio) creados',             7, (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = DATABASE())
    UNION ALL SELECT 20, 'Relaciones (llaves foráneas) creadas',             4, (SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE())
) AS comprobaciones
ORDER BY orden;

-- Para ver el contenido de cada tabla, ejecuta estas líneas una por una:
-- SELECT * FROM usuario;
-- SELECT * FROM pedido;
-- SELECT * FROM archivo;
-- SELECT * FROM notificacion ORDER BY id_notificacion;
