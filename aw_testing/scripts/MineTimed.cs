using Godot;
using System;

public partial class MineTimed : AbilityItem
{
    [Export]
    float TimeToExplode = 3.0f;

    Area2D area;
    
    Label debugTimerLabel;
    
    private float timer = 1;
    bool exploded = false;
    
    public override void Start(Vector2 position, float rotation)
    {
        timer = TimeToExplode;
        area = GetNode<Area2D>("ExplosionArea");
        if (area == null)
        {
            GD.PrintErr("Mine has no ExplosionArea!");
            QueueFree();
        }
        
        debugTimerLabel = GetNode<Label>("Label");
        
        base.Start(position, rotation);
    }

    public override void _Process(double delta)
    {
        timer -= (float)delta;
        if (debugTimerLabel != null)
        {
            debugTimerLabel.Text = $"{timer:F1}";
        }

        if (timer < 0.0f && exploded == false)
        {
            exploded = true;
            var nearNodes = area.GetOverlappingBodies();
            foreach (var node2D in nearNodes)
            {
                if (node2D.HasMethod("OnHit"))
                {
                    node2D.Call("OnHit");
                }
            }
            QueueFree();
        }
    }
    
    
}
