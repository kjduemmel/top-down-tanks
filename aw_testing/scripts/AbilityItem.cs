using Godot;
using System;

public partial class AbilityItem : Node2D
{
    public virtual void Start(Vector2 position, float rotation)
    {
        Position = position;
        Rotation = rotation;
    }
}
