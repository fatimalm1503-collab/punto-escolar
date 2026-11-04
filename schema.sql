-- =====================================================================
-- Script de la BD "Punto Escolar"  (U2-E2 / U2-E3)
-- Alineado con: RF-01 a RF-19 (sin RF-16), RN-01 a RN-07
-- (RN-03: el pedido solo se cancela en "pendiente").
-- Casos de uso críticos de E3: CU-03 Registrar Pedido y
-- CU-07 Menú Principal Empleado.
-- Motor: MySQL 8 / MariaDB 10.4+
--
-- EJECUCIÓN (desde la terminal, en la carpeta del proyecto):
--     mysql -u root -p < schema.sql
-- ADVERTENCIA: el DROP DATABASE borra todos los datos cada vez que
-- se ejecuta. Úsalo para reiniciar la BD, no antes de una demostración.
-- =====================================================================

-- 1. PREPARACIÓN DE LA BASE DE DATOS
DROP DATABASE IF EXISTS punto_escolar;
CREATE DATABASE punto_escolar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE punto_escolar;

-- =====================================================================
-- 2. TABLA USUARIO  (Cliente y Empleado: herencia de Usuario)
--    RF-10 inicio de sesión, RF-14 registrarse, RN-04, RN-05
-- =====================================================================
CREATE TABLE usuario (
    id_usuario     INT AUTO_INCREMENT PRIMARY KEY,
    rol            ENUM('cliente', 'empleado') NOT NULL,
    nombre         VARCHAR(100) NOT NULL,
    usuario        VARCHAR(50)  NOT NULL UNIQUE,     -- RF-10: inicia sesión con "usuario" y contraseña
    correo         VARCHAR(100) NOT NULL UNIQUE,     -- dato de registro (RF-14)
    password_hash  VARCHAR(255) NOT NULL             -- la contraseña se guarda cifrada, nunca en texto plano
);

-- =====================================================================
-- 3. TABLA PEDIDO
--    id_pedido ES EL FOLIO (RF-02): lo asigna el sistema de forma
--    automática, es único y nunca se repite, aunque el cliente sea el mismo.
-- =====================================================================
CREATE TABLE pedido (
    id_pedido        INT AUTO_INCREMENT PRIMARY KEY,                 -- folio (RF-02)
    id_cliente       INT NOT NULL,                                   -- el cliente "realiza" el pedido (RF-09)

    -- Tipo de trabajo y estado
    servicio         ENUM('impresion', 'copiado', 'diseno', 'engargolado') NOT NULL,
    estado           ENUM('pendiente', 'listo', 'entregado') NOT NULL DEFAULT 'pendiente',   -- RF-19

    -- Cómo entregará el archivo el cliente (RF-07): solo hay dos opciones.
    tipo_entrega     ENUM('digital', 'usb') NOT NULL,

    -- Especificaciones (solo aplican según el servicio)
    es_color         BOOLEAN      NULL,
    num_copias       INT          NULL,
    tipo_diseno      VARCHAR(100) NULL,
    tipo_engargolado VARCHAR(50)  NULL,
    tamano_hojas     VARCHAR(50)  NULL,
    color_pastas     VARCHAR(50)  NULL,
    descripcion      TEXT         NULL,

    fecha_registro   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Llave foránea: pedido -> cliente
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente) REFERENCES usuario(id_usuario)
        ON DELETE CASCADE,

    -- Impresión y copiado exigen modo (color o B/N) y número de copias;
    -- los demás servicios no los registran
    CONSTRAINT chk_servicio_color CHECK (
        (servicio IN ('impresion', 'copiado') AND es_color IS NOT NULL AND num_copias IS NOT NULL) OR
        (servicio NOT IN ('impresion', 'copiado') AND es_color IS NULL AND num_copias IS NULL)
    ),

    -- El número de copias, si existe, debe ser positivo
    CONSTRAINT chk_num_copias CHECK (num_copias IS NULL OR num_copias > 0),

    -- Un engargolado exige tipo, tamaño y color de pastas
    CONSTRAINT chk_servicio_engargolado CHECK (
        (servicio = 'engargolado' AND tipo_engargolado IS NOT NULL
                                  AND tamano_hojas IS NOT NULL
                                  AND color_pastas IS NOT NULL) OR
        (servicio <> 'engargolado')
    )
);

