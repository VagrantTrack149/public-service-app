import { cargarEstados, cargarMunicipiosEnSelect, geocodificarUbicacion } from './estados.js';

var map;
var pin;
var diccionario_paradas = {};
var tilesURL = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
var mapAttrib = '';
var ruta_add = true;
var controlRutas;
var currentUser = null;

// Estado de rutas mostradas: { id, nombre, color, control, polyline, listItem, markers }
let rutasActivas = [];

//  Usuario actual 
async function fetchCurrentUser() {
  try {
    const res = await fetch('/api/me', { credentials: 'same-origin' });
    if (res.ok) {
      currentUser = await res.json();
      console.log('Usuario actual:', currentUser);
    } else {
      currentUser = null;
    }
  } catch (e) {
    console.error('Error al obtener usuario', e);
  }
}
fetchCurrentUser();

//  Init 
window.onload = function () {
  MapCreate();
  var attr = document.querySelector('.leaflet-control-attribution.leaflet-control');
  if (attr) attr.hidden = true;
};

//  Mapa 
function MapCreate() {
  if (!document.getElementById('map')) {
    var div = document.createElement('div');
    div.id = 'map';
    div.style.height = '100vh';
    div.style.width = '80%';
    div.style.marginLeft = 'auto';
    document.body.prepend(div);
  }

  map = L.map('map', { attributionControl: false, compass: true })
        .setView([23.6345, -102.5528], 5);

  L.tileLayer(tilesURL, { attribution: mapAttrib, maxZoom: 19 }).addTo(map);

  // Ajustar tamaño si el mapa tiene offset por el header
  const mapEl = document.getElementById('map');
  if (mapEl && mapEl.classList.contains('pt-16')) {
    setTimeout(() => map.invalidateSize(), 120);
  }

  // Control de rutas para "agregar ruta"
  if (window.L && L.Routing && typeof L.Routing.control === 'function') {
    controlRutas = L.Routing.control({
      waypoints: [],
      routeWhileDragging: true,
      createMarker: () => null,
      addWaypoints: false,
      show: false,
      fitSelectedRoutes: false,
      lineOptions: { styles: [{ color: '#2563eb', weight: 5, opacity: 0.85 }] }
    }).addTo(map);
  } else {
    controlRutas = null;
  }

  if (ruta_add) {
    map.on('click', function (ev) {
      const latEl = document.getElementById('lat');
      const lngEl = document.getElementById('lng');
      if (latEl) latEl.value = ev.latlng.lat;
      if (lngEl) lngEl.value = ev.latlng.lng;

      const idx = Object.keys(diccionario_paradas).length + 1;
      diccionario_paradas[idx] = [ev.latlng.lat, ev.latlng.lng];

      const lista = document.getElementById('lista_paradas');
      if (lista) {
        const li = document.createElement('li');
        li.id = 'lista_elemento_' + idx;
        li.className = 'flex items-center justify-between gap-2 p-2 rounded-md surface-soft';
        li.innerHTML = `
          <span class="truncate">
            <b>#${idx}</b>
            <span class="text-muted">${ev.latlng.lat.toFixed(4)}, ${ev.latlng.lng.toFixed(4)}</span>
          </span>
          <button class="btn btn-ghost p-1" title="Eliminar"
                  onclick="eliminarParada(${idx})">
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 6 6 18M6 6l12 12"/>
            </svg>
          </button>`;
        lista.appendChild(li);
      }
      actualizarRuta();
    });
  }

  window.map = map;
}

//  Ruta en edición 
function eliminarParada(index) {
  delete diccionario_paradas[index];
  document.getElementById('lista_elemento_' + index)?.remove();
  actualizarRuta();
}

function actualizarRuta() {
  const waypoints = Object.keys(diccionario_paradas)
    .sort((a, b) => a - b)
    .map(k => {
      const c = diccionario_paradas[k];
      return L.latLng(c[0], c[1]);
    });
  if (controlRutas) controlRutas.setWaypoints(waypoints);
}

