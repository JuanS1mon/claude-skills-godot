# Pasar el juego a Android (APK)

Lo que se dejó configurado para Zarita en la PC de Juan (Windows) y cómo repetirlo.

## Requisitos (una sola vez por PC)
- **Plantillas de exportación** de la misma versión de Godot (Editor > Administrar plantillas de exportación). Quedaron en `%APPDATA%\Godot\export_templates\4.7.stable`.
- **JDK 17** (Eclipse Adoptium): `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`.
- **Android SDK** con `cmdline-tools`, `platform-tools` (trae `adb`), `build-tools` 35.x y `platforms` 35: `C:\Users\PCJuan\AppData\Local\Android\Sdk`.
- **Debug keystore**: Godot lo generó solo en su carpeta de datos (`...\editor_data\keystores\debug.keystore`; en la instalación de Steam: `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\editor_data\keystores\`). Usuario `androiddebugkey`, contraseña `android`. (Alternativa: `C:\Users\PCJuan\.android\debug.keystore` de Android Studio.)
- En **Editor > Configuración del editor > Export > Android** completar: *Ruta del Android SDK*, *Ruta del SDK de Java*, *Debug Keystore*, su usuario y contraseña. Vacíos = el preset da error rojo.
- Ajuste del proyecto: **Rendering > Textures > VRAM Compression > Import ETC2 ASTC** activado (sin esto el preset marca error).

## El preset (`export_presets.cfg`)
Proyecto > Exportar > Añadir > Android, marcado **Ejecutable**. Lo que se dejó:
- `gradle_build/use_gradle_build=false` (APK simple), formato APK, solo `arm64-v8a`.
- `package/unique_name="com.zarita.zarigueya"` (no dejar `com.example...`: Google Play lo rechaza; cambiarlo después instala *otra* app), `package/name="Zarita"`.
- Iconos: `launcher_icons/main_192x192` (192×192), `adaptive_foreground_432x432` (432×432 transparente, personaje en el 58 % central) y `adaptive_background_432x432` (432×432 liso). Hechos con Pillow desde la cabeza del personaje.
- `exclude_filter="assets/practica/*, tools/*"`.
- `screen/immersive_mode=true`, orientación vertical en `project.godot` (`window/handheld/orientation=1`).
- Permisos: ninguno por ahora (`internet=false`). **Con anuncios reales hay que activar INTERNET y ACCESS_NETWORK_STATE.**

## Probar en el celular
1. Opciones de desarrollador: tocar 7 veces el *Número de compilación*; activar **Depuración USB**.
2. Cable **de datos**; aceptar "¿Permitir depuración USB?" en el celular.
3. Godot muestra un icono de Android arriba a la derecha (despliegue con un clic): instala y abre.
4. O **Proyecto > Exportar > Exportar proyecto...** a una carpeta **fuera** del proyecto, con *Exportar con depuración* marcado; pasar el `.apk` al celular e instalar (permitir orígenes desconocidos).

## Qué revisar en la primera prueba
- Joystick y botones responden al dedo; arrastrar muebles y deslizar listas.
- Rendimiento con lluvia + relámpagos + varias lámparas + ventanas: si va lento → apagar `LuzNatural.activa`, bajar partículas, quitar sombras proyectadas.
- Guardado al pausar/cerrar (`NOTIFICATION_APPLICATION_PAUSED`).
- Notch/gestos: HUD con márgenes de 24 px; `edge_to_edge=false`.

## Antes de publicar de verdad
- `Economia.MODO_PRUEBAS = false`.
- Firma de **release** (keystore propio, guardado en lugar seguro; sin él no se pueden actualizar las apps).
- **Anuncios reales**: activar *Gradle Build*, instalar el plugin de AdMob para Godot, cambiar solo `Anuncios._mostrar_anuncio_real()` (ver `escenas-y-datos.md`). Usar IDs de prueba mientras se desarrolla.
- Revisar licencias del arte y la política de contenido de IA de la tienda; formato AAB para Play Store (requiere Gradle Build).
- Fuente pixelada y audio (lluvia/trueno) quedan como mejoras.
