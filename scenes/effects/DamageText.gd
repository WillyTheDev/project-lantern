extends Label3D

func _ready() -> void:
	var tween = create_tween().set_parallel(true)
	
	# Float up
	tween.tween_property(self, "position:y", position.y + 1.0, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Scale pop
	scale = Vector3.ZERO
	tween.tween_property(self, "scale", Vector3(0.3, 0.3, 0.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Fade out
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.4)
	
	# Clean up
	tween.chain().tween_callback(queue_free)

func setup(amount: float) -> void:
	text = str(int(amount))
	if amount > 20: # Critical hit coloring?
		modulate = Color.GOLD
	else:
		modulate = Color.WHITE
