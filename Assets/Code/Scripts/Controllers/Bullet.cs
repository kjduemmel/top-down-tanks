using Godot;
using System;

public partial class Bullet : Node2D
{
	// --- Exported variables (editable in Inspector) ---
	[Export] public int speed = 150;             // Base movement speed of the bullet
	[Export] public float ScaleMultiplier = 5.0f; // How much larger the bullet is compared to default

	private CharacterBody2D body;
	
	// --- Internal variables ---
	private int maxCollisions = 3;  // Maximum bounces allowed before bullet is destroyed
	int collisionCount = 0;         // Tracks number of bounces

	// Called when the bullet enters the scene tree
	public override void _Ready()
	{
		// --- Scale the visual sprite ---
		var sprite = GetNode<Sprite2D>("Visual/Sprite2D");
		sprite.Scale = new Vector2(ScaleMultiplier, ScaleMultiplier);

		// --- Scale the collision shape ---
		var collisionShape = GetNode<CollisionShape2D>("Physics/CollisionShape2D");
			
		if (collisionShape.Shape is CircleShape2D circle)
		{
			circle.Radius *= ScaleMultiplier; // Scale circle radius
		}
		else if (collisionShape.Shape is RectangleShape2D rect)
		{
			rect.Size *= ScaleMultiplier; // Scale rectangle width & height
		}
	}

	// Initialize the bullet's position, rotation, and movement direction
	public void Start(Vector2 position, float rotation, Vector2 direction)
	{
		body = GetNode<CharacterBody2D>("Physics");
		if (body == null)
		{
			GD.PrintErr("Bullet Physics not found");
		}
		
		Rotation = rotation;                       // Set initial rotation
		Position = position;                        // Set initial position
		
		
		body.Velocity = direction.Normalized() * speed;  // Set velocity based on direction and speed
	}

	// Called every physics frame to move the bullet and handle collisions
	public override void _PhysicsProcess(double delta)
	{
		float d = (float)delta;

		// --- Move bullet and check for collisions ---
		var collision = body.MoveAndCollide(body.Velocity * d);

		if (collision != null )
		{
			
			// --- Bullet has hit something ---
			++collisionCount; // Increment bounce counter
			body.Velocity = body.Velocity.Bounce(collision.GetNormal()) * 1.12f; // Bounce and speed up

			// --- Check if collided object has "OnHit" method ---
			if (collision.GetCollider().HasMethod("OnHit"))
			{
				collision.GetCollider().Call("OnHit"); // Call OnHit on the object
				QueueFree(); // Destroy bullet
				return;
			}
			else if (collisionCount >= maxCollisions)
			{
				QueueFree(); // Destroy bullet if max bounces reached
				return;
			}
		}

		// Rotate bullet to match current movement direction 
		body.Rotation = body.Velocity.Angle();
	}

	// Allows external scripts to manually destroy the bullet
	public void Hit()
	{
		GD.Print("Bullet hit");
		QueueFree();
	}

	// Automatically destroy the bullet if it leaves the visible screen area
	private void OnVisibilityNotifier2DScreenExited()
	{
		QueueFree();
	}

	// Activates bullet collision 
	void OnActivateTimer()
	{
		GetNode<CollisionShape2D>("Physics/CollisionShape2D").Disabled = false;
	}
}
