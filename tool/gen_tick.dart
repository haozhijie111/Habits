import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

void main() {
  const sampleRate = 44100;
  const durationMs = 80;
  const freq = 880.0;
  final numSamples = (sampleRate * durationMs / 1000).round();

  final samples = Int16List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final envelope = exp(-t * 40.0);
    final v = (envelope * sin(2 * pi * freq * t) * 28000).round();
    samples[i] = v.clamp(-32768, 32767);
  }

  final dataSize = numSamples * 2;
  final header = ByteData(44);
  // RIFF
  [0x52,0x49,0x46,0x46].asMap().forEach((i,b) => header.setUint8(i, b));
  header.setUint32(4, 36 + dataSize, Endian.little);
  [0x57,0x41,0x56,0x45].asMap().forEach((i,b) => header.setUint8(8+i, b));
  // fmt
  [0x66,0x6D,0x74,0x20].asMap().forEach((i,b) => header.setUint8(12+i, b));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  // data
  [0x64,0x61,0x74,0x61].asMap().forEach((i,b) => header.setUint8(36+i, b));
  header.setUint32(40, dataSize, Endian.little);

  final out = File('assets/sounds/metronome_tick.wav');
  final sink = out.openSync(mode: FileMode.write);
  sink.writeFromSync(header.buffer.asUint8List());
  sink.writeFromSync(samples.buffer.asUint8List());
  sink.closeSync();
  print('Generated: ${out.path} (${out.lengthSync()} bytes)');
}
