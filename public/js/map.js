var map;
var pin;
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add= false; //temporal
// Esperar a que el HTML esté listo
window.onload = function() {
    MapCreate();
    if (this.document.getElementById('map').exists) {       
        document.getElementById('leaflet-control-attribution leaflet-control').hidden = true;
    }
};



function MapCreate() {
    //Crear el contenedor si no existe
    if (!document.getElementById('map')) {
        var div = document.createElement('div');
        div.id = 'map';
        div.style.height = '100vh';
        div.style.width = '80%';
        div.style.marginLeft = 'auto';
        document.body.prepend(div);
    }

    //Inicializar el objeto map
    map = L.map('map',{
        attributionControl: false,
        compass: true
    }).setView([40, 0], 3);
     map.setView([23.6345, -102.5528], 5);
    L.tileLayer(tilesURL, {
        attribution: mapAttrib,
        maxZoom: 19
    }).addTo(map);
    // Mover el listener de CLICK aquí adentro
    if (ruta_add) {   
    map.on('click', function(ev) {
        document.getElementById('lat').value = ev.latlng.lat;
        document.getElementById('lng').value = ev.latlng.lng;

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
}