export async function cargarEstados() {
    try {
        const response = await fetch('/api/estados');
        const estados = await response.json();
        return estados;
    } catch (error) {
        console.error("Error cargando estados:", error);
    }
}

// Llenar select de estados al cargar la página
(async () => {
    const allEstados = await cargarEstados();
    const estadosSelect = document.getElementById("estados");
    if (!estadosSelect) return;
    allEstados.forEach(estado => {
        const option = document.createElement("option");
        option.value = estado.id;
        option.text = estado.nombre;
        estadosSelect.add(option);
    });
})();

export async function cargarMunicipios(estadoId) {
    try {
        const response = await fetch(`/api/estados/${estadoId}/municipios`);
        const municipios = await response.json();
        return municipios;
    } catch (error) {
        console.error("Error cargando municipios:", error);
    }
}

// Evento change del select de estados
document.getElementById("estados")?.addEventListener("change", async function() {
    const estadoId = this.value;
    if (!estadoId) return;
    const municipios = await cargarMunicipios(estadoId);
    const municipiosSelect = document.getElementById("municipios");
    municipiosSelect.innerHTML = '<option value="">Seleccione un municipio</option>';
    municipios.forEach(m => {
        const option = document.createElement("option");
        option.value = m.id;
        option.text = m.nombre;
        municipiosSelect.add(option);
    });
});

// Evento change del select de municipios (geocodificar)
document.getElementById("municipios")?.addEventListener("change", async function() {
    const municipioId = this.value;
    if (!municipioId) return;
    const estadoSelect = document.getElementById("estados");
    const estadoNombre = estadoSelect.options[estadoSelect.selectedIndex].text;
    const municipioNombre = this.options[this.selectedIndex].text;
    const resultado = await geocodificarUbicacion(estadoNombre, municipioNombre);
    if (resultado) {
        if (window.map) {
            window.map.setView([resultado.lat, resultado.lng], 12);
        }
        document.getElementById('lat').value = resultado.lat;
        document.getElementById('lng').value = resultado.lng;
    } else {
        alert("No se pudo encontrar la ubicación");
    }
});

export async function geocodificarUbicacion(estado, municipio) {
    try {
        const query = `Centro,${municipio}, ${estado}, México`;
        const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1&addressdetails=1`;
        const response = await fetch(url, {
            headers: {
                'Accept': 'application/json',
                'User-Agent': 'MiAplicacionLogistica/1.0'
            }
        });
        if (!response.ok) throw new Error('Error en la respuesta de la red');
        const data = await response.json();
        if (data && data.length > 0) {
            return {
                lat: parseFloat(data[0].lat),
                lng: parseFloat(data[0].lon),
                nombre: data[0].display_name
            };
        } else {
            // Fallback: buscar solo el estado
            const queryEstado = `${estado}, México`;
            const urlEstado = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(queryEstado)}&limit=1`;
            const responseEstado = await fetch(urlEstado, { headers: { 'User-Agent': 'TuAplicacion/1.0' } });
            const dataEstado = await responseEstado.json();
            if (dataEstado && dataEstado.length > 0) {
                return {
                    lat: parseFloat(dataEstado[0].lat),
                    lng: parseFloat(dataEstado[0].lon),
                    nombre: dataEstado[0].display_name
                };
            }
            return null;
        }
    } catch (error) {
        console.error("Error en geocodificación:", error);
        return null;
    }
}