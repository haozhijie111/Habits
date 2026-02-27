import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import '../models/pitch_result.dart';

/// 音符名称映射（MIDI 音符编号 -> 名称）
const List<String> _noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F',
  'F#', 'G', 'G#', 'A', 'A#', 'B'
];

class PitchDetector {
  final int sampleRate;
  final int bufferSize;

  PitchDetector({
    this.sampleRate = 44100,
    this.bufferSize = 4096,
  });

  /// 从 PCM 16-bit 字节数组中检测音高
  PitchResult detect(List<int> pcmBytes) {
    if (pcmBytes.length < bufferSize * 2) return PitchResult.empty;

    // 1. 将 PCM bytes 转换为 float 样本
    final samples = _pcmToFloat(pcmBytes);

    // 2. 计算 RMS 能量，过滤静音
    final rms = _calcRms(samples);
    if (rms < 0.03) return PitchResult.empty;

    // 3. 加 Hann 窗，减少频谱泄漏
    final windowed = _applyHannWindow(samples);

    // 4. 执行 FFT
    final fft = FFT(windowed.length);
    final freq = fft.realFft(windowed);

    // 5. 找到主频率
    final dominantFreq = _findDominantFrequency(freq);
    if (dominantFreq < 130 || dominantFreq > 2100) return PitchResult.empty;

    // 6. 映射到音符
    final midiNote = _freqToMidi(dominantFreq);
    final noteName = _midiToNoteName(midiNote.round());
    final centsOffset = _calcCentsOffset(dominantFreq, midiNote);

    // 置信度基于 RMS 能量
    final confidence = (rms * 10).clamp(0.0, 1.0);

    return PitchResult(
      frequency: dominantFreq,
      noteName: noteName,
      centsOffset: centsOffset,
      confidence: confidence,
    );
  }

  /// PCM 16-bit little-endian -> [-1.0, 1.0]
  List<double> _pcmToFloat(List<int> bytes) {
    final result = <double>[];
    for (int i = 0; i + 1 < bytes.length && result.length < bufferSize; i += 2) {
      final sample = (bytes[i + 1] << 8) | bytes[i];
      final signed = sample > 32767 ? sample - 65536 : sample;
      result.add(signed / 32768.0);
    }
    return result;
  }

  /// 计算 RMS 能量
  double _calcRms(List<double> samples) {
    final sum = samples.fold(0.0, (acc, s) => acc + s * s);
    return sqrt(sum / samples.length);
  }

  /// Hann 窗函数
  List<double> _applyHannWindow(List<double> samples) {
    final n = samples.length;
    return List.generate(n, (i) {
      final window = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      return samples[i] * window;
    });
  }

  /// 从 FFT 结果中找主频率（使用抛物线插值提高精度）
  double _findDominantFrequency(Float64x2List freq) {
    final magnitudes = List.generate(
      freq.length,
      (i) => sqrt(freq[i].x * freq[i].x + freq[i].y * freq[i].y),
    );

    // 只看有效频率范围（130Hz ~ 2100Hz）
    final minBin = (130.0 * bufferSize / sampleRate).round();
    final maxBin = (2100.0 * bufferSize / sampleRate).round().clamp(0, magnitudes.length - 1);

    int peakBin = minBin;
    double peakMag = 0;
    for (int i = minBin; i <= maxBin; i++) {
      if (magnitudes[i] > peakMag) {
        peakMag = magnitudes[i];
        peakBin = i;
      }
    }

    // 抛物线插值，提高频率精度
    if (peakBin > 0 && peakBin < magnitudes.length - 1) {
      final alpha = magnitudes[peakBin - 1];
      final beta = magnitudes[peakBin];
      final gamma = magnitudes[peakBin + 1];
      final correction = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
      return (peakBin + correction) * sampleRate / bufferSize;
    }

    return peakBin * sampleRate / bufferSize.toDouble();
  }

  /// 频率 -> MIDI 音符编号（含小数，用于计算 cents）
  double _freqToMidi(double freq) {
    return 69.0 + 12.0 * log(freq / 440.0) / log(2);
  }

  /// MIDI 编号 -> 音符名称（如 69 -> "A4"）
  String _midiToNoteName(int midi) {
    final octave = (midi ~/ 12) - 1;
    final note = _noteNames[midi % 12];
    return '$note$octave';
  }

  /// 计算偏离标准音高的 cents（-50 ~ +50）
  double _calcCentsOffset(double freq, double midiFloat) {
    final nearestMidi = midiFloat.round();
    final standardFreq = 440.0 * pow(2, (nearestMidi - 69) / 12.0);
    return 1200.0 * log(freq / standardFreq) / log(2);
  }
}
