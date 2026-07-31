extends Node
class_name LanHost
## Starts an ENet server for a Multiplayer Shootout match and answers LAN
## broadcast queries for its 4-digit join code, so the other player never has
## to type an IP address - see LanClient.gd for the other side of this.

signal match_code_ready(code: int)
signal client_connected(id: int)
signal client_disconnected(id: int)

const DISCOVERY_PORT := 47320
const GAME_PORT := 47321
const MAX_CLIENTS := 4
const DISCOVERY_PREFIX := "BASHROYALE_DISCOVER:"
const HOST_REPLY_PREFIX := "BASHROYALE_HOST:"

var code: int = 0

var _udp := PacketPeerUDP.new()
var _peer: ENetMultiplayerPeer

## Returns the generated code, or -1 if the server couldn't be started
## (most likely the game port is already in use).
func start_hosting() -> int:
	code = randi_range(1000, 9999)
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_server(GAME_PORT, MAX_CLIENTS)
	if err != OK:
		push_error("LanHost: failed to create server (%d)" % err)
		return -1
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_udp.bind(DISCOVERY_PORT)
	set_process(true)
	match_code_ready.emit(code)
	return code

func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = _udp.get_packet()
		var sender_ip: String = _udp.get_packet_ip()
		var sender_port: int = _udp.get_packet_port()
		var text: String = packet.get_string_from_utf8()
		if text == DISCOVERY_PREFIX + str(code):
			var reply: String = "%s%d:%d" % [HOST_REPLY_PREFIX, code, GAME_PORT]
			_udp.set_dest_address(sender_ip, sender_port)
			_udp.put_packet(reply.to_utf8_buffer())

func _on_peer_connected(id: int) -> void:
	client_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	client_disconnected.emit(id)

func stop() -> void:
	_udp.close()
	set_process(false)
