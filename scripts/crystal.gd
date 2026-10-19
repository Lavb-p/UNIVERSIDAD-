extends Area2D

## El jugador tocó el cristal (main decide si se puede recoger o no).
signal touched(crystal: Area2D)
## El cristal fue recogido y debe contarse. Solo se emite con la misión activa.
signal collected
## El jugador se alejó del cristal.
signal player_left

var was_collected: bool = false

# body_entered y body_exited están conectadas desde crystal.tscn.

func _on_body_entered(body: Node2D) -> void:
	if was_collected:
		return

	if body.is_in_group("player"):
		touched.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_left.emit()

## main.gd llama a esta función solo cuando la misión está activa.
func collect() -> void:
	if was_collected:
		return

	was_collected = true
	collected.emit()
	queue_free()
