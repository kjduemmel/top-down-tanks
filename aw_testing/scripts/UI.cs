using Godot;
using System;

public partial class UI : CanvasLayer
{
	[Export] 
	Label MessageLabel;
	
	[Export]
	Label ScoreLabel;
	
	[Export]
	Timer MessageTimer;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
	
	public void ShowMessage(string message)
	{
		MessageLabel.Text = message;
		MessageLabel.Show();
		
		MessageTimer.Start();
	}

	public void UpdateScore(int score)
	{
		ScoreLabel.Text = score.ToString();
	}

	void OnMessageTimerTimeout()
	{
		MessageLabel.Hide();
	}
	
}
