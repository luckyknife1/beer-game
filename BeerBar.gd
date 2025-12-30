extends Control

signal beer_redeemed

@export var max_beer := 100.0
var beer := 0.0

@onready var bar: TextureProgressBar = $TextureProgressBar

func _ready() -> void:
	bar.max_value = max_beer
	bar.value = beer

func add_beer(amount: float) -> void:
	beer = clamp(beer + amount, 0.0, max_beer)
	bar.value = beer

func can_redeem() -> bool:
	return beer >= max_beer

func redeem() -> void:
	if not can_redeem():
		return

	beer = 0.0
	bar.value = 0.0
	print("🍺 Beer redeemed")
	emit_signal("beer_redeemed")
