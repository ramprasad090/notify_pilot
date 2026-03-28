import 'dart:typed_data' show Uint8List;

/// Image source for a notification (big picture, attachment).
sealed class NotifyImage {
  const NotifyImage._();

  /// URL — auto-downloaded, cached, shown as big picture.
  const factory NotifyImage.url(String url) = _UrlImage;

  /// Flutter asset path.
  const factory NotifyImage.asset(String assetPath) = _AssetImage;

  /// Absolute file path on device.
  const factory NotifyImage.file(String filePath) = _FileImage;

  /// Raw bytes.
  const factory NotifyImage.bytes(Uint8List data) = _BytesImage;

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap();
}

final class _UrlImage extends NotifyImage {
  final String url;
  const _UrlImage(this.url) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'url', 'url': url};
}

final class _AssetImage extends NotifyImage {
  final String assetPath;
  const _AssetImage(this.assetPath) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'asset', 'assetPath': assetPath};
}

final class _FileImage extends NotifyImage {
  final String filePath;
  const _FileImage(this.filePath) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'file', 'filePath': filePath};
}

final class _BytesImage extends NotifyImage {
  final Uint8List data;
  const _BytesImage(this.data) : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'bytes', 'data': data};
}
