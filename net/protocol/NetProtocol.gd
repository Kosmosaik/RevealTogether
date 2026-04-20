extends RefCounted
class_name NetProtocol

const PROTOCOL_VERSION: String = "0.1.0"

const SERVER_PEER_ID: int = 1
const DEFAULT_SERVER_PORT: int = 7777

# Channel 0 is reserved for handshake/session-critical messages.
const HANDSHAKE_CHANNEL: int = 0
const SESSION_CHANNEL: int = 0
const GAMEPLAY_CHANNEL: int = 1
const UI_CHANNEL: int = 2

const CONNECTION_STATE_CONNECTING: StringName = &"connecting"
const CONNECTION_STATE_CONNECTED: StringName = &"connected"
const CONNECTION_STATE_DISCONNECTED: StringName = &"disconnected"

const MATCH_STATE_WAITING_FOR_PLAYERS: StringName = &"waiting_for_players"
const MATCH_STATE_ACTIVE: StringName = &"active"
const MATCH_STATE_FINAL_RUSH: StringName = &"final_rush"
const MATCH_STATE_FINISHED: StringName = &"finished"

const ACTION_STATE_IDLE: StringName = &"idle"
const ACTION_STATE_MOVING: StringName = &"moving"
const ACTION_STATE_REVEALING: StringName = &"revealing"
const ACTION_STATE_INTERACTING: StringName = &"interacting"

const HELLO_REJECT_REASON_PROTOCOL_MISMATCH: StringName = &"protocol_mismatch"
const HELLO_REJECT_REASON_CONTENT_HASH_MISMATCH: StringName = &"content_hash_mismatch"

const JOIN_REJECT_REASON_NOT_HANDSHAKEN: StringName = &"not_handshaken"
const JOIN_REJECT_REASON_MATCH_UNAVAILABLE: StringName = &"match_unavailable"
const JOIN_REJECT_REASON_MATCH_NOT_FOUND: StringName = &"match_not_found"
const JOIN_REJECT_REASON_ALREADY_JOINED: StringName = &"already_joined"
