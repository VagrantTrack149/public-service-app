const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
dotenv.config();

const pool = mysql.createPool({
    host: process.env.DB_SERVER || 'localhost',
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

async function executeQuery(q, params = []) {
    try {
        const [rows] = await pool.query(q, params);
        return rows;
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

//  USUARIOS 
async function login_google(p_google_id, p_nombre, p_email, p_avatar_url) {
    try {
        const q = `CALL sp_login_google(?, ?, ?, ?)`;
        const [rows] = await pool.query(q, [p_google_id, p_nombre, p_email, p_avatar_url]);
        //return rows[0];
        return rows[0][0];
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

//  ESTADOS Y MUNICIPIOS 
async function obtenerEstados() {
    try {
        const q = `SELECT id, nombre FROM estados ORDER BY nombre`;
        const [rows] = await pool.query(q);
        return rows;
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function obtenerMunicipiosPorEstado(estado_id) {
    try {
        const q = `SELECT id, nombre FROM municipios WHERE estado_id = ? ORDER BY nombre`;
        const [rows] = await pool.query(q, [estado_id]);
        return rows;
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

//  RUTAS 
async function Obtener_RutabyEstado_Municipio(municipio_id, usuario_id = null) {
    try {
        const q = `CALL sp_obtener_rutas_por_municipio(?, ?)`;
        const [rows] = await pool.query(q, [municipio_id, usuario_id]);
        return rows[0];
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Insertar_Ruta(usuario_id, nombre, descripcion, municipio_id, estado_id, paradas_json, is_public = true) {
    try {
        const q = `CALL sp_crear_ruta(?, ?, ?, ?, ?, ?, ?)`;

        console.log('pruba'+[usuario_id, nombre, descripcion, municipio_id, estado_id, paradas_json, is_public])
        const [rows] = await pool.query(q, [usuario_id, nombre, descripcion, municipio_id, estado_id, paradas_json, is_public]);
        
        return rows[0];
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Actualizar_Ruta(ruta_id, usuario_id, nombre, descripcion, municipio_id, estado_id, paradas_json, is_public) {
    try {
        const q = `CALL sp_actualizar_ruta(?, ?, ?, ?, ?, ?, ?, ?)`;
        await pool.query(q, [ruta_id, usuario_id, nombre, descripcion, municipio_id, estado_id, paradas_json, is_public]);
        return { success: true };
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Borrar_Ruta(ruta_id, usuario_id) {
    try {
        const q = `CALL sp_eliminar_ruta(?, ?)`;
        await pool.query(q, [ruta_id, usuario_id]);
        return { success: true };
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Obtener_Detalles_Ruta(ruta_id, usuario_id) {
    try {
        const q = `CALL sp_detalles_ruta(?, ?)`;
        const [rows] = await pool.query(q, [ruta_id, usuario_id]);
        return {
            ruta: rows[0][0],
            municipios: rows[1],
            puntos: rows[2],
            compartidos: rows[3] || []
        };
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

module.exports = {
    executeQuery,
    login_google,
    obtenerEstados,
    obtenerMunicipiosPorEstado,
    Obtener_RutabyEstado_Municipio,
    Insertar_Ruta,
    Actualizar_Ruta,
    Borrar_Ruta,
    Obtener_Detalles_Ruta
};