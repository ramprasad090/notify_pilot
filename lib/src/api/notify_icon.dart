import 'dart:typed_data' show Uint8List;

/// Icon source for a notification.
sealed class NotifyIcon {
  const NotifyIcon._();

  /// Android drawable resource name (e.g., `@drawable/ic_notification`).
  const factory NotifyIcon.resource(String name) = _ResourceIcon;

  /// URL — auto-downloaded and cached.
  const factory NotifyIcon.url(String url) = _UrlIcon;

  /// Flutter asset path (e.g., `assets/icons/payment.png`).
  const factory NotifyIcon.asset(String assetPath) = _AssetIcon;

  /// Absolute file path on device.
  const factory NotifyIcon.file(String filePath) = _FileIcon;

  /// Raw bytes.
  const factory NotifyIcon.bytes(Uint8List data) = _BytesIcon;

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap();
}

final class _ResourceIcon extends NotifyIcon {
  final String name;
  const _ResourceIcon(this.name) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'resource', 'name': name};
}

final class _UrlIcon extends NotifyIcon {
  final String url;
  const _UrlIcon(this.url) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'url', 'url': url};
}

final class _AssetIcon extends NotifyIcon {
  final String assetPath;
  const _AssetIcon(this.assetPath) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'asset', 'assetPath': assetPath};
}

final class _FileIcon extends NotifyIcon {
  final String filePath;
  const _FileIcon(this.filePath) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'file', 'filePath': filePath};
}

final class _BytesIcon extends NotifyIcon {
  final Uint8List data;
  const _BytesIcon(this.data) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'bytes', 'data': data};
}