//  Descargar / leer ruta 
function Descargar_Ruta() {
  const ruta = {
    paradas: diccionario_paradas,
    municipio_id: document.getElementById('municipios')?.value,
    estado_id: document.getElementById('estados')?.value,
    nombre: document.getElementById('nombre_parada')?.value
  };
  const blob = new Blob([JSON.stringify(ruta)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = 'ruta.json'; a.click();
  URL.revokeObjectURL(url);
}

function leerRuta() {
  const file = document.getElementById('ruta')?.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = function (e) {
    const ruta = JSON.parse(e.target.result);
    console.log('Ruta leída:', ruta);
    diccionario_paradas = ruta.paradas || {};
    const estadoSelect = document.getElementById('estados');
    if (ruta.estado_id && estadoSelect) estadoSelect.value = ruta.estado_id;
    
    if (ruta.municipio_id && estadoSelect) {
      cargarMunicipiosEnSelect(ruta.estado_id, ruta.municipio_id);
    }
    if (ruta.nombre) document.getElementById('nombre_parada').value = ruta.nombre;

    const lista = document.getElementById('lista_paradas');
    if (lista) lista.innerHTML = '';
    Object.keys(diccionario_paradas).forEach(k => {
      const c = diccionario_paradas[k];
      L.marker(c).addTo(map).bindPopup('Parada ' + k);
      const li = document.createElement('li');
      li.id = 'lista_elemento_' + k;
      li.className = 'flex items-center justify-between gap-2 p-2 rounded-md surface-soft';
      li.innerHTML = `<span class="truncate"><b>#${k}</b></span>
        <button class="btn btn-ghost p-1" onclick="eliminarParada(${k})">✕</button>`;
      lista?.appendChild(li);
    });
    actualizarRuta();
  };
  reader.readAsText(file);
}

//  BÚSQUEDA DE RUTAS + HOVER 
const colores = ['#ef4444', '#3b82f6', '#22c55e', '#eab308', '#a855f7', '#06b6d4'];

function limpiarRutas() {
  rutasActivas.forEach(r => {
    if (r.control) map.removeControl(r.control);
    if (r.polyline) map.removeLayer(r.polyline);
    if (r.markers) r.markers.forEach(m => map.removeLayer(m));
    r.listItem?.remove();
  });
  rutasActivas = [];
}

function highlightRoute(entry, fromMap = false) {
  if (!entry) return;
  if (entry.polyline) {
    entry.polyline.setStyle({ weight: 9, opacity: 1 });
    entry.polyline.bringToFront();
    if (fromMap) entry.polyline.openTooltip();
  }
  entry.listItem?.classList.add('is-active');
}

function unhighlightRoute(entry, fromMap = false) {
  if (!entry) return;
  if (entry.polyline) {
    entry.polyline.setStyle({ weight: 5, opacity: 0.8 });
    if (fromMap) entry.polyline.closeTooltip();
  }
  entry.listItem?.classList.remove('is-active');
}

async function buscarRutas() {
  const municipioId = document.getElementById('municipios')?.value;
  const estadoId    = document.getElementById('estados')?.value;
  const inRutasDiv  = document.getElementById('rutas_encontradas');
  const countSpan   = document.getElementById('rutas-count');

  if (!estadoId)    return alert('Selecciona un estado');
  if (!municipioId) return alert('Selecciona un municipio');

  // Limpiar anteriores
  limpiarRutas();
  if (inRutasDiv) inRutasDiv.innerHTML = '';

  try {
    const response = await fetch(`/api/rutas?estado_id=${estadoId}&municipio_id=${municipioId}`);
    if (!response.ok) throw new Error('Error en la petición');
    const rutasRaw = await response.json();
    const rutas_solo = (Array.isArray(rutasRaw?.[0]) ? rutasRaw[0] : (Array.isArray(rutasRaw) ? rutasRaw : [])).filter(Boolean);  
    console.log('Rutas encontradas:', rutas_solo);

    if (countSpan) countSpan.textContent = rutas_solo.length;

    if (!rutas_solo.length) {
      if (inRutasDiv) inRutasDiv.innerHTML =
        '<p class="text-muted text-xs text-center py-3">No hay rutas en esta zona.</p>';
      return;
    }

    const bounds = [];

    rutas_solo.forEach((ruta, index) => {
      if (!ruta.puntos || !Array.isArray(ruta.puntos) || !ruta.puntos.length) return;

      const color = colores[index % colores.length];
      const waypoints = ruta.puntos.map(p => L.latLng(p.lat, p.lng));
      waypoints.forEach(w => bounds.push(w));

      //  Tarjeta de la lista 
      const item = document.createElement('div');
      item.className = 'route-item';
      item.style.borderLeftColor = color;
      item.innerHTML = `
        <div class="font-semibold truncate">${ruta.nombre || 'Ruta sin nombre'}</div>
        <div class="text-xs text-muted truncate">
          ${ruta.municipio_nombre || ''}${ruta.estado_nombre ? ', ' + ruta.estado_nombre : ''}
          · ${ruta.puntos.length} paradas
        </div>
        ${ruta.descripcion ? `<div class="text-xs mt-1 opacity-80 line-clamp-2">${ruta.descripcion}</div>` : ''}`;
      inRutasDiv?.appendChild(item);

      //  Control de ruta 
      const control = L.Routing.control({
        waypoints,
        createMarker: () => null,
        addWaypoints: false,
        routeWhileDragging: false,
        show: false,
        fitSelectedRoutes: false,
        lineOptions: { styles: [{ color, weight: 5, opacity: 0.8 }] }
      }).addTo(map);

      const entry = {
        id: ruta.id,
        nombre: ruta.nombre || 'Ruta',
        color,
        control,
        polyline: null,
        listItem: item,
        markers: []
      };
      rutasActivas.push(entry);

      //  Sincronizar hover (mapa <-> lista) 
      control.on('routesfound', function (e) {
        // Polyline interna del control
        const line = control._line || (e.routes[0] && e.routes[0].coordinates && null);
        if (line && line.setStyle) {
          entry.polyline = line;
          line.bindTooltip(entry.nombre, { sticky: true });
          line.on('mouseover', () => highlightRoute(entry, true));
          line.on('mouseout',  () => unhighlightRoute(entry, true));
        } else {
          // Fallback: dibujamos nuestra propia polilínea a partir de las coordenadas
          const coords = e.routes[0].coordinates;
          const custom = L.polyline(coords, { color, weight: 5, opacity: 0.8 }).addTo(map);
          custom.bindTooltip(entry.nombre, { sticky: true });
          custom.on('mouseover', () => highlightRoute(entry, true));
          custom.on('mouseout',  () => unhighlightRoute(entry, true));
          entry.polyline = custom;
        }
        entry.polyline.bringToFront?.();
      });

      // Hover desde la tarjeta
      item.addEventListener('mouseenter', () => highlightRoute(entry, false));
      item.addEventListener('mouseleave', () => unhighlightRoute(entry, false));
      item.addEventListener('click', () => {
        map.fitBounds(L.latLngBounds(waypoints), { padding: [60, 60] });
        highlightRoute(entry, false);
      });

      //  Marcadores de paradas 
      ruta.puntos.forEach((coords, idx) => {
        const marker = L.marker([coords.lat, coords.lng], {
          icon: L.divIcon({
            className: 'custom-icon',
            html: `<div style="background:${color};width:12px;height:12px;border-radius:50%;border:2px solid #fff;box-shadow:0 0 0 1px rgba(0,0,0,.2);"></div>`,
            iconSize: [12, 12],
            iconAnchor: [6, 6]
          })
        })
          .addTo(map)
          .bindPopup(`<b>${entry.nombre}</b><br>Parada ${idx + 1}`);
        entry.markers.push(marker);
      });
    });

    if (bounds.length) map.fitBounds(L.latLngBounds(bounds), { padding: [60, 60] });
  } catch (error) {
    console.error('Error al buscar rutas:', error);
    if (inRutasDiv) inRutasDiv.innerHTML =
      '<p class="text-xs text-center py-3" style="color:rgb(var(--c-danger))">Error al buscar rutas</p>';
  }
}

//  Guardar ruta 
async function Guardar_ruta() {
  if (!currentUser) return alert('Debes iniciar sesión para guardar una ruta');

  const estadoId    = document.getElementById('estados').value;
  const municipioId = document.getElementById('municipios').value;
  const nombre      = document.getElementById('nombre_parada').value.trim();
  const descripcion = document.getElementById('descripcion_parada').value.trim();

  if (!estadoId || !municipioId || !nombre) return alert('Completa todos los campos');
  if (Object.keys(diccionario_paradas).length === 0) return alert('Agrega al menos una parada');

  const puntos = Object.values(diccionario_paradas).map(c => ({ lat: c[0], lng: c[1] }));

  const data = {
    usuario_id: currentUser.id,
    nombre, descripcion,
    publica: true,
    estado_id: parseInt(estadoId),
    municipio_id: parseInt(municipioId),
    puntos
  };

  try {
    const response = await fetch('/api/rutas', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify(data)
    });
    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error(err.error || 'Error al guardar');
    }
    const result = await response.json();
    alert('Ruta guardada con ID: ' + result.ruta_id);

    // Reset
    diccionario_paradas = {};
    document.getElementById('lista_paradas').innerHTML = '';
    if (controlRutas) controlRutas.setWaypoints([]);
  } catch (error) {
    console.error('Error al guardar ruta:', error);
    alert('Error al guardar: ' + error.message);
  }
}

// Exponer al HTML
window.leerRuta      = leerRuta;
window.buscarRutas   = buscarRutas;
window.eliminarParada = eliminarParada;
window.Descargar_Ruta = Descargar_Ruta;
window.Guardar_ruta  = Guardar_ruta;