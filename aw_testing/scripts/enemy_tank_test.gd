extends Node

@export var tank: Node = null
@export var reloadTime: int = 2
var reloadTimer = reloadTime

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Register the hit function, will be called when Controller OnHit is triggered
	tank.Hit.connect(on_hit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#determine a direction and pass to the tank controller to move
	var dir = Vector2i(randi() % 3 - 1, randi() % 3 - 1)
	tank.SetDirection(dir)
	
	reloadTimer -= delta
	if(reloadTimer <= 0):
		reloadTimer = reloadTime
		#Get Postion of target and tell tank controller where to shoot
		var tarPos = get_node("%PlayerTank/TankController").position
		tank.Shoot(tarPos)
		

#what to do when hit by bullet
func on_hit() -> void:
	print("HIT!")
