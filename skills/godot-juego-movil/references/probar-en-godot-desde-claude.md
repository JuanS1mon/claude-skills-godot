# Probar el juego desde Claude Code (sí se puede, sin tocar tu partida ni tu editor)

Se creyó que no se podía ejecutar Godot desde aquí. **Sí se puede**: hay un ejecutable (en Zarita:
`C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`; verlo con
`Get-Process godot*` mientras el editor está abierto). Receta que funcionó (se verificó una casa de 4 habitaciones):

## 1. Probar sobre una COPIA del proyecto
Así no se pisan el `.godot/` del editor abierto ni el guardado real del jugador.
```bash
SC=<carpeta scratchpad>; cp -r "<proyecto>" "$SC/copia"; cd "$SC/copia"
sed -i 's|^config/name=.*|config/name="ZaritaTestHeadless"|' project.godot   # otro user:// (otra partida)
rm -f .godot/editor/*.cfg
"$GODOT" --headless --path . --editor --quit        # registra los class_name nuevos e importa las imágenes (1-2 min)
```
- Los `class_name` nuevos NO existen para el juego hasta que un editor escanea el proyecto. Este paso los registra en la copia.
- Para volver a probar tras editar: copiar los archivos cambiados a la copia (`cp`), no hace falta reimportar si no hay arte nuevo.

## 2. ¿Compila y carga sin errores? (sin ventana)
```bash
"$GODOT" --headless --path . --quit-after 240 res://scenes/casa.tscn 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
```
Una salida sin `SCRIPT ERROR` ni `ERROR:` (salvo los `BUG: Unreferenced static string` de Godot al cerrar, que son ruido) = carga bien.

## 3. Probar el flujo: un AUTOLOAD de prueba (solo en la copia)
Un script `-s` (extends SceneTree) NO sirve: se compila antes que los autoloads y falla con `Identifier not found: Economia`.
En cambio, un autoload más en la copia (`Prueba="*res://prueba.gd"` en `[autoload]`) arranca antes de la escena principal y
sobrevive a los cambios de escena:
```gdscript
extends Node
func _ready() -> void:
    await get_tree().create_timer(1.5).timeout
    var casa = get_tree().current_scene        # volver a pedirla tras cada recarga
    casa._abrir_mapa()                         # llamar funciones del juego directamente
    print("[1] actual=", Habitaciones.actual)  # imprimir lo que se quiere comprobar
    get_tree().quit()
```
Ejecutar CON ventana (`--resolution 540x960 --position 40,20 res://scenes/casa.tscn`) para poder capturar:
`get_tree().root.get_texture().get_image().save_png("<scratchpad>/foto.png")` y mirar la imagen con `Read`.
Sobre un `await create_timer(...)` hay que esperar el tiempo real (los tweens, la física y el fundido corren).
`var x := autoload.propiedad` falla por tipo en el autoload de prueba: usar `var x = ...`.

## 4. Qué conviene probar cada vez
- Un recorrido completo del flujo nuevo (en la casa: mapa → desbloquear → viajar → volver) imprimiendo los estados.
- El guardado: imprimir `FileAccess.get_file_as_string("user://partida.json")` al final.
- Un guardado en el formato ANTERIOR (migración).
- Una captura de cada pantalla nueva: cazó puertas tapadas por los botones del HUD que el código no mostraba.
- Lo que NO se puede comprobar así: cómo se siente el toque en el celular, el rendimiento y el audio.

Dilo siempre claro en la entrega: qué se probó (y cómo) y qué falta probar a mano.

