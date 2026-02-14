using Godot;
using System;

public partial class TankController : CharacterBody2D
{
    [Export]
    float Speed = 300.0f;
    [Export]
    PackedScene Bullet;
    
    Vector2 Direction = Vector2.Zero;

    public override void _Process(double delta)
    {
        base._Process(delta);
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 velocity = Velocity;

        // Handle the movement/deceleration.
        if (Direction != Vector2.Zero)
        {
            velocity = Direction * Speed;
        }
        else
        {
            velocity.X = Mathf.MoveToward(Velocity.X, 0, Speed);
            velocity.Y = Mathf.MoveToward(Velocity.Y, 0, Speed);
        }
        //Velocities Properties cant be directly set in c#, must reassign back
        Velocity = velocity;
        
        
        //var collision = MoveAndCollide(velocity * (float)delta);
        MoveAndSlide();
    }

    public void Shoot(Vector2 direction)
    {
        var b = (awBullet)Bullet.Instantiate();
        
        //might be - 90
		float rotation = direction.Angle() + Mathf.Pi/2;
        
        b.Start(Position + direction.Normalized() * 20, rotation, direction.Normalized());
        //GetTree().Root.AddChild(b);
        GetTree().GetCurrentScene().AddChild(b);
    }

    public void Hit()
    {
        GD.Print("You Died");
        GetTree().ReloadCurrentScene();
    }
    
    public void UseItem()
    {
        
    }

    public float GetSpeed()
    {
        return Speed;
    }

    public void SetSpeed(float speed)
    {
        Speed = speed;
    }

    public PackedScene GetBullet()
    {
        return Bullet;
    }

    public void SetBullet(PackedScene bullet)
    {
        Bullet = bullet;
    }

    public void SetDirection(Vector2 direction)
    {
        Direction = direction;
    }
    
}