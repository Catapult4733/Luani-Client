# client_and_studio/scenes/items/pickable_item.gd
extends Area3D

## 3D World Pickable Item with float animation and proximity pickup detection

@export var item_data: Dictionary = {
	"id": "apple",
	"name": "🍎 Apple",
	"type": "item",
	"icon": "🍎",
	"count": 1,
	"scene": ""
}

var float_time: float = 0.0
var base_y: float = 0.0

@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)
	if label_3d:
		label_3d.text = item_data.get("name", "Item")

func _process(delta: float) -> void:
	float_time += delta * 2.5
	position.y = base_y + sin(float_time) * 0.15
	rotate_y(delta * 1.5)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("pickup_item"):
		body.call("pickup_item", item_data)
		queue_free()
