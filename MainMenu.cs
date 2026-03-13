using Godot;

public partial class MainMenu : Control
{
	public override void _Ready()
	{
		Button newGameButton = GetNode<Button>("CenterContainer/VBoxContainer/NewGameButton");
		Button exitButton = GetNode<Button>("CenterContainer/VBoxContainer/ExitButton");

		newGameButton.Pressed += OnNewGamePressed;
		exitButton.Pressed += OnExitPressed;
	}

	private void OnNewGamePressed()
	{
		GetTree().ChangeSceneToFile("res://game.tscn");
	}

	private void OnExitPressed()
	{
		GetTree().Quit();
	}
}
