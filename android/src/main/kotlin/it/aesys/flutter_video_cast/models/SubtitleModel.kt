package it.aesys.flutter_video_cast.models

class SubtitleModel(
        val id: Int,
        var name: String,
        var language: String,
        var url: String
) {
        override fun toString(): String {
		return "Subtitle [id: ${this.id}, url: ${this.url}, name: ${this.name}, language: ${this.language}]"
	}     
}