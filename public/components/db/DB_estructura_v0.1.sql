--Este archivo contiene la propuesta de base de datos a utilizar en el proyecto, base de datos mysql
--xdxd voy a usar docker para base de datos y tal vez para alojar nominatim para los mapas, lo actualizaré cuando haya escrito el docker compose
-- MODIFICAR LA BASE DE DATOS PENSANDO EN QUE SE RECIBE ESTO, AÑADIR PERTENENCIAS DE USUARIO Y SI ES PUBLICO, PRIVADO O COMPARTIDO CON OTRO USUARIO, MODIFICAR LA RELACIÓN EN BASE A LOS Puntos:
-- var ruta = {
--        paradas: diccionario_paradas,
--        municipio: document.getElementById('municipios').value,
--        estado: document.getElementById('estados').value,
--        nombre: document.getElementById('nombre_parada').value,
--        estado: document.getElementById('estados').value,
--    };

--  usuarios (Google auth)

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    google_id VARCHAR(255) UNIQUE NOT NULL,
    nombre VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE estados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(10) NULL
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE municipios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    estado_id INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    FOREIGN KEY (estado_id) REFERENCES estados(id) ON DELETE CASCADE,
    INDEX idx_estado_id (estado_id)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE rutas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    creada_por INT NOT NULL,
    is_public BOOLEAN DEFAULT TRUE COMMENT 'TRUE = pública, FALSE = privada (solo creador)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (creada_por) REFERENCES usuarios(id) ON DELETE CASCADE,
    INDEX idx_creada_por (creada_por),
    INDEX idx_is_public (is_public)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE rutas_municipios (
    ruta_id INT NOT NULL,
    municipio_id INT NOT NULL,
    PRIMARY KEY (ruta_id, municipio_id),
    FOREIGN KEY (ruta_id) REFERENCES rutas(id) ON DELETE CASCADE,
    FOREIGN KEY (municipio_id) REFERENCES municipios(id) ON DELETE CASCADE,
    INDEX idx_municipio_id (municipio_id)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE puntos_ruta (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ruta_id INT NOT NULL,
    latitud DECIMAL(10,8) NOT NULL,
    longitud DECIMAL(11,8) NOT NULL,
    orden_secuencia INT NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ruta_id) REFERENCES rutas(id) ON DELETE CASCADE,
    INDEX idx_ruta_id (ruta_id)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE rutas_compartidas (
    ruta_id INT NOT NULL,
    usuario_id INT NOT NULL,
    permiso ENUM('view', 'edit') DEFAULT 'view',
    shared_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ruta_id, usuario_id),
    FOREIGN KEY (ruta_id) REFERENCES rutas(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    INDEX idx_usuario_id (usuario_id)
) DEFAULT CHARSET=utf8mb4;

-- 
-- VISTAS
-- 

CREATE OR REPLACE VIEW v_rutas_con_municipios AS
SELECT 
    r.id AS ruta_id,
    r.nombre AS nombre_ruta,
    r.descripcion,
    r.creada_por,
    u.nombre AS nombre_creador,
    r.is_public,
    r.created_at,
    r.updated_at,
    GROUP_CONCAT(DISTINCT CONCAT(m.nombre, ' (', e.nombre, ')') SEPARATOR ', ') AS municipios_cubiertos,
    GROUP_CONCAT(DISTINCT e.nombre SEPARATOR ', ') AS estados_cubiertos
FROM rutas r
LEFT JOIN usuarios u ON r.creada_por = u.id
LEFT JOIN rutas_municipios rm ON r.id = rm.ruta_id
LEFT JOIN municipios m ON rm.municipio_id = m.id
LEFT JOIN estados e ON m.estado_id = e.id
GROUP BY r.id;

CREATE OR REPLACE VIEW v_rutas_publicas AS
SELECT * FROM v_rutas_con_municipios WHERE is_public = TRUE;

CREATE OR REPLACE VIEW v_rutas_usuario AS
SELECT 
    r.*,
    u.nombre AS nombre_creador,
    u.email AS email_creador,
    u.avatar_url AS avatar_creador
FROM rutas r
JOIN usuarios u ON r.creada_por = u.id;

 
-- PROCEDIMIENTOS ALMACENADOS
 

-- Obtener rutas por estado
DROP PROCEDURE IF EXISTS sp_obtener_rutas_por_estado;
DELIMITER $$
CREATE PROCEDURE sp_obtener_rutas_por_estado(
    IN p_estado_id INT,
    IN p_usuario_id INT  -- puede ser NULL (visitante)
)
BEGIN
    SELECT DISTINCT r.*, u.nombre AS nombre_creador
    FROM rutas r
    JOIN usuarios u ON r.creada_por = u.id
    JOIN rutas_municipios rm ON r.id = rm.ruta_id
    JOIN municipios m ON rm.municipio_id = m.id
    WHERE m.estado_id = p_estado_id
      AND (r.is_public = TRUE 
           OR (p_usuario_id IS NOT NULL AND r.creada_por = p_usuario_id)
           OR (p_usuario_id IS NOT NULL AND EXISTS (SELECT 1 FROM rutas_compartidas rc WHERE rc.ruta_id = r.id AND rc.usuario_id = p_usuario_id)));
END$$
DELIMITER ;

-- Obtener rutas por municipio
DROP PROCEDURE IF EXISTS sp_obtener_rutas_por_municipio;
DELIMITER $$
CREATE PROCEDURE sp_obtener_rutas_por_municipio(
    IN p_municipio_id INT,
    IN p_usuario_id INT
)
BEGIN
    SELECT r.*, u.nombre AS nombre_creador
    FROM rutas r
    JOIN usuarios u ON r.creada_por = u.id
    JOIN rutas_municipios rm ON r.id = rm.ruta_id
    WHERE rm.municipio_id = p_municipio_id
      AND (r.is_public = TRUE 
           OR (p_usuario_id IS NOT NULL AND r.creada_por = p_usuario_id)
           OR (p_usuario_id IS NOT NULL AND EXISTS (SELECT 1 FROM rutas_compartidas rc WHERE rc.ruta_id = r.id AND rc.usuario_id = p_usuario_id)));
END$$
DELIMITER ;

-- Crear ruta desde frontend (formato objeto con paradas)
DROP PROCEDURE IF EXISTS sp_crear_ruta;
DELIMITER $$
CREATE PROCEDURE sp_crear_ruta(
    IN p_usuario_id INT,
    IN p_nombre VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_municipio_id INT,
    IN p_estado_id INT,
    IN p_paradas_json JSON,      -- Diccionario: {"1":[lat,lng], "2":[lat,lng], ...}
    IN p_is_public BOOLEAN
)
BEGIN
    DECLARE v_ruta_id INT;
    DECLARE v_estado_municipio INT;
    DECLARE v_indice INT DEFAULT 0;
    DECLARE v_num_claves INT;
    DECLARE v_clave VARCHAR(10);
    DECLARE v_coords JSON;
    DECLARE v_lat DECIMAL(10,8);
    DECLARE v_lng DECIMAL(11,8);
    
    -- Validar que el municipio pertenezca al estado
    SELECT estado_id INTO v_estado_municipio FROM municipios WHERE id = p_municipio_id;
    IF v_estado_municipio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Municipio no encontrado';
    END IF;
    IF v_estado_municipio != p_estado_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El municipio no pertenece al estado indicado';
    END IF;
    
    START TRANSACTION;
    
    INSERT INTO rutas (nombre, descripcion, creada_por, is_public)
    VALUES (p_nombre, p_descripcion, p_usuario_id, p_is_public);
    SET v_ruta_id = LAST_INSERT_ID();
    
    -- Asociar municipio
    INSERT INTO rutas_municipios (ruta_id, municipio_id) VALUES (v_ruta_id, p_municipio_id);
    
    -- Procesar paradas
    SET v_num_claves = JSON_LENGTH(p_paradas_json);
    SET v_indice = 0;
    
    WHILE v_indice < v_num_claves DO
        SET v_clave = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(p_paradas_json), CONCAT('$[', v_indice, ']')));
        SET v_coords = JSON_EXTRACT(p_paradas_json, CONCAT('$."', v_clave, '"'));
        SET v_lat = CAST(JSON_EXTRACT(v_coords, '$[0]') AS DECIMAL(10,8));
        SET v_lng = CAST(JSON_EXTRACT(v_coords, '$[1]') AS DECIMAL(11,8));
        
        INSERT INTO puntos_ruta (ruta_id, latitud, longitud, orden_secuencia)
        VALUES (v_ruta_id, v_lat, v_lng, CAST(v_clave AS UNSIGNED));
        
        SET v_indice = v_indice + 1;
    END WHILE;
    
    COMMIT;
    
    SELECT v_ruta_id AS ruta_id;
END$$
DELIMITER ;

-- Actualizar ruta (solo el creador)
DROP PROCEDURE IF EXISTS sp_actualizar_ruta;
DELIMITER $$
CREATE PROCEDURE sp_actualizar_ruta(
    IN p_ruta_id INT,
    IN p_usuario_id INT,
    IN p_nombre VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_municipio_id INT,
    IN p_estado_id INT,
    IN p_paradas_json JSON,
    IN p_is_public BOOLEAN
)
BEGIN
    DECLARE v_duenio INT;
    DECLARE v_estado_municipio INT;
    DECLARE v_indice INT DEFAULT 0;
    DECLARE v_num_claves INT;
    DECLARE v_clave VARCHAR(10);
    DECLARE v_coords JSON;
    DECLARE v_lat DECIMAL(10,8);
    DECLARE v_lng DECIMAL(11,8);
    
    -- Verificar propiedad
    SELECT creada_por INTO v_duenio FROM rutas WHERE id = p_ruta_id;
    IF v_duenio != p_usuario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes permiso para modificar esta ruta';
    END IF;
    
    -- Validar municipio
    SELECT estado_id INTO v_estado_municipio FROM municipios WHERE id = p_municipio_id;
    IF v_estado_municipio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Municipio no encontrado';
    END IF;
    IF v_estado_municipio != p_estado_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El municipio no pertenece al estado indicado';
    END IF;
    
    START TRANSACTION;
    
    -- Actualizar datos básicos
    UPDATE rutas
    SET nombre = p_nombre,
        descripcion = p_descripcion,
        is_public = p_is_public
    WHERE id = p_ruta_id;
    
    -- Reemplazar municipios (solo uno)
    DELETE FROM rutas_municipios WHERE ruta_id = p_ruta_id;
    INSERT INTO rutas_municipios (ruta_id, municipio_id) VALUES (p_ruta_id, p_municipio_id);
    
    -- Eliminar puntos antiguos
    DELETE FROM puntos_ruta WHERE ruta_id = p_ruta_id;
    
    -- Insertar nuevos puntos
    SET v_num_claves = JSON_LENGTH(p_paradas_json);
    SET v_indice = 0;
    
    WHILE v_indice < v_num_claves DO
        SET v_clave = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(p_paradas_json), CONCAT('$[', v_indice, ']')));
        SET v_coords = JSON_EXTRACT(p_paradas_json, CONCAT('$."', v_clave, '"'));
        SET v_lat = CAST(JSON_EXTRACT(v_coords, '$[0]') AS DECIMAL(10,8));
        SET v_lng = CAST(JSON_EXTRACT(v_coords, '$[1]') AS DECIMAL(11,8));
        
        INSERT INTO puntos_ruta (ruta_id, latitud, longitud, orden_secuencia)
        VALUES (p_ruta_id, v_lat, v_lng, CAST(v_clave AS UNSIGNED));
        
        SET v_indice = v_indice + 1;
    END WHILE;
    
    COMMIT;
END$$
DELIMITER ;

-- Eliminar ruta (solo el creador)
DROP PROCEDURE IF EXISTS sp_eliminar_ruta;
DELIMITER $$
CREATE PROCEDURE sp_eliminar_ruta(
    IN p_ruta_id INT,
    IN p_usuario_id INT
)
BEGIN
    DECLARE v_duenio INT;
    
    SELECT creada_por INTO v_duenio FROM rutas WHERE id = p_ruta_id;
    IF v_duenio != p_usuario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes permiso para eliminar esta ruta';
    END IF;
    
    DELETE FROM rutas WHERE id = p_ruta_id;  -- ON DELETE CASCADE elimina relaciones y puntos
END$$
DELIMITER ;

-- Obtener rutas de un usuario (propias)
DROP PROCEDURE IF EXISTS sp_obtener_rutas_usuario;
DELIMITER $$
CREATE PROCEDURE sp_obtener_rutas_usuario(
    IN p_usuario_id INT
)
BEGIN
    SELECT r.*, 
           GROUP_CONCAT(DISTINCT CONCAT(m.nombre, ' (', e.nombre, ')') SEPARATOR ', ') AS municipios_cubiertos
    FROM rutas r
    LEFT JOIN rutas_municipios rm ON r.id = rm.ruta_id
    LEFT JOIN municipios m ON rm.municipio_id = m.id
    LEFT JOIN estados e ON m.estado_id = e.id
    WHERE r.creada_por = p_usuario_id
    GROUP BY r.id;
END$$
DELIMITER ;

-- Cambiar visibilidad de ruta (pública/privada)
DROP PROCEDURE IF EXISTS sp_cambiar_visibilidad_ruta;
DELIMITER $$
CREATE PROCEDURE sp_cambiar_visibilidad_ruta(
    IN p_ruta_id INT,
    IN p_usuario_id INT,
    IN p_is_public BOOLEAN
)
BEGIN
    DECLARE v_duenio INT;
    
    SELECT creada_por INTO v_duenio FROM rutas WHERE id = p_ruta_id;
    IF v_duenio != p_usuario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No eres el propietario de esta ruta';
    END IF;
    
    UPDATE rutas SET is_public = p_is_public WHERE id = p_ruta_id;
END$$
DELIMITER ;

