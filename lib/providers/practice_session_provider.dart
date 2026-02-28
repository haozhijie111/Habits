import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  final bool recordAudio;
  final String? audioPath;

  const PracticeSession({
    this.state = RecordingState.idle,
    this.elapsed = 0,
    this.currentPitch = PitchResult.empty,
    this.result,
    this.currentSong = SongLibrary.twinkleTwinkle,
    this.recordAudio = false,
    this.audioPath,
  });

  PracticeSession copyWith({
    RecordingState? state,
    double? elapsed,
    PitchResult? currentPitch,
    SessionResult? result,
    Song? currentSong,
    bool? recordAudio,
    String? audioPath,
  }) =>
      PracticeSession(
        state: state ?? this.state,
        elapsed: elapsed ?? this.elapsed,
        currentPitch: currentPitch ?? this.currentPitch,
        result: result ?? this.result,
        currentSong: currentSong ?? this.currentSong,
        recordAudio: recordAudio ?? this.recordAudio,
        audioPath: audioPath,
      );
}

class PracticeSessionNotifier extends StateNotifier<PracticeSession> {
  final AudioAnalysisService _audio;
  final AudioRecorder _recorder = AudioRecorder();

  ScoreComparator? _comparator;
  Timer? _ticker;
  StreamSubscription<PitchResult>? _pitchSub;
  double _elapsed = 0;

  PracticeSessionNotifier(this._audio) : super(const PracticeSession());

  void selectSong(Song song) {
    if (state.state == RecordingState.recording) return;
    state = PracticeSession(currentSong: song, recordAudio: state.recordAudio);
  }

  void setRecordAudio(bool value) => state = state.copyWith(recordAudio: value);

  Future<void> startRecording({int? bpm}) async {
    final ok = await _audio.start();
    if (!ok) return;

    final speedRatio = (bpm != null && bpm > 0)
        ? bpm / state.currentSong.bpm
        : 1.0;

    _elapsed = 0;
    _comparator = ScoreComparator(scoreSheet: state.currentSong.notes);
    state = state.copyWith(state: RecordingState.recording, elapsed: 0, audioPath: null);

    if (state.recordAudio) {
      final dir = await getTemporaryDirectory();
      final audioFile = p.join(dir.path, 'practice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: audioFile);
    }

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

    String? audioPath;
    if (state.recordAudio) {
      audioPath = await _recorder.stop();
    }

    final result = _comparator?.evaluate();
    state = state.copyWith(
      state: RecordingState.finished,
      result: result,
      audioPath: audioPath,
    );
  }

  void reset() {
    _ticker?.cancel();
    _comparator = null;
    _elapsed = 0;
    state = PracticeSession(currentSong: state.currentSong, recordAudio: state.recordAudio);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pitchSub?.cancel();
    _recorder.dispose();
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
