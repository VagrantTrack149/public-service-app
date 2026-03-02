const express = require('express');
const path = require('path');
<<<<<<< HEAD
=======
const session = require('express-session');
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
const fs = require('fs');
const cors = require('cors');
const session = require('express-session');
require('dotenv').config();

<<<<<<< HEAD
// auth module
=======
// auth
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
const auth = require('./public/components/auth');

const app = express();
const PORT = process.env.PORT || 3307;

app.use(cors()); // Enable CORS for all routes
app.use(express.json());

// sesion para passport
app.use(session({
  secret: process.env.SESSION_SECRET || 'xd',
  resave: false,
  saveUninitialized: false
}));

// init auth
auth.initialize(app);
<<<<<<< HEAD

//ruta segura
app.get('/perfil',auth.ensureLoggedIn,(req, res)=>{
    res.send('Usuario Loggeado')
})

app.use(express.static(path.join(__dirname, 'public')));


=======

app.use(express.static(path.join(__dirname, 'public')));

// middleware para proteger rutas 
const ensureLoggedIn = auth.ensureLoggedIn;
>>>>>>> 14ebbfb6803338e62f592bf1f00101fd6390798e
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