-- =====================================================================
-- 4. TABLA ARCHIVO  (solo existe cuando el cliente eligió entrega digital)
--    RF-03 asociar archivo con pedido, RF-11 adjuntar, RF-08 eliminar,
--    RNF-01 localizar archivo. Relación 1 : 0..1 con pedido.
-- =====================================================================
CREATE TABLE archivo (
    id_archivo       INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido        INT NOT NULL UNIQUE,            -- UNIQUE: un pedido tiene como máximo un archivo
    nombre           VARCHAR(255) NOT NULL,
    formato          VARCHAR(10)  NOT NULL,          -- p. ej. pdf, docx, jpg
    ruta             VARCHAR(255) NOT NULL,          -- dónde queda guardado (localizar rápido, RNF-01)
    fecha_recepcion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_archivo_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido)
        ON DELETE CASCADE                            -- si se cancela el pedido (RF-17), se va su archivo
);

-- =====================================================================
-- 5. TABLA NOTIFICACION  (la recibe un usuario: cliente o empleado)
--    RF-04 aviso "listo" al cliente, RF-15 aviso de USB al empleado
-- =====================================================================
CREATE TABLE notificacion (
    id_notificacion  INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido        INT NOT NULL,
    id_usuario       INT NOT NULL,                   -- destinatario
    mensaje          VARCHAR(255) NOT NULL,
    fecha_envio      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leida            BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_notificacion_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido)
        ON DELETE CASCADE,                           -- composición: no existe sin su pedido
    CONSTRAINT fk_notificacion_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
        ON DELETE CASCADE
);

-- =====================================================================
-- 6. ÍNDICES
-- =====================================================================
-- RF-06 (lista de pendientes) y RNF-02 (filtrar por tiempo)
CREATE INDEX idx_pedido_estado_fecha ON pedido(estado, fecha_registro);
-- Notificaciones no leídas de un usuario (RF-04, RF-15)
CREATE INDEX idx_notificacion_usuario ON notificacion(id_usuario, leida);

-- =====================================================================
-- 7. REGLAS DE NEGOCIO EN LA BASE DE DATOS (TRIGGERS)
--    Nota: RN-05 (solo un empleado accede a las funciones del empleado)
--    y RN-07 (con entrega digital es obligatorio adjuntar el archivo)
--    se validan en la aplicación, porque dependen de la sesión y de que
--    el pedido y su archivo se guarden en una sola transacción.
-- =====================================================================
DELIMITER $$

-- RF-09 / RF-19: solo un cliente registra pedidos y nacen en "pendiente"
CREATE TRIGGER trg_pedido_bi BEFORE INSERT ON pedido
FOR EACH ROW
BEGIN
    DECLARE v_rol VARCHAR(10);
    SELECT rol INTO v_rol FROM usuario WHERE id_usuario = NEW.id_cliente;
    IF v_rol IS NULL OR v_rol <> 'cliente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo un cliente puede registrar un pedido';
    END IF;
    SET NEW.estado = 'pendiente';
END$$

-- RF-15: si el cliente eligió USB, se avisa a los empleados (preaviso)
CREATE TRIGGER trg_pedido_ai AFTER INSERT ON pedido
FOR EACH ROW
BEGIN
    IF NEW.tipo_entrega = 'usb' THEN
        INSERT INTO notificacion (id_pedido, id_usuario, mensaje)
        SELECT NEW.id_pedido, u.id_usuario,
               LEFT(CONCAT('Nuevo pedido con USB. Folio ', NEW.id_pedido,
                           ': ', NEW.servicio,
                           IF(NEW.descripcion IS NULL, '', CONCAT(' - ', NEW.descripcion))), 255)
        FROM usuario u
        WHERE u.rol = 'empleado';
    END IF;
END$$

-- RN-01: el estado solo avanza pendiente -> listo -> entregado
CREATE TRIGGER trg_pedido_bu BEFORE UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        IF NOT ((OLD.estado = 'pendiente' AND NEW.estado = 'listo') OR
                (OLD.estado = 'listo'     AND NEW.estado = 'entregado')) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN-01: el estado solo puede avanzar pendiente, listo, entregado';
        END IF;
    END IF;
END$$

-- RF-04: cuando el pedido pasa a "listo", se notifica al cliente
CREATE TRIGGER trg_pedido_au AFTER UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF NEW.estado = 'listo' AND OLD.estado <> 'listo' THEN
        INSERT INTO notificacion (id_pedido, id_usuario, mensaje)
        VALUES (NEW.id_pedido, NEW.id_cliente,
                CONCAT('Tu pedido ', NEW.id_pedido, ' ya está listo.'));
    END IF;
END$$

