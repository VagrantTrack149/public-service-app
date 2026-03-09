const express = require('express');
const path = require('path');
const fs = require('fs');
const cors = require('cors');
const session = require('express-session');
require('dotenv').config();
const db = require('./db/conex_db');

const auth = require('./public/components/auth');

const app = express();
const PORT = process.env.PORT || 3307;

app.use(cors());
app.use(express.json());

app.use(session({
    secret: process.env.SESSION_SECRET || 'xd',
    resave: false,
    saveUninitialized: false
}));

auth.initialize(app);

app.use(express.static(path.join(__dirname, 'public')));

//  API 

app.get('/api/me', (req, res) => {
    if (req.isAuthenticated()) {
        res.json(req.user);
    } else {
        res.status(401).json({ error: 'No autenticado' });
    }
});

app.get('/api/estados', async (req, res) => {
    try {
        const estados = await db.obtenerEstados();
        res.json(estados);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener estados' });
    }
});

app.get('/api/estados/:id/municipios', async (req, res) => {
    try {
        const municipios = await db.obtenerMunicipiosPorEstado(req.params.id);
        res.json(municipios);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener municipios' });
    }
});

app.post('/api/login/google', async (req, res) => {
    try {
        const { google_id, nombre, email, avatar_url } = req.body;
        const result = await db.login_google(google_id, nombre, email, avatar_url);
        res.json(result);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error en login' });
    }
});

app.get('/api/rutas', async (req, res) => {
    try {
        const { municipio_id } = req.query;
        if (!municipio_id) {
            return res.status(400).json({ error: 'Falta municipio_id' });
        }
        const usuario_id = req.isAuthenticated() ? req.user.id : null;
        const rutas = await db.Obtener_RutabyEstado_Municipio(municipio_id, usuario_id);
        res.json(rutas);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener rutas' });
    }
});

app.post('/api/rutas', async (req, res) => {
    try {
        if (!req.isAuthenticated()) {
            return res.status(401).json({ error: 'Debes iniciar sesión' });
        }
        const { nombre, descripcion, municipio_id, estado_id, paradas, is_public } = req.body;
        const paradas_json = JSON.stringify(paradas);
        const result = await db.Insertar_Ruta(
            req.user.id,
            nombre,
            descripcion || null,
            municipio_id,
            estado_id,
            paradas_json,
            is_public !== undefined ? is_public : true
        );
        res.json({ ruta_id: result[0]?.ruta_id, success: true });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al insertar ruta' });
    }
});

app.get('/api/rutas/:id', async (req, res) => {
    try {
        const usuario_id = req.isAuthenticated() ? req.user.id : null;
        const detalles = await db.Obtener_Detalles_Ruta(req.params.id, usuario_id);
        res.json(detalles);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener detalles' });
    }
});

app.put('/api/rutas/:id', async (req, res) => {
    try {
        if (!req.isAuthenticated()) return res.status(401).json({ error: 'No autenticado' });
        const { nombre, descripcion, municipio_id, estado_id, paradas, is_public } = req.body;
        const paradas_json = JSON.stringify(paradas);
        await db.Actualizar_Ruta(
            req.params.id,
            req.user.id,
            nombre,
            descripcion,
            municipio_id,
            estado_id,
            paradas_json,
            is_public
        );
        res.json({ success: true });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al actualizar' });
    }
});

app.delete('/api/rutas/:id', async (req, res) => {
    try {
        if (!req.isAuthenticated()) return res.status(401).json({ error: 'No autenticado' });
        await db.Borrar_Ruta(req.params.id, req.user.id);
        res.json({ success: true });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al borrar' });
    }
});

//  paginas 
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'src', 'index.html'));
});
app.get('/Buscar_rutas', (req, res) => {
    res.sendFile(path.join(__dirname, 'src', 'pages', 'Buscar_rutas.html'));
});
app.get('/Agregar_rutas', (req, res) => {
    res.sendFile(path.join(__dirname, 'src', 'pages', 'agregar_ruta.html'));
});
app.get('/header.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'src', 'header.html'));
});

app.listen(PORT, () => {
    console.log('Server running in port ' + PORT);
});