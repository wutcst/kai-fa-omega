extends Area2D

@export var speed: float = 600.0
@export var damage: int = 12

var dir: Vector2 = Vector2.RIGHT
@onready var visibility_notifier = $VisibleOnScreenNotifier2D

func _ready():
	body_entered.connect(_hit)
<<<<<<< HEAD
	visibility_notifier.screen_exited.connect(queue_free)

func _physics_process(delta):
	position += dir * speed * delta
=======
	if visibility_notifier:
		visibility_notifier.screen_exited.connect(queue_free)

func _physics_process(_delta):
	position += dir * speed * _delta
>>>>>>> zlfui
	rotation = dir.angle()

func _hit(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
