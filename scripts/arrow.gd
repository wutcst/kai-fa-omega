extends Area2D

@export var speed: float = 600.0
@export var damage: int = 12

var dir: Vector2 = Vector2.RIGHT
@onready var visibility_notifier = $VisibleOnScreenNotifier2D

func _ready():
	body_entered.connect(_hit)
	visibility_notifier.screen_exited.connect(queue_free)

func _physics_process(delta):
	position += dir * speed * delta
	rotation = dir.angle()

func _hit(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
