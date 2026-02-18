using Godot;
using System;

public partial class TankController : CharacterBody2D
{
    float moveSpeed = 300.0f;
    float turnSpeed = 3.0f;
    PackedScene Bullet;

    private float moveDirection;
    float rotationTarget = 0.0f;
    
    [Signal]
    public delegate void HitEventHandler();
    
    
    public override void _Process(double delta)
    {
        base._Process(delta);
    }

    public override void _PhysicsProcess(double delta)
    {
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
        
        //var collision = MoveAndCollide(velocity * (float)delta);
        MoveAndSlide();
    }

    public void Shoot(Vector2 targetPos)
    {
        if (Bullet == null)
            return;
        
        var b = (awBullet)Bullet.Instantiate();
        
        Vector2 direction = (targetPos - Position).Normalized();
        
        //might be - 90 or 0 if graphic assumptions change
		float rotation = direction.Angle() + Mathf.Pi/2;
        
        b.Start(Position + direction.Normalized() * 20, rotation, direction.Normalized());
        
        //GetTree().Root.AddChild(b); // <- This breaks scene reloads
        
        GetTree().GetCurrentScene().AddChild(b);
    }
    
    public void OnHit()
    {
        EmitSignal(SignalName.Hit);
    }
    
    public void UseItem()
    {
        
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
}