using Godot;
using System;

public partial class PlayerController : Node
{
	[Export]
	TankController Tank;
	
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
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		Tank.SetDirection(Input.GetVector("move_left", "move_right", 
			"move_up", "move_down"));
		
		if (Input.IsActionJustPressed("shoot"))
		{
			Vector2 mosPos = Tank.GetGlobalMousePosition();
			Vector2 direction = mosPos - Tank.Position;
			
			Tank.Shoot(direction);
		}
	}
	
	async public void OnHit()
	{
		ui.ShowMessage("You Died");
		await ToSignal(GetTree().CreateTimer(1.0), SceneTreeTimer.SignalName.Timeout);
		GetTree().ReloadCurrentScene();
	}
}
