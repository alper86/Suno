class SongInfo {
  final String id;
  final String title;
  final String handle;
  final double? duration;
  final String tags;
  final String imageUrl;
  final String videoUrl;
  final String audioStreamUrl;

  SongInfo({
    required this.id,
    required this.title,
    required this.handle,
    this.duration,
    required this.tags,
    required this.imageUrl,
    required this.videoUrl,
    required this.audioStreamUrl,
  });

  String get safeFilename {
    final raw = handle.isNotEmpty ? '$handle - $title' : title;
    final clean = raw.replaceAll(RegExp(r'[\\/*?:"<>|]'), '').trim();
    return clean.isEmpty ? 'suno_track' : clean;
  }
}
