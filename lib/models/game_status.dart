/// Status of a game session
enum GameStatus {
  /// Game has not started yet
  notStarted,

  /// Game is actively playing, waiting for audio
  playing,

  /// Audio played, waiting for user input
  awaitingInput,

  /// Showing feedback for the last answer
  showingFeedback,

  /// All prompts completed, game is done
  completed,
}
