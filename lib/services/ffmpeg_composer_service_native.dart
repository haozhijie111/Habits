import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class FFmpegComposerService {
  /// 合成视频：混入伴奏 + 右下角水印
  ///
  /// [videoPath]     原始录像路径
  /// [bgmPath]       伴奏音频路径（可为 null，则只用原声）
  /// [score]         最终得分（0~100）
  /// [date]          打卡日期字符串
  /// 返回导出的 MP4 路径，失败返回 null
  Future<String?> compose({
    required String videoPath,
    String? bgmPath,
    required double score,
    required String date,
  }) async {
    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'flute_${DateTime.now().millisecondsSinceEpoch}.mp4');

    final cmd = bgmPath != null
        ? _buildCmdWithBgm(videoPath, bgmPath, outPath, score, date)
        : _buildCmdNoBgm(videoPath, outPath, score, date);

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc)) {
      // 保存到相册
      await Gal.putVideo(outPath);
      return outPath;
    }
    return null;
  }

  /// 有伴奏：将原声与伴奏混音，再叠水印
  String _buildCmdWithBgm(
    String video,
    String bgm,
    String out,
    double score,
    String date,
  ) {
    final watermark = _escapeText('$date  ${score.toStringAsFixed(1)}分');
    return [
      '-y',
      '-i "$video"',          // 输入0：原始视频（含原声）
      '-i "$bgm"',            // 输入1：伴奏
      // 混音：原声 0.8 + 伴奏 0.5
      '-filter_complex',
      '"[0:a]volume=0.8[a0];[1:a]volume=0.5[a1];[a0][a1]amix=inputs=2:duration=first[aout];'
      '[0:v]drawtext=text=\'$watermark\':'
      'fontsize=28:fontcolor=white:x=w-tw-20:y=h-th-20:'
      'box=1:boxcolor=black@0.5:boxborderw=8[vout]"',
      '-map "[vout]" -map "[aout]"',
      '-c:v libx264 -preset fast -crf 23',
      '-c:a aac -b:a 128k',
      '-movflags +faststart',
      '"$out"',
    ].join(' ');
  }

  /// 无伴奏：只叠水印
  String _buildCmdNoBgm(
    String video,
    String out,
    double score,
    String date,
  ) {
    final watermark = _escapeText('$date  ${score.toStringAsFixed(1)}分');
    return [
      '-y',
      '-i "$video"',
      '-vf "drawtext=text=\'$watermark\':'
          'fontsize=28:fontcolor=white:x=w-tw-20:y=h-th-20:'
          'box=1:boxcolor=black@0.5:boxborderw=8"',
      '-c:v libx264 -preset fast -crf 23',
      '-c:a copy',
      '-movflags +faststart',
      '"$out"',
    ].join(' ');
  }

  /// 转义 drawtext 特殊字符
  String _escapeText(String text) =>
      text.replaceAll("'", r"\'").replaceAll(':', r'\:');
}
