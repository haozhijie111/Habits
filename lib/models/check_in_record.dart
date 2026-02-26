class CheckInRecord {
  final String id;
  final DateTime createdAt;
  final String filePath;
  final String type; // 'video' | 'audio'
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

  factory CheckInRecord.fromJson(Map<String, dynamic> json) => CheckInRecord(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        filePath: json['filePath'] as String,
        type: json['type'] as String,
        score: (json['score'] as num).toDouble(),
        songTitle: json['songTitle'] as String,
      );
}
