@tool
extends EditorPlugin

@export var min_interval_minutes:float = 0.1
@export var max_interval_minutes:float = 0.1
@export var min_duration:float = 5
@export var post_audio_duration:float = 2
@export var transition_seconds:float = 1
@export var transition_distance:float = 540
@export var volume_db:float = -10

const addon_path:String = "res://addons/KyuCanDoIt"

var overlay_dock:Control = load(addon_path.path_join("Scenes/OverlayDock.tscn")).instantiate()
var audio_player:AudioStreamPlayer
var label:Label
var girl:TextureRect
var background:Control

var messages:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(addon_path.path_join("Text/Messages.json")))

var timer_seconds:float = 0
var voices:Array

func _enter_tree()->void:
	# TTS
	voices = DisplayServer.tts_get_voices_for_language("en");
	
	# Always start of with a message
	timer_seconds = 5;
	
	# Setup docks
	audio_player = overlay_dock.get_node("AudioPlayer")
	label = overlay_dock.get_node("Background/SpeechBubble/SpeechLabel")
	girl = overlay_dock.get_node("Background/Girl")
	background = overlay_dock.get_node("Background")
	
	overlay_dock.hide()
	EditorInterface.get_editor_main_screen().add_child(overlay_dock)

func _exit_tree()->void:
	# Cleanup docks
	overlay_dock.queue_free()

func _process(delta:float)->void:
	# Debounce
	if overlay_dock.visible: return
	
	# Progress timer
	timer_seconds -= delta
	if timer_seconds > 0: return
	reset_timer()
	
	# Pick qoute
	var type:String = messages.keys().pick_random()
	var qoute:Dictionary = messages[type]["qoutes"][0] # messages[type]["qoutes"].pick_random()
	label.text = qoute["text"]
	
	# Show overlay
	var girl_directory:String = addon_path.path_join("Images/Girls").path_join(type)
	var imagePath:String

	if qoute.has("image") and qoute["image"] != null:
		imagePath = girl_directory.path_join(qoute["image"])
	else:
		imagePath = girl_directory.path_join(get_files_at(girl_directory).pick_random())

	girl.texture = load(imagePath)
	
	overlay_dock.show()
	
	# Transition overlay in
	await transition_overlay(true)
	
	# Play sound
	if qoute["sound"] != null:
		var soundPath:String = addon_path.path_join("Sounds/Girls").path_join(type).path_join(qoute["sound"])
		if FileAccess.file_exists(soundPath):
			audio_player.stream = load(addon_path.path_join("Sounds/Girls").path_join(type).path_join(qoute["sound"]))
			audio_player.volume_db = volume_db
			audio_player.play()
		else:
			printerr(soundPath + " not found")
	elif voices != null:
		DisplayServer.tts_speak(qoute["text"], voices[messages[type]["tts"]])
	
	# Print
	print(type + ": " + qoute["text"])
	
	# Wait duration
	await get_tree().create_timer(min_duration).timeout
	if audio_player.playing == true : await audio_player.finished;
	while DisplayServer.tts_is_speaking():
		await get_tree().create_timer(1).timeout
		
	await get_tree().create_timer(post_audio_duration).timeout
	
	# Transition overlay out
	await transition_overlay(false)
	
	# Hide overlay
	overlay_dock.hide()
	
func reset_timer()->void:
	timer_seconds = randf_range(min_interval_minutes, max_interval_minutes) * 60

func transition_overlay(to_visible:bool)->void:
	var transition:Tween = get_tree().create_tween()
	
	if to_visible:
		background.position.y = transition_distance
		transition.tween_property(background, "position:y", 0, transition_seconds)
	else:
		background.position.y = 0
		transition.tween_property(background, "position:y", transition_distance, transition_seconds)
	
	await transition.finished

func get_files_at(directory:String)->Array:
	var files:Array = []
	for file:String in DirAccess.get_files_at(directory):
		if file.ends_with(".import"):
			files.append(file.trim_suffix(".import"))
	return files
