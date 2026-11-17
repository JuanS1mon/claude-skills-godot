extends RefCounted
## BOTÍN DEL JEFE: las cartas que se ofrecen (1 de 3, al azar) cada vez que cae un jefe. Valen SOLO para la misión en curso
## (se guardan en `Mision.botin` y se pierden al terminar): son la parte de la partida que el jugador decide sobre la marcha.
## Lo permanente sigue siendo el Taller (oro), las mejoras de la nave (cristales y materiales) y la fusión.
## Se usa con `const Botin = preload("res://scripts/botin.gd")` (sin `class_name`, como `Rasgos` y `Ayudas`).
##
## Todas suman en PORCENTAJE sobre lo que el equipo ya tiene (nivel de la misión, fusión, Taller), así siguen sirviendo cuando
## los enemigos crecen: +12% de daño vale lo mismo en la ola 10 que en la 200. Cada 10 olas los enemigos se vuelven ~1,75 veces
## más duros y una carta da entre +10% y +30%: ayudan, pero no reemplazan a mejorar la tripulación.
##
## Para agregar una carta: una línea en `CARTAS` y enganchar su `id` donde se usa con `Mision.bono("id")` (ver `batalla.gd`).

## Rareza de la carta: nombre, cuánto pesa en el sorteo (de cada 100) y su color (los mismos de R / SR / SSR de la tripulación).
const RAREZAS := [
	{"nombre": "Común", "peso": 62.0},
	{"nombre": "Rara", "peso": 29.0},
	{"nombre": "Épica", "peso": 9.0},
]

## `valores`: lo que da en común / rara / épica. `pct`: se muestra como porcentaje. `peso`: cuánto sale. `tipo`: "combate" o "botin"
## (las de botín dan más oro, recursos o experiencia: es la tentación contra las de poder). `instantanea`: se usa al elegirla y no se acumula.
const CARTAS := {
	"dano": {"nombre": "Pólvora negra", "texto": "+%d%% de daño de la tripulación", "valores": [0.12, 0.18, 0.28], "pct": true, "peso": 10.0, "tipo": "combate", "icono": "i_star", "color": Color(1.0, 0.55, 0.3)},
	"cadencia": {"nombre": "Gatillo ligero", "texto": "+%d%% de velocidad de ataque", "valores": [0.10, 0.15, 0.24], "pct": true, "peso": 10.0, "tipo": "combate", "icono": "i_gear", "color": Color(1.0, 0.85, 0.35)},
	"vida": {"nombre": "Raciones dobles", "texto": "+%d%% de vida de la tripulación", "valores": [0.15, 0.22, 0.35], "pct": true, "peso": 9.0, "tipo": "combate", "icono": "i_helmet", "color": Color(0.5, 0.95, 0.6)},
	"casco": {"nombre": "Planchas de latón", "texto": "+%d%% de casco de la nave", "valores": [0.20, 0.30, 0.45], "pct": true, "peso": 8.0, "tipo": "combate", "icono": "i_helmet", "color": Color(0.9, 0.7, 0.35)},
	"critico": {"nombre": "Ojo de halcón", "texto": "+%d%% de probabilidad de golpe crítico", "valores": [0.06, 0.09, 0.14], "pct": true, "peso": 8.0, "tipo": "combate", "icono": "i_star", "color": Color(1.0, 0.35, 0.35)},
	"enfriamiento": {"nombre": "Engranajes aceitados", "texto": "Las habilidades se recargan %d%% más rápido", "valores": [0.08, 0.12, 0.18], "pct": true, "peso": 7.0, "tipo": "combate", "icono": "i_gear", "color": Color(0.55, 0.85, 1.0), "tope": 0.5},
	"andanada": {"nombre": "Cañones extra", "texto": "+%d obuses en cada andanada de la nave", "valores": [2.0, 3.0, 4.0], "pct": false, "peso": 7.0, "tipo": "combate", "icono": "i_gear", "color": Color(1.0, 0.7, 0.4)},
	"curacion": {"nombre": "Botiquín de campaña", "texto": "+%d%% de curación al superar cada ola", "valores": [0.06, 0.09, 0.14], "pct": true, "peso": 7.0, "tipo": "combate", "icono": "i_fuel", "color": Color(0.45, 0.95, 0.85)},
	"lentitud": {"nombre": "Ancla de marea", "texto": "Los enemigos se mueven %d%% más lento", "valores": [0.05, 0.08, 0.12], "pct": true, "peso": 6.0, "tipo": "combate", "icono": "i_planet", "color": Color(0.6, 0.75, 1.0), "tope": 0.4},
	"oro": {"nombre": "Mapa del tesoro", "texto": "+%d%% de oro en esta misión", "valores": [0.25, 0.40, 0.60], "pct": true, "peso": 6.0, "tipo": "botin", "icono": "i_gold", "color": Color(1.0, 0.82, 0.3)},
	"recursos": {"nombre": "Bodegas hondas", "texto": "+%d%% de recursos en esta misión", "valores": [0.30, 0.45, 0.70], "pct": true, "peso": 5.0, "tipo": "botin", "icono": "i_planet", "color": Color(0.7, 0.9, 0.5)},
	"exp": {"nombre": "Bitácora del veterano", "texto": "+%d%% de experiencia del equipo", "valores": [0.15, 0.25, 0.40], "pct": true, "peso": 6.0, "tipo": "botin", "icono": "i_star", "color": Color(0.6, 0.92, 1.0)},
	"reparar": {"nombre": "Reparación de emergencia", "texto": "Cura %d%% a la nave y a la tripulación y levanta a los caídos", "valores": [0.5, 0.75, 1.0], "pct": true, "peso": 3.0, "tipo": "combate", "icono": "i_fuel", "color": Color(0.5, 1.0, 0.6), "instantanea": true},
}
## Cuánto más sale "Reparación de emergencia" cuando hace falta (hay un caído o la nave está a menos de la mitad).
const PESO_REPARAR_URGENTE := 14.0
const COLORES_RAREZA := [Color(0.42, 0.72, 1.0), Color(0.74, 0.52, 1.0), Color(1.0, 0.82, 0.35)]


