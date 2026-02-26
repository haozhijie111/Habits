import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pitch_result.dart';
import '../models/score_note.dart';
import '../models/song_library.dart';
import '../services/audio_analysis_service.dart';
import '../services/score_comparator.dart';

enum RecordingState { idle, recording, finished }

class PracticeSession {
  final RecordingState state;
  final double elapsed;
  final PitchResult currentPitch;
  final SessionResult? result;
  final Song currentSong;

  const PracticeSession({
    this.state = RecordingState.idle,
    this.elapsed = 0,
    this.currentPitch = PitchResult.empty,
    this.result,
    this.currentSong = SongLibrary.twinkleTwinkle,
  });

  PracticeSession copyWith({
    RecordingState? state,
    double? elapsed,
    PitchResult? currentPitch,
    SessionResult? result,
    Song? currentSong,
  }) =>
      PracticeSession(
        state: state ?? this.state,
        elapsed: elapsed ?? this.elapsed,
        currentPitch: currentPitch ?? this.currentPitch,
        result: result ?? this.result,
        currentSong: currentSong ?? this.currentSong,
      );
}

class PracticeSessionNotifier extends StateNotifier<PracticeSession> {
  final AudioAnalysisService _audio;

  ScoreComparator? _comparator;
  Timer? _ticker;
  StreamSubscription<PitchResult>? _pitchSub;
  double _elapsed = 0;

  PracticeSessionNotifier(this._audio) : super(const PracticeSession());

  void selectSong(Song song) {
    if (state.state == RecordingState.recording) return;
    state = PracticeSession(currentSong: song);
  }

  Future<void> startRecording({int? bpm}) async {
    final ok = await _audio.start();
    if (!ok) return;

    // 速度比例：用户 BPM / 曲子原始 BPM，调慢则进度慢
    final speedRatio = (bpm != null && bpm > 0)
        ? bpm / state.currentSong.bpm
        : 1.0;

    _elapsed = 0;
    _comparator = ScoreComparator(scoreSheet: state.currentSong.notes);
    state = state.copyWith(state: RecordingState.recording, elapsed: 0);

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsed += 0.1 * speedRatio;
      state = state.copyWith(elapsed: _elapsed);
    });

    _pitchSub = _audio.pitchStream.listen((pitch) {
      _comparator?.addFrame(_elapsed, pitch);
      state = state.copyWith(currentPitch: pitch);
    });
  }

  Future<void> stopRecording() async {
    _ticker?.cancel();
    await _pitchSub?.cancel();
    await _audio.stop();

    final result = _comparator?.evaluate();
    state = state.copyWith(
      state: RecordingState.finished,
      result: result,
    );
  }

  void reset() {
    _ticker?.cancel();
    _comparator = null;
    _elapsed = 0;
    state = PracticeSession(currentSong: state.currentSong);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pitchSub?.cancel();
    super.dispose();
  }
}

final practiceSessionProvider =
    StateNotifierProvider<PracticeSessionNotifier, PracticeSession>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return PracticeSessionNotifier(audio);
});

final audioServiceProvider = Provider<AudioAnalysisService>((ref) {
  final s = AudioAnalysisService();
  ref.onDispose(() => s.dispose());
  return s;
});
