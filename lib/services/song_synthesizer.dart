import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 将音符名称转换为频率（Hz）
double noteToFreq(String note) {
  const noteMap = {
    'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
    'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
    'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11,
  };
  // 解析音符名，如 "G4", "F#4", "C5"
  final match = RegExp(r'^([A-G][#b]?)(\d)$').firstMatch(note);
  if (match == null) return 440.0;
  final name = match.group(1)!;
  final octave = int.parse(match.group(2)!);
  final semitone = noteMap[name] ?? 0;
  // A4 = 440Hz, MIDI number = (octave+1)*12 + semitone
  final midi = (octave + 1) * 12 + semitone;
  return 440.0 * math.pow(2, (midi - 69) / 12);
}

/// 生成单个音符的 PCM 样本（带淡入淡出）
List<double> _generateNote(double freq, double duration, int sampleRate) {
  final numSamples = (duration * sampleRate).round();
  final samples = List<double>.filled(numSamples, 0.0);
  final fadeLen = (sampleRate * 0.01).round(); // 10ms 淡入淡出

  for (int i = 0; i < numSamples; i++) {
    double amp = 0.6;
    if (i < fadeLen) amp *= i / fadeLen;
    if (i > numSamples - fadeLen) amp *= (numSamples - i) / fadeLen;
    // 基频 + 泛音，模拟笛子音色
    samples[i] = amp * (
      0.6 * math.sin(2 * math.pi * freq * i / sampleRate) +
      0.25 * math.sin(2 * math.pi * freq * 2 * i / sampleRate) +
      0.1 * math.sin(2 * math.pi * freq * 3 * i / sampleRate) +
      0.05 * math.sin(2 * math.pi * freq * 4 * i / sampleRate)
    );
  }
  return samples;
}

/// 生成静音样本
List<double> _generateSilence(double duration, int sampleRate) {
  return List<double>.filled((duration * sampleRate).round(), 0.0);
}

/// 将 double 样本列表编码为 16-bit PCM WAV 字节
Uint8List _samplesToWav(List<double> samples, int sampleRate) {
  final numSamples = samples.length;
  final dataSize = numSamples * 2; // 16-bit = 2 bytes
  final fileSize = 44 + dataSize;

  final buf = ByteData(fileSize);
  // RIFF header
  buf.setUint8(0, 0x52); buf.setUint8(1, 0x49); buf.setUint8(2, 0x46); buf.setUint8(3, 0x46); // "RIFF"
  buf.setUint32(4, fileSize - 8, Endian.little);
  buf.setUint8(8, 0x57); buf.setUint8(9, 0x41); buf.setUint8(10, 0x56); buf.setUint8(11, 0x45); // "WAVE"
  // fmt chunk
  buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D); buf.setUint8(14, 0x74); buf.setUint8(15, 0x20); // "fmt "
  buf.setUint32(16, 16, Endian.little); // chunk size
  buf.setUint16(20, 1, Endian.little);  // PCM
  buf.setUint16(22, 1, Endian.little);  // mono
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  buf.setUint16(32, 2, Endian.little);  // block align
  buf.setUint16(34, 16, Endian.little); // bits per sample
  // data chunk
  buf.setUint8(36, 0x64); buf.setUint8(37, 0x61); buf.setUint8(38, 0x74); buf.setUint8(39, 0x61); // "data"
  buf.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    final v = (samples[i] * 32767).clamp(-32768, 32767).toInt();
    buf.setInt16(44 + i * 2, v, Endian.little);
  }
  return buf.buffer.asUint8List();
}

/// 曲目合成器：根据音符序列生成 WAV 并用 just_audio 播放
class SongSynthesizer {
  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 22050;

  bool get isPlaying => _player.playing;

  /// 合成并播放曲目
  /// [notes] 格式：List of (noteName, startTime, duration)
  Future<void> play(List<({String note, double time, double duration})> notes) async {
    if (notes.isEmpty) return;

    final totalDuration = notes.map((n) => n.time + n.duration).reduce(math.max) + 0.3;
    final totalSamples = (totalDuration * _sampleRate).round();
    final mixed = List<double>.filled(totalSamples, 0.0);

    for (final n in notes) {
      final freq = noteToFreq(n.note);
      final noteSamples = _generateNote(freq, n.duration, _sampleRate);
      final startIdx = (n.time * _sampleRate).round();
      for (int i = 0; i < noteSamples.length; i++) {
        final idx = startIdx + i;
        if (idx < totalSamples) mixed[idx] += noteSamples[i];
      }
    }

    // 归一化防止削波
    final maxAmp = mixed.map((v) => v.abs()).reduce(math.max);
    if (maxAmp > 0.95) {
      for (int i = 0; i < mixed.length; i++) mixed[i] = mixed[i] / maxAmp * 0.9;
    }

    final wav = _samplesToWav(mixed, _sampleRate);
    // 写临时文件，避免 Android ExoPlayer 处理 StreamAudioSource 的兼容问题
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/preview_song.wav');
    await file.writeAsBytes(wav);
    await _player.setFilePath(file.path);
    await _player.seek(Duration.zero);
    await _player.play();
    // 等待播放完成
    await _player.playerStateStream
        .firstWhere((s) => s.processingState == ProcessingState.completed);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
