package dev.notify_pilot

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat

/**
 * Manages a MediaSessionCompat for media-style notifications.
 *
 * Provides methods to create a session, update playback state and metadata,
 * and retrieve the session token for use with MediaStyle notifications.
 */
class MediaSessionHelper(private val context: Context) {

    companion object {
        private const val SESSION_TAG = "notify_pilot_media"
    }

    private var mediaSession: MediaSessionCompat? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Creates and activates a new MediaSessionCompat.
     *
     * If a session already exists, it is released before creating a new one.
     *
     * @param context Application context
     * @return The created MediaSessionCompat
     */
    fun createMediaSession(context: Context): MediaSessionCompat {
        mediaSession?.release()

        val session = MediaSessionCompat(context, SESSION_TAG).apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            isActive = true
        }

        mediaSession = session
        return session
    }

    /**
     * Updates the playback state of the current media session.
     *
     * @param isPlaying Whether media is currently playing
     * @param position Current playback position in milliseconds
     */
    fun updatePlaybackState(isPlaying: Boolean, position: Long) {
        val session = mediaSession ?: return

        val state = if (isPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }

        val playbackState = PlaybackStateCompat.Builder()
            .setState(state, position, if (isPlaying) 1.0f else 0.0f)
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_STOP
            )
            .build()

        session.setPlaybackState(playbackState)
    }

    /**
     * Updates the media metadata (title, artist, album, art) for the session.
     *
     * @param title Track title
     * @param artist Artist name
     * @param album Album name
     * @param albumArt Optional album art bitmap
     */
    fun updateMetadata(
        title: String?,
        artist: String?,
        album: String?,
        albumArt: Bitmap?
    ) {
        val session = mediaSession ?: return

        val metadata = MediaMetadataCompat.Builder().apply {
            if (title != null) putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            if (artist != null) putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            if (album != null) putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            if (albumArt != null) putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, albumArt)
        }.build()

        session.setMetadata(metadata)
    }

    /**
     * Returns the session token for use with MediaStyle notifications.
     *
     * @return The MediaSessionCompat.Token, or null if no session exists
     */
    fun getMediaSessionToken(): MediaSessionCompat.Token? {
        return mediaSession?.sessionToken
    }

    /**
     * Releases the media session and frees resources.
     */
    fun release() {
        mediaSession?.apply {
            isActive = false
            release()
        }
        mediaSession = null
    }
}
