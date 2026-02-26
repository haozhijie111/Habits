/// 音高分析结果
class PitchResult {
  final double frequency; // 检测到的频率 Hz
  final String noteName;  // 音符名称，如 "A4"
  final double centsOffset; // 偏离标准音高的 cents (-50 ~ +50)
  final double confidence; // 置信度 0.0 ~ 1.0

  const PitchResult({
    required this.frequency,
    required this.noteName,
    required this.centsOffset,
    required this.confidence,
  });

  /// 偏离百分比（用于 UI 显示）
  double get offsetPercent => centsOffset / 50.0; // -1.0 ~ 1.0

  /// 是否在可接受范围内（±25 cents）
  bool get isInTune => centsOffset.abs() <= 25.0;

  static const PitchResult empty = PitchResult(
    frequency: 0,
    noteName: '--',
    centsOffset: 0,
    confidence: 0,
  );
}
