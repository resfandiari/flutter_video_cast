package it.aesys.flutter_video_cast

import android.content.Context
import android.net.Uri
import android.view.ContextThemeWrapper
import android.graphics.Color
import androidx.mediarouter.app.MediaRouteButton
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadOptions
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.TextTrackStyle
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.Session
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.api.PendingResult
import com.google.android.gms.common.api.Status
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import com.google.gson.Gson

import it.aesys.flutter_video_cast.models.SubtitleModel

class ChromeCastController(
        messenger: BinaryMessenger,
        viewId: Int,
        context: Context?
) : PlatformView, MethodChannel.MethodCallHandler, SessionManagerListener<Session>, PendingResult.StatusListener, RemoteMediaClient.ProgressListener {
    private val channel = MethodChannel(messenger, "flutter_video_cast/chromeCast_$viewId")
    private val chromeCastButton = MediaRouteButton(ContextThemeWrapper(context, R.style.Theme_AppCompat_NoActionBar))
    private val sessionManager = CastContext.getSharedInstance()?.sessionManager

    init {
        CastButtonFactory.setUpMediaRouteButton(context, chromeCastButton)
        channel.setMethodCallHandler(this)
    }

    private fun loadMedia(args: Any?) {
        if (args is Map<*, *>) {
            val url = args["url"] as? String
            val subtitlesJson = args["subtitles"] as? String
            /// keep all tracks like subittles and audio tracks
            val tracks: MutableList<MediaTrack> = ArrayList<MediaTrack>()

            if (subtitlesJson != null) {
                val gson = Gson()
                val subtitles = gson.fromJson(subtitlesJson, Array<SubtitleModel>::class.java).asList();
                
                for (subtitle in subtitles) {
                   val mediTrackSubtitle = MediaTrack.Builder(subtitle.id.toLong(), MediaTrack.TYPE_TEXT)
                   .setName(subtitle.name)
                   .setSubtype(MediaTrack.SUBTYPE_SUBTITLES)
                   .setContentId(subtitle.url)
                   /* language is required for subtitle type but optional otherwise */
                   .setLanguage(subtitle.language)
                   .build() 

                   tracks.add(mediTrackSubtitle)
                }
            } 
            
            val meta = MediaMetadata(MediaMetadata.MEDIA_TYPE_GENERIC)
            meta.putString(MediaMetadata.KEY_TITLE, args["title"] as? String)
            meta.putString(MediaMetadata.KEY_SUBTITLE, args["subTitle"] as? String)
            meta.putString(MediaMetadata.KEY_STUDIO, args["subTitle"] as? String)
            (args["imgUrl"] as? String).let{imageUrl ->
                meta.addImage(WebImage(Uri.parse(imageUrl)))
            }

            val media = MediaInfo.Builder(url).setMetadata(meta).setMediaTracks(tracks).build()
            val options = MediaLoadOptions.Builder().build()
            val request = sessionManager?.currentCastSession?.remoteMediaClient?.load(media, options)
            sessionManager?.currentCastSession?.remoteMediaClient?.addProgressListener(this, 1000)

            request?.addStatusListener(this)
        }
    }

    private fun play() {
        val request = sessionManager?.currentCastSession?.remoteMediaClient?.play()
        request?.addStatusListener(this)
    }

    private fun pause() {
        val request = sessionManager?.currentCastSession?.remoteMediaClient?.pause()
        request?.addStatusListener(this)
    }

    private fun seek(args: Any?) {
        if (args is Map<*, *>) {
            val relative = (args["relative"] as? Boolean) ?: false
            var interval = args["interval"] as? Double
            interval = interval?.times(1000)
            if (relative) {
                interval = interval?.plus(sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.streamPosition ?: 0)
            }
            val request = sessionManager?.currentCastSession?.remoteMediaClient?.seek(interval?.toLong() ?: 0)
            request?.addStatusListener(this)
        }
    }

    private fun changeSubtitle(args: Any?) {
        if (args is Map<*, *>) {
            val id = args["id"] as? Int 
            val request = sessionManager?.currentCastSession?.remoteMediaClient?.setActiveMediaTracks(longArrayOf(id!!.toLong()))
            val subtitleStyle = TextTrackStyle()
            subtitleStyle.setBackgroundColor(Color.argb(76, 0, 0, 0))
            sessionManager?.currentCastSession?.remoteMediaClient?.setTextTrackStyle(subtitleStyle)
            request?.addStatusListener(this)    
        }
    }

    private fun turnOffSubtitle() {
        val request = sessionManager?.currentCastSession?.remoteMediaClient?.setActiveMediaTracks(LongArray(0))
        request?.addStatusListener(this)
    }

    private fun setVolume(args: Any?) {
        if (args is Map<*, *>) {
            val volume = args["volume"] as? Double
            val request = sessionManager?.currentCastSession?.setVolume(volume ?: 0.0)
            //request?.addStatusListener(this)
        }
    }

    private fun getVolume() = sessionManager?.currentCastSession?.volume ?: 0.0

    private fun stop() {
        val request = sessionManager?.currentCastSession?.remoteMediaClient?.stop()
        request?.addStatusListener(this)
    }

    private fun isPlaying() = sessionManager?.currentCastSession?.remoteMediaClient?.isPlaying ?: false

    private fun isConnected() = sessionManager?.currentCastSession?.isConnected ?: false

    private fun endSession() {
        sessionManager?.currentCastSession?.remoteMediaClient?.removeProgressListener(this)
        sessionManager?.endCurrentSession(true)
    }

    private fun position() = sessionManager?.currentCastSession?.remoteMediaClient?.approximateStreamPosition ?: 0

    private fun duration() = sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.streamDuration ?: 0

    private fun addSessionListener() {
        sessionManager?.addSessionManagerListener(this)
    }

    private fun removeSessionListener() {
        sessionManager?.removeSessionManagerListener(this)
    }

    override fun getView() = chromeCastButton

    override fun dispose() {

    }

    // Flutter methods handling

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "chromeCast#wait" -> result.success(null)
            "chromeCast#loadMedia" -> {
                loadMedia(call.arguments)
                result.success(null)
            }
            "chromeCast#play" -> {
                play()
                result.success(null)
            }
            "chromeCast#pause" -> {
                pause()
                result.success(null)
            }
            "chromeCast#seek" -> {
                seek(call.arguments)
                result.success(null)
            }
            "chromeCast#setVolume" -> {
                setVolume(call.arguments)
                result.success(null)
            }
            "chromeCast#getVolume" -> result.success(getVolume())
            "chromeCast#stop" -> {
                stop()
                result.success(null)
            }
            "chromeCast#isPlaying" -> result.success(isPlaying())
            "chromeCast#isConnected" -> result.success(isConnected())
            "chromeCast#endSession" -> {
                endSession()
                result.success(null)
            }
            "chromeCast#position" -> result.success(position())
            "chromeCast#duration" -> result.success(duration())
            "chromeCast#changeSubtitle" -> {
                changeSubtitle(call.arguments)
                result.success(null)
            }
            "chromeCast#turnOffSubtitle" -> {
                turnOffSubtitle()
                result.success(null)
            }
            "chromeCast#addSessionListener" -> {
                addSessionListener()
                result.success(null)
            }
            "chromeCast#removeSessionListener" -> {
                removeSessionListener()
                result.success(null)
            }
        }
    }

    // SessionManagerListener
    override fun onSessionStarted(p0: Session?, p1: String?) {
        channel.invokeMethod("chromeCast#didStartSession", null)
    }

    override fun onSessionEnded(p0: Session?, p1: Int) {
        channel.invokeMethod("chromeCast#didEndSession", null)
    }

    override fun onSessionResuming(p0: Session?, p1: String?) {

    }

    override fun onSessionResumed(p0: Session?, p1: Boolean) {

    }

    override fun onSessionResumeFailed(p0: Session?, p1: Int) {

    }

    override fun onSessionSuspended(p0: Session?, p1: Int) {

    }

    override fun onSessionStarting(p0: Session?) {

    }

    override fun onSessionEnding(p0: Session?) {

    }

    override fun onSessionStartFailed(p0: Session?, p1: Int) {

    }

    // PendingResult.StatusListener
    override fun onComplete(status: Status?) {
        if (status?.isSuccess == true) {
            channel.invokeMethod("chromeCast#requestDidComplete", null)
        }
    }

    override fun onProgressUpdated(progress: Long, duration: Long) {
        val data = HashMap<String, String>()
        data[DURATION] = duration.toString()
        data[PROGRESS] = progress.toString()
        channel.invokeMethod("chromeCast#getVideoProgress", data)
    }
}
