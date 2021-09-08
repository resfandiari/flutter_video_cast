class VideoProgress {
  Duration? currentProgress;
  Duration? videoDuration;

  VideoProgress({this.currentProgress, this.videoDuration});

  VideoProgress.fromJson(Map<String, String> map) {
    currentProgress = Duration(
      milliseconds: double.parse(map['progress'] ?? "0").toInt(),
    );
    videoDuration = Duration(
      milliseconds: double.parse(map['duration'] ?? "0").toInt(),
    );
  }
}
