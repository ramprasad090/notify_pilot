import '../api/enums.dart';
import '../platform/notify_pilot_platform.dart';

/// Manages notification permission requests and status checks.
class PermissionManager {
  /// Requests notification permission from the user.
  ///
  /// Returns `true` if permission was granted.
  Future<bool> requestPermission() async {
    return NotifyPilotPlatform.instance.requestPermission();
  }

  /// Gets the current notification permission status.
  Future<NotifyPermission> getPermissionStatus() async {
    final status = await NotifyPilotPlatform.instance.getPermission();
    return _parsePermission(status);
  }

  static NotifyPermission _parsePermission(String status) {
    return switch (status) {
      'granted' => NotifyPermission.granted,
      'denied' => NotifyPermission.denied,
      'permanentlyDenied' => NotifyPermission.permanentlyDenied,
      'provisional' => NotifyPermission.provisional,
      _ => NotifyPermission.notDetermined,
    };
  }
}
