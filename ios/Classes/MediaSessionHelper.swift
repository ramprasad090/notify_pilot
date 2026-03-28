import Foundation
import MediaPlayer
import UIKit

/// Integrates with MPNowPlayingInfoCenter for media-style notifications.
/// Sets now playing metadata (title, artist, album, artwork, duration, position)
/// and manages playback state.
@available(iOS 13.0, *)
class MediaSessionHelper {

    /// Shared singleton instance.
    static let shared = MediaSessionHelper()

    private let infoCenter = MPNowPlayingInfoCenter.default()

    private init() {}

    // MARK: - Now Playing Info

    /// Sets the now playing info on MPNowPlayingInfoCenter.
    ///
    /// - Parameters:
    ///   - title: The media title.
    ///   - artist: The artist name.
    ///   - album: The album name.
    ///   - duration: Total duration in seconds.
    ///   - position: Current playback position in seconds.
    ///   - playbackRate: Current playback rate (1.0 = normal speed).
    ///   - artworkUrl: Optional URL string for album artwork.
    ///   - completion: Called when the info has been set (artwork download may be async).
    func setNowPlaying(
        title: String?,
        artist: String?,
        album: String?,
        duration: Double?,
        position: Double?,
        playbackRate: Double? = nil,
        artworkUrl: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        var info: [String: Any] = [:]

        if let title = title {
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let duration = duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let position = position {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }
        if let rate = playbackRate {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }

        // Download and set artwork if URL provided
        if let urlString = artworkUrl, let url = URL(string: urlString) {
            downloadArtwork(from: url) { [weak self] artwork in
                if let artwork = artwork {
                    info[MPMediaItemPropertyArtwork] = artwork
                }
                self?.infoCenter.nowPlayingInfo = info
                NSLog("[NotifyPilot] MediaSessionHelper: Now playing info set with artwork")
                completion?()
            }
        } else {
            infoCenter.nowPlayingInfo = info
            NSLog("[NotifyPilot] MediaSessionHelper: Now playing info set")
            completion?()
        }
    }

    /// Updates only the playback position and rate without changing other metadata.
    func updatePlaybackPosition(position: Double, playbackRate: Double = 1.0) {
        var info = infoCenter.nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        infoCenter.nowPlayingInfo = info
    }

    // MARK: - Playback State

    /// Updates the playback state.
    ///
    /// - Parameter state: One of "playing", "paused", "stopped", or "interrupted".
    func setPlaybackState(_ state: String) {
        switch state {
        case "playing":
            infoCenter.playbackState = .playing
        case "paused":
            infoCenter.playbackState = .paused
        case "stopped":
            infoCenter.playbackState = .stopped
        case "interrupted":
            infoCenter.playbackState = .interrupted
        default:
            infoCenter.playbackState = .unknown
        }

        NSLog("[NotifyPilot] MediaSessionHelper: Playback state set to '\(state)'")
    }

    // MARK: - Clear

    /// Clears all now playing info and resets playback state.
    func clearNowPlaying() {
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
        NSLog("[NotifyPilot] MediaSessionHelper: Now playing info cleared")
    }

    // MARK: - Private

    /// Downloads an image from the given URL and creates an MPMediaItemArtwork.
    private func downloadArtwork(from url: URL, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil, let image = UIImage(data: data) else {
                NSLog("[NotifyPilot] MediaSessionHelper: Artwork download failed: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }

            DispatchQueue.main.async { completion(artwork) }
        }
        task.resume()
    }
}
