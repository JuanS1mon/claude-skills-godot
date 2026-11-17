# Probar el juego 2.5D desde Claude

Lo general (copia del proyecto, autoload de prueba, partida real) está en `godot-juego-movil/references/probar-en-godot-desde-claude.md`. Esto es lo que se agregó en el prototipo.

## Ejecutable y salida
- Godot de Juan para este proyecto: `C:\GODOT\Godot_v4.7-stable_win64.exe` (solo el ejecutable con ventana, sin la versión `console`).
- Ese ejecutable **no escribe en la consola de PowerShell**: usar `--log-file` y leer el archivo.
```powershell
Start-Process -Wait "C:\GODOT\Godot_v4.7-stable_win64.exe" -ArgumentList "--headless","--path",$proyecto,"--import","--log-file",$log
Start-Process -Wait $godot -ArgumentList "--path",$proyecto,"--log-file",$log,"--fixed-fps","60","--script",$prueba
Get-Content $log | Select-String "ERROR|WARN|SCRIPT"
```

## Prueba con input simulado (`assets/pruebas/prueba_input.gd`)
Sin autoloads en el proyecto, un script `--script` (`extends SceneTree`) sí sirve (con autoloads no: ver la otra skill).
- `_initialize()` → `change_scene_to_file("res://escenas/mundo.tscn")`.
- `_process()` cuenta frames y en cada frame elegido: `Input.action_press("mover_der")` / `action_release`, imprime estados (`jug.objeto`, `enem.vida`, posición) y saca capturas con `root.get_texture().get_image().save_png(ruta)`.
- `--fixed-fps 60` hace que cada frame sea 1/60 s aunque la PC vaya más lenta: la prueba es repetible.
- Para un caso límite (KO), llamar directo `enem.recibir_dano(150, punto)` en vez de disparar 10 veces.
- Los primeros frames muestran FPS bajos (compilación de shaders): ignorarlos.
- **Mirar las capturas** con `Read`: los problemas de esta sesión (pared invisible, cámara del .glb, bloque que tapaba las balas, enemigo chico) solo se vieron así.

## MCP `godot-mcp-runtime` (capturas, input y GDScript en vivo)
- Configurado en `D:\Prototipo\.mcp.json` (`npx -y godot-mcp-runtime@4.0.1`, `GODOT_PATH` en `env`), junto con `mojulo@3.1.1`.
- Un `.mcp.json` de proyecto queda **"Pending approval"** y la app de escritorio no muestra el aviso para aprobarlo (`claude mcp list` lo muestra). Lo que funcionó: registrarlo con alcance local desde la CLI, que no pide aprobación:
  `claude mcp add godot --scope local -e GODOT_PATH=C:\GODOT\Godot_v4.7-stable_win64.exe '--' npx -y godot-mcp-runtime@4.0.1`
  (en PowerShell el `--` va entre comillas, si no se lo come). Queda `√ Connected`, pero las herramientas aparecen recién en una **sesión nueva**. Mientras tanto, usar la prueba con `--script`.

## Trampas de esta sesión
- **PowerShell 5.1 `Get-Content -Raw` + `Set-Content -Encoding utf8`** rompe las tildes (`Cámara` → `CÃ¡mara`) y agrega BOM. Para reemplazos en archivos usar la herramienta Edit, o `[IO.File]::WriteAllText(ruta, texto, (New-Object Text.UTF8Encoding $false))`.
- Un comentario `## ...` arriba de `extends` se toma como descripción de la clase: está bien.
- Al pasar un `Sprite3D` a `AnimatedSprite3D`, actualizar el tipo en el script (`@onready var sprite: AnimatedSprite3D`).
