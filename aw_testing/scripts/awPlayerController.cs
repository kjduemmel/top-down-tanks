using Godot;
using System;

public partial class awPlayerController : CharacterBody2D
{
	public const float Speed = 300.0f;
	[Export]
	public PackedScene bullet;

	public override void _Process(double delta)
	{
		base._Process(delta);

		if (Input.IsActionJustPressed("shoot"))
		{
			Shoot();
		}
	}

	public override void _PhysicsProcess(double delta)
	{
		Vector2 velocity = Velocity;

		// Get the input direction and handle the movement/deceleration.
		// As good practice, you should replace UI actions with custom gameplay actions.
		Vector2 direction = Input.GetVector("move_left", "move_right", "move_up", "move_down");
		if (direction != Vector2.Zero)
		{
			velocity = direction * Speed;
		}
		else
		{
			velocity.X = Mathf.MoveToward(Velocity.X, 0, Speed);
			velocity.Y = Mathf.MoveToward(Velocity.Y, 0, Speed);
		}

		Velocity = velocity;
		//var collision = MoveAndCollide(velocity * (float)delta);
		
		MoveAndSlide();
	}

	public void Shoot()
	{
		var b = (awBullet)bullet.Instantiate();
		Vector2 mosPos = GetGlobalMousePosition();
		Vector2 direction = mosPos - Position;
		
		b.Start(Position + direction.Normalized() * 20, Rotation, direction.Normalized());
		GetTree().Root.AddChild(b);
	}
	
}
