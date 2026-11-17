class_name Mate
extends RefCounted
## El ritual del mate: el motor diario de Zarita. Lleva su energía, la yerba y el agua caliente (clase con datos estáticos,
## como Habitaciones: sobrevive a las recargas de la casa y no hace falta un autoload). Cada mateada gasta yerba y agua y
## sube la energía; sin yerba o sin agua la energía baja más rápido. Con poca energía Zarita camina más despacio, pero nunca
## se bloquea el juego (es un juego relajante). Se guarda en la partida (ver Partida / casa.gd::_guardar).
## Todavía no hay forma de comprar yerba ni de calentar agua: la cocina y Homero lo harán (docs/universo-y-lore.md).

const ENERGIA_MAXIMA: float = 100.0
const ENERGIA_POR_MATEADA: float = 25.0
## Energía que se pierde por segundo con yerba y agua, y sin alguna de las dos.
const DESGASTE_NORMAL: float = 0.05
const DESGASTE_SIN_INSUMOS: float = 0.4
## A partir de qué energía empieza a notarse en la velocidad, y cuánto frena como máximo.
const ENERGIA_BAJA: float = 40.0
const FRENO_MAXIMO: float = 0.3
const YERBA_INICIAL: int = 5
const AGUA_INICIAL: int = 5
## Cuánto se calienta de una vez (una pava) y cuánta yerba trae cada compra, con su precio en Destellos.
const AGUA_MAXIMA: int = 5
const YERBA_POR_COMPRA: int = 5
const PRECIO_YERBA: int = 20

## Cada tantos puntos de confort de la habitación, 1 de energía extra por mateada, hasta BONUS_CONFORT_MAXIMO.
const CONFORT_POR_ENERGIA: int = 2
const BONUS_CONFORT_MAXIMO: int = 15

static var energia: float = ENERGIA_MAXIMA
## Confort de la habitación en que está Zarita (lo fija la casa): una habitación más cómoda hace mateadas mejores.
static var confort_actual: int = 0
static var yerba: int = YERBA_INICIAL
## Cebadas de agua caliente disponibles (la pava de la cocina las repondrá).
static var agua_caliente: int = AGUA_INICIAL
## Mezcla que se está usando (null = yerba sola).
static var blend: BlendData
## Día (de la hora real) en que Homero le regaló yuyos por última vez: uno por día.
static var dia_ultimo_regalo: int = -1


## ¿Hay con qué cebar un mate?
static func puede_tomar() -> bool:
	return yerba > 0 and agua_caliente > 0


## Los yuyos de Homero: uno por día real. Le da algo de yerba y una mezcla al azar de las que se regalan (precio 0).
static func puede_recibir_regalo() -> bool:
	return dia_ultimo_regalo != int(Time.get_unix_time_from_system() / 86400.0)


static func recibir_regalo(mezclas: Array[BlendData]) -> BlendData:
	dia_ultimo_regalo = int(Time.get_unix_time_from_system() / 86400.0)
	yerba += 2
	if not mezclas.is_empty():
		blend = mezclas[randi() % mezclas.size()]
	return blend


## Energía extra de cada mateada por el confort de la habitación.
static func bonus_confort() -> int:
	return mini(confort_actual / CONFORT_POR_ENERGIA, BONUS_CONFORT_MAXIMO)


## La pava de la cocina: llena las cebadas de agua caliente.
static func calentar_agua() -> void:
	agua_caliente = AGUA_MAXIMA


## Una mateada: gasta una yerba y un agua y sube la energía. Devuelve false si faltaba algo.
static func beber() -> bool:
	if not puede_tomar():
		return false
	yerba -= 1
	agua_caliente -= 1
	energia = minf(ENERGIA_MAXIMA, energia + ENERGIA_POR_MATEADA + (blend.energia_extra if blend != null else 0) + bonus_confort())
	return true


## Un mate preparado a mano en el minijuego (MateJuego): gasta una yerba (más las que se hayan caído) y NO gasta agua caliente,
## porque la calentó ahí mismo. `calidad` (0-1) escala la energía; `mezcla` son los yuyos puestos (null = yerba sola).
static func beber_preparado(calidad: float, yerba_extra: int, mezcla: BlendData) -> void:
	yerba = maxi(0, yerba - 1 - yerba_extra)
	var base := ENERGIA_POR_MATEADA + (mezcla.energia_extra if mezcla != null else 0) + bonus_confort()
	energia = minf(ENERGIA_MAXIMA, energia + base * calidad)


## El tiempo baja la energía. La casa lo llama cada cuadro.
static func actualizar(delta: float) -> void:
	var desgaste := DESGASTE_NORMAL if puede_tomar() else DESGASTE_SIN_INSUMOS
	energia = maxf(0.0, energia - desgaste * delta)


## 1.0 con energía normal; baja hasta 1 - FRENO_MAXIMO cuando está en cero.
static func factor_velocidad() -> float:
	if energia >= ENERGIA_BAJA:
		return 1.0
	return 1.0 - FRENO_MAXIMO * (1.0 - energia / ENERGIA_BAJA)


static func a_datos() -> Dictionary:
	return {"energia": energia, "yerba": yerba, "agua": agua_caliente, "blend": blend.resource_path if blend != null else "", "regalo_dia": dia_ultimo_regalo}


static func cargar_datos(datos: Dictionary) -> void:
	energia = clampf(float(datos.get("energia", ENERGIA_MAXIMA)), 0.0, ENERGIA_MAXIMA)
	yerba = maxi(0, int(datos.get("yerba", YERBA_INICIAL)))
	agua_caliente = maxi(0, int(datos.get("agua", AGUA_INICIAL)))
	dia_ultimo_regalo = int(datos.get("regalo_dia", -1))
	var ruta: String = datos.get("blend", "")
	blend = load(ruta) as BlendData if ruta != "" and ResourceLoader.exists(ruta) else null
