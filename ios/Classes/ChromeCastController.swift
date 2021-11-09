//
//  ChromeCastController.swift
//  flutter_video_cast
//
//  Created by Alessio Valentini on 07/08/2020.
//

import Flutter
import GoogleCast

class ChromeCastController: NSObject, FlutterPlatformView, GCKRemoteMediaClientListener {

    // MARK: - Internal properties

    private let channel: FlutterMethodChannel
    private let chromeCastButton: GCKUICastButton
    private let volumeController: GCKUIDeviceVolumeController
    private let sessionManager = GCKCastContext.sharedInstance().sessionManager

    // MARK: - Init

    init(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        registrar: FlutterPluginRegistrar
    ) {
        self.channel = FlutterMethodChannel(name: "flutter_video_cast/chromeCast_\(viewId)", binaryMessenger: registrar.messenger())
        self.chromeCastButton = GCKUICastButton(frame: frame)
        self.volumeController = GCKUIDeviceVolumeController()
        super.init()
        self.configure(arguments: args)
    }

    func view() -> UIView {
        return chromeCastButton
    }

    private func configure(arguments args: Any?) {
        setTint(arguments: args)
        setMethodCallHandler()
    }

    // MARK: - Styling

    private func setTint(arguments args: Any?) {
        guard
            let args = args as? [String: Any],
            let red = args["red"] as? CGFloat,
            let green = args["green"] as? CGFloat,
            let blue = args["blue"] as? CGFloat,
            let alpha = args["alpha"] as? Int else {
                print("Invalid color")
                return
        }
        chromeCastButton.tintColor = UIColor(
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            alpha: CGFloat(alpha) / 255
        )
    }

    // MARK: - Flutter methods handling

    private func setMethodCallHandler() {
        channel.setMethodCallHandler { call, result in
            self.onMethodCall(call: call, result: result)
        }
    }

