import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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

void genSong(String filename, List<(String, double, double)> notes) {
  final totalDuration = notes.map((n) => n.$2 + n.$3).reduce(math.max) + 0.3;
  final totalSamples = (totalDuration * _sr).round();
  final mixed = List<double>.filled(totalSamples, 0.0);

  for (final n in notes) {
    final samples = _synthNote(_noteToFreq(n.$1), n.$3);
    final start = (n.$2 * _sr).round();
    for (int i = 0; i < samples.length; i++) {
      final idx = start + i;
      if (idx < totalSamples) mixed[idx] += samples[i];
    }
  }

  final maxAmp = mixed.map((v) => v.abs()).reduce(math.max);
  if (maxAmp > 0.95) {
    for (int i = 0; i < mixed.length; i++) mixed[i] = mixed[i] / maxAmp * 0.9;
  }

  final wav = _toWav(mixed);
  File('assets/sounds/$filename').writeAsBytesSync(wav);
  print('Generated assets/sounds/$filename  (${totalDuration.toStringAsFixed(2)}s)');
}

void main() {
  // 小星星
  genSong('song_twinkle.wav', [
    ('D4', 0.0,  0.5), ('D4', 0.5,  0.5), ('A4', 1.0,  0.5), ('A4', 1.5,  0.5),
    ('B4', 2.0,  0.5), ('B4', 2.5,  0.5), ('A4', 3.0,  1.0),
    ('G4', 4.0,  0.5), ('G4', 4.5,  0.5), ('F#4', 5.0, 0.5), ('F#4', 5.5, 0.5),
    ('E4', 6.0,  0.5), ('E4', 6.5,  0.5), ('D4', 7.0,  1.0),
  ]);

  // 新年好
  genSong('song_happy_new_year.wav', [
    ('G4', 0.0,  0.5), ('E4', 0.5,  0.5), ('G4', 1.0,  0.5), ('G4', 1.5,  0.5),
    ('E4', 2.0,  0.5), ('G4', 2.5,  0.5),
    ('A4', 3.0,  0.33), ('A4', 3.33, 0.33), ('A4', 3.66, 0.34),
    ('G4', 4.0,  0.5), ('A4', 4.5,  0.5), ('G4', 5.0,  1.0),
    ('G4', 6.0,  0.5), ('G4', 6.5,  0.5), ('A4', 7.0,  0.5), ('G4', 7.5,  0.5),
    ('E4', 8.0,  1.0),
    ('F4', 9.0,  0.33), ('F4', 9.33, 0.33), ('F4', 9.66, 0.34),
    ('E4', 10.0, 0.5), ('F4', 10.5, 0.5), ('E4', 11.0, 1.0),
  ]);

  // 红河谷
  genSong('song_red_river.wav', [
    ('E4', 0.0,  0.5), ('G4', 0.5,  0.5), ('G4', 1.0,  0.5), ('A4', 1.5,  0.5),
    ('G4', 2.0,  0.5), ('A4', 2.5,  0.5), ('C5', 3.0,  1.0),
    ('G4', 4.0,  1.0), ('E4', 5.0,  0.5), ('G4', 5.5,  0.5),
    ('A4', 6.0,  0.5), ('G4', 6.5,  0.5), ('E4', 7.0,  0.5), ('D4', 7.5,  0.5),
    ('C4', 8.0,  1.5),
    ('E4', 9.5,  0.5), ('G4', 10.0, 0.5), ('G4', 10.5, 0.5), ('A4', 11.0, 0.5),
    ('G4', 11.5, 0.5), ('A4', 12.0, 0.5), ('C5', 12.5, 1.0),
    ('G4', 13.5, 1.0), ('E4', 14.5, 0.5), ('G4', 15.0, 0.5),
    ('A4', 15.5, 0.5), ('G4', 16.0, 0.5), ('E4', 16.5, 0.5), ('D4', 17.0, 0.5),
    ('C4', 17.5, 2.0),
  ]);

  print('Done!');
}
