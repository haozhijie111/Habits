import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_analysis_service.dart';
import '../models/pitch_result.dart';

final audioServiceProvider = Provider<AudioAnalysisService>((ref) {
  final service = AudioAnalysisService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pitchStreamProvider = StreamProvider<PitchResult>((ref) {
  final service = ref.watch(audioServiceProvider);
  return service.pitchStream;
});

// 控制录音开关的状态
final isListeningProvider = StateProvider<bool>((ref) => false);
