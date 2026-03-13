using Godot;

public partial class MainMenu : Control
{
	public override void _Ready()
	{
		var newGameButton = GetNode<Button>("CenterContainer/VBoxContainer/NewGameButton");
		newGameButton.Pressed += OnNewGamePressed;
	}

	private void OnNewGamePressed()
	{
		GetTree().ChangeSceneToFile("res://Game.tscn");
	}
}
