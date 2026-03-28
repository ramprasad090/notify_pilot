import Foundation
import UserNotifications

/// Downloads and caches images from URLs for use as notification attachments.
/// Uses a simple file-based cache in the temporary directory to avoid
/// redundant downloads of the same resource.
@available(iOS 13.0, *)
class MediaDownloader {

    /// Shared singleton instance.
    static let shared = MediaDownloader()

    /// Cache directory for downloaded media.
    private let cacheDirectory: URL

    init() {
        let tempDir = FileManager.default.temporaryDirectory
        cacheDirectory = tempDir.appendingPathComponent("dev.notify_pilot.media_cache", isDirectory: true)

        // Ensure cache directory exists
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Download

    /// Downloads an image from the given URL and returns a local file URL
    /// suitable for creating a UNNotificationAttachment.
    ///
    /// - Parameters:
    ///   - url: The remote URL to download from.
    ///   - completion: Called with the local file URL on success, or nil on failure.
    func downloadImage(from url: URL, completion: @escaping (URL?) -> Void) {
        // Check cache first
        let cachedURL = cachedFileURL(for: url)
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            NSLog("[NotifyPilot] MediaDownloader: Using cached image for \(url.absoluteString)")
            completion(cachedURL)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            guard let self = self, let localURL = localURL, error == nil else {
                NSLog("[NotifyPilot] MediaDownloader: Download failed: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let ext = self.fileExtension(from: response, url: url)
            let destURL = self.cachedFileURL(for: url, extension: ext)

            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destURL)

                NSLog("[NotifyPilot] MediaDownloader: Cached image at \(destURL.path)")
                DispatchQueue.main.async { completion(destURL) }
            } catch {
                NSLog("[NotifyPilot] MediaDownloader: Failed to cache image: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
        task.resume()
    }

    /// Downloads an image and creates a UNNotificationAttachment.
    ///
    /// - Parameters:
    ///   - url: The remote URL to download from.
    ///   - completion: Called with the attachment on success, or nil on failure.
    func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        downloadImage(from: url) { localURL in
            guard let localURL = localURL else {
                completion(nil)
                return
            }

            do {
                // UNNotificationAttachment moves the file, so copy to a temp path first
                // to preserve the cache
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(UUID().uuidString + "." + (localURL.pathExtension.isEmpty ? "jpg" : localURL.pathExtension))
                try FileManager.default.copyItem(at: localURL, to: tempFile)

                let attachment = try UNNotificationAttachment(
                    identifier: UUID().uuidString,
                    url: tempFile,
                    options: nil
                )
                completion(attachment)
            } catch {
                NSLog("[NotifyPilot] MediaDownloader: Failed to create attachment: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - Cache Management

    /// Clears all cached media files.
    func clearCache() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
            )
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            NSLog("[NotifyPilot] MediaDownloader: Cache cleared")
        } catch {
            NSLog("[NotifyPilot] MediaDownloader: Failed to clear cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    /// Generates a cache file URL for the given remote URL.
    private func cachedFileURL(for url: URL, extension ext: String? = nil) -> URL {
        let hash = url.absoluteString.sha256Hash
        let fileExt = ext ?? fileExtension(from: nil, url: url)
        return cacheDirectory.appendingPathComponent("\(hash)\(fileExt)")
    }

    /// Determines the file extension from the response MIME type or URL path.
    private func fileExtension(from response: URLResponse?, url: URL) -> String {
        if let mimeType = response?.mimeType {
            switch mimeType {
            case "image/png": return ".png"
            case "image/jpeg": return ".jpg"
            case "image/gif": return ".gif"
            case "image/webp": return ".webp"
            default: break
            }
        }

        let pathExt = url.pathExtension.lowercased()
        if !pathExt.isEmpty {
            return ".\(pathExt)"
        }

        return ".png"
    }
}

// MARK: - String SHA256

private extension String {
    /// Simple hash for cache key generation.
    var sha256Hash: String {
        var hash = 0
        for char in self.unicodeScalars {
            hash = 31 &* hash &+ Int(char.value)
        }
        return String(format: "%016lx", abs(hash))
    }
}
