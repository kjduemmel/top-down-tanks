using Godot;
using System;

public partial class TankController : CharacterBody2D
{
	float moveSpeed = 300.0f;
	float turnSpeed = 4.5f;
	PackedScene Bullet;
	private PackedScene Item;

	private float moveDirection;
	float rotationTarget = 0.0f;

	private float rotLockout = 1.0f;
	float rotLockTimer = 0.0f;
	int forcedRotation = 0;
	
	private Node worldDecoupler;
	
	[Signal]
	public delegate void HitEventHandler();
	
	
	public override void _Process(double delta)
	{
		base._Process(delta);
	}

	public override void _PhysicsProcess(double delta)
	{
		Vector2 velocity = Velocity;
		if (moveDirection != 0.0)
		{
			Vector2 dir = Vector2.FromAngle(Rotation);
			velocity = dir * moveDirection * moveSpeed;
		}
		else
		{
			//probably need to reduce these proportionally?
			velocity.X = Mathf.MoveToward(Velocity.X, 0, moveSpeed);
			velocity.Y = Mathf.MoveToward(Velocity.Y, 0, moveSpeed);
		}
		//Velocity's Properties cant be directly set in c#, must reassign back
		Velocity = velocity;
		
		var collision = MoveAndCollide(velocity * (float)delta);
		rotLockTimer -= (float)delta;
		
		if (collision != null)
		{
			//override rotation if against another collider
			float angle = collision.GetNormal().AngleTo(Velocity);
			//GD.Print(angle);
			float rotationDeadZone = 0.3f;
			if (rotLockTimer <= 0.0f && Mathf.Abs(angle) < Mathf.Pi - rotationDeadZone)
			{
				rotLockTimer = rotLockout;
				if (angle > 0)// && angle < Mathf.Pi - rotationDeadZone)
				{
					rotationTarget = -1;
					forcedRotation = -1;
				}
				else if (angle < 0)// && angle > -Mathf.Pi - rotationDeadZone)
				{
					rotationTarget = 1;
					forcedRotation = 1;
				}
			}
			else
			{
				if(Mathf.Abs(angle) < Mathf.Pi - rotationDeadZone)
					rotationTarget = forcedRotation;
			}
		}
		
		if (rotationTarget > 0.0f)
		{
			float rotation = Rotation + turnSpeed * (float)delta;
			Rotation = rotation;
		}
		else if (rotationTarget < 0.0f)
		{
			float rotation = Rotation - turnSpeed * (float)delta;
			Rotation = rotation;
		}
		
		//MoveAndSlide();
	}

	public void Shoot(Vector2 targetPos, float turretRot)
	{
		if (Bullet == null)
			return;
		
		var b = (Bullet)Bullet.Instantiate();
		
		Vector2 barrelPos = (Position + new Vector2(Mathf.Cos(turretRot), Mathf.Sin(turretRot)).Normalized() * 48);
		
		Vector2 direction = (targetPos - barrelPos).Normalized();
		
		//might be - 90 or 0 if graphic assumptions change
		float rotation = direction.Angle();// + Mathf.Pi/2;
		Vector2 spawnPos = (Vector2)worldDecoupler.Call("_project", barrelPos);
		
		//b.Start(spawnPos + direction.Normalized() * 30, rotation, direction.Normalized());
		b.Start(spawnPos, rotation, direction.Normalized());
		
		//GetTree().Root.AddChild(b); // <- This breaks scene reloads
		
		GetParent().GetParent().AddChild(b);
	}
	
	public void UseItem(Vector2 position, float rotation)
	{
		if(Item == null)
			return;
		
		var it = (AbilityItem)Item.Instantiate();
		it.Start(position, rotation);
		
		GetTree().GetCurrentScene().AddChild(it);
	}
	
	public void OnHit()
	{
		EmitSignal(SignalName.Hit);
	}

	public float GetMoveSpeed()
	{
		return moveSpeed;
	}

	public void SetMoveSpeed(float speed)
	{
		moveSpeed = speed;
	}
	
	public float GetTurnSpeed()
	{
		return turnSpeed;
	}

	public void SetTurnSpeed(float speed)
	{
		turnSpeed = speed;
	}

	public void SetMoveDirection(float moveDir)
	{
		moveDirection = moveDir;
	}
	
	public float GetRotation()
	{
		return Rotation;
	}
	
	public void SetRotationTarget(float rotTarget)
	{
		//if(rotLockTimer <= 0.0f)
			rotationTarget = rotTarget;
	}
	
	public PackedScene GetBullet()
	{
		return Bullet;
	}

	public void SetBullet(PackedScene bullet)
	{
		Bullet = bullet;
	}

	public PackedScene GetItem()
	{
		return Item;
	}
	
	public void SetItem(PackedScene item)
	{
		Item = item;
	}

	public void SetWorldDecoupler(Node worldDecoupler)
	{
		this.worldDecoupler = worldDecoupler;
	}
	
}
