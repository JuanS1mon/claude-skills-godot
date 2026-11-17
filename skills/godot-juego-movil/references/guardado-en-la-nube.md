# Guardado en la nube sin perder avance (Play Games "Saved Games")

Lo que sirvió para dejar un juego con partida local en JSON **listo** para sincronizar con la nube, y probarlo entero en la PC antes de tener el plugin ni el APK. Código de ejemplo en `assets/nube/` (`nube.gd`, `proveedor_nube.gd`, `proveedor_nube_simulado.gd`, `conflicto_nube.gd/.tscn`); se copia y se adapta (usa un autoload `Guardado` con `armar_partida`, `estado_local`, `resumen_de`, `guardar(subir)`).

## Decidir primero si hace falta
- **Saved Games** (Play Games Services): gratis, hasta 3 MB por archivo, sin servidor propio, sincroniza offline. Necesita Play Console (activar Saved Games, credenciales OAuth con el SHA-1 de depuración, de release **y de la firma de Play**) y un plugin de Godot (comunitario: `godot-sdk-integrations/godot-play-game-services`, bajarlo de GitHub Releases; pide Gradle Build).
- **Level Up** (programa de Google Play que pide cloud save entre otras cosas) **no** conviene a un estudio chico: para inscribirse hay que haber ganado ≥ 1 M USD en 12 meses y la rebaja de comisión solo toca lo que pase de 1 M. El cloud save se hace igual, por la experiencia del jugador (celular nuevo, reinstalación), no por el programa.

## Diseño que funcionó
1. **La partida es UN bloque**: `armar_partida(para_nube)` (versión + fecha + una sección por sistema) y `aplicar_partida(datos)`. Lo que es propio del dispositivo (el bloque `nube`) no se sube.
2. **Un proveedor intercambiable**: clase base "sin nube" (`disponible() = false`, el juego se comporta como siempre) con tres funciones (`disponible`, `descargar`, `subir`, las de red son corrutinas). Se agrega un proveedor simulado (archivo en `user://`) para probar todo en la PC y, más tarde, el de Play Games. El resto del juego no se entera.
3. **Política con una "huella" y no con fechas**: la huella es el SHA-256 del estado SIN fecha ni ruido. El dispositivo anota la huella de la última partida que sabe igual en los dos lados (`base_huella`). Al abrir: nube vacía → sube; sin avance local → baja sola; iguales → nada; cambió solo este → sube; cambió solo la nube → baja; **cambiaron los dos → pregunta al jugador** (nunca elige solo; Google lo recomienda). Es una función pura: se prueba con una tabla de casos.
4. **Antes de ver la nube no se sube nada** (si no hubo red al abrir), y si la nube tarda (≈6 s) se sigue con la local.
5. **Subir con espera** (~2 min) y al pausar/cerrar, y solo si la huella cambió. Un guardado local que viene de una subida no vuelve a pedir subir (si no, bucle).
6. **"Nueva partida" también reemplaza la nube**; si no hay red queda un `forzar` anotado en el archivo, para que no vuelva la partida vieja al reabrir.
7. El juego, al abrir, **espera a la nube con los botones del título bloqueados** ("Sincronizando…"), y recién después entra a la pantalla de juego. Cambiar la partida en pleno juego (reintento al volver de segundo plano) pregunta siempre y reinicia la escena.

## Trampas que costaron
- **Ruido en el estado**: cualquier `a_dict` que guarde "la última hora vista" o un contador que se mueve solo cambia la huella en cada guardado (parecería que el jugador cambió algo). Se excluye por nombre de clave, a cualquier profundidad. Al agregar un `a_dict` nuevo, pensar si guarda algo así.
- **Medir "¿cambió este dispositivo?" sobre el archivo tal como estaba al abrir**, no sobre el estado ya cargado: al cargar se renuevan topes diarios y se suma lo ganado sin conexión, y eso daría preguntas falsas entre dos celulares. Tomar esa huella ANTES de esperar la red (el autoguardado de 3 s no debe alterarla) y descartarla al primer guardado.
- **`JSON.parse_string` devuelve `float` para todo**: hay que pasar por `parse` los dos lados antes de calcular la huella (si no, `5` y `5.0` difieren). `JSON.stringify(x, "", true)` ordena las claves.
- **`FileAccess` dentro de una corrutina no se cierra al hacer `return`** hasta que termina todo lo que la espera: cerrar con `f.close()` antes de responder.
- Agregar una escena a `get_tree().root` al arrancar da "Parent node is busy": `add_child.call_deferred(n)` + `await n.ready`.
- Esperar con límite de tiempo: emitir una señal propia desde un temporizador y desde la respuesta, con un **número de pedido** para ignorar respuestas tardías de un pedido viejo.
- No hace falta registrar un autoload nuevo en `project.godot` (peligroso con el editor abierto): el módulo puede ser un `Node` hijo del autoload de guardado, cargado con `preload("res://.../nube.gd")`.

## Cómo probarlo sin plugin ni APK
Copia del proyecto + autoload de prueba con el proveedor simulado (receta en `probar-en-godot-desde-claude.md`). Casos que cazaron errores reales: celular nuevo con nube con avance, partida local dañada, jugó en otro celular, **abrir en un día nuevo sin jugar**, conflicto (las dos respuestas), "Nueva partida" con y sin red, sin red, red lenta, partida de la versión anterior del archivo, y la **partida real del usuario** reabierta varias veces (no debe volver a subir). Poner un temporizador de seguridad en la prueba: si queda el cartel de conflicto abierto sin pantalla, nadie lo toca y se cuelga. Lo que NO se puede probar en la PC: el plugin real, el inicio de sesión de Play Games y dos celulares.