    private func onMethodCall(call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "chromeCast#wait":
            result(nil)
            break
        case "chromeCast#loadMedia":
            loadMedia(args: call.arguments)
            result(nil)
            break
        case "chromeCast#play":
            play()
            result(nil)
            break
        case "chromeCast#pause":
            pause()
            result(nil)
            break
        case "chromeCast#seek":
            seek(args: call.arguments)
            result(nil)
            break
        case "chromeCast#setVolume":
            setVolume(args: call.arguments)
            result(nil) 
            break
        case "chromeCast#stop":
            stop()
            result(nil)
            break
        case "chromeCast#isConnected":
            result(isConnected())
            break
        case "chromeCast#changeSubtitle":
            changeSubtitle(args: call.arguments)
            result(nil) 
            break
        case "chromeCast#turnOffSubtitle":
            turnOffSubtitle()
            result(nil) 
            break       
        case "chromeCast#isPlaying":
            result(isPlaying())
            break
        case "chromeCast#addSessionListener":
            addSessionListener()
            result(nil)
        case "chromeCast#removeSessionListener":
            removeSessionListener()
            result(nil)
        case "chromeCast#position":
            result(position())
        case "chromeCast#endSession":
            sessionManager.currentCastSession?.remoteMediaClient?.remove(self)
            sessionManager.endSession()
            result(nil)
        default:
            result(nil)
            break
        }
    }

    private func loadMedia(args: Any?) {
        guard
            let args = args as? [String: Any],
            let url = args["url"] as? String,
            let mediaUrl = URL(string: url) else {
                print("Invalid URL")
                return
        }

        let subtitlesJson = args["subtitles"] as? String
        var tracks = [GCKMediaTrack]()

        if subtitlesJson != nil {
          let decoder = JSONDecoder()  
          let jsonData = Data(subtitlesJson!.utf8)
          do {
            let subtitles = try decoder.decode([SubtitleModel].self, from: jsonData)
            for subtitle in subtitles {
                let captionsTrack = GCKMediaTrack.init(identifier: subtitle.id,
                                       contentIdentifier: subtitle.url,
                                       contentType: "text/vtt",
                                       type: GCKMediaTrackType.text,
                                       textSubtype: GCKMediaTextTrackSubtype.captions,
                                       name: subtitle.name,
                                       languageCode: subtitle.language,
                                       customData: nil) 
                tracks.append(captionsTrack)
            }
          } catch {
            print(error.localizedDescription)
          }
        }

        let metadata = GCKMediaMetadata()
        metadata.setString(args["title"] as? String ?? "", forKey: kGCKMetadataKeyTitle)
        metadata.setString(args["subTitle"] as? String ?? "", forKey: kGCKMetadataKeySubtitle)

        if args["imgUrl"] as? String != nil {
           let imageUrl = args["imgUrl"] as? String ?? ""
           metadata.addImage(GCKImage(url: URL(string: imageUrl)!,
                           width: 480,
                           height: 360)) 
        }

        let mediaInfoBuilder = GCKMediaInformationBuilder.init(contentURL: mediaUrl)

        mediaInfoBuilder.metadata = metadata;
        mediaInfoBuilder.mediaTracks = tracks;

        let mediaInformation = mediaInfoBuilder.build()
        
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.loadMedia(mediaInformation) {
            request.delegate = self
        }
        sessionManager.currentCastSession?.remoteMediaClient?.add(self)
    }

    public func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        if let mediaStatusPosition = mediaStatus?.streamPosition, let duration = mediaStatus?.mediaInformation?.streamDuration {
             channel.invokeMethod("chromeCast#getVideoProgress", arguments:
                 [
                    "position": String(mediaStatusPosition * 1000),
                    "duration": String(duration * 1000)
                 ]
             )
        }

    }

    private func play() {
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.play() {
            request.delegate = self
        }
    }

    private func pause() {
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.pause() {
            request.delegate = self
        }
    }

    private func seek(args: Any?) {
        guard
            let args = args as? [String: Any],
            let relative = args["relative"] as? Bool,
            let interval = args["interval"] as? Double else {
                return
        }
        let seekOptions = GCKMediaSeekOptions()
        seekOptions.relative = relative
        seekOptions.interval = interval
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.seek(with: seekOptions) {
            request.delegate = self
        }
    }

    private func setVolume(args: Any?) {
        guard 
         let args = args as? [String: Any],
         let volume = args["volume"] as? Float else {
                return
        }
       
        self.volumeController.setVolume(volume)
    }

    private func changeSubtitle(args: Any?) {
        guard
          let args = args as? [String: Any],
          let id = args["id"] as? NSNumber else {
                return
        }

      sessionManager.currentSession?.remoteMediaClient?.setActiveTrackIDs([id])  

      let textTrackStyle = GCKMediaTextTrackStyle.createDefault()
      textTrackStyle.backgroundColor = GCKColor.init(cssString: "#0000004D")
      let styleChangeRequest = sessionManager.currentSession?.remoteMediaClient?.setTextTrackStyle(textTrackStyle)
      styleChangeRequest?.delegate = self
    }

    private func turnOffSubtitle() {
       if let request =  sessionManager.currentSession?.remoteMediaClient?.setActiveTrackIDs([]) {
            request.delegate = self
       }
    }

    private func stop() {
        if let request = sessionManager.currentCastSession?.remoteMediaClient?.stop() {
            request.delegate = self
        }
    }

    private func isConnected() -> Bool {
        return sessionManager.currentCastSession?.remoteMediaClient?.connected ?? false
    }

    private func isPlaying() -> Bool {
        return sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.playerState == GCKMediaPlayerState.playing
    }

    private func addSessionListener() {
        sessionManager.add(self)
    }

    private func removeSessionListener() {
        sessionManager.remove(self)
    }

    private func position() -> Int {
        return Int(sessionManager.currentCastSession?.remoteMediaClient?.approximateStreamPosition() ?? 0) * 1000
    }
}

// MARK: - GCKSessionManagerListener

extension ChromeCastController: GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        channel.invokeMethod("chromeCast#didStartSession", arguments: nil)
    }

    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        channel.invokeMethod("chromeCast#didEndSession", arguments: nil)
    }
}

// MARK: - GCKRequestDelegate

extension ChromeCastController: GCKRequestDelegate {
    func requestDidComplete(_ request: GCKRequest) {
        channel.invokeMethod("chromeCast#requestDidComplete", arguments: nil)
    }

    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        channel.invokeMethod("chromeCast#requestDidFail", arguments: ["error" : error.localizedDescription])
    }
}
