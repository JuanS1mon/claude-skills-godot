extends Node
## BÚSQUEDA EVOLUTIVA DE DIFICULTAD (se usa en una copia, como autoload `Prueba`; ver CLAUDE.md, "Balance").
## Lanzar varias instancias en paralelo, cada una en su copia del proyecto con otro `config/name`, pasando el número de instancia:
##   godot --headless --path <copia_N> --fixed-fps 60 --quit-after 30000000 -- N
## Cada una escribe `user://busqueda_N.txt`; la línea FINAL es su mejor combinación, verificada con más corridas.
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


## --- Búsqueda evolutiva de dificultad -------------------------------------------------------------------------------
## Objetivo: en qué ola cae cada tipo de equipo (jugador "perezoso" del simulador).
const OBJ_INICIAL := 11.0
const OBJ_MEDIO := 45.0
const OBJ_FUERTE := 60.0
## Qué se busca y entre qué valores. La FORMA de las curvas (vida_lineal y dano_lineal) queda como en las tablas de Juan.
const PARAMS := {
	"vida_exponencial": [0.040, 0.065],
	"dano_exponencial": [0.035, 0.065],
	"escala_vida": [0.08, 0.30],
	"dano_enemigo": [0.25, 0.80],
	"curacion_base": [0.05, 0.20],
	"curar_al_subir": [0.0, 0.20],
	"bono_por_nivel": [0.02, 0.06],
}
const LIMITE_MS := 1500000

var _inst := 0
var _reg: FileAccess
var _t0 := 0


func _log(texto: String) -> void:
	print(texto)
	if _reg != null:
		_reg.store_line(texto)
		_reg.flush()


func _evaluar(v: Dictionary, veces: Array = [2, 1, 1]) -> Array:
	var medio := ["mora|2", "zorg|3", "caldera|3"]
	var fuerte := {"drones": 4, "satelite": 4, "muros": 4, "minas": 4}
	var a: int = await medir(BASE, {}, v, 0.0, veces[0])
	var b: int = await medir(medio, {}, v, 0.0, veces[1])
	var c: int = await medir(medio, fuerte, v, 0.0, veces[2])
	var perdida := pow((a - OBJ_INICIAL) / OBJ_INICIAL, 2) + pow((b - OBJ_MEDIO) / OBJ_MEDIO, 2) + pow((c - OBJ_FUERTE) / OBJ_FUERTE, 2)
	return [perdida, a, b, c]


func _texto(v: Dictionary) -> String:
	var t := ""
	for k in PARAMS:
		t += "%s=%.4f " % [k, v[k]]
	return t


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_inst = int(args[0])
	_reg = FileAccess.open("user://busqueda_%d.txt" % _inst, FileAccess.WRITE)
	Engine.time_scale = 10.0
	await get_tree().create_timer(1.0).timeout
	p = get_tree().current_scene
	p.titulo.boton_continuar.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	p.bienvenida.boton.pressed.emit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + _inst
	var inicio: Dictionary = {}
	var mejor: Dictionary = {}
	for k in PARAMS:
		inicio[k] = float(p.batalla.get(k))
		var lo: float = PARAMS[k][0]
		var hi: float = PARAMS[k][1]
		# la instancia 0 arranca de los valores actuales; las demás de un punto al azar
		mejor[k] = inicio[k] if _inst == 0 else rng.randf_range(lo, hi)
	_t0 = Time.get_ticks_msec()
	var r := await _evaluar(mejor)
	var mejor_perdida: float = r[0]
	_log("[SIM] inst=%d it=0 perdida=%.4f ini=%d med=%d fue=%d | %s" % [_inst, mejor_perdida, r[1], r[2], r[3], _texto(mejor)])
	var sigma := 0.30
	var it := 1
	while Time.get_ticks_msec() - _t0 < LIMITE_MS:
		var cand := mejor.duplicate()
		var tocar := rng.randi_range(0, PARAMS.size() - 1)
		var i := 0
		for k in PARAMS:
			if i == tocar or rng.randf() < 0.4:
				var lo: float = PARAMS[k][0]
				var hi: float = PARAMS[k][1]
				cand[k] = clampf(float(cand[k]) + rng.randfn(0.0, sigma * (hi - lo)), lo, hi)
			i += 1
		var res := await _evaluar(cand)
		# pequeña preferencia por quedarse cerca de los valores actuales (cambiar lo menos posible)
		var dist := 0.0
		for k in PARAMS:
			dist += pow((float(cand[k]) - float(inicio[k])) / (float(PARAMS[k][1]) - float(PARAMS[k][0])), 2)
		var perdida: float = res[0] + 0.01 * dist / PARAMS.size()
		var marca := ""
		if perdida < mejor_perdida:
			mejor_perdida = perdida
			mejor = cand
			marca = " *"
		_log("[SIM] inst=%d it=%d perdida=%.4f ini=%d med=%d fue=%d%s | %s" % [_inst, it, perdida, res[1], res[2], res[3], marca, _texto(cand)])
		sigma = maxf(0.05, sigma * 0.96)
		it += 1
	# verificación del mejor con más corridas (menos ruido)
	var fin := await _evaluar(mejor, [4, 3, 2])
	_log("[SIM] FINAL inst=%d perdida=%.4f ini=%d med=%d fue=%d | %s" % [_inst, fin[0], fin[1], fin[2], fin[3], _texto(mejor)])
	_reg.close()
	get_tree().quit()
