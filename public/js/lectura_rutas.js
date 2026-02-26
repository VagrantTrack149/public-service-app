import { cargarEstados, cargarMunicipios,geocodificarUbicacion } from './estados.js';
var map;
var pin;
var diccionario_paradas = {};// Dicionario para almacenar las paradas 1:[lat,lng],2:[lat,lng]
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add= true; //temporal
var controlRutas; // Control de rutas de Leaflet Routing Machine
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
    var lista= document.getElementById('lista_paradas');
    var item = document.getElementById('lista_elemento_' + index);
    if (lista && item) lista.removeChild(item);
    actualizarRuta()
    console.log(diccionario_paradas);
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
    }).setView([40, 0], 3);
     map.setView([23.6345, -102.5528], 5);
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
        console.warn('Leaflet Routing Machine not available: controlRutas disabled.');
        controlRutas = null;
    }


    
    if (ruta_add) {   
    map.on('click', function(ev) {
        var latEl = document.getElementById('lat');
        var lngEl = document.getElementById('lng');
        if (latEl) latEl.value = ev.latlng.lat;
        if (lngEl) lngEl.value = ev.latlng.lng;

        diccionario_paradas[Object.keys(diccionario_paradas).length + 1] = [ev.latlng.lat,ev.latlng.lng];
        var idx = Object.keys(diccionario_paradas).length;
        var lista = document.getElementById('lista_paradas');
        if (lista) {
            lista.innerHTML += '<li id="lista_elemento_' + idx + '"> Parada ' + idx + ': Latitud ' + ev.latlng.lat + ', Longitud ' + ev.latlng.lng + ' <label style="cursor: pointer; color: red;" onclick="eliminarParada(' + idx + ')">Eliminar</label> </li>';
        }
        console.log(diccionario_paradas);

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
    // Expose map globally so other modules/scripts can access it
    window.map = map;
};

function actualizarRuta() {
    var waypoints = [];
    
    Object.keys(diccionario_paradas).forEach(function(key) {
        var coords = diccionario_paradas[key];
        waypoints.push(L.latLng(coords[0], coords[1]));
        console.log(waypoints);
    });

    if (controlRutas) {
        controlRutas.setWaypoints(waypoints);
    }
}

function guardarRuta() {
    //se crea un objeto con la información de la ruta, incluyendo las paradas y se coloca en un json dentro de Rutas locales/idruta.json
    //se implementará posteriormente, se guardará en la base de datos, se mostrará un menu con las rutas guardadas y se podrá seleccionar cual eliminar o leer
    var ruta = {
        paradas: diccionario_paradas,
        municipio: document.getElementById('municipios').value,
        estado: document.getElementById('estados').value,
        nombre: document.getElementById('nombre_parada').value,
        estado: document.getElementById('estados').value,
    };
    console.log(ruta);
    var rutaJSON = JSON.stringify(ruta);
    console.log(rutaJSON);
    var blob = new Blob([rutaJSON], { type: 'application/json' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'ruta.json';
    a.click();
    URL.revokeObjectURL(url);
}
function eliminarRuta() {
    //Eliminar ruta de la base de datos, se implementará posteriormente, mostrará un menu con las rutas guardadas y se podrá seleccionar cual eliminar
}
function leerRuta() {
    //Leer ruta de la base de datos, se implementará posteriormente, mostrará un menu con las rutas guardadas y se podrá seleccionar cual leer
    //Se mostraran las rutas en el mapa según estaado y municipio o se podrá acceder a una en particular, se implementará posteriormente
    let rutas_leidas = document.getElementById('ruta') && document.getElementById('ruta').files ? document.getElementById('ruta').files[0] : null;
    if (!rutas_leidas) {
        console.warn('No se seleccionó ningún archivo de ruta.');
        return;
    }
    console.log(rutas_leidas);
    var reader = new FileReader();
    reader.onload = function(e) {
        var ruta = JSON.parse(e.target.result);
        console.log(ruta);
        diccionario_paradas = ruta.paradas;
        console.log(diccionario_paradas);
        var muniEl = document.getElementById('municipios');
        var estadoEl = document.getElementById('estados');
        var nombreEl = document.getElementById('nombre_parada');
        var lista = document.getElementById('lista_paradas');
        
        if (estadoEl) estadoEl.value = ruta.estado || '';
        if(cargarMunicipios) cargarMunicipios(ruta.estado);
        if (muniEl) muniEl.value = ruta.municipio || '';
        if (nombreEl) nombreEl.value = ruta.nombre || '';
        if (lista) lista.innerHTML = '';
        console.log(ruta.estado, ruta.municipio);
        geocodificarUbicacion(ruta.estado, ruta.municipio).then(resultado => {
            if (resultado) {
                console.log(`Geocodificado: ${resultado.nombre} en [${resultado.lat}, ${resultado.lng}]`);
                //map.setView([resultado.lat, resultado.lng], 12); Problemas, envia de cdmx o estado cuando no responde rapido
                }
            }
        );
        Object.keys(diccionario_paradas).forEach(function(key) {
            var coords = diccionario_paradas[key];
            var lat = coords[0];
            var lng = coords[1];
            if (window.L && map) {
                var marker = L.marker([lat, lng]).addTo(map);
                marker.bindPopup('Parada ' + key).openPopup();
            }
            if (lista) {
                lista.innerHTML += '<li id="lista_elemento_' + key + '"> Parada ' + key + ': Latitud ' + lat + ', Longitud ' + lng + ' <label style="cursor: pointer; color: red;" onclick="eliminarParada(' + key + ')">Eliminar</label> </li>';
            }
        });
        actualizarRuta();
    };
    reader.readAsText(rutas_leidas);

}
function buscarRutas(estadoEl, municipioEl) {
    //Buscar rutas en la base de datos según estado y municipio, se implementará posteriormente, mostrará las rutas en el mapa según estaado y municipio o se podrá acceder a una en particular, se implementará posteriormente
    console.log('Buscando rutas en el estado: ' + estadoEl.value + ' y municipio: ' + municipioEl.value);
}

// Expose functions used by inline handlers in the HTML (modules are not global)
window.leerRuta = leerRuta;
window.buscarRutas = buscarRutas;
window.eliminarParada = eliminarParada;
window.guardarRuta = guardarRuta;