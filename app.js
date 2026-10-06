// app.js — Servidor principal
require('dotenv').config();

const express = require('express');
const session = require('express-session');
const path = require('path');
const db = require('./db/conex_db');
const auth = require('./src/index');

const app = express();
const PORT = process.env.PORT || 3307;

//  Middlewares base 
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

//  Sesión 
app.use(session({
  secret: process.env.SESSION_SECRET || 'cambia-esto-en-produccion-por-favor',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 1000 * 60 * 60 * 24 * 7 // 7 días
  }
}));

//  Auth (passport + rutas /api/login, /api/register, /auth/google, /logout, /api/me) 
auth.initialize(app);

//  Archivos estáticos 
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'src')));

//  Rutas de páginas 
app.get('/', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/index.html')));

app.get('/login', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/pages/login.html')));

app.get('/register', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/pages/register.html')));

app.get('/Buscar_rutas', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/pages/Buscar_rutas.html')));

app.get('/Agregar_rutas', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/pages/agregar_ruta.html')));

app.get('/Seleccionar_coordenadas', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/pages/selecionar_coordenadas.html')));

app.get('/header.html', (req, res) =>
  res.sendFile(path.join(__dirname, 'src/header.html')));

//  API: Estados y municipios 
app.get('/api/estados', async (req, res) => {
  try {
    const estados = await db.obtenerEstados();
    res.json(estados);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al obtener estados' });
  }
});

app.get('/api/estados/:estadoId/municipios', async (req, res) => {
  try {
    const municipios = await db.obtenerMunicipiosPorEstado(req.params.estadoId);
    res.json(municipios);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al obtener municipios' });
  }
});

//  API: Rutas 
// GET /api/rutas?estado_id=..&municipio_id=..
app.get('/api/rutas', async (req, res) => {
  try {
    const estadoId    = req.query.estado_id;
    const municipioId = req.query.municipio_id;
    const usuarioId   = (req.isAuthenticated && req.isAuthenticated()) ? req.user.id : null;

    if (!estadoId || !municipioId) {
      return res.status(400).json({ error: 'Se requieren estado_id y municipio_id' });
    }

    const rutas = await db.Obtener_Detalles_Ruta(estadoId, municipioId, usuarioId);

    // El frontend espera [ [rutas...] ] y filtra nulls
    res.json([Array.isArray(rutas) ? rutas.filter(Boolean) : []]);
  } catch (e) {
    console.error('Error en GET /api/rutas:', e);
    res.status(500).json({ error: 'Error al obtener rutas' });
  }
});

// POST /api/rutas — crear ruta (requiere login)
app.post('/api/rutas', auth.ensureLoggedIn, async (req, res) => {
  try {
    const {
      nombre, descripcion, publica = true,
      estado_id, municipio_id, puntos
    } = req.body || {};

    if (!nombre || !estado_id || !municipio_id || !Array.isArray(puntos) || puntos.length === 0) {
      return res.status(400).json({ error: 'Faltan datos de la ruta' });
    }

    const usuarioId = req.user.id;
    const puntosJson = JSON.stringify(puntos);

    const result = await db.Insertar_Ruta(
      usuarioId, nombre, descripcion || '',
      publica, estado_id, municipio_id, puntosJson
    );

    res.json({ ok: true, ruta_id: result?.[0]?.ruta_id || result?.ruta_id });
  } catch (e) {
    console.error('Error al insertar ruta:', e);
    res.status(500).json({ error: e.message || 'Error al guardar ruta' });
  }
});

//  404 
app.use((req, res) => {
  res.status(404).send('Página no encontrada');
});

//  Error handler 
app.use((err, req, res, next) => {
  console.error('Error no manejado:', err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

//  Iniciar servidor 
app.listen(PORT, () => {
  console.log(` http://localhost:${PORT}`);
});