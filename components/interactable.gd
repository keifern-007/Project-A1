class_name Interactable
extends Area3D
## A spot the player walks up to and presses interact on: hub stations now, NPCs and doors later.
## Shows a floating "[E] <name>" prompt while a player is in range. The owner listens to
## `interacted` and decides what happens (it checks `action` to tell stations apart).

signal interacted(player: Player)

@export var action: StringName = &"" ## e.g. &"missions", &"stash". The owner matches on this.
@export var prompt_key: String = "" ## Translation key of the station's name.
@export var enabled: bool = true

@onready var prompt: Label3D = $Prompt


func _ready() -> void:
	add_to_group("interactables")
	prompt.text = tr("UI_INTERACT_PROMPT") % [InputHints.key_for("interact"), tr(prompt_key)]
	prompt.visible = false


func _physics_process(_delta: float) -> void:
	var player: Player = _player_in_range()
	prompt.visible = enabled and player != null
	if enabled and player and player.is_interact_just_pressed():
		interacted.emit(player)


func _player_in_range() -> Player:
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player and player.controlled and player.is_alive():
			return player
	return null
