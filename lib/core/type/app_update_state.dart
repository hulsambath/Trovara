enum AppUpdateState {
  idle,
  checking,
  updateAvailable,
  downloading,
  downloaded,
  installing,
  installed,
  failed,
  updating, // Added based on view_model_provider.dart usage
}
