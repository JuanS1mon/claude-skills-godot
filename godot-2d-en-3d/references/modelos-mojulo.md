# Modelos 3D con Mojulo (probado en la v3.1.1, 2026-11)

Mojulo es un servidor MCP local (Apache-2.0, `npx -y mojulo`) que genera modelos 3D como "recetas" y los exporta a .glb/STL. **Veredicto**: sirve para piezas grandes o con forma propia; para props simples (cajas, bloques) rinden más las primitivas de Godot con el toon shader. Sus "personajes" son modelos 3D con esqueleto, no sprites 2D.

## Usarlo sin MCP (CLI)
Cada llamada es un proceso nuevo; poner `MOJULO_HOST=claude-code`.
```powershell
npx -y mojulo@3.1.1 orient                        # qué es y cómo leer sus respuestas
npx -y mojulo@3.1.1 tools                         # packs: pack_object, pack_character, pack_world, pack_game...
npx -y mojulo@3.1.1 pack_object --manual mint_solid
npx -y mojulo@3.1.1 pack_object get_solid_vocab --json '{\"id\":\"furniture\"}'
npx -y mojulo@3.1.1 pack_object mint_solid --json "@C:\ruta\absoluta\pedido.json"
npx -y mojulo@3.1.1 pack_world export_model --json '{\"ref\":\"sk_...\",\"format\":\"glb\",\"lit\":true}'
```
- **`--json @archivo` necesita ruta ABSOLUTA**: una relativa la busca dentro de la carpeta del paquete en la caché de npx.
- JSON en línea desde PowerShell 5.1 se rompe con las comillas: escapar `\"` o usar un archivo.
- Cada `mint_solid` crea un modelo nuevo (aunque sea el mismo pedido); la respuesta trae el `ref` (`sk_...`).
- `furniture` con `like: 'chest'` dio una cómoda con cajones, no un baúl. Ojo con el vocabulario.
- **Exportar con `lit: true`**: por defecto el .glb sale **sin iluminación** (luz "horneada", `KHR_materials_unlit`) y no recibe las luces de Godot. El archivo queda en `~/.mojulo/data/outcomes/<ref>/model.glb`.

## Problemas al importar en Godot
1. **El .glb trae 5 `Camera3D`**: una se vuelve la cámara activa y tapa la del juego (la pantalla mostraba el cofre de cerca).
2. **92 mallas** separadas y **81 PNG** extraídos en la carpeta del modelo: pesado y desordenado para un prop.
3. Los materiales importados **no usan el color por vértice** (`vertex_color_use_as_albedo = false`), y el color de Mojulo está ahí: se ve blanco/celeste.

Solución (`assets/scripts/modelo_importado.gd`): script en la raíz de la instancia del .glb que borra cámaras, luces y `WorldEnvironment`, y pone `material_override` = `toon_vertice.tres` (lee `COLOR`). Aun así el cofre pedido en `#b8743a` quedó casi blanco: el color pintado no está en los vértices. **Sin resolver**.

Para medir un modelo importado: instanciarlo, `add_child.call_deferred`, esperar 2 `process_frame` y unir los `global_transform * get_aabb()` de sus `MeshInstance3D` (fuera del árbol, `global_transform` da error).
