extends Node3D
class_name ShooterGameManager
## Root of a Multiplayer Shootout match: spawns players, runs the 6-minute
## host-authoritative timer, and turns each replicated died/respawned signal
## (see ShooterPlayer.gd) into scorekeeping + a Voice announcement, the same
## split of responsibility as the bat mode's GameManager.gd/Character.gd -
## just with the state changes arriving over the network instead of locally.
##
## Player spawning is careful about a race: a client's MultiplayerSpawner can
## only receive replicated spawns once IT has loaded this same scene, so
## clients explicitly request their own spawn (_request_spawn) after their
## local _ready() has run, rather than the server spawning the instant ENet
## reports a connected peer.
##
## Spawning goes through spawner.spawn_function rather than a plain add_child
## with a pre-set node name: add_child under a watched spawn_path replicates
## *that* instantiation, but there is no guarantee every peer's copy ends up
## with the exact same node name the server set beforehand. ShooterPlayer
## derives its multiplayer authority from its name, so a mismatch there
## silently breaks is_multiplayer_authority() on the client - which quietly
## disables movement, shooting, footsteps and aim-assist all at once (this
## was the actual cause of "no sound for anything"). spawn_function runs the
## exact same code, with the exact same peer-id argument, on every peer, so
## the name/authority assignment can't drift.
##
## Registration (connecting died/respawned, seeding _kills/_deaths) happens
## via players_container.child_entered_tree instead of inline after spawning:
## that signal fires on *every* peer whenever a player node lands in their
## local tree, whether it was spawned locally (server) or arrived through the
## spawner's replication (clients). Doing it only where the server calls
## spawn() - as an earlier version did - meant a client never connected to
## anyone's signals at all, silently breaking its own score tracking and
## death/respawn/match-end announcements.

const MATCH_DURATION := 360.0 # 6 minutes
const TIME_LOW_WARNING := 60.0

@onready var field: ShooterField = $Field
@onready var players_container: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner

var _players: Dictionary = {} # peer_id (int) -> ShooterPlayer
var _kills: Dictionary = {} # peer_id -> int
var _deaths: Dictionary = {} # peer_id -> int
var _match_time_left: float = MATCH_DURATION
var _match_running: bool = false
var _warned_time_low: bool = false
var _local_peer_id: int = 0

func _ready() -> void:
	_local_peer_id = multiplayer.get_unique_id()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	spawner.spawn_path = spawner.get_path_to(players_container)
	spawner.add_spawnable_scene("res://scenes/shooter/ShooterPlayer.tscn")
	spawner.spawn_function = _spawn_player_instance
	players_container.child_entered_tree.connect(_on_player_spawned)
	if multiplayer.is_server():
		_spawn_player(1)
	else:
		rpc_id(1, "_request_spawn")
	_match_time_left = MATCH_DURATION
	_match_running = true
	_warned_time_low = false
	Voice.say("shootout_start")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("check_score"):
		Voice.say_score(_kills.get(_local_peer_id, 0), _deaths.get(_local_peer_id, 0))
	if Input.is_action_just_pressed("ui_cancel"):
		_leave_match()
		return
	if not _match_running or not multiplayer.is_server():
		return
	_match_time_left -= delta
	if not _warned_time_low and _match_time_left <= TIME_LOW_WARNING:
		_warned_time_low = true
		rpc("_announce_time_low")
	if _match_time_left <= 0.0:
		_match_running = false
		rpc("_finish_match")

@rpc("any_peer", "reliable")
func _request_spawn() -> void:
	if not multiplayer.is_server():
		return
	var requester_id: int = multiplayer.get_remote_sender_id()
	if requester_id != 0:
		_spawn_player(requester_id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if _players.has(id):
		var p: ShooterPlayer = _players[id]
		p.queue_free()
		_players.erase(id)

## Runs identically on every peer via spawner.spawn()'s replication - see the
## note at the top of this file for why this replaces a plain add_child.
func _spawn_player_instance(id: Variant) -> Node:
	var peer_id: int = int(id)
	var scene: PackedScene = preload("res://scenes/shooter/ShooterPlayer.tscn")
	var player: ShooterPlayer = scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.configure_replication()
	return player

func _spawn_player(id: int) -> void:
	if not multiplayer.is_server() or _players.has(id):
		return
	var player: ShooterPlayer = spawner.spawn(id)
	player.position = field.random_spawn_point()

## Fires on every peer for every player node that lands under Players,
## whether spawned locally (server) or replicated in (clients) - see the note
## at the top of this file.
func _on_player_spawned(node: Node) -> void:
	var player: ShooterPlayer = node
	var id := player.peer_id()
	_players[id] = player
	_kills[id] = _kills.get(id, 0)
	_deaths[id] = _deaths.get(id, 0)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)

func _on_player_died(who: ShooterPlayer, attacker_id: int) -> void:
	var victim_id: int = who.peer_id()
	_deaths[victim_id] = _deaths.get(victim_id, 0) + 1
	_kills[attacker_id] = _kills.get(attacker_id, 0) + 1
	if victim_id == _local_peer_id:
		Voice.say("you_died")
	elif attacker_id == _local_peer_id:
		Voice.say("eliminated_generic")
	if multiplayer.is_server():
		_schedule_respawn(who)

func _on_player_respawned(who: ShooterPlayer) -> void:
	if who.peer_id() == _local_peer_id:
		Voice.say("you_respawned")

func _schedule_respawn(who: ShooterPlayer) -> void:
	await get_tree().create_timer(who.respawn_delay).timeout
	if not is_instance_valid(who):
		return
	who.rpc("respawn_at", field.random_spawn_point())

@rpc("any_peer", "call_local", "reliable")
func _announce_time_low() -> void:
	Voice.say("match_time_low")

@rpc("any_peer", "call_local", "reliable")
func _finish_match() -> void:
	_match_running = false
	var my_kills: int = _kills.get(_local_peer_id, 0)
	var is_tie := true
	var is_winner := true
	for id in _kills.keys():
		if id == _local_peer_id:
			continue
		var other_kills: int = _kills[id]
		if other_kills != my_kills:
			is_tie = false
		if other_kills > my_kills:
			is_winner = false
	Voice.say_match_result(is_winner, is_tie, my_kills)

func _leave_match() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