-- Compartir ruta con otro usuario
DROP PROCEDURE IF EXISTS sp_compartir_ruta;
DELIMITER $$
CREATE PROCEDURE sp_compartir_ruta(
    IN p_ruta_id INT,
    IN p_duenio_id INT,
    IN p_usuario_destino_id INT,
    IN p_permiso ENUM('view','edit')
)
BEGIN
    DECLARE v_duenio INT;
    
    SELECT creada_por INTO v_duenio FROM rutas WHERE id = p_ruta_id;
    IF v_duenio != p_duenio_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No eres el propietario de esta ruta';
    END IF;
    
    IF p_usuario_destino_id = p_duenio_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No puedes compartir la ruta contigo mismo';
    END IF;
    
    INSERT INTO rutas_compartidas (ruta_id, usuario_id, permiso)
    VALUES (p_ruta_id, p_usuario_destino_id, p_permiso)
    ON DUPLICATE KEY UPDATE permiso = VALUES(permiso), shared_at = CURRENT_TIMESTAMP;
END$$
DELIMITER ;

-- Dejar de compartir ruta
DROP PROCEDURE IF EXISTS sp_dejar_compartir;
DELIMITER $$
CREATE PROCEDURE sp_dejar_compartir(
    IN p_ruta_id INT,
    IN p_duenio_id INT,
    IN p_usuario_destino_id INT
)
BEGIN
    DECLARE v_duenio INT;
    
    SELECT creada_por INTO v_duenio FROM rutas WHERE id = p_ruta_id;
    IF v_duenio != p_duenio_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No eres el propietario de esta ruta';
    END IF;
    
    DELETE FROM rutas_compartidas WHERE ruta_id = p_ruta_id AND usuario_id = p_usuario_destino_id;
END$$
DELIMITER ;

-- Obtener rutas compartidas conmigo
DROP PROCEDURE IF EXISTS sp_obtener_compartidas_conmigo;
DELIMITER $$
CREATE PROCEDURE sp_obtener_compartidas_conmigo(
    IN p_usuario_id INT
)
BEGIN
    SELECT r.*, u.nombre AS nombre_creador, rc.permiso, rc.shared_at
    FROM rutas_compartidas rc
    JOIN rutas r ON rc.ruta_id = r.id
    JOIN usuarios u ON r.creada_por = u.id
    WHERE rc.usuario_id = p_usuario_id;
END$$
DELIMITER ;

-- Obtener detalles completos de una ruta
DROP PROCEDURE IF EXISTS sp_detalles_ruta;
DELIMITER $$
CREATE PROCEDURE sp_detalles_ruta(
    IN p_ruta_id INT,
    IN p_usuario_id INT   -- para verificar permisos de edición si es necesario
)
BEGIN
    -- Datos de la ruta + creador
    SELECT r.*, u.nombre AS nombre_creador, u.avatar_url
    FROM rutas r
    JOIN usuarios u ON r.creada_por = u.id
    WHERE r.id = p_ruta_id;
    
    -- Municipios asociados
    SELECT m.*, e.nombre AS estado_nombre, e.id
    FROM rutas_municipios rm
    JOIN municipios m ON rm.municipio_id = m.id
    JOIN estados e ON m.estado_id = e.id
    WHERE rm.ruta_id = p_ruta_id;
    
    -- Puntos de la ruta ordenados
    SELECT latitud, longitud, orden_secuencia, descripcion
    FROM puntos_ruta
    WHERE ruta_id = p_ruta_id
    ORDER BY orden_secuencia;
    
    -- Usuarios con quienes está compartida (si es el propietario)
    IF EXISTS (SELECT 1 FROM rutas WHERE id = p_ruta_id AND creada_por = p_usuario_id) THEN
        SELECT u.id, u.nombre, u.email, rc.permiso, rc.shared_at
        FROM rutas_compartidas rc
        JOIN usuarios u ON rc.usuario_id = u.id
        WHERE rc.ruta_id = p_ruta_id;
    END IF;
END$$
DELIMITER ;

 
-- ÍNDICES ADICIONALES
 

CREATE INDEX idx_puntos_ruta_coords ON puntos_ruta(latitud, longitud);
CREATE INDEX idx_rutas_created_at ON rutas(created_at);
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_rutas_compartidas_usuario ON rutas_compartidas(usuario_id);

 
INSERT INTO estados (nombre, codigo) VALUES
('Aguascalientes', 'AGS'),
('Baja California', 'BC'),
('Baja California Sur', 'BCS'),
('Campeche', 'CAMP'),
('Chiapas', 'CHIS'),
('Chihuahua', 'CHIH'),
('Ciudad de México', 'CDMX'),
('Coahuila de Zaragoza', 'COAH'),
('Colima', 'COL'),
('Durango', 'DGO'),
('Guanajuato', 'GTO'),
('Guerrero', 'GRO'),
('Hidalgo', 'HGO'),
('Jalisco', 'JAL'),
('México', 'MEX'),
('Michoacán de Ocampo', 'MICH'),
('Morelos', 'MOR'),
('Nayarit', 'NAY'),
('Nuevo León', 'NL'),
('Oaxaca', 'OAX'),
('Puebla', 'PUE'),
('Querétaro', 'QRO'),
('Quintana Roo', 'QROO'),
('San Luis Potosí', 'SLP'),
('Sinaloa', 'SIN'),
('Sonora', 'SON'),
('Tabasco', 'TAB'),
('Tamaulipas', 'TAMPS'),
('Tlaxcala', 'TLAX'),
('Veracruz de Ignacio de la Llave', 'VER'),
('Yucatán', 'YUC'),
('Zacatecas', 'ZAC');

-- PROCEDIMIENTOS PARA GESTIÓN DE USUARIOS

