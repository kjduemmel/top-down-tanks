using Godot;
using System;

public partial class PlayerController : Node
{
	[Export]
	TankController Tank;

	[Export]
	private float MoveSpeed = 300.0f;
	[Export]
	private float TurnSpeed = 3.0f;
	[Export]
	PackedScene Bullet;
	
	private float rotationTarget;
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
		rotationTarget = Tank.GetRotation();
		
		//set Tank values
		Tank.SetMoveSpeed(MoveSpeed);
		Tank.SetTurnSpeed(TurnSpeed);
		Tank.SetBullet(Bullet);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		rotationTarget = Input.GetAxis("rotate_left", "rotate_right");
		Tank.SetRotationTarget(rotationTarget);

		float moveDir = Input.GetAxis("move_backward", "move_forward");
		Tank.SetMoveDirection(moveDir);
		
		if (Input.IsActionJustPressed("shoot"))
		{
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
