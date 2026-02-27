import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

// ── WAV 合成工具 ──────────────────────────────────────────────────────────────

const _sr = 44100;

final _noteMap = {
  'C': 0, 'C#': 1, 'Cs': 1, 'Db': 1,
  'D': 2, 'D#': 3, 'Ds': 3, 'Eb': 3,
  'E': 4,
  'F': 5, 'F#': 6, 'Fs': 6, 'Gb': 6,
  'G': 7, 'G#': 8, 'Gs': 8, 'Ab': 8,
  'A': 9, 'A#': 10, 'As': 10, 'Bb': 10,
  'B': 11,
};

double _noteToFreq(String name) {
  final m = RegExp(r'^([A-G][#bs]?)(\d)$').firstMatch(name);
  if (m == null) return 440.0;
  final midi = (int.parse(m.group(2)!) + 1) * 12 + (_noteMap[m.group(1)!] ?? 0);
  return 440.0 * math.pow(2, (midi - 69) / 12);
}

/// 合成单音 PCM 样本
List<double> _synthNote(double freq, double duration) {
  final n = (duration * _sr).round();
  final fade = (_sr * 0.01).round();
  final s = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    double a = 0.6;
    if (i < fade) a *= i / fade;
    if (i > n - fade) a *= (n - i) / fade;
    s[i] = a * (0.55 * math.sin(2 * math.pi * freq * i / _sr) +
        0.28 * math.sin(4 * math.pi * freq * i / _sr) +
        0.12 * math.sin(6 * math.pi * freq * i / _sr) +
        0.05 * math.sin(8 * math.pi * freq * i / _sr));
  }
  return s;
}

/// 将 PCM 样本编码为 16-bit WAV
Uint8List _toWav(List<double> samples) {
  final n = samples.length;
  final dataSize = n * 2;
  final buf = ByteData(44 + dataSize);
  [0x52,0x49,0x46,0x46].asMap().forEach((i,v) => buf.setUint8(i, v));
  buf.setUint32(4, 36 + dataSize, Endian.little);
  [0x57,0x41,0x56,0x45].asMap().forEach((i,v) => buf.setUint8(8+i, v));
  [0x66,0x6D,0x74,0x20].asMap().forEach((i,v) => buf.setUint8(12+i, v));
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little);
  buf.setUint32(24, _sr, Endian.little);
  buf.setUint32(28, _sr * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  [0x64,0x61,0x74,0x61].asMap().forEach((i,v) => buf.setUint8(36+i, v));
  buf.setUint32(40, dataSize, Endian.little);
  for (int i = 0; i < n; i++) {
    buf.setInt16(44 + i * 2, (samples[i] * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return buf.buffer.asUint8List();
}

class _WavSource extends StreamAudioSource {
  final Uint8List _bytes;
  _WavSource(this._bytes) : super(tag: 'song');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

// ── SongSynthesizer ───────────────────────────────────────────────────────────

/// 曲目合成器：将整首曲子混音为单个 WAV，用 StreamAudioSource 播放
class SongSynthesizer {
  final AudioPlayer _player = AudioPlayer();

  bool get isPlaying => _player.playing;

  /// 合成并播放曲目
  /// [notes] 格式：List of (noteName, startTime, duration)
  Future<void> play(List<({String note, double time, double duration})> notes) async {
    if (notes.isEmpty) return;

    // 计算总时长并混音
    final totalDuration = notes.map((n) => n.time + n.duration).reduce(math.max) + 0.1;
    final totalSamples = (totalDuration * _sr).round();
    final mixed = List<double>.filled(totalSamples, 0.0);

    for (final n in notes) {
      final samples = _synthNote(_noteToFreq(n.note), n.duration);
      final start = (n.time * _sr).round();
      for (int i = 0; i < samples.length; i++) {
        final idx = start + i;
        if (idx < totalSamples) mixed[idx] += samples[i];
      }
    }

    // 归一化
    final maxAmp = mixed.map((v) => v.abs()).reduce(math.max);
    if (maxAmp > 0.95) {
      for (int i = 0; i < mixed.length; i++) mixed[i] = mixed[i] / maxAmp * 0.9;
    }

    final wav = _toWav(mixed);
    await _player.setAudioSource(_WavSource(wav));
    await _player.seek(Duration.zero);
    await _player.play();
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
