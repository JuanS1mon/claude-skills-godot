## Todos los números que definen cómo se siente el personaje.
## Se editan en datos/jugador_stats.tres desde el Inspector, incluso con el juego corriendo.
class_name JugadorStats
extends Resource

@export_group("Movimiento")
@export var velocidad := 7.0
@export var aceleracion := 60.0
@export var frenado := 70.0
@export_range(0.0, 1.0) var control_aire := 0.7

@export_group("Salto")
@export var fuerza_salto := 11.0
@export var gravedad := 30.0
## Multiplica la gravedad al caer: caída más rápida que la subida.
@export var mult_caida := 1.6
## Al soltar el botón en subida, la velocidad vertical se multiplica por esto (salto variable).
@export_range(0.0, 1.0) var corte_salto := 0.45
## Segundos que todavía podés saltar después de dejar el borde.
@export var coyote_time := 0.1
## Segundos que se recuerda un salto apretado antes de tocar el piso.
@export var buffer_salto := 0.12
@export var velocidad_caida_max := 25.0

@export_group("Doble salto")
## Saltos extra en el aire (1 = doble salto, 0 = desactivado).
@export var saltos_extra := 1
@export var fuerza_doble_salto := 9.5
## Vuelta en el aire al hacer el doble salto (segundos; 0 = sin vuelta).
@export var duracion_vuelta := 0.3

@export_group("Dash")
@export var velocidad_dash := 20.0
@export var duracion_dash := 0.14
@export var enfriamiento_dash := 0.45
## Dashes permitidos antes de volver a tocar el piso.
@export var dashes_aereos := 1
## Fracción de la velocidad del dash cuando va hacia arriba o abajo (1 = igual que de costado).
@export_range(0.2, 1.0) var factor_dash_vertical := 0.6
## Empujón que reciben las cajas al chocarlas en dash.
@export var empuje_dash := 6.0

@export_group("Pared")
## Velocidad máxima de caída mientras se desliza agarrado a una pared.
@export var velocidad_deslizar := 2.5
## Salto desde la pared: empuje hacia afuera y hacia arriba.
@export var empuje_pared := 7.5
@export var fuerza_salto_pared := 11.0
## Segundos sin control horizontal después de saltar de la pared (si no, vuelve a pegarse enseguida).
@export var bloqueo_tras_salto_pared := 0.16
## Margen para saltar después de soltarse de la pared (como el coyote time).
@export var coyote_pared := 0.1

@export_group("Golpe")
@export var dano_golpe := 25
@export var empuje_golpe := 7.0
@export var duracion_golpe := 0.12
@export var enfriamiento_golpe := 0.3
@export var alcance_golpe := Vector3(1.3, 1.3, 1.0)

@export_group("Vida")
@export var vida_max := 5
@export var invulnerable := 1.0
@export var empuje_al_recibir := Vector2(6.0, 6.0)

@export_group("Disparo")
## Segundos entre balas manteniendo el botón.
@export var cadencia := 0.15
@export var velocidad_bala := 24.0
@export var dano_bala := 10
## Retroceso horizontal que recibe el personaje al disparar.
@export var retroceso := 0.6
## Segundos manteniendo el botón para llegar a la carga completa.
@export var tiempo_carga := 0.8
## Carga mínima (0 a 1) para que al soltar salga un disparo cargado.
@export_range(0.0, 1.0) var carga_minima := 0.3
## Daño y tamaño del disparo con la carga completa (además atraviesa enemigos).
@export var dano_cargado := 45
@export var escala_cargada := 2.6

@export_group("Disparos de las estrellas")
## Triple: apertura del abanico, en grados.
@export var angulo_triple := 12.0
## Rebote: veces que la bala rebota contra piso y paredes.
@export var rebotes := 3
## Explosivo: radio, daño y velocidad de la bala.
@export var radio_explosion := 2.2
@export var dano_explosion := 30
@export var velocidad_explosivo := 13.0

@export_group("Poderes de enemigos")
## Volador: segundos de vuelo después del doble salto (se recarga en el piso).
@export var tiempo_vuelo := 2.5
@export var velocidad_vuelo := 5.0
@export var aceleracion_vuelo := 60.0

@export_group("Agarrar y arrojar")
@export var fuerza_lanzamiento := 9.0
## Ángulo hacia arriba del lanzamiento, en grados.
@export_range(0.0, 80.0) var angulo_lanzamiento := 25.0
## Fracción de la velocidad del personaje que hereda el objeto arrojado.
@export_range(0.0, 1.0) var herencia_velocidad := 0.5
## Segundos manteniendo el botón para el lanzamiento más fuerte, y cuánto multiplica la fuerza.
@export var tiempo_carga_lanzar := 0.7
@export var mult_lanzamiento_cargado := 2.0
