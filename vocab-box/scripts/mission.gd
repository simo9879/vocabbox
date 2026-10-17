extends RefCounted
signal changed
# Ordered states: city, worker, bananas, customer, checkout, results.
var finalized: bool = false
var stage: int = 0
var bananas: int = 0
var best: Dictionary = {"worker": 0, "customer": 0, "cashier": 0}
var failures: Dictionary = {"worker": 0, "customer": 0, "cashier": 0}
func reset() -> void:
	finalized = false
	stage = 0
	bananas = 0
	best = {"worker": 0, "customer": 0, "cashier": 0}
	failures = {"worker": 0, "customer": 0, "cashier": 0}
	changed.emit()
func enter() -> void:
	if stage == 0:
		stage = 1
		changed.emit()
func collect() -> bool:
	if stage != 2 or bananas != 0: return false
	bananas = 1
	stage = 3
	changed.emit()
	return true
func respond(id: String, quality: int) -> bool:
	var required: int = {"worker": 1, "customer": 3, "cashier": 4}.get(id, 99)
	if stage < required or finalized or not best.has(id): return false
	if quality < 1:
		failures[id] += 1
		return false
	best[id] = maxi(best[id], quality)
	if stage == required: stage += 1
	changed.emit()
	return true
func stars() -> int:
	if stage != 5: return 0
	var strong: int = best.values().count(2)
	return 3 if strong == 3 else (2 if strong >= 2 else 1)
