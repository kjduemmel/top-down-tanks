extends Node

@export var tank: Node = null
@export var moveSpeed: float = 300.0
@export var turnSpeed: float = 3.0
@export var bullet: PackedScene = null
@export var reloadTime: int = 2
var reloadTimer = reloadTime
var moveTar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Register the hit function, will be called when Controller OnHit is triggered
	tank.Hit.connect(on_hit)
	tank.SetMoveSpeed(moveSpeed)
	tank.SetTurnSpeed(turnSpeed)
	tank.SetBullet(bullet)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#determine a direction and pass rotation and direction the tank controller to move
	moveTar = get_node("%Tank").position - tank.position
	var rotationToTar = moveTar.normalized().angle()
	var rotTar = tank.rotation - rotationToTar
	
	tank.SetRotationTarget(-rotTar/abs(rotTar))
	
	tank.SetMoveDirection(1)
	
	reloadTimer -= delta
	if(reloadTimer <= 0):
		reloadTimer = reloadTime
		#Get Postion of target and tell tank controller where to shoot
		var tarPos = get_node("%Tank").position
		tank.Shoot(tarPos)
		

#what to do when hit by bullet
func on_hit() -> void:
	print("HIT!")
