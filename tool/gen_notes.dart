import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

double noteToFreq(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);

Uint8List genWav(double freq, {double duration = 0.65}) {
  final n = (duration * sampleRate).round();
  final fade = (sampleRate * 0.015).round();
  final samples = List<int>.filled(n, 0);

  for (int i = 0; i < n; i++) {
    double a = 0.55;
    if (i < fade) a *= i / fade;
    if (i > n - fade) a *= (n - i) / fade;
    final v = a * (0.55 * math.sin(2 * math.pi * freq * i / sampleRate) +
        0.28 * math.sin(4 * math.pi * freq * i / sampleRate) +
        0.12 * math.sin(6 * math.pi * freq * i / sampleRate) +
        0.05 * math.sin(8 * math.pi * freq * i / sampleRate));
    samples[i] = (v * 32767).round().clamp(-32768, 32767);
  }

  final dataSize = n * 2;
  final buf = ByteData(44 + dataSize);
  [0x52, 0x49, 0x46, 0x46].asMap().forEach((i, v) => buf.setUint8(i, v));
  buf.setUint32(4, 36 + dataSize, Endian.little);
  [0x57, 0x41, 0x56, 0x45].asMap().forEach((i, v) => buf.setUint8(8 + i, v));
  [0x66, 0x6D, 0x74, 0x20].asMap().forEach((i, v) => buf.setUint8(12 + i, v));
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little);
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  [0x64, 0x61, 0x74, 0x61].asMap().forEach((i, v) => buf.setUint8(36 + i, v));
  buf.setUint32(40, dataSize, Endian.little);
  for (int i = 0; i < n; i++) {
    buf.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return buf.buffer.asUint8List();
}

// MIDI 音符名（用 s 代替 #，方便做文件名）
String midiToName(int midi) {
  const names = ['C', 'Cs', 'D', 'Ds', 'E', 'F', 'Fs', 'G', 'Gs', 'A', 'As', 'B'];
  final octave = (midi ~/ 12) - 1;
  final name = names[midi % 12];
  return '$name$octave';
}

void main() {
  // C4(midi=60) 到 E6(midi=88)，覆盖完整笛子音域
  const midiStart = 60; // C4
  const midiEnd = 88;   // E6

  final outDir = 'assets/sounds';
  for (int midi = midiStart; midi <= midiEnd; midi++) {
    final name = midiToName(midi);
    final freq = noteToFreq(midi);
    final wav = genWav(freq);
    final path = '$outDir/note_$name.wav';
    File(path).writeAsBytesSync(wav);
    print('Generated $path  freq=${freq.toStringAsFixed(2)} Hz');
  }
  print('\nDone! ${midiEnd - midiStart + 1} files generated.');
}
