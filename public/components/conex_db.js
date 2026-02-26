const express= require('express');
const app= express();
const sql= require('mssql');
const cors= require('cors');
const dotenv= require('dotenv');
dotenv.config();
app.use(cors());

const dbSettings = {
    user: process.env.DB_USER || "sa",
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER || "localhost",
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