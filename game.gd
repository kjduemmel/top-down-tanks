extends Node2D

func _process(_delta: float) -> void:
	if (Input.is_action_just_pressed("exit")):
		get_tree().change_scene_to_file("res://Assets/Scenes/UI/MainMenu.tscn")
