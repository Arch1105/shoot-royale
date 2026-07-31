extends Node2D
## Root of the match: hooks up spoken announcements to death/respawn events
## and tracks the player's kill/death count for the on-demand score check.

var player_kills: int = 0
var player_deaths: int = 0

func _ready() -> void:
	for c in get_tree().get_nodes_in_group("characters"):
		var ch: Character = c
		ch.died.connect(_on_character_died)
		if ch is PlayerController:
			ch.respawned.connect(_on_player_respawned)
	Voice.say("match_start")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("check_score"):
		Voice.say_score(player_kills, player_deaths)

func _on_character_died(who: Character, attacker: Character, cause: String) -> void:
	if who is PlayerController:
		player_deaths += 1
		Voice.say("fall_damage" if cause == "fall" else "you_died")
	elif attacker is PlayerController and who is BotAI:
		var bot: BotAI = who
		player_kills += 1
		Voice.say_bot_eliminated(bot.bot_index)

func _on_player_respawned(_who: Character) -> void:
	Voice.say("you_respawned")
