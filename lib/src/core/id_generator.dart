/// Generates unique integer IDs for notifications.
///
/// Uses a combination of timestamp and counter to ensure uniqueness.
/// IDs are positive 32-bit integers to be compatible with all platforms.
class IdGenerator {
  static int _counter = 0;

  /// Generates a unique notification ID.
  ///
  /// Returns a positive integer derived from the current timestamp
  /// and an incrementing counter.
  static int generate() {
    _counter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Use lower 24 bits of timestamp + 8-bit counter for uniqueness
    return ((timestamp & 0x00FFFFFF) << 8 | (_counter & 0xFF)).abs();
  }

  /// Resets the counter. Primarily for testing.
  static void reset() {
    _counter = 0;
  }
}
