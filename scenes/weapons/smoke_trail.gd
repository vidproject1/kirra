extends MeshInstance3D

func init(start_pos: Vector3, end_pos: Vector3) -> void:
	var path = end_pos - start_pos
	var distance = path.length()
	
	if distance < 0.1:
		queue_free()
		return
	
	# Move to the center between start and end
	global_position = start_pos + (path / 2.0)
	
	# Manually construct the basis to align Y-axis with the path
	var y_axis = path.normalized()
	var temp_up = Vector3.UP if abs(y_axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x_axis = y_axis.cross(temp_up).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	
	global_basis = Basis(x_axis, y_axis, z_axis)
	
	# Scale height (Y) to distance
	scale.y = distance
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "transparency", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)
