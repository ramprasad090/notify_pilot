/// Configuration for notification history storage.
class HistoryConfig {
  /// Whether history tracking is enabled.
  final bool enabled;

  /// Maximum number of history entries to retain.
  final int maxEntries;

  /// Creates a history configuration.
  const HistoryConfig({
    this.enabled = true,
    this.maxEntries = 100,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'maxEntries': maxEntries,
      };
}
