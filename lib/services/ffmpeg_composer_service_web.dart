// Web 平台存根：FFmpeg 功能在 Web 上不可用
class FFmpegComposerService {
  Future<String?> compose({
    required String videoPath,
    String? bgmPath,
    required double score,
    required String date,
  }) async {
    // Web 平台不支持 FFmpeg，直接返回原始路径
    return videoPath;
  }
}