-- RN-03 / RF-17: el pedido solo se puede cancelar (eliminar) mientras está "pendiente"
CREATE TRIGGER trg_pedido_bd BEFORE DELETE ON pedido
FOR EACH ROW
BEGIN
    IF OLD.estado <> 'pendiente' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-03: solo se puede cancelar un pedido pendiente';
    END IF;
END$$

-- RN-06: con entrega en USB no se puede adjuntar archivo digital
CREATE TRIGGER trg_archivo_bi BEFORE INSERT ON archivo
FOR EACH ROW
BEGIN
    DECLARE v_entrega VARCHAR(10);
    SELECT tipo_entrega INTO v_entrega FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_entrega IS NULL OR v_entrega <> 'digital' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-06: un pedido con entrega en USB no admite archivo digital';
    END IF;
END$$

-- RN-02 / RF-08: el archivo solo se elimina si el pedido ya fue entregado
-- (al cancelar un pedido, el archivo se borra por ON DELETE CASCADE;
--  en MySQL las acciones en cascada no activan triggers)
CREATE TRIGGER trg_archivo_bd BEFORE DELETE ON archivo
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(10);
    SELECT estado INTO v_estado FROM pedido WHERE id_pedido = OLD.id_pedido;
    IF v_estado <> 'entregado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-02: el archivo solo se puede eliminar si el pedido esta entregado';
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- 8. DATOS DE PRUEBA (SEEDS)
--    Los hash son de ejemplo, no son contraseñas reales.
--    id_usuario 1 = empleado, 2 = Martha (cliente), 3 = Juan (cliente)
-- =====================================================================
INSERT INTO usuario (rol, nombre, usuario, correo, password_hash) VALUES
    ('empleado', 'Empleado Mostrador', 'empleado1',    'empleado1@example.com',    '$2y$10$HASH_DE_EJEMPLO_empleado1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
    ('cliente',  'Martha Silva',       'martha.silva', 'martha.silva@example.com', '$2y$10$HASH_DE_EJEMPLO_martha_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
    ('cliente',  'Juan Pérez',         'juan.perez',   'juan.perez@example.com',   '$2y$10$HASH_DE_EJEMPLO_juan_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');

-- Folio 1: impresión, digital (20 copias, B/N, carta)
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tamano_hojas, descripcion) VALUES
    (2, 'impresion', 'digital', FALSE, 20, 'carta', 'Tarea de matemáticas');

-- Folio 2: engargolado, USB
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, tipo_engargolado, tamano_hojas, color_pastas, descripcion) VALUES
    (2, 'engargolado', 'usb', 'espiral', 'carta', 'azul', 'Tarea final de 80 hojas');

-- Folio 3: diseño, digital
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, tipo_diseno, tamano_hojas, descripcion) VALUES
    (2, 'diseno', 'digital', 'invitacion', 'carta', 'Invitación de cumpleaños');

-- Folio 4: copiado, USB (10 copias a color)
INSERT INTO pedido (id_cliente, servicio, tipo_entrega, es_color, num_copias, tamano_hojas, descripcion) VALUES
    (3, 'copiado', 'usb', TRUE, 10, 'carta', 'Copias a color');

-- Archivos de los pedidos con entrega digital (folios 1 y 3)
INSERT INTO archivo (id_pedido, nombre, formato, ruta) VALUES
    (1, 'tarea_matematicas.pdf', 'pdf',  '/archivos/2026/10/pedido_1_tarea_matematicas.pdf'),
    (3, 'invitacion.docx',       'docx', '/archivos/2026/10/pedido_3_invitacion.docx');

-- =====================================================================
-- 9. CONSULTAS DE EJEMPLO (una por requisito principal)
-- =====================================================================
-- RF-06 / RNF-02: lista de pedidos pendientes, del más antiguo al más nuevo
-- SELECT id_pedido AS folio, servicio, tipo_entrega, fecha_registro
-- FROM pedido WHERE estado = 'pendiente' ORDER BY fecha_registro;

-- RF-05: estado actual de un pedido
-- SELECT id_pedido AS folio, estado FROM pedido WHERE id_pedido = 1;

-- RF-18: el cliente examina el resumen de sus pedidos (con su folio)
-- SELECT id_pedido AS folio, servicio, estado, tipo_entrega, descripcion
-- FROM pedido WHERE id_cliente = 2;

-- RNF-01: localizar el archivo de un pedido por su folio
-- SELECT nombre, formato, ruta FROM archivo WHERE id_pedido = 1;

-- RF-04 / RF-15: notificaciones sin leer de un usuario
-- SELECT id_notificacion, mensaje, fecha_envio
-- FROM notificacion WHERE id_usuario = 1 AND leida = FALSE ORDER BY fecha_envio DESC;
