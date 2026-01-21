async function cargarEstados() {
    try {
        // Llamamos a la ruta que definimos en Express
        const response = await fetch('http://localhost:3000/api/estados');
        const estados = await response.json();
        return estados;
        //console.log(estados);
        // Aquí puedes manipular el DOM para mostrar los estados
    } catch (error) {
        console.error("Error cargando estados:", error);
    }
}

(async () => {
    const allestados = await cargarEstados();
    var estados = document.getElementById("estados");
    allestados.forEach(estado => {
        var option = document.createElement("option");
        option.value = estado.id;
        option.text = estado.Estado;
        estados.add(option);
    });
})();

async function cargarMunicipios(estadoId) {
    try {
        // Llamamos a la ruta que definimos en Express
        const response = await fetch(`http://localhost:3000/api/estados/${estadoId}`);
        const municipios = await response.json();
        return municipios;
        // Aquí puedes manipular el DOM para mostrar los municipios
        //console.log(municipios);
    } catch (error) {
        console.error("Error cargando municipios:", error);
    }
}

document.getElementById("estados").addEventListener("change", async function() {
    const estadoId = this.value;
    const Estados_m = await cargarMunicipios(estadoId);
    console.log(await cargarMunicipios(estadoId));
    var municipiosSelect = document.getElementById("municipios");
    municipiosSelect.innerHTML = "";
    Estados_m.Municipios.forEach(municipio => {
        var option = document.createElement("option");
        option.value = municipio;
        option.text = municipio;
        municipiosSelect.add(option);
    });
});

document.getElementById("municipios").addEventListener("change", async function() {
    const estadoSelect = document.getElementById("estados");
    const estadoTexto = estadoSelect.options[estadoSelect.selectedIndex].text;
    const municipioTexto = this.value;
    
    if (!municipioTexto) return;
    
    // Opcional: mostrar un indicador de carga
    console.log(`Buscando: ${municipioTexto}, ${estadoTexto}`);
    
    const resultado = await geocodificarUbicacion(estadoTexto, municipioTexto);
    
    if (resultado) {
        console.log(`Geocodificado: ${resultado.nombre} en [${resultado.lat}, ${resultado.lng}]`);
        
        // 1. Mover el centro del mapa
        map.setView([resultado.lat, resultado.lng], 12); // Zoom 12 es bueno para municipios
        
        // 2. Actualizar los campos ocultos del formulario
        document.getElementById('lat').value = resultado.lat;
        document.getElementById('lng').value = resultado.lng;
        
        // 3. Mover o colocar el área circular (en lugar del marcador)
        if (window.areaCirculo) {
            // Si ya existe, mover el círculo a las nuevas coordenadas
            window.areaCirculo.setLatLng([resultado.lat, resultado.lng]);
        } else {
            // Crear un círculo azul transparente
            window.areaCirculo = L.circle([resultado.lat, resultado.lng], {
                color: '#3388ff',     
                fillColor: '#3388ff',  
                fillOpacity: 0.2,      
                radius: 3000,         
                weight: 2,             
                draggable: false
            }).addTo(map);
            
            // Evento cuando se termina de arrastrar el círculo
            window.areaCirculo.on('dragend', function(e) {
                var position = e.target.getLatLng();
                document.getElementById('lat').value = position.lat;
                document.getElementById('lng').value = position.lng;
            });
            
            // Opcional: mostrar información al hacer clic
            window.areaCirculo.bindPopup(`<b>${municipioTexto}</b><br>Área seleccionada`);
        }
    } else {
        alert("No se pudo encontrar la ubicación exacta. Intenta con una búsqueda más general.");
        // Podrías centrar el mapa en una vista por defecto de México
        map.setView([23.6345, -102.5528], 5);
    }
});


async function geocodificarUbicacion(estado, municipio) {
    try {
        // Construir la consulta: municipio, estado, México
        const query = `${municipio}, ${estado}, México`;
        const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1&addressdetails=1`;

        const response = await fetch(url);

        if (!response.ok) throw new Error('Error en la respuesta de la red');

        const data = await response.json();

        if (data && data.length > 0) {
            console.log('Resultado encontrado:', data[0]);
            return {
                lat: parseFloat(data[0].lat),
                lng: parseFloat(data[0].lon),
                nombre: data[0].display_name // Nombre completo para verificación
            };
        } else {
            console.warn('Nominatim no devolvió resultados para:', query);
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
        console.error("Error en geocodificación con Nominatim:", error);
        return null;
    }
}


/*
document.getElementById("formulario").addEventListener("submit", function(event) {
    event.preventDefault();
    var formData = new FormData(this);
    var data = {};
    formData.forEach((value, key) => {
        data[key] = value;
    });
    console.log("Datos del formulario:", data);
    
});*/

