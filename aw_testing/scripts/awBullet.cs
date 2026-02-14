using Godot;
using System;

public partial class awBullet : CharacterBody2D
{
	[Export]
	public int speed = 100;
	

	public void Start(Vector2 position, float rotation, Vector2 direction)
	{
		Rotation = rotation;
		Position = position;
		//Velocity = new Vector2(speed, 0).Rotated(Rotation);
		Velocity = direction * speed;
	}

	public override void _PhysicsProcess(double delta)
	{
		var collision = MoveAndCollide(Velocity * (float)delta);
		if (collision != null)
		{
			Velocity = Velocity.Bounce(collision.GetNormal());
			Rotation = Velocity.Angle() + Mathf.Pi/2;
			if (collision.GetCollider().HasMethod("Hit"))
			{
				collision.GetCollider().Call("Hit");
			}
		}
	}
	
	public void Hit()
	{
		GD.Print("Bullet hit");
		QueueFree();
	}

	private void OnVisibilityNotifier2DScreenExited()
	{
		// Deletes the bullet when it exits the screen.
		QueueFree();
	}
}
