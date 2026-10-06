var map;
var pin;
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '&copy; OpenStreetMap';
var ruta_add = true; // al hacer clic en el mapa, se agrega una parada si el contenedor existe

window.onload = function () {
  MapCreate();
};

function MapCreate() {
  if (!document.getElementById('map')) {
    var div = document.createElement('div');
    div.id = 'map';
    div.style.height = '100vh';
    div.style.width = '80%';
    div.style.marginLeft = 'auto';
    document.body.prepend(div);
  }

  map = L.map('map', { attributionControl: false, zoomControl: true })
        .setView([23.6345, -102.5528], 5);

  L.tileLayer(tilesURL, { attribution: mapAttrib, maxZoom: 19 }).addTo(map);

  // Ajustar a la altura del header si existe
  const mapEl = document.getElementById('map');
  if (mapEl && mapEl.classList.contains('pt-16')) {
    setTimeout(() => map.invalidateSize(), 100);
  }

  if (ruta_add) {
    map.on('click', function (ev) {
      const latEl = document.getElementById('lat');
      const lngEl = document.getElementById('lng');
      if (latEl) latEl.value = ev.latlng.lat;
      if (lngEl) lngEl.value = ev.latlng.lng;

      if (pin) {
        pin.setLatLng(ev.latlng);
      } else {
        pin = L.marker(ev.latlng, { riseOnHover: true, draggable: true }).addTo(map);
        pin.on('drag', function (e) {
          const position = e.target.getLatLng();
          if (latEl) latEl.value = position.lat;
          if (lngEl) lngEl.value = position.lng;
        });
      }
    });
  }

  window.map = map;
}