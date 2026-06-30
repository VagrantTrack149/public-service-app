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

function leerRuta(rutas_leidas) {
    rutas_leidas = document.getElementById('ruta')?.files[0];
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

const colores = ['#FF5733', '#33FF57', '#3357FF', '#F333FF', '#FF33A1'];
async function buscarRutas() {
    const municipioSelect = document.getElementById('municipios');
    const municipioId = municipioSelect.value;
    const estadoSelect = document.getElementById('estados');
    const estadoId = estadoSelect.value;
    if (!municipioId) {
        alert('Selecciona un municipio');
        return;
    }
    if (!estadoId) {
        alert('Selecciona un estado');
        return;
    }
    try {
        //const response = await fetch(`/api/rutas?municipio_id=${municipioId}`);
        const response = await fetch(`/api/rutas?estado_id=${estadoId}&municipio_id=${municipioId}`, {
            method: 'GET'
        });
        console.log('Petición enviada a /api/rutas con municipio_id: y estado_id: ', municipioId, estadoId);
        if (!response.ok) throw new Error('Error en la petición');
        const rutas = await response.json();
        const rutas_solo=rutas[0];
        console.log('Rutas encontradas:', rutas);
        //alert(`Se encontraron ${rutas.length} rutas. Revisa la consola.`);
        const text_rutas=document.getElementById('temporal_ruta');
        text_rutas.value = JSON.stringify(rutas);
        var waypoints = [];
        rutas_solo.forEach((ruta, index) => {
            if (ruta.puntos && Array.isArray(ruta.puntos)) {
                const colorActual = colores[index % colores.length];
                L.Routing.control({
                    waypoints: waypoints,
                    createMarker: function() { return null; },
                    routeWhileDragging: false,
                    lineOptions: {
                        styles: [{ color: colorActual, weight: 5, opacity: 0.8 }]
                    }
                }).addTo(map);
                ruta.puntos.forEach((coords, idx) => {
                    const latLng = L.latLng(coords.lat, coords.lng);
                    waypoints.push(latLng);
                    L.marker([coords.lat, coords.lng], {
                        icon: L.divIcon({
                            className: 'custom-icon',
                            html: `<div style="background-color: ${colorActual}; width: 12px; height: 12px; border-radius: 50%; border: 2px solid white;"></div>`
                        })
                    })
                    .addTo(map)
                    .bindPopup(`Ruta ${index + 1} - Parada ${idx + 1}`);
                });
            }
        });
        if (controlRutas) {
            controlRutas.setWaypoints(waypoints);
        }
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
    const descripcion = document.getElementById('descripcion_parada').value;
    if (!estadoId || !municipioId || !nombre) {
        alert('Completa todos los campos');
        return;
    }
    if (Object.keys(diccionario_paradas).length === 0) {
        alert('Agrega al menos una parada');
        return;
    }

    // Convertir diccionario_paradas a array de objetos {lat, lng}
    const puntos = Object.values(diccionario_paradas).map(coords => ({
        lat: coords[0],
        lng: coords[1]
    }));
    console.log('Puntos a guardar:', puntos);
    const data = {
        usuario_id: currentUser.id,
        nombre: nombre,
        descripcion: descripcion,
        publica: true,
        estado_id: parseInt(estadoId),
        municipio_id: parseInt(municipioId),
        puntos: puntos
    };

    try {
        const response = await fetch('/api/rutas', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.error || 'Error al guardar');
        }
        const result = await response.json();
        alert('Ruta guardada con ID: ' + result.ruta_id);
        
        diccionario_paradas = {};
        document.getElementById('lista_paradas').innerHTML = '';
        actualizarRuta();
    } catch (error) {
        console.error('Error al guardar ruta:', error);
        alert('Error al guardar: ' + error.message);
    }
}

window.leerRuta = leerRuta;
window.buscarRutas = buscarRutas;
window.eliminarParada = eliminarParada;
window.Descargar_Ruta = Descargar_Ruta;
window.Guardar_ruta = Guardar_ruta;