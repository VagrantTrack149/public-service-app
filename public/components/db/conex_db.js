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

async function login_google(p_google_id, p_nombre, p_email, p_avatar_url) {
    try {
        const q = `call sp_login_google('${p_google_id}','${p_nombre}','${p_email}','${p_avatar_url}')`;
        return await executeQuery(q);
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Obtener_RutabyEstado_Municipio(estado, municipio) {
    try {
        const q = `Select * from vistaRutas where Estado = '${estado}' and Municipio = '${municipio}'`;
        return await executeQuery(q);
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Insertar_Rutaby_User(id, Nombre_ruta) {
    try {
        const q = `CALL Insertar_Ruta(${id},'${Nombre_ruta}')`;
        return await executeQuery(q);
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Borrar_Rutaby_User(id, Nombre_ruta) {
    try {
        const q = `CALL Borrar_Ruta(${id},'${Nombre_ruta}')`;
        return await executeQuery(q);
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

async function Actualizar_Rutaby_User(id, Nombre_ruta) {
    try {
        const q = `CALL Actualizar_Ruta(${id},'${Nombre_ruta}')`;
        return await executeQuery(q);
    } catch (error) {
        console.error(error.message);
        throw error;
    }
}

module.exports = {
    
    executeQuery,
    login_google,
    Obtener_RutabyEstado_Municipio,
    Insertar_Rutaby_User,
    Borrar_Rutaby_User,
    Actualizar_Rutaby_User
};


