using Godot;
using System;

public partial class awBullet : CharacterBody2D
{
	// --- Exported variables (editable in Inspector) ---
	[Export] public int speed = 100;           // Base movement speed of the bullet
	[Export] public float ScaleMultiplier = 5.0f; // How much larger the bullet is compared to default
	[Export] public float SpinSpeed = 5.0f;    // Radians per second rotation after collision

	// --- Internal variables ---
	private int maxCollisions = 3;  // Maximum bounces allowed before bullet is destroyed
	int collisionCount = 0;         // Tracks number of bounces
	private bool startSpinning = false; // Flag to indicate spinning after collision

	// Called when the bullet enters the scene tree
	public override void _Ready()
	{
		// --- Scale the visual sprite ---
		var sprite = GetNode<Sprite2D>("Sprite2D");
		sprite.Scale = new Vector2(ScaleMultiplier, ScaleMultiplier);

		// --- Scale the collision shape ---
		var collisionShape = GetNode<CollisionShape2D>("CollisionShape2D");

		if (collisionShape.Shape is CircleShape2D circle)
		{
			// If it's a circle, scale the radius
			circle.Radius *= ScaleMultiplier;
		}
		else if (collisionShape.Shape is RectangleShape2D rect)
		{
			// If it's a rectangle, scale width and height
			rect.Size *= ScaleMultiplier;
		}
	}

	// Initialize the bullet's position, rotation, and movement direction
	public void Start(Vector2 position, float rotation, Vector2 direction)
	{
		Rotation = rotation;                    // Set initial rotation
		Position = position;                     // Set initial position
		Velocity = direction.Normalized() * speed; // Set velocity based on direction and speed
	}

	// Called every physics frame to move the bullet and handle collisions
	public override void _PhysicsProcess(double delta)
	{
		float d = (float)delta;  // Convert delta to float for calculations

		// --- Move bullet and check for collisions ---
		var collision = MoveAndCollide(Velocity * d);

		if (collision != null)
		{
			// --- Bullet has hit something ---
			++collisionCount; // Increment bounce counter
			Velocity = Velocity.Bounce(collision.GetNormal()) * 1.2f; // Bounce off surface and increaces speed by 20%

			// --- Check if collided object has "OnHit" method  ---
			if (collision.GetCollider().HasMethod("OnHit"))
			{
				collision.GetCollider().Call("OnHit"); // Call OnHit on the object
				QueueFree(); // Destroy bullet
				return; // Exit PhysicsProcess
			}
			else if (collisionCount >= maxCollisions)
			{
				// Destroy bullet if max bounces reached
				QueueFree();
				return;
			}

			// Start spinning after first collision
			startSpinning = true;
			
			// --- Double spin speed on each collision ---
			SpinSpeed *= 2;
			
		}

		// --- Handle rotation ---
		if (startSpinning)
		{
			// After first collision, bullet spins continuously
			Rotation += SpinSpeed * d;
		}
		else
		{
			// Before collision, rotate bullet to match movement direction
			Rotation = Velocity.Angle();
		}
	}

	// Allows external scripts to manually destroy the bullet
	public void Hit()
	{
		GD.Print("Bullet hit"); // Debug message
		QueueFree(); // Destroy bullet
	}

	// Automatically destroy the bullet if it leaves the visible screen area
	private void OnVisibilityNotifier2DScreenExited()
	{
		QueueFree();
	}

	// Activates bullet collision (if you are using delayed activation)
	void OnActivateTimer()
	{
		GetNode<CollisionShape2D>("CollisionShape2D").Disabled = false;
	}
}
