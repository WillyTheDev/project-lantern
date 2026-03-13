@tool
extends OmniLight3D
class_name controlled_light

@export var emission_curve: Curve
@export var duration: float = 10.0

var time: float = 0.0

func _process(delta):
	if not emission_curve:
		return
	
	time += delta
	if time > duration:
		time = 0.0
	
	var normalized_time = time / duration
	light_energy = emission_curve.sample(normalized_time)
