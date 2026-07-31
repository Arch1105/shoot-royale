extends Node
class_name LanClient
## Finds a Multiplayer Shootout host on the LAN by 4-digit code (broadcasting
## a query and waiting for that code-holder to answer - see LanHost.gd) and
## connects to it via ENet. No manual IP entry required.

signal found_host(ip: String, port: int)
signal connected_to_server()
signal connection_failed()
signal timed_out()

const DISCOVERY_PORT := 47320
const DISCOVERY_PREFIX := "BASHROYALE_DISCOVER:"
const HOST_REPLY_PREFIX := "BASHROYALE_HOST:"
const QUERY_INTERVAL := 1.0
const SEARCH_TIMEOUT := 10.0

var code: int = 0

var _udp := PacketPeerUDP.new()
var _peer: ENetMultiplayerPeer
var _searching: bool = false
var _query_timer: float = 0.0
var _timeout_timer: float = 0.0

func start_search(join_code: int) -> void:
	code = join_code
	_udp.set_broadcast_enabled(true)
	_udp.bind(0)
	_searching = true
	_query_timer = 0.0
	_timeout_timer = 0.0
	set_process(true)
	_send_query()

func _process(delta: float) -> void:
	if not _searching:
		return
	_timeout_timer += delta
	if _timeout_timer >= SEARCH_TIMEOUT:
		_stop_searching()
		timed_out.emit()
		return
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = QUERY_INTERVAL
		_send_query()
	while _udp.get_available_packet_count() > 0:
		var packet: PackedByteArray = _udp.get_packet()
		var text: String = packet.get_string_from_utf8()
		if not text.begins_with(HOST_REPLY_PREFIX):
			continue
		var parts: PackedStringArray = text.trim_prefix(HOST_REPLY_PREFIX).split(":")
		if parts.size() != 2 or int(parts[0]) != code:
			continue
		var host_ip: String = _udp.get_packet_ip()
		var host_port: int = int(parts[1])
		_stop_searching()
		found_host.emit(host_ip, host_port)
		_connect_to(host_ip, host_port)
		return

func _send_query() -> void:
	_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_udp.put_packet((DISCOVERY_PREFIX + str(code)).to_utf8_buffer())

func _stop_searching() -> void:
	_searching = false
	set_process(false)
	_udp.close()

func _connect_to(ip: String, port: int) -> void:
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(ip, port)
	if err != OK:
		push_error("LanClient: failed to create client (%d)" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_connected() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func stop() -> void:
	_udp.close()
	set_process(false)
