import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

final noteMap = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

double noteToFreq(String name) {
  final m = RegExp(r'^([A-G][#b]?)(\d)$').firstMatch(name)!;
  final note = m.group(1)!;
  final octave = int.parse(m.group(2)!);
  int semitone = noteMap[note[0]]!;
  if (note.length > 1) semitone += note[1] == '#' ? 1 : -1;
  final midi = (octave + 1) * 12 + semitone;
  return 440.0 * math.pow(2, (midi - 69) / 12);
}

Uint8List genWav(String noteName, {double duration = 0.65}) {
  final freq = noteToFreq(noteName);
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
    samples[i] = v.clamp(-1.0, 1.0) == v
        ? (v * 32767).round().clamp(-32768, 32767)
        : (v > 0 ? 32767 : -32768);
  }

  final dataSize = n * 2;
  final buf = ByteData(44 + dataSize);
  // RIFF header
  [0x52, 0x49, 0x46, 0x46].asMap().forEach((i, v) => buf.setUint8(i, v));
  buf.setUint32(4, 36 + dataSize, Endian.little);
  [0x57, 0x41, 0x56, 0x45].asMap().forEach((i, v) => buf.setUint8(8 + i, v));
  // fmt chunk
  [0x66, 0x6D, 0x74, 0x20].asMap().forEach((i, v) => buf.setUint8(12 + i, v));
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);  // PCM
  buf.setUint16(22, 1, Endian.little);  // mono
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  // data chunk
  [0x64, 0x61, 0x74, 0x61].asMap().forEach((i, v) => buf.setUint8(36 + i, v));
  buf.setUint32(40, dataSize, Endian.little);
  for (int i = 0; i < n; i++) {
    buf.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return buf.buffer.asUint8List();
}

void main() {
  // filename -> note name
  final notes = {
    'note_C4': 'C4', 'note_D4': 'D4', 'note_E4': 'E4',
    'note_F4': 'F4', 'note_Fs4': 'F#4', 'note_G4': 'G4',
    'note_A4': 'A4', 'note_B4': 'B4',
    'note_C5': 'C5', 'note_D5': 'D5', 'note_E5': 'E5',
  };

  final outDir = 'assets/sounds';
  for (final entry in notes.entries) {
    final wav = genWav(entry.value);
    final path = '$outDir/${entry.key}.wav';
    File(path).writeAsBytesSync(wav);
    print('Generated $path (${wav.length} bytes)');
  }
  print('Done!');
}
