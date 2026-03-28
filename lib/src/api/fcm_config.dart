/// Configuration for Firebase Cloud Messaging integration.
class FcmConfig {
  /// Called when the FCM token is first obtained.
  final void Function(String token)? onToken;

  /// Called when the FCM token is refreshed.
  final void Function(String token)? onTokenRefresh;

  /// FCM topics to automatically subscribe to on initialization.
  final List<String> topics;

  /// Creates an FCM configuration.
  const FcmConfig({
    this.onToken,
    this.onTokenRefresh,
    this.topics = const [],
  });
}
