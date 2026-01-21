const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;
const cors= require('cors');
const fs = require('fs');
app.use(cors()); // Enable CORS for all routes

app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, () => {
  console.log('Server running in port'+ PORT);
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'src', 'index.html'));
});



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


module.exports = {
    getEstadoById,
    getAllEstados,
    getMunicipiosByEstadoId
};