DROP PROCEDURE IF EXISTS sp_guardar_usuario_google;
DELIMITER $$
CREATE PROCEDURE sp_guardar_usuario_google(
    IN p_google_id VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    INSERT INTO usuarios (google_id, nombre, email, avatar_url)
    VALUES (p_google_id, p_nombre, p_email, p_avatar_url)
    ON DUPLICATE KEY UPDATE
        nombre = VALUES(nombre),
        avatar_url = VALUES(avatar_url),
        updated_at = CURRENT_TIMESTAMP;
    
    SELECT * FROM usuarios WHERE google_id = p_google_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_obtener_usuario_por_google_id;
DELIMITER $$
CREATE PROCEDURE sp_obtener_usuario_por_google_id(
    IN p_google_id VARCHAR(255)
)
BEGIN
    SELECT * FROM usuarios WHERE google_id = p_google_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_obtener_usuario_por_email;
DELIMITER $$
CREATE PROCEDURE sp_obtener_usuario_por_email(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT * FROM usuarios WHERE email = p_email;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_actualizar_usuario;
DELIMITER $$
CREATE PROCEDURE sp_actualizar_usuario(
    IN p_usuario_id INT,
    IN p_nombre VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    UPDATE usuarios
    SET nombre = COALESCE(p_nombre, nombre),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_usuario_id;
    
    SELECT * FROM usuarios WHERE id = p_usuario_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_eliminar_usuario;
DELIMITER $$
CREATE PROCEDURE sp_eliminar_usuario(
    IN p_usuario_id INT
)
BEGIN
    DELETE FROM usuarios WHERE id = p_usuario_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_login_google;
DELIMITER $$
CREATE PROCEDURE sp_login_google(
    IN p_google_id VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    CALL sp_guardar_usuario_google(p_google_id, p_nombre, p_email, p_avatar_url);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_listar_usuarios;
DELIMITER $$
CREATE PROCEDURE sp_listar_usuarios()
BEGIN
    SELECT id, google_id, nombre, email, avatar_url, created_at, updated_at
    FROM usuarios
    ORDER BY created_at DESC;
END$$
DELIMITER ;

INSERT INTO municipios (estado_id, nombre) VALUES
-- Aguascalientes (ID 1)
(1, 'Aguascalientes'),
(1, 'Asientos'),
(1, 'Calvillo'),
(1, 'Cosío'),
(1, 'Jesús María'),
(1, 'Pabellón de Arteaga'),
(1, 'Rincón de Romos'),
(1, 'San José de Gracia'),
(1, 'Tepezalá'),
(1, 'El Llano'),
(1, 'San Francisco de los Romo'),

-- Baja California (ID 2)
(2, 'Ensenada'),
(2, 'Mexicali'),
(2, 'Tecate'),
(2, 'Tijuana'),
(2, 'Playas de Rosarito'),
(2, 'San Felipe'),
(2, 'San Quintín'),

-- Baja California Sur (ID 3)
(3, 'Comondú'),
(3, 'Mulegé'),
(3, 'La Paz'),
(3, 'Los Cabos'),
(3, 'Loreto'),

-- Campeche (ID 4)
(4, 'Calkiní'),
(4, 'Campeche'),
(4, 'Carmen'),
(4, 'Champotón'),
(4, 'Hecelchakán'),
(4, 'Hopelchén'),
(4, 'Palizada'),
(4, 'Tenabo'),
(4, 'Escárcega'),
(4, 'Calakmul'),
(4, 'Candelaria'),
(4, 'Seybaplaya'),
(4, 'Dzitbalché'),

-- Chiapas (ID 5)
(5, 'Acacoyagua'),
(5, 'Acala'),
(5, 'Acapetahua'),
(5, 'Altamirano'),
(5, 'Amatán'),
(5, 'Amatenango de la Frontera'),
(5, 'Amatenango del Valle'),
(5, 'Angel Albino Corzo'),
(5, 'Arriaga'),
(5, 'Bejucal de Ocampo'),
(5, 'Bella Vista'),
(5, 'Berriozábal'),
(5, 'Bochil'),
(5, 'El Bosque'),
(5, 'Cacahoatán'),
(5, 'Catazajá'),
(5, 'Cintalapa'),
(5, 'Coapilla'),
(5, 'Comitán de Domínguez'),
(5, 'La Concordia'),
(5, 'Copainalá'),
(5, 'Chalchihuitán'),
(5, 'Chamula'),
(5, 'Chanal'),
(5, 'Chapultenango'),
(5, 'Chenalhó'),
(5, 'Chiapa de Corzo'),
(5, 'Chiapilla'),
(5, 'Chicoasén'),
(5, 'Chicomuselo'),
(5, 'Chilón'),
(5, 'Escuintla'),
(5, 'Francisco León'),
(5, 'Frontera Comalapa'),
(5, 'Frontera Hidalgo'),
(5, 'Huehuetán'),
(5, 'Huitiupán'),
(5, 'Huixtán'),
(5, 'Huixtla'),
(5, 'La Independencia'),
(5, 'Ixhuatán'),
(5, 'Ixtacomitán'),
(5, 'Ixtapa'),
(5, 'Ixtapangajoya'),
(5, 'Jiquipilas'),
(5, 'Jitotol'),
(5, 'Juárez'),
(5, 'Larráinzar'),
(5, 'La Libertad'),
(5, 'Mapastepec'),
(5, 'Las Margaritas'),
(5, 'Mazapa de Madero'),
(5, 'Mazatán'),
(5, 'Metapa'),
(5, 'Mitontic'),
(5, 'Montecristo de Guerrero'),
(5, 'Motozintla'),
(5, 'Nicolás Ruíz'),
(5, 'Ocosingo'),
(5, 'Ocotepec'),
(5, 'Ocozocoautla de Espinosa'),
(5, 'Ostuacán'),
(5, 'Palenque'),
(5, 'Pantelhó'),
(5, 'Pantepec'),
(5, 'Pichucalco'),
(5, 'Pijijiapan'),
(5, 'El Porvenir'),
(5, 'Villa Comaltitlán'),
(5, 'Pueblo Nuevo Solistahuacán'),
(5, 'Rayón'),
(5, 'Reforma'),
(5, 'Las Rosas'),
(5, 'Sabanilla'),
(5, 'Salto de Agua'),
(5, 'San Cristóbal de las Casas'),
(5, 'San Fernando'),
(5, 'Siltepec'),
(5, 'Simojovel'),
(5, 'Sitalá'),
(5, 'Socoltenango'),
(5, 'Solosuchiapa'),
(5, 'Soyaló'),
(5, 'Suchiapa'),
(5, 'Suchiate'),
(5, 'Tapachula'),
(5, 'Tapalapa'),
(5, 'Tecpatán'),
(5, 'Tenejapa'),
(5, 'Teopisca'),
(5, 'Tila'),
(5, 'Tonalá'),
(5, 'Totolapa'),
(5, 'La Trinitaria'),
(5, 'Tumbalá'),
(5, 'Tuxtla Gutiérrez'),
(5, 'Tuxtla Chico'),
(5, 'Tuzantán'),
(5, 'Venustiano Carranza'),
(5, 'Villa Corzo'),
(5, 'Villaflores'),
(5, 'Yajalón'),
(5, 'San Lucas Sacatepéquez'),
(5, 'Capitán Luis Ángel Vidal'),
(5, 'Rincón Chamula San Pedro'),
(5, 'Honduras de la Sierra'),

-- Chihuahua (ID 6)
(6, 'Ahumada'),
(6, 'Aldama'),
(6, 'Allende'),
(6, 'Aquiles Serdán'),
(6, 'Ascensión'),
(6, 'Bachíniva'),
(6, 'Balleza'),
(6, 'Batopilas'),
(6, 'Bocoyna'),
(6, 'Buenaventura'),
(6, 'Camargo'),
(6, 'Carichí'),
(6, 'Casas Grandes'),
(6, 'Coronado'),
(6, 'Coyame del Sotol'),
(6, 'La Cruz'),
(6, 'Cuauhtémoc'),
(6, 'Cusihuiriachi'),
(6, 'Chihuahua'),
(6, 'Chínipas'),
(6, 'Delicias'),
(6, 'Dr. Belisario Domínguez'),
(6, 'Galeana'),
(6, 'Santa Isabel'),
(6, 'Gómez Farías'),
(6, 'Gran Morelos'),
(6, 'Guachochi'),
(6, 'Guadalupe'),
(6, 'Guadalupe y Calvo'),
(6, 'Hidalgo del Parral'),
(6, 'Huejotitán'),
(6, 'Ignacio Zaragoza'),
(6, 'Janos'),
(6, 'Jiménez'),
(6, 'Juárez'),
(6, 'Julimes'),
(6, 'López'),
(6, 'Madera'),
(6, 'Maguarichi'),
(6, 'Manuel Benavides'),
(6, 'Matachí'),
(6, 'Matamoros'),
(6, 'Meoqui'),
(6, 'Morelos'),
(6, 'Moris'),
(6, 'Namiquipa'),
(6, 'Nonoava'),
(6, 'Nuevo Casas Grandes'),
(6, 'Ocampo'),
(6, 'Ojinaga'),
(6, 'Praxedis G. Guerrero'),
(6, 'Riva Palacio'),
(6, 'Rosales'),
(6, 'Rosario'),
(6, 'San Francisco de Borja'),
(6, 'San Francisco de Conchos'),
(6, 'San Francisco del Oro'),
(6, 'Santa Bárbara'),
(6, 'Satevó'),
(6, 'Saucillo'),
(6, 'Temósachic'),
(6, 'El Tule'),
(6, 'Urique'),
(6, 'Uruachi'),
(6, 'Valle de Zaragoza'),
(6, 'Zaragoza'),

-- Ciudad de México (ID 7)
(7, 'Álvaro Obregón'),
(7, 'Azcapotzalco'),
(7, 'Benito Juárez'),
(7, 'Coyoacán'),
(7, 'Cuajimalpa'),
(7, 'Cuauhtémoc'),
(7, 'Gustavo A. Madero'),
(7, 'Iztacalco'),
(7, 'Iztapalapa'),
(7, 'La Magdalena Contreras'),
(7, 'Miguel Hidalgo'),
(7, 'Milpa Alta'),
(7, 'Tláhuac'),
(7, 'Tlalpan'),
(7, 'Venustiano Carranza'),
(7, 'Xochimilco'),

-- Coahuila (ID 8)
(8, 'Abasolo'),
(8, 'Acuña'),
(8, 'Allende'),
(8, 'Arteaga'),
(8, 'Candela'),
(8, 'Castaños'),
(8, 'Cuatro Ciénegas'),
(8, 'Escobedo'),
(8, 'Francisco I. Madero'),
(8, 'Frontera'),
(8, 'General Cepeda'),
(8, 'Guerrero'),
(8, 'Hidalgo'),
(8, 'Jiménez'),
(8, 'Juárez'),
(8, 'Lamadrid'),
(8, 'Matamoros'),
(8, 'Monclova'),
(8, 'Morelos'),
(8, 'Múzquiz'),
(8, 'Nadadores'),
(8, 'Nava'),
(8, 'Ocampo'),
(8, 'Parras'),
(8, 'Piedras Negras'),
(8, 'Progreso'),
(8, 'Ramos Arizpe'),
(8, 'Sabinas'),
(8, 'Sacramento'),
(8, 'Saltillo'),
(8, 'San Buenaventura'),
(8, 'San Juan de Sabinas'),
(8, 'San Pedro'),
(8, 'Sierra Mojada'),
(8, 'Torreón'),
(8, 'Viesca'),
(8, 'Villa Unión'),
(8, 'Zaragoza'),

-- Colima (ID 9)
(9, 'Armería'),
(9, 'Colima'),
(9, 'Comala'),
(9, 'Coquimatlán'),
(9, 'Cuauhtémoc'),
(9, 'Ixtlahuacán'),
(9, 'Manzanillo'),
(9, 'Minatitlán'),
(9, 'Tecomán'),
(9, 'Villa de Álvarez'),

-- Durango (ID 10)
(10, 'Canatlán'),
(10, 'Canelas'),
(10, 'Coneto de Comonfort'),
(10, 'Cuencamé'),
(10, 'Durango'),
(10, 'General Simón Bolívar'),
(10, 'Gómez Palacio'),
(10, 'Guadalupe Victoria'),
(10, 'Guanaceví'),
(10, 'Hidalgo'),
(10, 'Indé'),
(10, 'Lerdo'),
(10, 'Mapimí'),
(10, 'Mezquital'),
(10, 'Nazas'),
(10, 'Nombre de Dios'),
(10, 'Ocampo'),
(10, 'El Oro'),
(10, 'Otáez'),
(10, 'Pánuco de Coronado'),
(10, 'Peñón Blanco'),
(10, 'Poanas'),
(10, 'Pueblo Nuevo'),
(10, 'Rodeo'),
(10, 'San Bernardo'),
(10, 'San Dimas'),
(10, 'San Juan de Guadalupe'),
(10, 'San Juan del Río'),
(10, 'San Luis del Cordero'),
(10, 'San Pedro del Gallo'),
(10, 'Santa Clara'),
(10, 'Santiago Papasquiaro'),
(10, 'Súchil'),
(10, 'Tamazula'),
(10, 'Tepehuanes'),
(10, 'Tlahualilo'),
(10, 'Topia'),
(10, 'Vicente Guerrero'),
(10, 'Zaragoza'),

-- Guanajuato (ID 11)
(11, 'Abasolo'),
(11, 'Acámbaro'),
(11, 'San Miguel de Allende'),
(11, 'Apaseo el Alto'),
(11, 'Apaseo el Grande'),
(11, 'Atarjea'),
(11, 'Celaya'),
(11, 'Manuel Doblado'),
(11, 'Comonfort'),
(11, 'Coroneo'),
(11, 'Cortazar'),
(11, 'Cuerámaro'),
(11, 'Doctor Mora'),
(11, 'Dolores Hidalgo Cuna de la Independencia Nacional'),
(11, 'Guanajuato'),
(11, 'Hidalgo'),
(11, 'Irapuato'),
(11, 'Jaral del Progreso'),
(11, 'Jerécuaro'),
(11, 'León'),
(11, 'Moroleón'),
(11, 'Ocampo'),
(11, 'Pénjamo'),
(11, 'Pueblo Nuevo'),
(11, 'Purísima del Rincón'),
(11, 'Romita'),
(11, 'Salamanca'),
(11, 'Salvatierra'),
(11, 'San Diego de la Unión'),
(11, 'San Felipe'),
(11, 'San Francisco del Rincón'),
(11, 'San José Iturbide'),
(11, 'San Luis de la Paz'),
(11, 'Santa Catarina'),
(11, 'Santa Cruz de Juventino Rosas'),
(11, 'Santiago Maravatío'),
(11, 'Silao de la Victoria'),
(11, 'Tarandacuao'),
(11, 'Tarimoro'),
(11, 'Tierra Blanca'),
(11, 'Uriangato'),
(11, 'Valle de Santiago'),
(11, 'Victoria'),
(11, 'Villagrán'),
(11, 'Xichú'),
(11, 'Yuriria'),

-- Guerrero (ID 12)
(12, 'Acapulco de Juárez'),
(12, 'Ahuacuotzingo'),
(12, 'Ajuchitlán del Progreso'),
(12, 'Alcozauca de Guerrero'),
(12, 'Alpoyeca'),
(12, 'Apaxtla'),
(12, 'Arcelia'),
(12, 'Atenango del Río'),
(12, 'Atlamajalcingo del Monte'),
(12, 'Atlixtac'),
(12, 'Atoyac de Álvarez'),
(12, 'Ayutla de los Libres'),
(12, 'Azoyú'),
(12, 'Benito Juárez'),
(12, 'Buenavista de Cuéllar'),
(12, 'Coahuayutla de José María Izazaga'),
(12, 'Cocula'),
(12, 'Copala'),
(12, 'Copalillo'),
(12, 'Copanatoyac'),
(12, 'Coyuca de Benítez'),
(12, 'Coyuca de Catalán'),
(12, 'Cuajinicuilapa'),
(12, 'Cualác'),
(12, 'Cuautepec'),
(12, 'Cuetzala del Progreso'),
(12, 'Cutzamala de Pinzón'),
(12, 'Chilapa de Álvarez'),
(12, 'Chilpancingo de los Bravo'),
(12, 'Florencio Villarreal'),
(12, 'General Canuto A. Neri'),
(12, 'General Heliodoro Castillo'),
(12, 'Huamuxtitlán'),
(12, 'Huitzuco de los Figueroa'),
(12, 'Iguala de la Independencia'),
(12, 'Igualapa'),
(12, 'Ixcateopan de Cuauhtémoc'),
(12, 'Zihuatanejo de Azueta'),
(12, 'Juan R. Escudero'),
(12, 'Leonardo Bravo'),
(12, 'Malinaltepec'),
(12, 'Mártir de Cuilapan'),
(12, 'Metlatónoc'),
(12, 'Mochitlán'),
(12, 'Olinalá'),
(12, 'Ometepec'),
(12, 'Pedro Ascencio Alquisiras'),
(12, 'Petatlán'),
(12, 'Pilcaya'),
(12, 'Pungarabato'),
(12, 'Quechultenango'),
(12, 'San Luis Acatlán'),
(12, 'San Marcos'),
(12, 'San Miguel Totolapan'),
(12, 'Taxco de Alarcón'),
(12, 'Tecoanapa'),
(12, 'Técpan de Galeana'),
(12, 'Teloloapan'),
(12, 'Tepecoacuilco de Trujano'),
(12, 'Tetipac'),
(12, 'Tixtla de Guerrero'),
(12, 'Tlacoachistlahuaca'),
(12, 'Tlacoapa'),
(12, 'Tlalchapa'),
(12, 'Tlalixtaquilla de Maldonado'),
(12, 'Tlapa de Comonfort'),
(12, 'Tlalnepantla'),
(12, 'Tlapehuala'),
(12, 'La Unión de Isidoro Montes de Oca'),
(12, 'Xalpatláhuac'),
(12, 'Xochihuehuetlán'),
(12, 'Xochistlahuaca'),
(12, 'Zapotitlán Tablas'),
(12, 'Zirándaro'),
(12, 'Zitlala'),
(12, 'Eduardo Neri'),
(12, 'Acatepec'),
(12, 'Marquelia'),
(12, 'Cochoapa el Grande'),
(12, 'José Joaquín de Herrera'),
(12, 'Juchitán'),
(12, 'Iliatenco'),
(12, 'Las Vigas'),
(12, 'Ñuu Savi'),
(12, 'San Nicolás'),
(12, 'Santa Cruz del Rincón'),

-- Hidalgo (ID 13)
(13, 'Aculco'),
(13, 'Alfajayucan'),
(13, 'Almoloya'),
(13, 'Apan'),
(13, 'El Arenal'),
(13, 'Atitalaquia'),
(13, 'Atotonilco el Grande'),
(13, 'Atotonilco de Tula'),
(13, 'Calnali'),
(13, 'Cardonal'),
(13, 'Cuautepec de Hinojosa'),
(13, 'Chapantongo'),
(13, 'Chapulhuacán'),
(13, 'Chilcuautla'),
(13, 'Eloxochitlán'),
(13, 'Emiliano Zapata'),
(13, 'Epazoyucan'),
(13, 'Francisco I. Madero'),
(13, 'Huasca de Ocampo'),
(13, 'Huautla'),
(13, 'Huazalingo'),
(13, 'Huehuetla'),
(13, 'Huejutla de Reyes'),
(13, 'Huichapan'),
(13, 'Ixmiquilpan'),
(13, 'Jacala de Ledezma'),
(13, 'Jaltocán'),
(13, 'Juárez Hidalgo'),
(13, 'Lolotla'),
(13, 'Metepec'),
(13, 'Mezquital'),
(13, 'Mineral del Chico'),
(13, 'Mineral del Monte'),
(13, 'La Misión'),
(13, 'Mixquiahuala de Juárez'),
(13, 'Molango de Escamilla'),
(13, 'Nicolás Flores'),
(13, 'Nopala de Villagrán'),
(13, 'Omitlán de Juárez'),
(13, 'San Bartolo Tutotepec'),
(13, 'San Felipe Orizatlán'),
(13, 'San Salvador'),
(13, 'Santiago de Anaya'),
(13, 'Signoret'),
(13, 'Tasquillo'),
(13, 'Tecozautla'),
(13, 'Tenango de Doria'),
(13, 'Tepeapulco'),
(13, 'Tepehuacán de Guerrero'),
(13, 'Tepeji del Río de Ocampo'),
(13, 'Tepetitlán'),
(13, 'Tetepango'),
(13, 'Villa de Tezontepec'),
(13, 'Tezontepec de Aldama'),
(13, 'Tianguistengo'),
(13, 'Tizayuca'),
(13, 'Tlahuelilpan'),
(13, 'Tlahuiltepa'),
(13, 'Tlanalapa'),
(13, 'Tlanchinol'),
(13, 'Tlaxcoapan'),
(13, 'Tolcayuca'),
(13, 'Tula de Allende'),
(13, 'Tulancingo de Bravo'),
(13, 'Xochiatipan'),
(13, 'Xochicoatlán'),
(13, 'Yahualica'),
(13, 'Zacualtipán de Ángeles'),
(13, 'Zimapán'),
(13, 'Zempoala'),

-- Jalisco (ID 14)
(14, 'Acatic'),
(14, 'Acatlán de Juárez'),
(14, 'Ahualulco de Mercado'),
(14, 'Amacueca'),
(14, 'Amatitán'),
(14, 'Ameca'),
(14, 'San Juanito de Escobedo'),
(14, 'Arandas'),
(14, 'El Arenal'),
(14, 'Atemajac de Brizuela'),
(14, 'Autlán de Navarro'),
(14, 'Ayotlán'),
(14, 'Ayutla'),
(14, 'La Barca'),
(14, 'Bolaños'),
(14, 'Cabo Corrientes'),
(14, 'Casimiro Castillo'),
(14, 'Cihuatlán'),
(14, 'Ciudad Guzmán'),
(14, 'Cocula'),
(14, 'Colotlán'),
(14, 'Concepción de Buenos Aires'),
(14, 'Cuautitlán de García Barragán'),
(14, 'Cuautla'),
(14, 'Cuquío'),
(14, 'Chapala'),
(14, 'Chimaltitán'),
(14, 'Chiquilistlán'),
(14, 'Degollado'),
(14, 'Ejutla'),
(14, 'Encarnación de Díaz'),
(14, 'Etzatlán'),
(14, 'El Grullo'),
(14, 'Guachinango'),
(14, 'Guadalajara'),
(14, 'Hostotipaquillo'),
(14, 'Huejúcar'),
(14, 'Huejuquilla el Alto'),
(14, 'La Huerta'),
(14, 'Ixtlahuacán de los Membrillos'),
(14, 'Ixtlahuacán del Río'),
(14, 'Jalostotitlán'),
(14, 'Jamay'),
(14, 'Jesús María'),
(14, 'Jilotlán de los Dolores'),
(14, 'Juchitlán'),
(14, 'Jocotepec'),
(14, 'Juanacatlán'),
(14, 'Lagos de Moreno'),
(14, 'El Limón'),
(14, 'Magdalena'),
(14, 'Santa María del Oro'),
(14, 'La Manzanilla de la Paz'),
(14, 'Mascota'),
(14, 'Mazamitla'),
(14, 'Mazatlán'),
(14, 'Mezquitic'),
(14, 'Mixtlán'),
(14, 'Ocotlán'),
(14, 'Ojuelos de Jalisco'),
(14, 'Pihuamo'),
(14, 'Poncitlán'),
(14, 'Puerto Vallarta'),
(14, 'Villa Purificación'),
(14, 'Quitupan'),
(14, 'El Salto'),
(14, 'San Cristóbal de la Barranca'),
(14, 'San Diego de Alejandría'),
(14, 'San Juan de los Lagos'),
(14, 'San Julián'),
(14, 'San Marcos'),
(14, 'San Martín de Bolaños'),
(14, 'San Martín Hidalgo'),
(14, 'San Miguel el Alto'),
(14, 'San Sebastián del Oeste'),
(14, 'Santa María de los Ángeles'),
(14, 'Sayula'),
(14, 'Tala'),
(14, 'Talpa de Allende'),
(14, 'Tampico Alto'),
(14, 'Tecalitlán'),
(14, 'Tecolotlán'),
(14, 'Techaluta de Montenegro'),
(14, 'Tenamaxtlán'),
(14, 'Teocaltiche'),
(14, 'Teocuitatlán de Corona'),
(14, 'Tepatitlán de Morelos'),
(14, 'Tepetongo'),
(14, 'Tequila'),
(14, 'Teuchitlán'),
(14, 'Tizapán el Alto'),
(14, 'Tlajomulco de Zúñiga'),
(14, 'San Pedro Tlaquepaque'),
(14, 'Tolimán'),
(14, 'Tomatlán'),
(14, 'Tonalá'),
(14, 'Tonaya'),
(14, 'Tonila'),
(14, 'Totatiche'),
(14, 'Tototlán'),
(14, 'Tuxcacuesco'),
(14, 'Tuxcueca'),
(14, 'Tuxpan'),
(14, 'Unión de San Antonio'),
(14, 'Unión de Tula'),
(14, 'Valle de Guadalupe'),
(14, 'Valle de Juárez'),
(14, 'San Gabriel'),
(14, 'Villa Corona'),
(14, 'Villa Guerrero'),
(14, 'Villa Hidalgo'),
(14, 'Cañadas de Obregón'),
(14, 'Yahualica de González Gallo'),
(14, 'Zacoalco de Torres'),
(14, 'Zapopan'),
(14, 'Zapotiltic'),
(14, 'Zapotitlán de Vadillo'),
(14, 'Zapotlanejo'),
(14, 'San Ignacio Cerro Gordo'),

-- México (ID 15)
(15, 'Acambay de Ruíz Castañeda'),
(15, 'Acolman'),
(15, 'Aculco'),
(15, 'Almoloya de Alquisiras'),
(15, 'Almoloya de Juárez'),
(15, 'Almoloya del Río'),
(15, 'Amanoalco de Becerra'),
(15, 'Amatepec'),
(15, 'Amecameca'),
(15, 'Apaxco'),
(15, 'Atenco'),
(15, 'Atizapán'),
(15, 'Atizapán de Zaragoza'),
(15, 'Atlacomulco'),
(15, 'Atlautla'),
(15, 'Axapusco'),
(15, 'Ayapango'),
(15, 'Calimaya'),
(15, 'Capulhuac'),
(15, 'Coacalco de Berriozábal'),
(15, 'Coatepec Harinas'),
(15, 'Cocotitlán'),
(15, 'Coyotepec'),
(15, 'Cuautitlán'),
(15, 'Cuautitlán Izcalli'),
(15, 'Chapa de Mota'),
(15, 'Chapultepec'),
(15, 'Chiautla'),
(15, 'Chicoloapan'),
(15, 'Chiconcuac'),
(15, 'Chimalhuacán'),
(15, 'Donato Guerra'),
(15, 'Ecatepec de Morelos'),
(15, 'Ecatzingo'),
(15, 'Huehuetoca'),
(15, 'Hueypoxtla'),
(15, 'Huixquilucan'),
(15, 'Isidro Fabela'),
(15, 'Ixtapaluca'),
(15, 'Ixtapan de la Sal'),
(15, 'Ixtapan del Oro'),
(15, 'Ixtlahuaca'),
(15, 'Xalatlaco'),
(15, 'Jaltenco'),
(15, 'Jilotepec'),
(15, 'Jilotzingo'),
(15, 'Jiquipilco'),
(15, 'Jocotitlán'),
(15, 'Joquicingo'),
(15, 'Juchitepec'),
(15, 'Lerma'),
(15, 'Malinalco'),
(15, 'Melchor Ocampo'),
(15, 'Metepec'),
(15, 'Mexicaltzingo'),
(15, 'Morelos'),
(15, 'Naucalpan de Juárez'),
(15, 'Nezahualcóyotl'),
(15, 'Nextlalpan'),
(15, 'Nopaltepec'),
(15, 'Ocoyoacac'),
(15, 'Ocuilan'),
(15, 'El Oro'),
(15, 'Otumba'),
(15, 'Ozumba'),
(15, 'Papalotla'),
(15, 'La Paz'),
(15, 'Polotitlán'),
(15, 'Rayón'),
(15, 'San Antonio la Isla'),
(15, 'San Felipe del Progreso'),
(15, 'San Martín de las Pirámides'),
(15, 'San Mateo Atenco'),
(15, 'San Simón de Guerrero'),
(15, 'Santo Tomás'),
(15, 'Soyaniquilpan de Juárez'),
(15, 'Sultepec'),
(15, 'Tecámac'),
(15, 'Tejupilco'),
(15, 'Temamatla'),
(15, 'Temascalapa'),
(15, 'Temascalcingo'),
(15, 'Temascaltepec'),
(15, 'Temoaya'),
(15, 'Tenancingo'),
(15, 'Tenango del Aire'),
(15, 'Tenango del Valle'),
(15, 'Teoloyucan'),
(15, 'Teotihuacán'),
(15, 'Tepetlaoxtoc'),
(15, 'Tepetlixpa'),
(15, 'Tepotzotlán'),
(15, 'Tequixquiac'),
(15, 'Texcaltitlán'),
(15, 'Texcalyacac'),
(15, 'Texcoco'),
(15, 'Tezoyuca'),
(15, 'Tianguistenco'),
(15, 'Timilpan'),
(15, 'Tlalmanalco'),
(15, 'Tlalnepantla de Baz'),
(15, 'Tlatlaya'),
(15, 'Toluca'),
(15, 'Tonatico'),
(15, 'Tultepec'),
(15, 'Tultitlán'),
(15, 'Valle de Bravo'),
(15, 'Villa de Allende'),
(15, 'Villa del Carbón'),
(15, 'Villa Guerrero'),
(15, 'Villa Victoria'),
(15, 'Xonacatlán'),
(15, 'Zacazonapan'),
(15, 'Zacualpan'),
(15, 'Zinacantepec'),
(15, 'Zumpahuacán'),
(15, 'Zumpango'),

-- Michoacán (ID 16)
(16, 'Acuitzio'),
(16, 'Aguililla'),
(16, 'Álvaro Obregón'),
(16, 'Angamacutiro'),
(16, 'Angangueo'),
(16, 'Apatzingán'),
(16, 'Aporo'),
(16, 'Aquila'),
(16, 'Ario'),
(16, 'Arteaga'),
(16, 'Briseñas'),
(16, 'Buenavista'),
(16, 'Carácuaro'),
(16, 'Coahuayana'),
(16, 'Coalcomán de Vázquez Pallares'),
(16, 'Coeneo'),
(16, 'Contepec'),
(16, 'Copándaro'),
(16, 'Cotija'),
(16, 'Cuitzeo'),
(16, 'Charapan'),
(16, 'Charo'),
(16, 'Chavinda'),
(16, 'Cherán'),
(16, 'Chilchota'),
(16, 'Chinicuila'),
(16, 'Chucándiro'),
(16, 'Churintzio'),
(16, 'Churumuco'),
(16, 'Ecuandureo'),
(16, 'Epitacio Huerta'),
(16, 'Gabriel Zamora'),
(16, 'Hidalgo'),
(16, 'La Huacana'),
(16, 'Huandacareo'),
(16, 'Huaniqueo'),
(16, 'Huetamo'),
(16, 'Huiramba'),
(16, 'Indaparapeo'),
(16, 'Irimbo'),
(16, 'Ixtlán'),
(16, 'Jacona'),
(16, 'Jiménez'),
(16, 'Jiquilpan'),
(16, 'Juárez'),
(16, 'Jungapeo'),
(16, 'Lagunillas'),
(16, 'Lázaro Cárdenas'),
(16, 'Los Reyes'),
(16, 'Luvianos'),
(16, 'Maravatío'),
(16, 'Marcos Castellanos'),
(16, 'Morelia'),
(16, 'Morelos'),
(16, 'Múgica'),
(16, 'Nahuatzen'),
(16, 'Nocupétaro'),
(16, 'Nuevo Parangaricutiro'),
(16, 'Nuevo Urecho'),
(16, 'Numarán'),
(16, 'Ocampo'),
(16, 'Pajacuarán'),
(16, 'Panindícuaro'),
(16, 'Parácuaro'),
(16, 'Paracho'),
(16, 'Pátzcuaro'),
(16, 'Penjamillo'),
(16, 'Peribán'),
(16, 'Purépero'),
(16, 'Puruaándiro'),
(16, 'Queréndaro'),
(16, 'Quiroga'),
(16, 'Cohuecan'),
(16, 'Salvador Escalante'),
(16, 'Santa Ana Maya'),
(16, 'Senguio'),
(16, 'Susupuato'),
(16, 'Tacámbaro'),
(16, 'Tancítaro'),
(16, 'Tangamandapio'),
(16, 'Tangancícuaro'),
(16, 'Tanhuato'),
(16, 'Taretan'),
(16, 'Tarímbaro'),
(16, 'Tepalcatepec'),
(16, 'Tingambato'),
(16, 'Tingüindín'),
(16, 'Tiquicheo de Nicolás Romero'),
(16, 'Tlalpujahua'),
(16, 'Tlazazalca'),
(16, 'Tocumbo'),
(16, 'Tumbiscatío'),
(16, 'Turicato'),
(16, 'Tuxpan'),
(16, 'Tuzantla'),
(16, 'Tzintzuntzan'),
(16, 'Tzitzio'),
(16, 'Uruapan'),
(16, 'Venustiano Carranza'),
(16, 'Villamar'),
(16, 'Vista Hermosa'),
(16, 'Yurécuaro'),
(16, 'Zacapu'),
(16, 'Zamora'),
(16, 'Zaragoza'),
(16, 'Zináparo'),
(16, 'Zinapécuaro'),
(16, 'Ziracuaretiro'),
(16, 'Zitácuaro'),

-- Morelos (ID 17)
(17, 'Amacuzac'),
(17, 'Atlatlahucan'),
(17, 'Axochiapan'),
(17, 'Ayala'),
(17, 'Coatlán del Río'),
(17, 'Cuautla'),
(17, 'Cuernavaca'),
(17, 'Emiliano Zapata'),
(17, 'Huitzilac'),
(17, 'Jantetelco'),
(17, 'Jiutepec'),
(17, 'Jocotepec'),
(17, 'Jonacatepec'),
(17, 'Mazatlán'),
(17, 'Miacatlán'),
(17, 'Ocuituco'),
(17, 'Puente de Ixtla'),
(17, 'Temixco'),
(17, 'Temoac'),
(17, 'Tepalcingo'),
(17, 'Tepoztlán'),
(17, 'Tetecala'),
(17, 'Tetela del Volcán'),
(17, 'Tlalnepantla'),
(17, 'Tlaltizapán de Zapata'),
(17, 'Tlaquiltenango'),
(17, 'Tlayacapan'),
(17, 'Totolapan'),
(17, 'Xochitepec'),
(17, 'Yautepec'),
(17, 'Yecapixtla'),
(17, 'Zacatepec'),
(17, 'Zacualpan de Amilpas'),
(17, 'Coatetelco'),
(17, 'Hueyapan'),
(17, 'Xoxocotla'),

-- Nayarit (ID 18)
(18, 'Acaponeta'),
(18, 'Ahuacatlán'),
(18, 'Amatlán de Cañas'),
(18, 'Compostela'),
(18, 'Huajicori'),
(18, 'Ixtlán del Río'),
(18, 'Jala'),
(18, 'Xalisco'),
(18, 'Del Nayar'),
(18, 'Rosamorada'),
(18, 'Ruiz'),
(18, 'San Blas'),
(18, 'San Pedro Lagunillas'),
(18, 'Santa María del Oro'),
(18, 'Santiago Ixcuintla'),
(18, 'Tecuala'),
(18, 'Tepic'),
(18, 'Tuxpan'),
(18, 'La Yesca'),
(18, 'Bahía de Banderas'),

-- Nuevo León (ID 19)
(19, 'Abasolo'),
(19, 'Agualeguas'),
(19, 'Los Aldamas'),
(19, 'Allende'),
(19, 'Anáhuac'),
(19, 'Apodaca'),
(19, 'Aramberri'),
(19, 'Bustamante'),
(19, 'Cadereyta Jiménez'),
(19, 'Carmen'),
(19, 'Cerralvo'),
(19, 'Ciénega de Flores'),
(19, 'China'),
(19, 'Doctor Arroyo'),
(19, 'Doctor Coss'),
(19, 'Doctor González'),
(19, 'Galeana'),
(19, 'García'),
(19, 'San Pedro Garza García'),
(19, 'General Bravo'),
(19, 'General Escobedo'),
(19, 'General Terán'),
(19, 'General Treviño'),
(19, 'General Zaragoza'),
(19, 'General Zuazua'),
(19, 'Guadalupe'),
(19, 'Los Herreras'),
(19, 'Higueras'),
(19, 'Hualahuises'),
(19, 'Iturbide'),
(19, 'Juárez'),
(19, 'Lampazos de Naranjo'),
(19, 'Linares'),
(19, 'Marín'),
(19, 'Melchor Ocampo'),
(19, 'Mier y Noriega'),
(19, 'Mina'),
(19, 'Montemorelos'),
(19, 'Monterrey'),
(19, 'Parás'),
(19, 'Pesquería'),
(19, 'Los Ramones'),
(19, 'Rayones'),
(19, 'Sabinas Hidalgo'),
(19, 'Salinas Victoria'),
(19, 'San Nicolás de los Garza'),
(19, 'Hidalgo'),
(19, 'Santa Catarina'),
(19, 'Santiago'),
(19, 'Vallecillo'),
(19, 'Villaldama'),
(19, 'Zaragoza'),

-- Oaxaca (ID 20)
(20, 'Abejones'),
(20, 'Acatlán de Pérez Figueroa'),
(20, 'Asunción Cacalotepec'),
(20, 'Asunción Cuyotepeji'),
(20, 'Asunción Ixtaltepec'),
(20, 'Asunción Nochixtlán'),
(20, 'Asunción Ocotlán'),
(20, 'Asunción Tlacolulita'),
(20, 'Ayotzintepec'),
(20, 'El Barrio de la Soledad'),
(20, 'Calihualá'),
(20, 'Candelaria Loxicha'),
(20, 'Ciénega de Zimatlán'),
(20, 'Ciudad Ixtepec'),
(20, 'Coatecas Altas'),
(20, 'Coicoyán de las Flores'),
(20, 'La Compañía'),
(20, 'Concepción Buenavista'),
(20, 'Concepción Pápalo'),
(20, 'Constancia del Rosario'),
(20, 'Cosolapa'),
(20, 'Cosoltepec'),
(20, 'Cuilápam de Guerrero'),
(20, 'Cuyamecalco Villa de Zaragoza'),
(20, 'Chahuites'),
(20, 'Chalcatongo de Hidalgo'),
(20, 'Chiquihuitlán de Benito Juárez'),
(20, 'Heroica Ciudad de Ejutla de Crespo'),
(20, 'Eloxochitlán de Flores Magón'),
(20, 'El Espinal'),
(20, 'Fresnillo de Trujano'),
(20, 'Guadalupe Etla'),
(20, 'Guadalupe de Ramírez'),
(20, 'Guatelulco'),
(20, 'Guelatao de Juárez'),
(20, 'Guevea de Humboldt'),
(20, 'Mesías Hidalgo'),
(20, 'Villa Hidalgo'),
(20, 'Heroica Ciudad de Huajuapan de León'),
(20, 'Huitzo'),
(20, 'Huautla de Jiménez'),
(20, 'Ixtlán de Juárez'),
(20, 'Heroica Ciudad de Juchitán de Zaragoza'),
(20, 'Loma Bonita'),
(20, 'Magdalena Apasco'),
(20, 'Magdalena Jaltepec'),
(20, 'Santa Magdalena Jicotlán'),
(20, 'Magdalena Mixtepec'),
(20, 'Magdalena Ocotlán'),
(20, 'Magdalena Peñasco'),
(20, 'Magdalena Teitipac'),
(20, 'Magdalena Tequisistlán'),
(20, 'Magdalena Tlacotepec'),
(20, 'Magdalena Zahuatlán'),
(20, 'Mariscala de Juárez'),
(20, 'Mazatlán Villa de Flores'),
(20, 'Miahuatlán de Porfirio Díaz'),
(20, 'Mixistlán de la Reforma'),
(20, 'Monjas'),
(20, 'Natividad'),
(20, 'Nazareno Etla'),
(20, 'Nejapa de Madero'),
(20, 'Ixpantepec Nieves'),
(20, 'Santiago Niltepec'),
(20, 'Oaxaca de Juárez'),
(20, 'Ocotlán de Morelos'),
(20, 'La Pe'),
(20, 'Pinotepa de Don Luis'),
(20, 'Pluma Hidalgo'),
(20, 'San José del Progreso'),
(20, 'San José Estancia Grande'),
(20, 'San José Tenango'),
(20, 'San Juan Achiutla'),
(20, 'San Juan Atepec'),
(20, 'San Juan Bautista Atatlahuca'),
(20, 'San Juan Bautista Coixtlahuaca'),
(20, 'San Juan Bautista Cuicatlán'),
(20, 'San Juan Bautista Guelache'),
(20, 'San Juan Bautista Jayacatlán'),
(20, 'San Juan Bautista Lo de Soto'),
(20, 'San Juan Bautista Suchitepec'),
(20, 'San Juan Bautista Tlacoatzintepec'),
(20, 'San Juan Bautista Tlaxiaco'),
(20, 'San Juan Bautista Tuxtepec'),
(20, 'San Juan Cacahuatepec'),
(20, 'San Juan Cieneguilla'),
(20, 'San Juan Coatzóspam'),
(20, 'San Juan Colorado'),
(20, 'San Juan Comaltepec'),
(20, 'San Juan Cotzocón'),
(20, 'San Juan Chilateca'),
(20, 'San Juan del Estado'),
(20, 'San Juan del Río'),
(20, 'San Juan Diuxi'),
(20, 'San Juan Evangelista Analco'),
(20, 'San Juan Guelavía'),
(20, 'San Juan Guichicovi'),
(20, 'San Juan Ihualtepec'),
(20, 'San Juan Juquila Mixes'),
(20, 'San Juan Juquila Vijanos'),
(20, 'San Juan Lachao'),
(20, 'San Juan Lachigalla'),
(20, 'San Juan Lajarcia'),
(20, 'San Juan Lalana'),
(20, 'San Juan de los Cués'),
(20, 'San Juan Mamaltepec'),
(20, 'San Juan Mazatlán'),
(20, 'San Juan Mixtepec'),
(20, 'San Juan Ñumí'),
(20, 'San Juan Ozolotepec'),
(20, 'San Juan Petlapa'),
(20, 'San Juan Quiahije'),
(20, 'San Juan Sayultepec'),
(20, 'San Juan Tabaá'),
(20, 'San Juan Tamazola'),
(20, 'San Juan Teita'),
(20, 'San Juan Teitipac'),
(20, 'San Juan Tepeuxila'),
(20, 'San Juan Teposcolula'),
(20, 'San Juan Yaee'),
(20, 'San Juan Yatzona'),
(20, 'San Juan Yucuita'),
(20, 'San Lorenzo'),
(20, 'San Lorenzo Albarradas'),
(20, 'San Lorenzo Cacaotepec'),
(20, 'San Lorenzo Cuaunecuiltitla'),
(20, 'San Lorenzo Texmelúcan'),
(20, 'San Lorenzo Victoria'),
(20, 'San Lucas Camotlán'),
(20, 'San Lucas Ojitlán'),
(20, 'San Lucas Quiaviní'),
(20, 'San Lucas Zoquiápam'),
(20, 'San Luis Amatlán'),
(20, 'San Marcial Ozolotepec'),
(20, 'San Marcos Arteaga'),
(20, 'San Martín de los Cansecos'),
(20, 'San Martín Huamelúlpam'),
(20, 'San Martín Itunyoso'),
(20, 'San Martín Lachilá'),
(20, 'San Martín Peras'),
(20, 'San Martín Tilcajete'),
(20, 'San Martín Toxpalan'),
(20, 'San Mateo Cajonos'),
(20, 'San Mateo del Mar'),
(20, 'San Mateo Etlatongo'),
(20, 'San Mateo Nejápam'),
(20, 'San Mateo Peñasco'),
(20, 'San Mateo Río Hondo'),
(20, 'San Mateo Sindihui'),
(20, 'San Mateo Tlapiltepec'),
(20, 'San Melchor Betaza'),
(20, 'San Miguel Achiutla'),
(20, 'San Miguel Ahuehuetitlán'),
(20, 'San Miguel Aloápam'),
(20, 'San Miguel Amatitlán'),
(20, 'San Miguel Amatlán'),
(20, 'San Miguel Coatlán'),
(20, 'San Miguel Chicahua'),
(20, 'San Miguel del Puerto'),
(20, 'San Miguel del Río'),
(20, 'San Miguel Ejutla'),
(20, 'San Miguel Huautla'),
(20, 'San Miguel Mixtepec'),
(20, 'San Miguel Panixtlahuaca'),
(20, 'San Miguel Peras'),
(20, 'San Miguel Quetzaltepec'),
(20, 'San Miguel Soyaltepec'),
(20, 'San Miguel Suchixtepec'),
(20, 'San Miguel Tecomatlán'),
(20, 'San Miguel Tenango'),
(20, 'San Miguel Tequixtepec'),
(20, 'San Miguel Tilquiápam'),
(20, 'San Miguel Tlacamama'),
(20, 'San Miguel Tlacotepec'),
(20, 'San Miguel Tulancingo'),
(20, 'San Miguel Yotao'),
(20, 'San Miguel Zacatepec'),
(20, 'San Nicolás'),
(20, 'San Nicolás Hidalgo'),
(20, 'San Pablo Coatlán'),
(20, 'San Pablo Cuatro Venados'),
(20, 'San Pablo Etla'),
(20, 'San Pablo Huitzo'),
(20, 'San Pablo Huixtepec'),
(20, 'San Pablo Macuiltianguis'),
(20, 'San Pablo Yaganiza'),
(20, 'San Pedro Amuzgos'),
(20, 'San Pedro Apóstol'),
(20, 'San Pedro Atoyac'),
(20, 'San Pedro Cajonos'),
(20, 'San Pedro Coxcaltepec'),
(20, 'San Pedro Comitancillo'),
(20, 'San Pedro el Alto'),
(20, 'San Pedro Huamelula'),
(20, 'San Pedro Ixcatlán'),
(20, 'San Pedro Ixtlahuaca'),
(20, 'San Pedro Jaltepetongo'),
(20, 'San Pedro Jicayán'),
(20, 'San Pedro Jocotipac'),
(20, 'San Pedro Juchatengo'),
(20, 'San Pedro Mártir'),
(20, 'San Pedro Mártir Quiechapa'),
(20, 'San Pedro Mártir Yucuxaco'),
(20, 'San Pedro Mixtepec'),
(20, 'San Pedro Molinos'),
(20, 'San Pedro Nopala'),
(20, 'San Pedro Ocopetatillo'),
(20, 'San Pedro Ocotepec'),
(20, 'San Pedro Pochutla'),
(20, 'San Pedro Quiatoni'),
(20, 'San Pedro Sochiápam'),
(20, 'San Pedro Tapanatepec'),
(20, 'San Pedro Taviche'),
(20, 'San Pedro Teozacoalco'),
(20, 'San Pedro Teutila'),
(20, 'San Pedro Tidaá'),
(20, 'San Pedro Topiltepec'),
(20, 'San Pedro Totolápam'),
(20, 'San Pedro Yaneri'),
(20, 'San Pedro Yólox'),
(20, 'San Pedro y San Pablo Ayutla'),
(20, 'San Pedro y San Pablo Teposcolula'),
(20, 'San Pedro y San Pablo Tequixtepec'),
(20, 'San Pedro Yoloxochitl'),
(20, 'San Sebastián Abasolo'),
(20, 'San Sebastián Coatlán'),
(20, 'San Sebastián Ixcapa'),
(20, 'San Sebastián Nicananduta'),
(20, 'San Sebastián Río Hondo'),
(20, 'San Sebastián Tecomaxtlahuaca'),
(20, 'San Sebastián Teitipac'),
(20, 'San Sebastián Tutla'),
(20, 'San Simón Almolongas'),
(20, 'San Simón Zahuatlán'),
(20, 'Santa Ana'),
(20, 'Santa Ana Ateixtlahuaca'),
(20, 'Santa Ana Cuauhtémoc'),
(20, 'Santa Ana del Valle'),
(20, 'Santa Ana Tavela'),
(20, 'Santa Ana Tlapacoyan'),
(20, 'Santa Ana Yareni'),
(20, 'Santa Ana Zegache'),
(20, 'Santa Catalina Quierí'),
(20, 'Santa Catarina Tayata'),
(20, 'Santa Catarina Ticuá'),
(20, 'Santa Catarina Yucundaa'),
(20, 'Santa Catarina Zapoquila'),
(20, 'Santa Cruz Acatepec'),
(20, 'Santa Cruz Amilpas'),
(20, 'Santa Cruz de Bravo'),
(20, 'Santa Cruz Itundujia'),
(20, 'Santa Cruz Mixtepec'),
(20, 'Santa Cruz Nundaco'),
(20, 'Santa Cruz Papalutla'),
(20, 'Santa Cruz Tacache de Mina'),
(20, 'Santa Cruz Tacahua'),
(20, 'Santa Cruz Tayata'),
(20, 'Santa Cruz Xitla'),
(20, 'Santa Cruz Xoxocotlán'),
(20, 'Santa Cruz Zenzontepec'),
(20, 'Santa Gertrudis'),
(20, 'Santa Inés del Monte'),
(20, 'Santa Inés Yatzeche'),
(20, 'Santa Lucía del Camino'),
(20, 'Santa Lucía Miahuatlán'),
(20, 'Santa Lucía Monteverde'),
(20, 'Santa Lucía Ocotlán'),
(20, 'Santa María Alotepec'),
(20, 'Santa María Apazco'),
(20, 'Santa María Atzompa'),
(20, 'Santa María Camotlán'),
(20, 'Santa María Colotepec'),
(20, 'Santa María Cortijo'),
(20, 'Santa María Coyotepec'),
(20, 'Santa María Chachoápam'),
(20, 'Santa María Chilchotla'),
(20, 'Santa María Chimalapa'),
(20, 'Santa María del Rosario'),
(20, 'Santa María del Tule'),
(20, 'Santa María Ecatepec'),
(20, 'Santa María Guelacé'),
(20, 'Santa María Guienagati'),
(20, 'Santa María Huatulco'),
(20, 'Santa María Huazolotitlán'),
(20, 'Santa María Ipalapa'),
(20, 'Santa María Ixcatlán'),
(20, 'Santa María Jacatepec'),
(20, 'Santa María Jalapa del Marqués'),
(20, 'Santa María Jaltianguis'),
(20, 'Santa María Lachixío'),
(20, 'Santa María Mixtequilla'),
(20, 'Santa María Nativitas'),
(20, 'Santa María Nduayaco'),
(20, 'Santa María Ozolotepec'),
(20, 'Santa María Pápalo'),
(20, 'Santa María Peñoles'),
(20, 'Santa María Petapa'),
(20, 'Santa María Quiegolani'),
(20, 'Santa María Sola'),
(20, 'Santa María Tataltepec'),
(20, 'Santa María Tecomavaca'),
(20, 'Santa María Temaxcalapa'),
(20, 'Santa María Temaxcaltepec'),
(20, 'Santa María Teopoxco'),
(20, 'Santa María Tepantlali'),
(20, 'Santa María Texcatitlán'),
(20, 'Santa María Tlahuitoltepec'),
(20, 'Santa María Tlalixtac'),
(20, 'Santa María Tonameca'),
(20, 'Santa María Totolapilla'),
(20, 'Santa María Xadani'),
(20, 'Santa María Yalina'),
(20, 'Santa María Yavesía'),
(20, 'Santa María Yosoyúa'),
(20, 'Santa María Yucuhiti'),
(20, 'Santa María Zaniza'),
(20, 'Santa María Zoquitlán'),
(20, 'Santiago Amoltepec'),
(20, 'Santiago Apoala'),
(20, 'Santiago Apóstol'),
(20, 'Santiago Astata'),
(20, 'Santiago del Río'),
(20, 'Santiago Ayuquililla'),
(20, 'Santiago Cacaloxtepec'),
(20, 'Santiago Camotlán'),
(20, 'Santiago Comaltepec'),
(20, 'Santiago Chazumba'),
(20, 'Santiago Choápam'),
(20, 'Santiago Huajolotitlán'),
(20, 'Santiago Huauclilla'),
(20, 'Santiago Ihuitlán Plumas'),
(20, 'Santiago Ixcuintepec'),
(20, 'Santiago Ixtayutla'),
(20, 'Santiago Jamiltepec'),
(20, 'Santiago Juxtlahuaca'),
(20, 'Santiago Lachiguiri'),
(20, 'Santiago Lalopa'),
(20, 'Santiago Laollaga'),
(20, 'Santiago Laxopa'),
(20, 'Santiago Llano Grande'),
(20, 'Santiago Matatlán'),
(20, 'Santiago Minas'),
(20, 'Santiago Nacaltepec'),
(20, 'Santiago Nejapilla'),
(20, 'Santiago Nundiche'),
(20, 'Santiago Nuyoó'),
(20, 'Santiago Pinotepa Nacional'),
(20, 'Santiago Suchilquitongo'),
(20, 'Santiago Tamazola'),
(20, 'Santiago Tapextla'),
(20, 'Santiago Tenango'),
(20, 'Santiago Tepetlapa'),
(20, 'Santiago Tetepec'),
(20, 'Santiago Texcalcingo'),
(20, 'Santiago Tillo'),
(20, 'Santiago Tlazoyaltepec'),
(20, 'Santiago Xanica'),
(20, 'Santiago Xiacuí'),
(20, 'Santiago Yaitepec'),
(20, 'Santiago Yaveo'),
(20, 'Santiago Yolomécatl'),
(20, 'Santiago Yosondúa'),
(20, 'Santiago Yucuyachi'),
(20, 'Santiago Zacatepec'),
(20, 'Santiago Zoochila'),
(20, 'Nuevo Zoquiápam'),
(20, 'Santo Domingo Albarradas'),
(20, 'Santo Domingo Armenta'),
(20, 'Santo Domingo Chihuitán'),
(20, 'Santo Domingo de Morelos'),
(20, 'Santo Domingo Ingenio'),
(20, 'Santo Domingo Ixcatlán'),
(20, 'Santo Domingo Nuxaá'),
(20, 'Santo Domingo Ozolotepec'),
(20, 'Santo Domingo Petapa'),
(20, 'Santo Domingo Roayaga'),
(20, 'Santo Domingo Tehuantepec'),
(20, 'Santo Domingo Teojomulco'),
(20, 'Santo Domingo Tepuxtepec'),
(20, 'Santo Domingo Tlatayápam'),
(20, 'Santo Domingo Tomaltepec'),
(20, 'Santo Domingo Tonalá'),
(20, 'Santo Domingo Tonaltepec'),
(20, 'Santo Domingo Xagacía'),
(20, 'Santo Domingo Yanhuitlán'),
(20, 'Santo Domingo Yodohino'),
(20, 'Santo Domingo Zanatepec'),
(20, 'Santos Reyes Nopala'),
(20, 'Santos Reyes Pápalo'),
(20, 'Santos Reyes Tepejillo'),
(20, 'Santos Reyes Yucuná'),
(20, 'Silacayoápam'),
(20, 'Sitio de Xitlapehua'),
(20, 'Soledad Etla'),
(20, 'Villa de Chilapa de Díaz'),
(20, 'Villa de Etla'),
(20, 'Villa de Tamazulápam del Progreso'),
(20, 'Villa de Tututepec de Melchor Ocampo'),
(20, 'Villa de Zaachila'),
(20, 'Villa Hidalgo'),
(20, 'Villa Sola de Vega'),
(20, 'Villa Talea de Castro'),
(20, 'Villa Tejúpam de la Unión'),
(20, 'Yaxe'),
(20, 'Yodocono de Porfirio Díaz'),
(20, 'Yetla de Yeter'),
(20, 'Yutanduchi de Guerrero'),
(20, 'Zaachila'),
(20, 'Zacatepec'),
(20, 'Zaragoza'),
(20, 'Zautla'),
(20, 'Zimatlán de Álvarez'),
(20, 'Ziniaré'),
(20, 'Zoquiápam'),
(20, 'Zoquitlán'),

-- Puebla (ID 21)
(21, 'Acajete'),
(21, 'Acateno'),
(21, 'Acatlán'),
(21, 'Acatzingo'),
(21, 'Acteopan'),
(21, 'Ahuacatlán'),
(21, 'Ahuatlán'),
(21, 'Ahuazotepec'),
(21, 'Ahuehuetitla'),
(21, 'Ajalpan'),
(21, 'Albino Zertuche'),
(21, 'Aljojuca'),
(21, 'Altepexi'),
(21, 'Amixtlán'),
(21, 'Amozoc'),
(21, 'Aquixtla'),
(21, 'Atempan'),
(21, 'Atexcal'),
(21, 'Atlixco'),
(21, 'Atoyatempan'),
(21, 'Atzala'),
(21, 'Atzitzihuacán'),
(21, 'Atzitzintla'),
(21, 'Axutla'),
(21, 'Ayotoxco de Guerrero'),
(21, 'Calpan'),
(21, 'Caltepec'),
(21, 'Camocuautla'),
(21, 'Caxhuacan'),
(21, 'Coatepec'),
(21, 'Coatzingo'),
(21, 'Cohetzala'),
(21, 'Cohuecan'),
(21, 'Coronango'),
(21, 'Coxcatlán'),
(21, 'Coyomeapan'),
(21, 'Coyotepec'),
(21, 'Cuapiaxtla de Madero'),
(21, 'Cuautempan'),
(21, 'Cuautinchán'),
(21, 'Cuautlancingo'),
(21, 'Cuayuca de Andrade'),
(21, 'Cuetzalan del Progreso'),
(21, 'Cuyoaco'),
(21, 'Chalchicomula de Sesma'),
(21, 'Chapulco'),
(21, 'Chiautla'),
(21, 'Chiautzingo'),
(21, 'Chiconcuautla'),
(21, 'Chichiquila'),
(21, 'Chietla'),
(21, 'Chigmecatitlán'),
(21, 'Chignahuapan'),
(21, 'Chignautla'),
(21, 'Chila'),
(21, 'Chila de la Sal'),
(21, 'Honey'),
(21, 'Chilchotla'),
(21, 'Chinantla'),
(21, 'Domingo Arenas'),
(21, 'Eloxochitlán'),
(21, 'Epatlán'),
(21, 'Esperanza'),
(21, 'Francisco Z. Mena'),
(21, 'General Felipe Ángeles'),
(21, 'Guadalupe'),
(21, 'Guadalupe Victoria'),
(21, 'Hermenegildo Galeana'),
(21, 'Huaquechula'),
(21, 'Huatlatlauca'),
(21, 'Huauchinango'),
(21, 'Huehuetla'),
(21, 'Huehuetlán el Chico'),
(21, 'Huejotzingo'),
(21, 'Hueyapan'),
(21, 'Hueytamalco'),
(21, 'Hueytlalpan'),
(21, 'Huitzilan de Serdán'),
(21, 'Huitziltepec'),
(21, 'Atlequizayan'),
(21, 'Ixcamilpa de Guerrero'),
(21, 'Ixcaquixtla'),
(21, 'Ixtacamaxtitlán'),
(21, 'Ixtepec'),
(21, 'Izúcar de Matamoros'),
(21, 'Jalpan'),
(21, 'Jalpa de Méndez'),
(21, 'Jonotla'),
(21, 'Jopala'),
(21, 'Juan C. Bonilla'),
(21, 'Juan Galindo'),
(21, 'Juan N. Méndez'),
(21, 'Lafragua'),
(21, 'Libres'),
(21, 'La Magdalena Tlatlauquitepec'),
(21, 'Mazapiltepec de Juárez'),
(21, 'Mixtla'),
(21, 'Molcaxac'),
(21, 'Naupan'),
(21, 'Nauzontla'),
(21, 'Nealtican'),
(21, 'Nicolás Bravo'),
(21, 'Nopalucan'),
(21, 'Ocotepec'),
(21, 'Ocoyucan'),
(21, 'Olintla'),
(21, 'Oriental'),
(21, 'Pahuatlán'),
(21, 'Palmar de Bravo'),
(21, 'Pantepec'),
(21, 'Petlalcingo'),
(21, 'Piaxtla'),
(21, 'Puebla'),
(21, 'Quecholac'),
(21, 'Quimixtlán'),
(21, 'Rafael Lara Grajales'),
(21, 'Los Reyes de Juárez'),
(21, 'Reforma'),
(21, 'Regla'),
(21, 'San Andrés Cholula'),
(21, 'San Antonio Cañada'),
(21, 'San Diego la Mesa Tochimiltzingo'),
(21, 'San Felipe Teotlalcingo'),
(21, 'San Felipe Tepatlán'),
(21, 'San Gabriel Chilac'),
(21, 'San Gregorio Atzompa'),
(21, 'San Jerónimo Tecuanipan'),
(21, 'San Jerónimo Xayacatlán'),
(21, 'San José Chiapa'),
(21, 'San José Miahuatlán'),
(21, 'San Juan Atenco'),
(21, 'San Juan Atzompa'),
(21, 'San Martín Texmelucan'),
(21, 'San Martín Totoltepec'),
(21, 'San Matías Tlalancaleca'),
(21, 'San Miguel Ixitlán'),
(21, 'San Miguel Xoxtla'),
(21, 'San Nicolás Buenos Aires'),
(21, 'San Nicolás de los Ranchos'),
(21, 'San Pablo Anicano'),
(21, 'San Pedro Cholula'),
(21, 'San Pedro Yeloixtlahuaca'),
(21, 'San Salvador el Seco'),
(21, 'San Salvador el Verde'),
(21, 'San Salvador Huixcolotla'),
(21, 'San Sebastián Tlacotepec'),
(21, 'Santa Catarina Tlaltempan'),
(21, 'Santa Inés Ahuatempan'),
(21, 'Santa Isabel Cholula'),
(21, 'Santiago Miahuatlán'),
(21, 'Huehuetlán el Grande'),
(21, 'Santo Tomás Hueyotlipan'),
(21, 'Soltepec'),
(21, 'Tecali de Herrera'),
(21, 'Tecamachalco'),
(21, 'Tecomatlán'),
(21, 'Tehuacán'),
(21, 'Tehuitzingo'),
(21, 'Tenampulco'),
(21, 'Teopantlán'),
(21, 'Teotlalco'),
(21, 'Tepanco de López'),
(21, 'Tepango de Rodríguez'),
(21, 'Tepatlaxco de Hidalgo'),
(21, 'Tepeaca'),
(21, 'Tepemaxalco'),
(21, 'Tepeojuma'),
(21, 'Tepetzintla'),
(21, 'Tepexi de Rodríguez'),
(21, 'Tepeyahualco'),
(21, 'Tepeyahualco de Cuauhtémoc'),
(21, 'Tetela de Ocampo'),
(21, 'Teteles de Avila Castillo'),
(21, 'Teziutlán'),
(21, 'Tianguismanalco'),
(21, 'Tilapa'),
(21, 'Tlacotepec de Benito Juárez'),
(21, 'Tlacuilotepec'),
(21, 'Tlachichuca'),
(21, 'Tlahuapan'),
(21, 'Tlaltenango'),
(21, 'Tlanepantla'),
(21, 'Tlaola'),
(21, 'Tlapacoya'),
(21, 'Tlapanalá'),
(21, 'Tlatlauquitepec'),
(21, 'Tlaxco'),
(21, 'Tochimilco'),
(21, 'Tochtepec'),
(21, 'Totoltepec de Guerrero'),
(21, 'Tulcingo'),
(21, 'Tuzamapan de Galeana'),
(21, 'Tzicatlacoyan'),
(21, 'Venustiano Carranza'),
(21, 'Vicente Guerrero'),
(21, 'Xayacatlán de Bravo'),
(21, 'Xicotepec'),
(21, 'Xicotlán'),
(21, 'Xiutetelco'),
(21, 'Xochiltepec'),
(21, 'Xochitlán de Vicente Suárez'),
(21, 'Xochitlán Todos Santos'),
(21, 'Yaonáhuac'),
(21, 'Yehualtepec'),
(21, 'Zacapala'),
(21, 'Zacapoaxtla'),
(21, 'Zacatlán'),
(21, 'Zapotitlán'),
(21, 'Zapotitlán de Méndez'),
(21, 'Zaragoza'),
(21, 'Zautla'),
(21, 'Zihuateutla'),
(21, 'Zinacatepec'),
(21, 'Zongozotla'),
(21, 'Zoquiapan'),
(21, 'Zoquitlán'),

-- Querétaro (ID 22)
(22, 'Amealco de Bonfil'),
(22, 'Pinal de Amoles'),
(22, 'Arroyo Seco'),
(22, 'Cadereyta de Montes'),
(22, 'Colón'),
(22, 'Corregidora'),
(22, 'Ezequiel Montes'),
(22, 'Huimilpan'),
(22, 'Jalpan de Serra'),
(22, 'Landa de Matamoros'),
(22, 'El Marqués'),
(22, 'Pedro Escobedo'),
(22, 'Peñamiller'),
(22, 'Querétaro'),
(22, 'San Joaquín'),
(22, 'San Juan del Río'),
(22, 'Tequisquiapan'),
(22, 'Tolimán'),

-- Quintana Roo (ID 23)
(23, 'Coahuila'),
(23, 'Felipe Carrillo Puerto'),
(23, 'Isla Mujeres'),
(23, 'Othón P. Blanco'),
(23, 'Puerto Morelos'),
(23, 'Solidaridad'),
(23, 'Tulum'),
(23, 'José María Morelos'),
(23, 'Lázaro Cárdenas'),

-- San Luis Potosí (ID 24)
(24, 'Ahualulco'),
(24, 'Alaquines'),
(24, 'Aquismón'),
(24, 'Armadillo de los Infante'),
(24, 'Axtla de Terrazas'),
(24, 'Bledos'),
(24, 'Cárdenas'),
(24, 'Catorce'),
(24, 'Cedral'),
(24, 'Cerritos'),
(24, 'Cerro de San Pedro'),
(24, 'Ciudad del Maíz'),
(24, 'Ciudad Fernández'),
(24, 'Tancanhuitz'),
(24, 'Ciudad Valles'),
(24, 'Coxcatlán'),
(24, 'Charcas'),
(24, 'Ebano'),
(24, 'Guadalcázar'),
(24, 'Huehuetlán'),
(24, 'Lagunillas'),
(24, 'Matehuala'),
(24, 'Mexquitic de Carmona'),
(24, 'Moctezuma'),
(24, 'Rayón'),
(24, 'Rioverde'),
(24, 'Salinas'),
(24, 'San Antonio'),
(24, 'San Ciro de Acosta'),
(24, 'San Luis Potosí'),
(24, 'San Martín Chalchicuautla'),
(24, 'San Nicolás Tolentino'),
(24, 'Santa Catarina'),
(24, 'Santa María del Río'),
(24, 'Santo Domingo'),
(24, 'San Vicente Tancuayalab'),
(24, 'Soledad de Graciano Sánchez'),
(24, 'Tamasopo'),
(24, 'Tamazunchale'),
(24, 'Tampacán'),
(24, 'Tampamolon Corona'),
(24, 'Tamuín'),
(24, 'Tanlajás'),
(24, 'Tanquián de Escobedo'),
(24, 'Tierra Nueva'),
(24, 'Vanegas'),
(24, 'Venado'),
(24, 'Villa de Arriaga'),
(24, 'Villa de Guadalupe'),
(24, 'Villa de la Paz'),
(24, 'Villa de Ramos'),
(24, 'Villa Hidalgo'),
(24, 'Villa Juárez'),
(24, 'Xilitla'),
(24, 'Zaragoza'),
(24, 'Villa de Pozos'),

-- Sinaloa (ID 25)
(25, 'Ahome'),
(25, 'Angostura'),
(25, 'Badiraguato'),
(25, 'Concordia'),
(25, 'Cosalá'),
(25, 'Culiacán'),
(25, 'Choix'),
(25, 'Elota'),
(25, 'Escuinapa'),
(25, 'Fuerte'),
(25, 'Guasave'),
(25, 'Mazatlán'),
(25, 'Mocorito'),
(25, 'Rosario'),
(25, 'Salvador Alvarado'),
(25, 'San Ignacio'),
(25, 'Sinaloa'),
(25, 'Navolato'),
(25, 'El Dorado'),
(25, 'Juan José Ríos'),

-- Sonora (ID 26)
(26, 'Aconchi'),
(26, 'Agua Prieta'),
(26, 'Alamos'),
(26, 'Altar'),
(26, 'Arivechi'),
(26, 'Arizpe'),
(26, 'Atil'),
(26, 'Bacadéhuachi'),
(26, 'Bacanora'),
(26, 'Bacerac'),
(26, 'Bacoachi'),
(26, 'Bácum'),
(26, 'Banámichi'),
(26, 'Baviácora'),
(26, 'Bavispe'),
(26, 'Benjamín Hill'),
(26, 'Caborca'),
(26, 'Cajeme'),
(26, 'Cananea'),
(26, 'Carbó'),
(26, 'La Colorada'),
(26, 'Cucurpe'),
(26, 'Cumpas'),
(26, 'Divisaderos'),
(26, 'Empalme'),
(26, 'Etchojoa'),
(26, 'Fronteras'),
(26, 'Granados'),
(26, 'Guaymas'),
(26, 'Hermosillo'),
(26, 'Huachinera'),
(26, 'Huásabas'),
(26, 'Huatabampo'),
(26, 'Huépac'),
(26, 'Imuris'),
(26, 'Magdalena'),
(26, 'Mazatán'),
(26, 'Moctezuma'),
(26, 'Naco'),
(26, 'Nácori Chico'),
(26, 'Nacozari de García'),
(26, 'Navojoa'),
(26, 'Nogales'),
(26, 'Onavas'),
(26, 'Opodepe'),
(26, 'Oquitoa'),
(26, 'Pitiquito'),
(26, 'Puerto Peñasco'),
(26, 'Quiriego'),
(26, 'Rayón'),
(26, 'Rosario'),
(26, 'Sahuaripa'),
(26, 'San Felipe de Jesús'),
(26, 'San Javier'),
(26, 'San Luis Río Colorado'),
(26, 'San Miguel de Horcasitas'),
(26, 'San Pedro de la Cueva'),
(26, 'Santa Ana'),
(26, 'Santa Cruz'),
(26, 'Sáric'),
(26, 'Soyopa'),
(26, 'Suaqui Grande'),
(26, 'Tepache'),
(26, 'Trincheras'),
(26, 'Tubutama'),
(26, 'Ures'),
(26, 'Villa Hidalgo'),
(26, 'Villa Pesqueira'),
(26, 'Yécora'),
(26, 'General Plutarco Elías Calles'),
(26, 'Benito Juárez'),
(26, 'San Ignacio Río Muerto'),

-- Tabasco (ID 27)
(27, 'Balancán'),
(27, 'Cárdenas'),
(27, 'Centla'),
(27, 'Centro'),
(27, 'Comalcalco'),
(27, 'Cunduacán'),
(27, 'Emiliano Zapata'),
(27, 'Huimanguillo'),
(27, 'Jalapa'),
(27, 'Jalpa de Méndez'),
(27, 'Jonuta'),
(27, 'Macuspana'),
(27, 'Nacajuca'),
(27, 'Paraíso'),
(27, 'Tacotalpa'),
(27, 'Teapa'),
(27, 'Tenosique'),

-- Tamaulipas (ID 28)
(28, 'Abasolo'),
(28, 'Aldama'),
(28, 'Altamira'),
(28, 'Antiguo Morelos'),
(28, 'Burgos'),
(28, 'Bustamante'),
(28, 'Camargo'),
(28, 'Casas'),
(28, 'Ciudad Madero'),
(28, 'Cruillas'),
(28, 'Gómez Farías'),
(28, 'González'),
(28, 'Güémez'),
(28, 'Guerrero'),
(28, 'Gustavo Díaz Ordaz'),
(28, 'Hidalgo'),
(28, 'Jaumave'),
(28, 'Jiménez'),
(28, 'Llera'),
(28, 'Mainero'),
(28, 'El Mante'),
(28, 'Matamoros'),
(28, 'Méndez'),
(28, 'Mier'),
(28, 'Miguel Alemán'),
(28, 'Miquihuana'),
(28, 'Nuevo Laredo'),
(28, 'Nuevo Morelos'),
(28, 'Ocampo'),
(28, 'Padilla'),
(28, 'Palmillas'),
(28, 'Reynosa'),
(28, 'Río Bravo'),
(28, 'San Carlos'),
(28, 'San Fernando'),
(28, 'San Nicolás'),
(28, 'Soto la Marina'),
(28, 'Tampico'),
(28, 'Tula'),
(28, 'Valle Hermoso'),
(28, 'Victoria'),
(28, 'Villagrán'),
(28, 'Xicoténcatl'),

-- Tlaxcala (ID 29)
(29, 'Amaxac de Guerrero'),
(29, 'Apetatitlán de Antonio Carvajal'),
(29, 'Atlangatepec'),
(29, 'Atltzayanca'),
(29, 'Apizaco'),
(29, 'Calpulalpan'),
(29, 'El Carmen Tequexquitla'),
(29, 'Cuapiaxtla'),
(29, 'Cuaxomulco'),
(29, 'Chiautempan'),
(29, 'Muñoz de Domingo Arenas'),
(29, 'Españita'),
(29, 'Huamantla'),
(29, 'Hueyotlipan'),
(29, 'Ixtacuixtla de Mariano Matamoros'),
(29, 'Ixtenco'),
(29, 'Mazatecochco de José María Morelos'),
(29, 'Contla de Juan Cuamatzi'),
(29, 'Tepetitla de Lardizábal'),
(29, 'Sanctórum de Lázaro Cárdenas'),
(29, 'Nanacamilpa de Mariano Arista'),
(29, 'Acuamanala de Miguel Hidalgo'),
(29, 'Natívitas'),
(29, 'Panotla'),
(29, 'San Pablo del Monte'),
(29, 'Santa Cruz Tlaxcala'),
(29, 'Tenancingo'),
(29, 'Teolocholco'),
(29, 'Tepeyanco'),
(29, 'Terrenate'),
(29, 'Tetla de la Solidaridad'),
(29, 'Tetlatlahuca'),
(29, 'Tlaxcala'),
(29, 'Tlaxco'),
(29, 'Tocatlán'),
(29, 'Totolac'),
(29, 'Ziltlaltépec de Trinidad Sánchez Santos'),
(29, 'Tzompantepec'),
(29, 'Xaloztoc'),
(29, 'Xaltocan'),
(29, 'Papalotla de Xicohténcatl'),
(29, 'Xicohtzinco'),
(29, 'Yauhquemehcan'),
(29, 'Zacatelco'),
(29, 'Emiliano Zapata'),
(29, 'Lázaro Cárdenas'),
(29, 'La Magdalena Tlaltelulco'),
(29, 'San Damián Texóloc'),
(29, 'San Francisco Tetlanohcan'),
(29, 'San Jerónimo Zacualpan'),
(29, 'San José Teacalco'),
(29, 'San Juan Huactzinco'),
(29, 'San Lorenzo Axocomanitla'),
(29, 'San Lucas Tecopilco'),
(29, 'Santa Ana Nopalucan'),
(29, 'Santa Apolonia Teacalco'),
(29, 'Santa Catarina Ayometla'),
(29, 'Santa Cruz Quilehtla'),
(29, 'Santa Isabel Xiloxoxtla'),

-- Veracruz (ID 30)
(30, 'Acajete'),
(30, 'Acatlán'),
(30, 'Acayucan'),
(30, 'Actopan'),
(30, 'Acula'),
(30, 'Acultzingo'),
(30, 'Camarón de Tejeda'),
(30, 'Alpatláhuac'),
(30, 'Alto Lucero de Gutiérrez Barrios'),
(30, 'Altotonga'),
(30, 'Alvarado'),
(30, 'Amatitlán'),
(30, 'Naranjos Amatlán'),
(30, 'Amatlán de los Reyes'),
(30, 'Angel R. Cabada'),
(30, 'La Antigua'),
(30, 'Apazapan'),
(30, 'Aquila'),
(30, 'Astacinga'),
(30, 'Atlahuilco'),
(30, 'Atoyac'),
(30, 'Atzacan'),
(30, 'Atzalan'),
(30, 'Tlaltetela'),
(30, 'Ayahualulco'),
(30, 'Banderilla'),
(30, 'Benito Juárez'),
(30, 'Boca del Río'),
(30, 'Calcahualco'),
(30, 'Camerino Z. Mendoza'),
(30, 'Carrillo Puerto'),
(30, 'Catemaco'),
(30, 'Cazones de Herrera'),
(30, 'Cerro Azul'),
(30, 'Citlaltépetl'),
(30, 'Coacoatzintla'),
(30, 'Coahuitlán'),
(30, 'Coatepec'),
(30, 'Coatzacoalcos'),
(30, 'Coatzintla'),
(30, 'Coetzala'),
(30, 'Colipa'),
(30, 'Comapa'),
(30, 'Córdoba'),
(30, 'Cosamaloapan del Carpio'),
(30, 'Cosautlán de Carvajal'),
(30, 'Coscomatepec'),
(30, 'Cosoleacaque'),
(30, 'Cotaxtla'),
(30, 'Coxquihui'),
(30, 'Coyutla'),
(30, 'Cuichapa'),
(30, 'Cuitláhuac'),
(30, 'Chacaltianguis'),
(30, 'Chalma'),
(30, 'Chiconamel'),
(30, 'Chiconquiaco'),
(30, 'Chicontepec'),
(30, 'Chinameca'),
(30, 'Chinampa de Gorostiza'),
(30, 'Las Choapas'),
(30, 'Chocamán'),
(30, 'Chontla'),
(30, 'Chumatlán'),
(30, 'Emiliano Zapata'),
(30, 'Espinal'),
(30, 'Filomeno Mata'),
(30, 'Fortín'),
(30, 'Gutiérrez Zamora'),
(30, 'Hidalgotitlán'),
(30, 'Huatusco'),
(30, 'Huayacocotla'),
(30, 'Hueyapan de Ocampo'),
(30, 'Huiloapan de Cuauhtémoc'),
(30, 'Ignacio de la Llave'),
(30, 'Ilamatlán'),
(30, 'Isla'),
(30, 'Ixcatepec'),
(30, 'Ixhuacán de los Reyes'),
(30, 'Ixhuatlán del Café'),
(30, 'Ixhuatlán del Sureste'),
(30, 'Ixhuatlán de Madero'),
(30, 'Ixmatlahuacan'),
(30, 'Ixtaczoquitlán'),
(30, 'Jalacingo'),
(30, 'Xalapa'),
(30, 'Jalcomulco'),
(30, 'Jáltipan'),
(30, 'Jamapa'),
(30, 'Jesús Carranza'),
(30, 'Xico'),
(30, 'Jilotepec'),
(30, 'Juan Rodríguez Clara'),
(30, 'Juchique de Ferrer'),
(30, 'Landero y Coss'),
(30, 'Lerdo de Tejada'),
(30, 'Magdalena'),
(30, 'Maltrata'),
(30, 'Manlio Fabio Altamirano'),
(30, 'Mariano Escobedo'),
(30, 'Martínez de la Torre'),
(30, 'Mecatlán'),
(30, 'Mecayapan'),
(30, 'Medellín de Bravo'),
(30, 'Miahuatlán'),
(30, 'Las Minas'),
(30, 'Minatitlán'),
(30, 'Misantla'),
(30, 'Mixtla de Altamirano'),
(30, 'Moloacán'),
(30, 'Naolinco'),
(30, 'Naranjal'),
(30, 'Nautla'),
(30, 'Nogales'),
(30, 'Oluta'),
(30, 'Omealca'),
(30, 'Oriental'),
(30, 'Otatitlán'),
(30, 'Oteapan'),
(30, 'Ozuluama de Mascareñas'),
(30, 'Pajapan'),
(30, 'Pánuco'),
(30, 'Papantla'),
(30, 'Paso del Macho'),
(30, 'Paso de Ovejas'),
(30, 'La Perla'),
(30, 'Perote'),
(30, 'Platón Sánchez'),
(30, 'Playa Vicente'),
(30, 'Poza Rica de Hidalgo'),
(30, 'Las Vigas de Ramírez'),
(30, 'Pueblo Viejo'),
(30, 'Puente Nacional'),
(30, 'Rafael Delgado'),
(30, 'Rafael Lucio'),
(30, 'Los Reyes'),
(30, 'Río Blanco'),
(30, 'Saltabarranca'),
(30, 'San Andrés Tenejapan'),
(30, 'San Andrés Tuxtla'),
(30, 'San Juan Evangelista'),
(30, 'Santiago Tuxtla'),
(30, 'Sayula de Alemán'),
(30, 'Soconusco'),
(30, 'Sochiapa'),
(30, 'Soledad Atzompa'),
(30, 'Soledad de Doblado'),
(30, 'Soteapan'),
(30, 'Tamalín'),
(30, 'Tamiahua'),
(30, 'Tampico Alto'),
(30, 'Tancoco'),
(30, 'Tantima'),
(30, 'Tantoyuca'),
(30, 'Tatatila'),
(30, 'Castillo de Teayo'),
(30, 'Tecolutla'),
(30, 'Tehuipango'),
(30, 'Álamo Temapache'),
(30, 'Tempoal'),
(30, 'Tenampa'),
(30, 'Tenochtitlán'),
(30, 'Teocelo'),
(30, 'Tepatlaxco'),
(30, 'Tepetlán'),
(30, 'Tepetzintla'),
(30, 'Tequila'),
(30, 'José Azueta'),
(30, 'Texcatepec'),
(30, 'Texhuacán'),
(30, 'Texistepec'),
(30, 'Tezonapa'),
(30, 'Tierra Blanca'),
(30, 'Tihuatlán'),
(30, 'Tlacojalpan'),
(30, 'Tlacolulan'),
(30, 'Tlacotalpan'),
(30, 'Tlacotepec de Mejía'),
(30, 'Tlachichilco'),
(30, 'Tlalixcoyan'),
(30, 'Tlalnelhuayocan'),
(30, 'Tlapacoyan'),
(30, 'Tlaquilpa'),
(30, 'Tlilapan'),
(30, 'Tomatlán'),
(30, 'Tonayán'),
(30, 'Totutla'),
(30, 'Tuxcacuesco'),
(30, 'Tuxpan'),
(30, 'Tuxtilla'),
(30, 'Ursulo Galván'),
(30, 'Vega de Alatorre'),
(30, 'Veracruz'),
(30, 'Villa Aldama'),
(30, 'Xoxocotla'),
(30, 'Yanga'),
(30, 'Yecuatla'),
(30, 'Zacualpan'),
(30, 'Zaragoza'),
(30, 'Zentla'),
(30, 'Zongolica'),
(30, 'Zontecomatlán de López y Fuentes'),
(30, 'Zozocolco de Hidalgo'),
(30, 'Agua Dulce'),
(30, 'El Higo'),
(30, 'Nanchital de Lázaro Cárdenas del Río'),
(30, 'Tres Valles'),
(30, 'Carlos A. Carrillo'),
(30, 'Tatahuicapan de Juárez'),
(30, 'Uxpanapa'),
(30, 'San Rafael'),
(30, 'Santiago Sochiapan'),

-- Yucatán (ID 31)
(31, 'Abalá'),
(31, 'Acanceh'),
(31, 'Akil'),
(31, 'Baca'),
(31, 'Bokobá'),
(31, 'Buctzotz'),
(31, 'Cacalchén'),
(31, 'Calotmul'),
(31, 'Cansahcab'),
(31, 'Cantamayec'),
(31, 'Caucel'),
(31, 'Cenotillo'),
(31, 'Conkal'),
(31, 'Cuncunul'),
(31, 'Cuzamá'),
(31, 'Chacsinkín'),
(31, 'Chankom'),
(31, 'Chapab'),
(31, 'Chemax'),
(31, 'Chicxulub Pueblo'),
(31, 'Chichimilá'),
(31, 'Chikindzonot'),
(31, 'Chocholá'),
(31, 'Chumayel'),
(31, 'Dzán'),
(31, 'Dzemul'),
(31, 'Dzidzantún'),
(31, 'Dzilam de Bravo'),
(31, 'Dzilam González'),
(31, 'Dzitás'),
(31, 'Dzoncauich'),
(31, 'Espita'),
(31, 'Halachó'),
(31, 'Hocabá'),
(31, 'Hoctún'),
(31, 'Homún'),
(31, 'Huhí'),
(31, 'Hunucmá'),
(31, 'Ixil'),
(31, 'Izamal'),
(31, 'Kanasín'),
(31, 'Kantunil'),
(31, 'Kaua'),
(31, 'Kinchil'),
(31, 'Kopomá'),
(31, 'Mama'),
(31, 'Maní'),
(31, 'Maxcanú'),
(31, 'Mayapán'),
(31, 'Mérida'),
(31, 'Mocochá'),
(31, 'Motul'),
(31, 'Muna'),
(31, 'Muxupip'),
(31, 'Opichén'),
(31, 'Oxkutzcab'),
(31, 'Panabá'),
(31, 'Peto'),
(31, 'Progreso'),
(31, 'Quintana Roo'),
(31, 'Río Lagartos'),
(31, 'Sacalum'),
(31, 'Samahil'),
(31, 'Sanahcat'),
(31, 'San Felipe'),
(31, 'Santa Elena'),
(31, 'Seyé'),
(31, 'Sinanché'),
(31, 'Sotuta'),
(31, 'Sucilá'),
(31, 'Sudzal'),
(31, 'Suma'),
(31, 'Tahdziú'),
(31, 'Tahmek'),
(31, 'Teabo'),
(31, 'Tecoh'),
(31, 'Tekal de Venegas'),
(31, 'Tekantó'),
(31, 'Tekax'),
(31, 'Tekom'),
(31, 'Telchac Pueblo'),
(31, 'Telchac Puerto'),
(31, 'Temax'),
(31, 'Temozón'),
(31, 'Tepakán'),
(31, 'Tetiz'),
(31, 'Teya'),
(31, 'Ticul'),
(31, 'Timucuy'),
(31, 'Tinum'),
(31, 'Tixcacalcupul'),
(31, 'Tixkokob'),
(31, 'Tixmehuac'),
(31, 'Tixpéhual'),
(31, 'Tizimín'),
(31, 'Tunkás'),
(31, 'Tzucacab'),
(31, 'Uayma'),
(31, 'Ucú'),
(31, 'Umán'),
(31, 'Valladolid'),
(31, 'Xocchel'),
(31, 'Yaxcabá'),
(31, 'Yaxkukul'),
(31, 'Yobain'),

-- Zacatecas (ID 32)
(32, 'Apozol'),
(32, 'Apulco'),
(32, 'Atolinga'),
(32, 'Benito Juárez'),
(32, 'Calera'),
(32, 'Cañitas de Felipe Pescador'),
(32, 'Concepción del Oro'),
(32, 'Cuauhtémoc'),
(32, 'Chalchihuites'),
(32, 'Fresnillo'),
(32, 'Trinidad García de la Cadena'),
(32, 'Genaro Codina'),
(32, 'General Enrique Estrada'),
(32, 'General Francisco R. Murguía'),
(32, 'El Plateado de Joaquín Amaro'),
(32, 'General Pánfilo Natera'),
(32, 'Guadalupe'),
(32, 'Huanusco'),
(32, 'Jalpa'),
(32, 'Jerez'),
(32, 'Jiménez del Teul'),
(32, 'Juan Aldama'),
(32, 'Juchipila'),
(32, 'Loreto'),
(32, 'Luis Moya'),
(32, 'Mazapil'),
(32, 'Mazatlán'),
(32, 'Melchor Ocampo'),
(32, 'Mezquital del Oro'),
(32, 'Miguel Auza'),
(32, 'Momax'),
(32, 'Monte Escobedo'),
(32, 'Morelos'),
(32, 'Moyahua de Estrada'),
(32, 'Nochistlán de Mejía'),
(32, 'Noria de Ángeles'),
(32, 'Ojocaliente'),
(32, 'Pinos'),
(32, 'Río Grande'),
(32, 'Sain Alto'),
(32, 'El Salvador'),
(32, 'Sombrerete'),
(32, 'Susticacán'),
(32, 'Tabasco'),
(32, 'Tepechitlán'),
(32, 'Tepetongo'),
(32, 'Teúl de González Ortega'),
(32, 'Tlaltenango de Sánchez Román'),
(32, 'Valparaíso'),
(32, 'Vetagrande'),
(32, 'Villa de Cos'),
(32, 'Villa García'),
(32, 'Villa González Ortega'),
(32, 'Villa Hidalgo'),
(32, 'Villanueva'),
(32, 'Zacatecas'),
(32, 'Trancoso'),
(32, 'Santa María de la Paz');

DROP PROCEDURE IF EXISTS sp_guardar_usuario_google;
DELIMITER $$
CREATE PROCEDURE sp_guardar_usuario_google(
    IN p_google_id VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    INSERT INTO usuarios (google_id, nombre, email, avatar_url)
    VALUES (p_google_id, p_nombre, p_email, p_avatar_url)
    ON DUPLICATE KEY UPDATE
        nombre = VALUES(nombre),
        avatar_url = VALUES(avatar_url),
        updated_at = CURRENT_TIMESTAMP;
    
    SELECT * FROM usuarios WHERE google_id = p_google_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_obtener_usuario_por_google_id;
DELIMITER $$
CREATE PROCEDURE sp_obtener_usuario_por_google_id(
    IN p_google_id VARCHAR(255)
)
BEGIN
    SELECT * FROM usuarios WHERE google_id = p_google_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_obtener_usuario_por_email;
DELIMITER $$
CREATE PROCEDURE sp_obtener_usuario_por_email(
    IN p_email VARCHAR(255)
)
BEGIN
    SELECT * FROM usuarios WHERE email = p_email;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_actualizar_usuario;
DELIMITER $$
CREATE PROCEDURE sp_actualizar_usuario(
    IN p_usuario_id INT,
    IN p_nombre VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    UPDATE usuarios
    SET nombre = COALESCE(p_nombre, nombre),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_usuario_id;
    
    SELECT * FROM usuarios WHERE id = p_usuario_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_eliminar_usuario;
DELIMITER $$
CREATE PROCEDURE sp_eliminar_usuario(
    IN p_usuario_id INT
)
BEGIN
    DELETE FROM usuarios WHERE id = p_usuario_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_login_google;
DELIMITER $$
CREATE PROCEDURE sp_login_google(
    IN p_google_id VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_avatar_url TEXT
)
BEGIN
    CALL sp_guardar_usuario_google(p_google_id, p_nombre, p_email, p_avatar_url);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_listar_usuarios;
DELIMITER $$
CREATE PROCEDURE sp_listar_usuarios()
BEGIN
    SELECT id, google_id, nombre, email, avatar_url, created_at, updated_at
    FROM usuarios
    ORDER BY created_at DESC;
END$$
DELIMITER ;
