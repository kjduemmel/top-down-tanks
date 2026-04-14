using Godot;
using System;

public partial class EnemyController : Node2D
{
	[Export]
	TankController Tank;
	[Export]
	TurretController Turret;

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
	float TurretSpeed = 5.0f;
	[Export] 
	private Strategy ShootingStrategy = Strategy.ShootAtPlayer;

	private Node2D player;
	
	private float rotationDirection;
	private float rotTimer = 0.0f;
	private float rotLength = 0.0f;

	private int moveDir = 0;
	float moveTimer = 0.0f;
	
	[Export]
	private int ScorePoints = 1;
	private UI ui;
	private Node worldDecoupler;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		AddToGroup("enemyTanksGroup");
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
			return;
		}
		Tank.Hit += OnHit;

		

		//set to the starting rot
		rotationDirection = Tank.GetRotation();
		
		//set Tank values
		Tank.SetMoveSpeed(MoveSpeed);
		Tank.SetTurnSpeed(TurnSpeed);
		Tank.SetBullet(Bullet);
		
		if (Turret == null)
		{
			GD.PrintErr("EnemyController: Turret was not assigned");
			return;
		}
		
		Turret.SetTankRoot(this);
		Turret.SetRotationSpeed(TurretSpeed);
		
		worldDecoupler = GetNode<Node>("/root/WorldDecoupler");
		if (worldDecoupler == null)
		{
			GD.PrintErr("EnemyController: WorldDecoupler was not found");
		}
		Tank.SetWorldDecoupler(worldDecoupler);
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

		//Vector2 playerVisualPos = (Vector2)worldDecoupler.Call("_project", player.Position);
		Turret.SetRotationTarget(player.Position);
		
		reloadTimer -= (float)delta;
		if (reloadTimer <= 0.0f && Turret.IsOnTarget())
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
			
			tarPos = (Vector2)worldDecoupler.Call("_unproject", tarPos);
			
			float slice = Mathf.Pi * 2 / 16;
			float barRot = slice * Mathf.FloorToInt((Turret.GetRotation() + slice * 0.5) / slice) % 16;
			
			Tank.Shoot(tarPos, barRot);
		}
	}
	
	async public void OnHit()
	{
		Die();
	}

	void Die()
	{
		ui.IncreaseScore(ScorePoints);
		QueueFree();
	}
	
}

public enum Strategy
{
	ShootAtPlayer,
	ShootInFrontOfPlayer
}
