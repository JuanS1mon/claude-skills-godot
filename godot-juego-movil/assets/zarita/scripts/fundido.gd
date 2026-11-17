extends CanvasLayer
## Fundido a negro, en su propia capa por encima de la interfaz. Las animaciones "salir" y "entrar" están en el nodo
## Animacion (se ven y se editan en el editor); sola (F6) arranca en negro y aclara. Autoplay "entrar": al nacer aclara.


## Oscurece la pantalla. Espera a que termine (`await fundido.salir()`).
func salir() -> void:
	$Animacion.play("salir")
	await $Animacion.animation_finished


## Parte de negro y aclara (se llama al empezar la habitación nueva).
func entrar() -> void:
	$Animacion.play("entrar")
	await $Animacion.animation_finished