## Sortea `cuantas` cartas distintas. `urgente`: hay un tripulante caído o la nave está muy golpeada (sale más la reparación).
## `acumulado`: lo que la misión ya lleva de cada carta (`Mision.botin`): una carta que llegó a su `tope` no vuelve a salir.
## Devuelve una lista de {id, rareza, valor}.
static func sortear(cuantas: int = 3, urgente: bool = false, acumulado: Dictionary = {}) -> Array:
	var disponibles: Array = []
	for id in CARTAS:
		var c: Dictionary = CARTAS[id]
		if c.has("tope") and float(acumulado.get(id, 0.0)) >= float(c.tope) - 0.001:
			continue
		var peso: float = c.peso
		if id == "reparar" and urgente:
			peso = PESO_REPARAR_URGENTE
		disponibles.append([id, peso])
	var salida: Array = []
	while salida.size() < cuantas and not disponibles.is_empty():
		var total := 0.0
		for par in disponibles:
			total += par[1]
		var tirada := randf() * total
		var elegido := 0
		for i in disponibles.size():
			tirada -= disponibles[i][1]
			if tirada < 0.0:
				elegido = i
				break
		var id: String = disponibles[elegido][0]
		disponibles.remove_at(elegido)
		var rareza := _sortear_rareza()
		salida.append({"id": id, "rareza": rareza, "valor": float(CARTAS[id].valores[rareza])})
	return salida


static func _sortear_rareza() -> int:
	var tirada := randf() * 100.0
	for i in RAREZAS.size():
		tirada -= float(RAREZAS[i].peso)
		if tirada < 0.0:
			return i
	return 0


## La que elige el juego cuando el jugador no toca ninguna (se acabó el tiempo, o pidió "elegir sola"): la de mayor rareza y,
## entre iguales, una de combate antes que una de botín (así una misión desatendida no se cae por elegir oro).
static func mejor(opciones: Array) -> Dictionary:
	var elegida: Dictionary = {}
	var nota := -1.0
	for carta in opciones:
		var n := float(carta.rareza) * 10.0 + (1.0 if CARTAS[carta.id].tipo == "combate" else 0.0)
		if n > nota:
			nota = n
			elegida = carta
	return elegida


static func nombre(carta: Dictionary) -> String:
	return TranslationServer.translate(CARTAS[carta.id].nombre)


static func nombre_rareza(rareza: int) -> String:
	return TranslationServer.translate(RAREZAS[clampi(rareza, 0, RAREZAS.size() - 1)].nombre)


static func color_rareza(rareza: int) -> Color:
	return COLORES_RAREZA[clampi(rareza, 0, COLORES_RAREZA.size() - 1)]


## "+18% de daño de la tripulación", ya traducido y con el valor de esa carta.
static func descripcion(carta: Dictionary) -> String:
	var c: Dictionary = CARTAS[carta.id]
	var numero := roundi(float(carta.valor) * 100.0) if c.pct else roundi(float(carta.valor))
	return String(TranslationServer.translate(c.texto)) % numero


static func icono(carta: Dictionary) -> Texture2D:
	return load("res://assets/ui/%s.png" % CARTAS[carta.id].icono)


static func color(carta: Dictionary) -> Color:
	return CARTAS[carta.id].color


## Lo que una carta suma al acumulado de la misión, respetando su tope (0 si es instantánea: no se acumula).
static func sumar(acumulado: Dictionary, carta: Dictionary) -> void:
	var c: Dictionary = CARTAS[carta.id]
	if c.get("instantanea", false):
		return
	var nuevo := float(acumulado.get(carta.id, 0.0)) + float(carta.valor)
	if c.has("tope"):
		nuevo = minf(nuevo, float(c.tope))
	acumulado[carta.id] = nuevo
