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
	
	int score = 0;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		ScoreLabel.Text = $"Score: {score}";
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

	public int GetScore()
	{
		return score;
	}
	
	public void SetScore(int newScore)
	{
		score = newScore;
		UpdateScoreLabel();
	}

	public void IncreaseScore(int amount)
	{
		score += amount;
		UpdateScoreLabel();
	}

	void UpdateScoreLabel()
	{
		ScoreLabel.Text = $"Score: {score}";
	}

	void OnMessageTimerTimeout()
	{
		MessageLabel.Hide();
	}
	
}
