using Godot;
using System;

public partial class EnemyController : Node2D
{
	[Export]
	TankController Tank;

	[Export]
	private float MoveSpeed = 100.0f;
	[Export]
	private float TimeBetweenMovement = 1.0f;
	[Export]
	private float TurnSpeed = 2.0f;
	[Export]
	private float TimeBetweenRotations = 1.0f;
	
	[Export]
	PackedScene Bullet;
	[Export]
	float ReloadTime = 4.0f;
	private float reloadTimer = 0.0f;
	[Export] 
	private Strategy ShootingStrategy = Strategy.ShootAtPlayer;

	private Node2D player;
	
	private float rotationDirection;
	private float rotTimer = 0.0f;
	private float rotLength = 0.0f;

	private int moveDir = 0;
	float moveTimer = 0.0f;
	
	private UI ui;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		reloadTimer = ReloadTime;
		
		ui = GetTree().GetCurrentScene().GetNode<UI>("UI");
		if (ui == null)
		{
			GD.PrintErr("EnemyController: UI was not found");
		}

		player = GetNode<Node2D>("%Tank");
		if (player == null)
		{
			GD.PrintErr("EnemyController: Player was not found");
		}
		
		if (Tank == null)
		{
			GD.PrintErr("EnemyController: Tank was not assigned");
		}
		Tank.Hit += OnHit;

		//set to the starting rot
		rotationDirection = Tank.GetRotation();
		
		//set Tank values
		Tank.SetMoveSpeed(MoveSpeed);
		Tank.SetTurnSpeed(TurnSpeed);
		Tank.SetBullet(Bullet);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		rotTimer -= (float)delta;
		if (rotTimer <= rotLength)
		{
			Tank.SetRotationTarget(0);
		}
		if (rotTimer <= 0.0f)
		{
			rotTimer = TimeBetweenRotations;
			rotationDirection = (int)(GD.Randi() % 3 - 1);
			Tank.SetRotationTarget(rotationDirection);
			rotLength = GD.Randf() * TimeBetweenRotations;
		}
		
		moveTimer -= (float)delta;
		if (moveTimer <= 0.0f)
		{
			float chance = GD.Randf();
			if (chance < 0.15f)
			{
				moveDir = 0;
			}
			else if (chance < 0.33f)
			{
				moveDir = 0;
			}
			else
			{
				moveDir = 1;
			}
		}
		
		Tank.SetMoveDirection(moveDir);

		reloadTimer -= (float)delta;
		if (reloadTimer <= 0.0f)
		{
			reloadTimer = ReloadTime;

			Vector2 tarPos = new Vector2();
			if (ShootingStrategy == Strategy.ShootInFrontOfPlayer)
			{
				int fowardAmount = 50 + (int)(GD.Randi() % 5) * 50;
				Vector2 forwardVector = new Vector2(MathF.Cos(player.GlobalRotation) * fowardAmount, 
													MathF.Sin(player.GlobalRotation) * fowardAmount);
				
				tarPos = player.GlobalPosition + forwardVector;
			}
			else
			{
				tarPos = player.GlobalPosition;
			}
			Tank.Shoot(tarPos);
		}
	}
	
	async public void OnHit()
	{
		//ui.IncreaseScore();
		QueueFree();
	}
}

public enum Strategy
{
	ShootAtPlayer,
	ShootInFrontOfPlayer
}