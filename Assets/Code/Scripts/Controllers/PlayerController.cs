using Godot;
using System;

// ReSharper disable CheckNamespace
// ReSharper disable InconsistentNaming
// ReSharper disable ArrangeTypeMemberModifiers

public partial class PlayerController : Node2D
{
	[Export]
	TankController Tank;
	[Export]
	TurretController Turret;

	[Export]
	private float MoveSpeed = 300.0f;
	[Export]
	private float TurnSpeed = 3.0f;
	[Export]
	PackedScene Bullet;
	[Export]
	float ReloadTime = 1.5f;
	private float reloadTimer = 0.0f;
	
	[Export]
	float TurretSpeed = 5.0f;
	
	[Export]
	PackedScene Item;
	[Export]
	int ItemUses = 5;
	
	private float rotationDirection;
	private UI ui;
	private Node worldDecoupler;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		if (Tank == null)
		{
			GD.PrintErr("PlayerController: Tank was not assigned");
			return;
		}
		Tank.Hit += OnHit;
		
		if (Bullet == null)
		{
			GD.PrintErr("PlayerController: Bullet was not assigned");
		}

		if (Item == null)
		{
			GD.PrintErr("PlayerController: Item was not assigned");
		}
		
		//find scene UI parent
		ui = GetTree().GetCurrentScene().GetNode<UI>("UI");
		if (ui == null)
		{
			GD.PrintErr("PlayerController: UI was not found");
		}
		
		worldDecoupler = GetNode<Node>("/root/WorldDecoupler");
		if (worldDecoupler == null)
		{
			GD.PrintErr("PlayerController: WorldDecoupler was not found");
		}

		//set to the starting rot
		rotationDirection = Tank.GetRotation();
		
		//set Tank values
		Tank.SetMoveSpeed(MoveSpeed);
		Tank.SetTurnSpeed(TurnSpeed);
		Tank.SetBullet(Bullet);
		Tank.SetItem(Item);
		Tank.SetWorldDecoupler(worldDecoupler);

		if (Turret == null)
		{
			GD.PrintErr("PlayerController: Turret was not assigned");
			return;
		}
		
		Turret.SetTankRoot(this);
		Turret.SetRotationSpeed(TurretSpeed);
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		rotationDirection = Input.GetAxis("rotate_left", "rotate_right");
		Tank.SetRotationTarget(rotationDirection);

		float moveDir = Input.GetAxis("move_backward", "move_forward");
		Tank.SetMoveDirection(moveDir);
		
		//mouse pos for turret rotation and shooting
		Vector2 mousePos = Tank.GetGlobalMousePosition();
		
		Turret.SetRotationTarget(mousePos);
		
		reloadTimer -= (float)delta;
		if (Input.IsActionJustPressed("shoot") && reloadTimer <= 0.0f && Turret.IsOnTarget())
		{
			reloadTimer = ReloadTime;
			
			//translate from visual to game position
			if(worldDecoupler != null)
				mousePos = (Vector2)worldDecoupler.Call("_unproject", mousePos);

			float slice = Mathf.Pi * 2 / 16;
			float barRot = slice * Mathf.FloorToInt((Turret.GetRotation() + slice * 0.5) / slice) % 16;
			
			Tank.Shoot(mousePos, barRot);
		}

		if (Input.IsActionJustPressed("use_item") && ItemUses > 0)
		{
			--ItemUses;
			float amountBehind = 75;
			Vector2 behind = Tank.Position - new Vector2((float)Math.Cos(GlobalRotation) * amountBehind,
													(float)Math.Sin(GlobalRotation) * amountBehind);
			Tank.UseItem(behind, GlobalRotation);
		}
		
	}
	
	private async void OnHit()
	{
		ui.ShowMessage("You Died");
		await ToSignal(GetTree().CreateTimer(1.0), SceneTreeTimer.SignalName.Timeout);
		GetTree().ReloadCurrentScene();
	}
}
