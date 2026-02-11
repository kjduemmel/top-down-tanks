using Godot;
using System;

public partial class awBullet : CharacterBody2D
{
	[Export]
	public int speed = 100;
	public Vector2 direction = Vector2.Zero;
	

	public void Start(Vector2 position, float rotation, Vector2 direction)
	{
		Rotation = rotation;
		Position = position;
		this.direction = direction;
		//Velocity = new Vector2(speed, 0).Rotated(Rotation);
		Velocity = direction * speed;
	}

	public override void _PhysicsProcess(double delta)
	{
		var collision = MoveAndCollide(Velocity * (float)delta);
		if (collision != null)
		{
			Velocity = Velocity.Bounce(collision.GetNormal());
			if (collision.GetCollider().HasMethod("Hit"))
			{
				collision.GetCollider().Call("Hit");
			}
		}
	}

	private void OnVisibilityNotifier2DScreenExited()
	{
		// Deletes the bullet when it exits the screen.
		QueueFree();
	}
}
