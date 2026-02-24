using Godot;
using System;

public partial class PlayerController : Node2D
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
	float ReloadTime = 1.5f;
	private float reloadTimer = 0.0f;
	
	private float rotationDirection;
	private UI ui;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		if (Tank == null)
		{
			GD.PrintErr("PlayerController: Tank was not assigned");
		}
		Tank.Hit += OnHit;
		
		//find scene UI parent
		ui = GetTree().GetCurrentScene().GetNode<UI>("UI");
		if (ui == null)
		{
			GD.PrintErr("PlayerController: UI was not found");
		}

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
		rotationDirection = Input.GetAxis("rotate_left", "rotate_right");
		Tank.SetRotationTarget(rotationDirection);

		float moveDir = Input.GetAxis("move_backward", "move_forward");
		Tank.SetMoveDirection(moveDir);
		
		reloadTimer -= (float)delta;
		if (Input.IsActionJustPressed("shoot") && reloadTimer <= 0.0f)
		{
			reloadTimer = ReloadTime;
			Vector2 mousePos = Tank.GetGlobalMousePosition();
			
			Tank.Shoot(mousePos);
		}
	}
	
	async public void OnHit()
	{
		ui.ShowMessage("You Died");
		await ToSignal(GetTree().CreateTimer(1.0), SceneTreeTimer.SignalName.Timeout);
		GetTree().ReloadCurrentScene();
	}
}
