extends Node
## Simulador de balance. Corre la batalla REAL en tiempo acelerado y sin pantalla, con el equipo y las mejoras que
## se le indiquen, y mide en qué ola cae cada configuración (los tripulantes se quedan quietos y con las habilidades
## en automático: es un jugador "perezoso", un piso razonable de lo que logra uno real).
##
## Cómo usarlo (siempre en una COPIA del proyecto, nunca en el real):
##   1. Copiar el proyecto, cambiar `config/name` y agregar este archivo como autoload llamado `Prueba`.
##   2. Correr:  godot --headless --path <copia> --fixed-fps 60 --quit-after 3000000
##      (`--fixed-fps 60` hace que cada cuadro dure 1/60 s de juego y corra lo más rápido que pueda;
##       una configuración tarda unos segundos reales.)
##   3. Leer las líneas que empiezan con [SIM]. (Con `time_scale` 10 los resultados varían ±2 olas; el tope es MAX_SEG = 6000 s de juego.)
## Para probar otra dificultad se pasan `ajustes` (las variables del grupo "Dificultad" de `batalla.gd`).

const MAX_SEG := 6000.0
const BASE := ["selene|1", "caldera|1", "zorg|1"]

var p


## Devuelve la ola mediana en que cae el equipo (o la que alcanzó al llegar al tope de tiempo).
func medir(equipo: Array, mejoras: Dictionary = {}, ajustes: Dictionary = {}, entrenamiento: float = 0.0, veces: int = 3) -> int:
	var olas := []
	for v in veces:
		for k in ajustes:
			p.batalla.set(k, ajustes[k])
		Tripulacion.puestos = 8
		Tripulacion.equipo = equipo.duplicate()
		Tripulacion.entrenamiento = entrenamiento
		Tripulacion.auto_habilidad = {"selene": true, "caldera": true, "zorg": true, "mora": true, "piston": true, "xylo": true}
		Mejoras.nivel = mejoras.duplicate()
		Mejoras.slots = 4
		Mejoras.equipadas = mejoras.keys().slice(0, 4)
		Sistema.actual = 0
		Mision.iniciar_nueva()
		Mision.iniciar()
		var t := 0.0
		while Mision.activa and t < MAX_SEG:
			await get_tree().process_frame
			t += Engine.time_scale / 60.0
		olas.append(Mision.ola)
		if Mision.activa:
			Mision.terminar("retirada")
		await get_tree().create_timer(0.05).timeout
	olas.sort()
	return olas[olas.size() / 2]


func _ready() -> void:
	Engine.time_scale = 10.0
	await get_tree().create_timer(1.0).timeout
	p = get_tree().current_scene
	p.titulo.boton_continuar.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	p.bienvenida.boton.pressed.emit()
	var medio := ["mora|2", "zorg|3", "caldera|3"]
	print("[SIM] inicial                  : ", await medir(BASE))
	print("[SIM] equipo medio             : ", await medir(medio))
	print("[SIM] medio + 4 mejoras Nv2    : ", await medir(medio, {"drones": 2, "mochilas": 2, "muros": 2, "satelite": 2}))
	print("[SIM] medio + 4 mejoras Nv4    : ", await medir(medio, {"drones": 4, "satelite": 4, "muros": 4, "minas": 4}, {}, 0.0, 2))
	get_tree().quit()
