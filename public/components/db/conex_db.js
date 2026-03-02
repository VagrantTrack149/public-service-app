const express= require('express');
const app= express();
const sql= require('mssql');
const cors= require('cors');
const dotenv= require('dotenv');
dotenv.config();
app.use(cors());

const dbSettings = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER,
    database: process.env.DB_DATABASE,
    options: {
        encrypt: process.env.DB_ENCRYPT === 'true', // true para Azure
        trustServerCertificate: true, // local
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};
let poolPromise;

export const getConnection = async () => {
    try {
        if (!poolPromise) {
            poolPromise = sql.connect(dbSettings);
        }
        return await poolPromise;
    } catch (error) {
        console.error(error.message);
        poolPromise = null;
        throw error; 
    }
};
const query = async (query) => {
    try {
        const pool = await getConnection();
        const result = await pool.request().query(query);
        return result.recordset;
    } catch (error) {
        console.error(error.message);
        throw error; 
    }
};

export const Obtener_RutabyEstado_Municipio = async (estado, municipio) => {
    try {
        const query = `Select * from vistaRutas where Estado = '${estado}' and Municipio = '${municipio}'`;
        const result = await query(query);
        return result;
    } catch (error) {
        console.error(error.message);
        throw error; 
    }
};

export const Insertar_Rutaby_User= async (id,Nombre_ruta) => {
    try {
        const query = `CALL Insertar_Ruta(${id},${Nombre_ruta})`;
        const result = await query(query);
        return result;
    }catch(error){
        console.error(error.message);
        throw error;
    }
};

export const Borrar_Rutaby_User= async (id,Nombre_ruta) => {
    try {
        const query = `CALL Borrar_Ruta(${id},${Nombre_ruta})`;
        const result = await query(query);
        return result;
    }catch(error){
        console.error(error.message);
        throw error;
    }
};

export const Actualizar_Rutaby_User= async (id,Nombre_ruta) => {
    try {
        const query = `CALL Actualizar_Ruta(${id},${Nombre_ruta})`;
        const result = await query(query);
        return result;
    }catch(error){
        console.error(error.message);
        throw error;
    }
};


