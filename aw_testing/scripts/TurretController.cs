using Godot;
using System;

public partial class TurretController : Node2D
{
    public Node2D TankRoot;

    private float rotationSpeed = 5.0f;
    private Vector2 rotationTarget;
    bool onTarget = false;

    public override void _Process(double delta)
    {
        if (TankRoot == null)
        {
            GD.PrintErr("TurretController: TankRoot was not set by tank");
            return;
        }

        Position = TankRoot.GlobalPosition;

        float rotation = GlobalRotation;
        float rotTargetAngle = (rotationTarget - Position).Angle();
        
        int rotDir = 1;
        //If we would rotate over 180 degrees, the other way is better
        if (Mathf.Abs(rotTargetAngle - rotation) > Mathf.Pi)
            rotDir = -1;

        if (rotation < rotTargetAngle - 0.2f)
        {
            rotation += rotationSpeed * (float)delta * rotDir;
            onTarget = false;
        }
        else if (rotation > rotTargetAngle + 0.2f)
        {
            rotation -= rotationSpeed * (float)delta * rotDir;
            onTarget = false;
        }
        else
        {
            onTarget = true;
        }
        
        GlobalRotation = rotation;
        
    }

    public bool IsOnTarget()
    {
        return onTarget;
    }
    
    public void SetRotationSpeed(float speed)
    {
        rotationSpeed = speed;
    }

    public float GetRotationSpeed()
    {
        return rotationSpeed;
    }
    
    public void SetRotationTarget(Vector2 target)
    {
        rotationTarget = target;
    }

    public Vector2 GetRotationTarget()
    {
        return rotationTarget;
    }
    
    public void SetTankRoot(Node2D root)
    {
        TankRoot = root;
    }
}
