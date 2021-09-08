part of flutter_video_cast;

class VideoSubtitle {
  int? id;
  String? name;
  String? url;
  String? language;

  VideoSubtitle({this.id, this.name, this.url, this.language});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': this.id,
        'name': this.name,
        'url': this.url,
        'language': this.language,
      };
}
