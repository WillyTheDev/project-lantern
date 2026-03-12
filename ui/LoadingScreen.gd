extends CanvasLayer

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var color_rect: ColorRect = %ColorRect
@onready var vbox: VBoxContainer = %VBoxContainer

func _ready() -> void:
	# Start invisible for transition
	color_rect.modulate.a = 0
	vbox.modulate.a = 0
	
	# Fade in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.3)

func update_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value * 100

func fade_out() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(vbox, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
