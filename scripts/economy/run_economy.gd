class_name RunEconomy
extends Node

signal buying_power_changed(value: int)
signal purchase_executed(transaction: Dictionary)

const MarketPricing := preload("res://scripts/market/market_pricing.gd")

var buying_power: int = 0
var starting_buying_power: int = 0
var buying_power_earned: int = 0
var buying_power_spent: int = 0
var _market_session: Node
var _next_transaction_id: int = 1


func setup(starting_value: int, market_session: Node) -> void:
	_market_session = market_session
	reset(starting_value)


func reset(starting_value: int) -> void:
	starting_buying_power = maxi(starting_value, 0)
	buying_power = starting_buying_power
	buying_power_earned = 0
	buying_power_spent = 0
	_next_transaction_id = 1
	buying_power_changed.emit(buying_power)


func add_buying_power(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	buying_power += amount
	buying_power_earned += amount
	buying_power_changed.emit(buying_power)


func can_afford(amount: int) -> bool:
	return amount >= 0 and buying_power >= amount


func spend_buying_power(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	buying_power -= amount
	buying_power_spent += amount
	buying_power_changed.emit(buying_power)
	return true


func quote_tower(definition: Resource) -> int:
	if _market_session != null and _market_session.has_method("quote_tower"):
		return int(_market_session.call("quote_tower", definition))
	return int(definition.get("cost")) if definition != null else 0


func quote_upgrade(definition: Resource) -> int:
	if _market_session != null and _market_session.has_method("quote_upgrade"):
		return int(_market_session.call("quote_upgrade", definition))
	return int(definition.get("upgrade_cost")) if definition != null else 0


func execute_tower_purchase(
	definition: Resource,
	runtime_id: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var quote := quote_tower(definition)
	return _execute("tower", definition, runtime_id, quote, metadata)


func execute_upgrade_purchase(
	definition: Resource,
	runtime_id: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var quote := quote_upgrade(definition)
	return _execute("upgrade", definition, runtime_id, quote, metadata)


func rollback_transaction(transaction: Dictionary) -> void:
	if transaction.is_empty() or bool(transaction.get("rolled_back", false)):
		return
	var amount := int(transaction.get("executed_price", 0))
	if amount <= 0:
		return
	buying_power += amount
	buying_power_spent = maxi(buying_power_spent - amount, 0)
	buying_power_changed.emit(buying_power)


func commit_transaction(transaction: Dictionary) -> void:
	if transaction.is_empty() or bool(transaction.get("committed", false)):
		return
	var committed := transaction.duplicate(true)
	committed["committed"] = true
	purchase_executed.emit(committed)


func _execute(
	kind: String,
	definition: Resource,
	runtime_id: String,
	locked_quote: int,
	metadata: Dictionary
) -> Dictionary:
	if definition == null or locked_quote <= 0 or not can_afford(locked_quote):
		return {}
	var transaction := metadata.duplicate(true)
	transaction.merge({
		"transaction_id": "BUY-%06d" % _next_transaction_id,
		"kind": kind,
		"tower_id": str(definition.get("tower_id")),
		"runtime_id": runtime_id,
		"base_price": int(
			definition.get("cost") if kind == "tower" else definition.get("upgrade_cost")
		),
		"executed_price": locked_quote,
	}, true)
	_next_transaction_id += 1
	buying_power -= locked_quote
	buying_power_spent += locked_quote
	buying_power_changed.emit(buying_power)
	return transaction


func capture() -> Dictionary:
	return {
		"buying_power": buying_power,
		"starting_buying_power": starting_buying_power,
		"buying_power_earned": buying_power_earned,
		"buying_power_spent": buying_power_spent,
		"next_transaction_id": _next_transaction_id,
	}


func restore(data: Dictionary, legacy_starting: int = 0) -> void:
	starting_buying_power = int(data.get(
		"starting_buying_power",
		data.get("starting_gold", legacy_starting)
	))
	buying_power = int(data.get("buying_power", data.get("gold", starting_buying_power)))
	buying_power_earned = int(data.get("buying_power_earned", data.get("gold_earned", 0)))
	buying_power_spent = int(data.get("buying_power_spent", data.get("gold_spent", 0)))
	_next_transaction_id = maxi(int(data.get("next_transaction_id", 1)), 1)
	buying_power_changed.emit(buying_power)
