import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'pitch_detector.dart';
import '../models/pitch_result.dart';

class AudioAnalysisService {
  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector();

  StreamController<PitchResult>? _pitchController;
  StreamSubscription<Uint8List>? _audioSub;

  Stream<PitchResult> get pitchStream =>
      _pitchController?.stream ?? const Stream.empty();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    _pitchController = StreamController<PitchResult>.broadcast();
    _isRunning = true;

    try {
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );

      // 累积缓冲区，凑够 4096 个样本再分析
      final buffer = <int>[];
      const targetBytes = 4096 * 2; // 16-bit = 2 bytes/sample

      _audioSub = audioStream.listen((chunk) {
        buffer.addAll(chunk);
        if (buffer.length >= targetBytes) {
          final slice = buffer.sublist(0, targetBytes);
          buffer.removeRange(0, targetBytes);

          compute(_detectInBackground, _DetectArgs(
            pcmBytes: slice,
            sampleRate: 44100,
            bufferSize: 4096,
          )).then((result) {
            if (_isRunning) _pitchController?.add(result);
          });
        }
      });
    } catch (e) {
      debugPrint('AudioAnalysisService.start error: $e');
      _isRunning = false;
      await _pitchController?.close();
      _pitchController = null;
      return false;
    }

    return true;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _audioSub?.cancel();
    await _recorder.stop();
    await _pitchController?.close();
    _pitchController = null;
  }

  void dispose() {
    stop();
    _recorder.dispose();
  }
}

// isolate 入口（顶层函数）
PitchResult _detectInBackground(_DetectArgs args) {
  final detector = PitchDetector(
    sampleRate: args.sampleRate,
    bufferSize: args.bufferSize,
  );
  return detector.detect(args.pcmBytes);
}

class _DetectArgs {
  final List<int> pcmBytes;
  final int sampleRate;
  final int bufferSize;
  const _DetectArgs({
    required this.pcmBytes,
    required this.sampleRate,
    required this.bufferSize,
  });
}
