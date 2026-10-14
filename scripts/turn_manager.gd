class_name TurnManager extends Node
signal phase_changed(phase: int, turn: int)
enum Phase { PLAYER, ENEMY }
var phase = Phase.PLAYER
var turn = 1

func start_player_phase() -> void:
	phase = Phase.PLAYER; phase_changed.emit(phase, turn)

func end_player_phase() -> void:
	phase = Phase.ENEMY; phase_changed.emit(phase, turn)

func end_enemy_phase() -> void:
	turn += 1; start_player_phase()
