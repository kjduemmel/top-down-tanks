using Godot;
using System;

public partial class EnemyController : Node2D
{
	[Export]
	TankController Tank;

	[Export]
	private float MoveSpeed = 300.0f;
	[Export]
	private float TurnSpeed = 3.0f;
	
	[Export]
	PackedScene Bullet;

	[Export] 
	private Strategy ShootingStrategy = Strategy.ShootAtPlayer;
	
	[Export]
	int ReloadTime = 2;

	private Node2D player;
	
	private float rotationTarget;
	private float timeRotDecision = 1;
	private float rotTimer = 0.0f;
	
	private float reloadTimer = 0.0f;
	private UI ui;

	private bool shouldMove = false;
	private float timeMoveDecision = 1;
	float moveTimer = 0.0f;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		reloadTimer = ReloadTime;
		
		ui = GetTree().GetCurrentScene().GetNode<UI>("UI");
		if (ui == null)
		{
			GD.PrintErr("EnemyController: UI was not found");
		}

		player = GetNode<Node2D>("%PlayerTank");
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
		rotationTarget = Tank.GetRotation();
		
		//set Tank values
		Tank.SetMoveSpeed(MoveSpeed);
		Tank.SetTurnSpeed(TurnSpeed);
		Tank.SetBullet(Bullet);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		rotTimer -= (float)delta;
		if (rotTimer <= 0.0f)
		{
			rotTimer = timeRotDecision;
			rotationTarget = (int)(GD.Randi() % 3 - 1);
		}
		Tank.SetRotationTarget(rotationTarget);
		
		moveTimer -= (float)delta;
		if (moveTimer <= 0.0f)
		{
			float chance = GD.Randf();
			if (chance < 0.33f)
			{
				shouldMove = true;
			}
			else
			{
				shouldMove = false;
			}
		}

		if (shouldMove)
		{
			Tank.SetMoveDirection(1);
		}

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