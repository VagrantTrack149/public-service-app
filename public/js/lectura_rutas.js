var map;
var pin;
var diccionario_paradas = {};// Dicionario para almacenar las paradas 1:[lat,lng],2:[lat,lng]
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add= true; //temporal
var controlRutas; // Control de rutas de Leaflet Routing Machine
// 1. Esperar a que el HTML esté listo
window.onload = function() {
    MapCreate();
    if (this.document.getElementById('map').exists) {       
        document.getElementById('leaflet-control-attribution leaflet-control').hidden = true;
    }
};

function eliminarParada(index) {
    delete diccionario_paradas[index];
    document.getElementById('lista_elemento' + index).remove();
    console.log(diccionario_paradas);
}


function MapCreate() {
    // 2. Crear el contenedor si no existe
    if (!document.getElementById('map')) {
        var div = document.createElement('div');
        div.id = 'map';
        div.style.height = '100vh';
        div.style.width = '80%';
        div.style.marginLeft = 'auto';
        document.body.prepend(div);
    }

    // 3. Inicializar el objeto map
    map = L.map('map',{
        attributionControl: false,
        compass: true
    }).setView([40, 0], 3);
     map.setView([23.6345, -102.5528], 5);
    L.tileLayer(tilesURL, {
        attribution: mapAttrib,
        maxZoom: 19
    }).addTo(map);

    // INICIALIZACIÓN DEL PLUGIN DE RUTAS
    controlRutas = L.Routing.control({
        waypoints: [],
        routeWhileDragging: true,
        createMarker: function() { return null; }, // No crea marcadores extra, ya usas los tuyos
        addWaypoints: false // Evita que el usuario añada puntos arrastrando la línea directamente
    }).addTo(map);


    // 4. Mover el listener de CLICK aquí adentro
    // Esto garantiza que map ya está definido
    if (ruta_add) {   
    map.on('click', function(ev) {
        document.getElementById('lat').value = ev.latlng.lat;
        document.getElementById('lng').value = ev.latlng.lng;
        diccionario_paradas[Object.keys(diccionario_paradas).length + 1] = [ev.latlng.lat,ev.latlng.lng];
        document.getElementById('lista_paradas').innerHTML += '<li id="lista_elemento ' + (Object.keys(diccionario_paradas).length) + '"> Parada ' + (Object.keys(diccionario_paradas).length) + ': Latitud ' + ev.latlng.lat + ', Longitud ' + ev.latlng.lng + ' <label style="cursor: pointer; color: red;" onclick="eliminarParada(' + (Object.keys(diccionario_paradas).length) + ')">Eliminar</label> </li>';
        console.log(diccionario_paradas);

        // ACTUALIZACIÓN: Dibujar la ruta con el nuevo punto
        actualizarRuta();
        if (pin) {
            pin.setLatLng(ev.latlng);
        } else {
            pin = L.marker(ev.latlng, { riseOnHover: true, draggable: true }).addTo(map);
            
            // Evento drag corregido (e.target)
            pin.on('drag', function(e) {
                var position = e.target.getLatLng();
                document.getElementById('lat').value = position.lat;
                document.getElementById('lng').value = position.lng;
            });
        }
    });     
    }
};

// FUNCIÓN NUEVA: Convierte el diccionario en waypoints para el mapa
function actualizarRuta() {
    var waypoints = [];
    
    // Extraemos las coordenadas del diccionario y las convertimos a objetos L.latLng
    Object.keys(diccionario_paradas).forEach(function(key) {
        var coords = diccionario_paradas[key];
        waypoints.push(L.latLng(coords[0], coords[1]));
    });

    // Pasamos los puntos al control de rutas
    if (controlRutas) {
        controlRutas.setWaypoints(waypoints);
    }
}