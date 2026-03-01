class CheckInRecord {
  final String id;
  final DateTime createdAt;
  final String filePath;
  // type: 'checkin_video' | 'checkin_audio' | 'drill' | 'practice'
  // 兼容旧数据：'video' => 'checkin_video', 'audio' => 'checkin_audio'
  final String type;
  final double score;
  final String songTitle;

  const CheckInRecord({
    required this.id,
    required this.createdAt,
    required this.filePath,
    required this.type,
    required this.score,
    required this.songTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'filePath': filePath,
        'type': type,
        'score': score,
        'songTitle': songTitle,
      };

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    // 兼容旧数据的 type 值
    String type = json['type'] as String;
    if (type == 'video') type = 'checkin_video';
    if (type == 'audio') type = 'checkin_audio';
    return CheckInRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      filePath: json['filePath'] as String,
      type: type,
      score: (json['score'] as num).toDouble(),
      songTitle: json['songTitle'] as String,
    );
  }
}
