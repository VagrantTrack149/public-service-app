import { cargarEstados, cargarMunicipios, geocodificarUbicacion } from './estados.js';

var map;
var pin;
var diccionario_paradas = {};
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add = true;
var controlRutas;
var currentUser = null;

// Obtener usuario actual al cargar la página
async function fetchCurrentUser() {
    try {
        const res = await fetch('/api/me');
        if (res.ok) {
            currentUser = await res.json();
            console.log('Usuario actual:', currentUser);
        } else {
            console.log('No autenticado');
        }
    } catch (e) {
        console.error('Error al obtener usuario', e);
    }
}
fetchCurrentUser();

window.onload = function() {
    MapCreate();
    var mapEl = document.getElementById('map');
    if (mapEl) {
        var attr = document.querySelector('.leaflet-control-attribution.leaflet-control');
        if (attr) attr.hidden = true;
    }
};

function eliminarParada(index) {
    delete diccionario_paradas[index];
    var lista = document.getElementById('lista_paradas');
    var item = document.getElementById('lista_elemento_' + index);
    if (lista && item) lista.removeChild(item);
    actualizarRuta();
}

function MapCreate() {
    if (!document.getElementById('map')) {
        var div = document.createElement('div');
        div.id = 'map';
        div.style.height = '100vh';
        div.style.width = '80%';
        div.style.marginLeft = 'auto';
        document.body.prepend(div);
    }

    map = L.map('map',{
        attributionControl: false,
        compass: true
    }).setView([23.6345, -102.5528], 5);
    L.tileLayer(tilesURL, {
        attribution: mapAttrib,
        maxZoom: 19
    }).addTo(map);

    if (window.L && L.Routing && typeof L.Routing.control === 'function') {
        controlRutas = L.Routing.control({
            waypoints: [],
            routeWhileDragging: true,
            createMarker: function() { return null; },
            addWaypoints: false
        }).addTo(map);
    } else {
        console.warn('Leaflet Routing Machine not available');
        controlRutas = null;
    }

    if (ruta_add) {
        map.on('click', function(ev) {
            var latEl = document.getElementById('lat');
            var lngEl = document.getElementById('lng');
            if (latEl) latEl.value = ev.latlng.lat;
            if (lngEl) lngEl.value = ev.latlng.lng;

            var idx = Object.keys(diccionario_paradas).length + 1;
            diccionario_paradas[idx] = [ev.latlng.lat, ev.latlng.lng];
            var lista = document.getElementById('lista_paradas');
            if (lista) {
                lista.innerHTML += '<li id="lista_elemento_' + idx + '"> Parada ' + idx + ': Latitud ' + ev.latlng.lat + ', Longitud ' + ev.latlng.lng + ' <label style="cursor: pointer; color: red;" onclick="eliminarParada(' + idx + ')">Eliminar</label> </li>';
            }
            actualizarRuta();
            if (pin) {
                pin.setLatLng(ev.latlng);
            } else {
                pin = L.marker(ev.latlng, { riseOnHover: true, draggable: true }).addTo(map);
                pin.on('drag', function(e) {
                    var position = e.target.getLatLng();
                    document.getElementById('lat').value = position.lat;
                    document.getElementById('lng').value = position.lng;
                });
            }
        });
    }
    window.map = map;
}

function actualizarRuta() {
    var waypoints = [];
    Object.keys(diccionario_paradas).forEach(function(key) {
        var coords = diccionario_paradas[key];
        waypoints.push(L.latLng(coords[0], coords[1]));
    });
    if (controlRutas) {
        controlRutas.setWaypoints(waypoints);
    }
}

function Descargar_Ruta() {
    var ruta = {
        paradas: diccionario_paradas,
        municipio_id: document.getElementById('municipios').value,
        estado_id: document.getElementById('estados').value,
        nombre: document.getElementById('nombre_parada').value
    };
    var blob = new Blob([JSON.stringify(ruta)], { type: 'application/json' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'ruta.json';
    a.click();
    URL.revokeObjectURL(url);
}

function leerRuta() {
    let rutas_leidas = document.getElementById('ruta')?.files[0];
    if (!rutas_leidas) return;
    var reader = new FileReader();
    reader.onload = function(e) {
        var ruta = JSON.parse(e.target.result);
        diccionario_paradas = ruta.paradas;
        var estadoSelect = document.getElementById('estados');
        var municipioSelect = document.getElementById('municipios');
        if (ruta.estado_id) estadoSelect.value = ruta.estado_id;
        if (ruta.municipio_id) {
            cargarMunicipios(ruta.estado_id).then(() => {
                municipioSelect.value = ruta.municipio_id;
            });
        }
        if (ruta.nombre) document.getElementById('nombre_parada').value = ruta.nombre;
        
        Object.keys(diccionario_paradas).forEach(function(key) {
            var coords = diccionario_paradas[key];
            L.marker(coords).addTo(map).bindPopup('Parada ' + key);
        });
        actualizarRuta();
    };
    reader.readAsText(rutas_leidas);
}

async function buscarRutas() {
    const municipioSelect = document.getElementById('municipios');
    const municipioId = municipioSelect.value;
    if (!municipioId) {
        alert('Selecciona un municipio');
        return;
    }
    try {
        //const response = await fetch(`/api/rutas?municipio_id=${municipioId}`);
        const response = await fetch(`/api/rutas?municipio_id=${municipioId}`, {
            method: 'GET'
        });
        if (!response.ok) throw new Error('Error en la petición');
        const rutas = await response.json();
        console.log('Rutas encontradas:', rutas);
        alert(`Se encontraron ${rutas.length} rutas. Revisa la consola.`);
    } catch (error) {
        console.error('Error al buscar rutas:', error);
    }
}

async function Guardar_ruta() {
    if (!currentUser) {
        alert('Debes iniciar sesión para guardar una ruta');
        return;
    }
    const estadoId = document.getElementById('estados').value;
    const municipioId = document.getElementById('municipios').value;
    const nombre = document.getElementById('nombre_parada').value;
    if (!estadoId || !municipioId || !nombre) {
        alert('Completa todos los campos');
        return;
    }
    if (Object.keys(diccionario_paradas).length === 0) {
        alert('Agrega al menos una parada');
        return;
    }
    const data = {
        usuario_id: currentUser.id, 
        nombre: nombre,
        descripcion: '',
        municipio_id: municipioId,
        estado_id: estadoId,
        paradas: diccionario_paradas,
        is_public: true
    };
    try {
        const response = await fetch('/api/rutas', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        if (!response.ok) throw new Error('Error al guardar');
        const result = await response.json();
        alert('Ruta guardada con ID: ' + result.ruta_id);
        
        diccionario_paradas = {};
        document.getElementById('lista_paradas').innerHTML = '';
        actualizarRuta();
    } catch (error) {
        console.error('Error al guardar ruta:', error);
        alert('Error al guardar');
    }
}

window.leerRuta = leerRuta;
window.buscarRutas = buscarRutas;
window.eliminarParada = eliminarParada;
window.Descargar_Ruta = Descargar_Ruta;
window.Guardar_ruta = Guardar_ruta;