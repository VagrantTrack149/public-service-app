const express = require('express');
const path = require('path');
const session = require('express-session');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const fs = require('fs');
const cors= require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3307;

app.use(cors()); // Enable CORS for all routes
app.use(express.json());

app.use(session({
  secret: process.env.SESSION_SECRET || 'xd',
  resave: false,
  saveUninitialized: false
}));
app.use(passport.initialize());
app.use(passport.session());

app.use(express.static(path.join(__dirname, 'public')));

passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: process.env.GOOGLE_CALLBACK_URL || `http://localhost:${PORT}/auth/google/callback`
  },
  async (accessToken, refreshToken, profile, cb) => {
    //insert o update usuario, despues implementar
    const usuario = {
      googleId: profile.id,
      nombre: profile.displayName,
      email: profile.emails && profile.emails[0].value
    };
    return cb(null, usuario);
  }
));

// rutas de autenticación
app.get('/auth/google',
  passport.authenticate('google', { scope: ['profile','email'] }));

app.get('/auth/google/callback',
  passport.authenticate('google', { failureRedirect: '/login.html' }),
  (req, res) => {
    res.redirect('/');
  });

// middleware para proteger rutas
function ensureLoggedIn(req, res, next) {
  if (req.isAuthenticated()) return next();
  res.redirect('/');
}

app.listen(PORT, () => {
  console.log('Server running in port '+ PORT);
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'src', 'index.html'));
});


//Cargar estados local alternativa db
const estados= JSON.parse(fs.readFileSync(path.join(__dirname, 'public', 'components', 'Estados.json'), 'utf8'));

function getEstadoById(id) {
    const estado=estados[String(id)];
    if (estado) {
        return estado;
    }
    return null;
}

function getAllEstados() {
    //return estados;
    const arrayEstados = Object.keys(estados).map(key => {
        return {
            id: key,
            Estado: estados[key].Estado,
            municipios: estados[key].municipios
        };
    });
    return arrayEstados;
}
function getMunicipiosByEstadoId(estadoId) {
    //return estados.find(estado => estado.id === estadoId).municipios;
    const estado = getEstadoById(estadoId);
    if (estado) {
        return estado.municipios;
    }
    return null;
}

//api interna para filtrado
app.get('/api/estados', (req, res) => {
    res.json(getAllEstados());
});

app.get('/api/estados/:id', (req, res) => {
    const estado = getEstadoById(req.params.id);
    if (estado) {
        res.json(estado);
    } else {
        res.status(404).send('Estado no encontrado');
    }
});
app.get('/api/estados/:id/municipios', (req, res) => {
    const estado = getEstadoById(req.params.id);
    if (estado) {
        res.json(estado.municipios);
    } else {
        res.status(404).send('Estado no encontrado');
    }
});
//rutas de uso comun
app.get('/Buscar_rutas', (req, res) => {
    res.sendFile(path.join(__dirname, 'src','pages', 'Buscar_rutas.html'));
});
app.get('/Agregar_rutas', (req, res) => {
    res.sendFile(path.join(__dirname, 'src', 'pages','agregar_ruta.html'));
});

module.exports = {
    getEstadoById,
    getAllEstados,
    getMunicipiosByEstadoId
};