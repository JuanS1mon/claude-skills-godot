## Arena del jefe: cuando el jugador entra, cierra una pared detrás, despierta al jefe y
## muestra su barra de vida. Al vencerlo, la pared se abre y aparece la estrella del premio.
extends Node3D

@export var jefe: Node3D
@export var puerta: StaticBody3D
@export var estrella_premio: Node3D
## Bordes de la arena (x de las paredes interiores).
@export var x_izq := 56.0
@export var x_der := 74.0

@onready var zona: Area3D = $Entrada

var _empezo := false


func _ready() -> void:
	zona.body_entered.connect(_al_entrar)
	puerta.get_node("Forma").disabled = true
	puerta.get_node("Malla").visible = false
	if estrella_premio:
		estrella_premio.visible = false
		estrella_premio.get_node("Forma").disabled = true
	jefe.x_izq = x_izq
	jefe.x_der = x_der
	jefe.derrotado.connect(_al_vencer)


func _al_entrar(cuerpo: Node3D) -> void:
	if _empezo or not cuerpo.is_in_group("jugador"):
		return
	_empezo = true
	puerta.get_node("Forma").disabled = false
	puerta.get_node("Malla").visible = true
	jefe.despertar()
	get_tree().call_group("hud", "mostrar_jefe", jefe)


func _al_vencer() -> void:
	puerta.get_node("Forma").disabled = true
	puerta.get_node("Malla").visible = false
	get_tree().call_group("hud", "ocultar_jefe")
	if estrella_premio:
		estrella_premio.visible = true
		estrella_premio.get_node("Forma").disabled = false