## 5. Probar con LA PARTIDA REAL del usuario (cazó casi todos los errores visuales)
Los muebles flotando, los huecos y las sombras solo aparecieron al renderizar la habitación con la partida guardada de Juan: un test con datos inventados no los ve.
1. Copiar `%APPDATA%/Godot/app_userdata/<proyecto>/partida.json` al directorio de usuario de la COPIA (`app_userdata/<nombre de la copia>/`), cambiando `habitacion_actual` (y `desbloqueadas`) a la habitación a mirar.
2. Autoload de prueba: `change_scene_to_file("res://scenes/casa.tscn")`, esperar ~30 frames, `await RenderingServer.frame_post_draw` y guardar `get_viewport().get_texture().get_image().save_png(...)`. Para simular un soltado: `m.position = m._ajustar_al_suelo(punto)`.
3. Con `--resolution 720x1280` para ver la pantalla entera; recortar y ampliar (Pillow, `NEAREST`) la zona dudosa antes de mirarla.
4. Si el script de prueba falla en `_ready` el juego queda abierto para siempre: correr con `timeout 80 godot ... > log.txt` y leer `SCRIPT ERROR` del log. Si el log dice "index 1 on Array", la partida copiada es vieja: volver a copiarla.
5. NUNCA matar Godot por nombre de proceso (`taskkill /IM`): puede cerrar el editor abierto del usuario. Para frenar algo propio usar el `TaskStop` de la tarea en segundo plano o un `timeout`.


## 6. Clics reales, regresión de todas las escenas y simulador (juego idle, 2026-11)
- **Clic real en un autoload de prueba** (detecta botones tapados por contenedores, lo que `emit_signal("pressed")` no ve):
  ```gdscript
  const ESCALA := 0.75                       # ventana de prueba 540x960 sobre un juego 720x1280
  func _clic(c: Control) -> void:
      await get_tree().create_timer(0.3).timeout           # esperar a que el layout termine
      var pos: Vector2 = (c.get_global_transform() * (c.size / 2.0)) * ESCALA
      var mov := InputEventMouseMotion.new(); mov.position = pos; mov.global_position = pos
      Input.parse_input_event(mov)                          # primero el hover
      await get_tree().create_timer(0.05).timeout
      print("hover: ", get_viewport().gui_get_hovered_control())   # debe ser el botón
      for presionado in [true, false]:
          var ev := InputEventMouseButton.new()
          ev.button_index = MOUSE_BUTTON_LEFT; ev.position = pos; ev.global_position = pos
          ev.pressed = presionado; ev.button_mask = MOUSE_BUTTON_MASK_LEFT if presionado else 0
          Input.parse_input_event(ev)
          await get_tree().create_timer(0.08).timeout
  ```
  Correr con `--resolution 540x960` (escala 0,75). Si el `hover` no es el botón, hay un control encima.
- **Preparar la copia cada vez** (robocopy, PowerShell): `robocopy <real> <copia> /MIR /XD .godot .git /XF export_presets.cfg prueba.gd prueba.gd.uid`; **regenerar `project.godot` a partir del real** (si no, faltan los autoloads nuevos), cambiando `config/name` y agregando `Prueba="*res://prueba.gd"` justo debajo de `[autoload]`. Después `--headless --editor --quit` **dos veces** (la primera registra los `class_name`, la segunda ya no da "X not declared").
- **Regresión de TODAS las escenas sueltas** (regla de oro): un `prueba.gd` que recorre `res://scenes/**/*.tscn`, hace `load` + `instantiate` + `add_child`, espera 0,4 s y la libera; imprime `REGRESION: N escenas, fallas: 0`. Se corrió al terminar cada tanda de cambios (53 escenas).
- **No confiar en `& godot ... | Select-String` de PowerShell para leer la salida** (a veces vuelve vacía aunque corrió): usar `Start-Process -FilePath $godot -ArgumentList "--headless","--path",$copia -RedirectStandardOutput out.txt -RedirectStandardError err.txt -Wait -PassThru -NoNewWindow` y leer los archivos.
- **Simulador de balance** (`assets/idle/simulador.gd`): corre la batalla real con `--fixed-fps 60` + `Engine.time_scale`, sin pantalla; ver `idle-gacha-economia-y-balance.md`.
- **Probar el caso límite del premio**: con el tope de anuncios agotado, sin premio, con la bodega llena, con un segundo toque. Cada uno fue un caso real de la pantalla de "duplicar al terminar la misión".
- Cuando el usuario diga **"por ahora solo Godot, nada de APK"**, probar únicamente dentro de Godot sobre la copia y no exportar ni preparar pruebas en el celular hasta que él lo pida.
