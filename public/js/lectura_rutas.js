var map;
var pin;
var diccionario_paradas = {};// Dicionario para almacenar las paradas 1:[lat,lng],2:[lat,lng]
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add= true; //temporal
var controlRutas; // Control de rutas de Leaflet Routing Machine
window.onload = function() {
    MapCreate();
    if (this.document.getElementById('map').exists) {       
        document.getElementById('leaflet-control-attribution leaflet-control').hidden = true;
    }
};

function eliminarParada(index) {
    delete diccionario_paradas[index];
    var lista= document.getElementById('lista_paradas');
    lista.removeChild(document.getElementById('lista_elemento ' + index));
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

    controlRutas = L.Routing.control({
        waypoints: [],
        routeWhileDragging: true,
        createMarker: function() { return null; }, 
        addWaypoints: false 
    }).addTo(map);


    
    if (ruta_add) {   
    map.on('click', function(ev) {
        document.getElementById('lat').value = ev.latlng.lat;
        document.getElementById('lng').value = ev.latlng.lng;
        diccionario_paradas[Object.keys(diccionario_paradas).length + 1] = [ev.latlng.lat,ev.latlng.lng];
        document.getElementById('lista_paradas').innerHTML += '<li id="lista_elemento ' + (Object.keys(diccionario_paradas).length) + '"> Parada ' + (Object.keys(diccionario_paradas).length) + ': Latitud ' + ev.latlng.lat + ', Longitud ' + ev.latlng.lng + ' <label style="cursor: pointer; color: red;" onclick="eliminarParada(' + (Object.keys(diccionario_paradas).length) + ')">Eliminar</label> </li>';
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
};

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
}