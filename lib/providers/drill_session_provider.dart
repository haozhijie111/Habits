import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/drill_lesson.dart';
import '../models/pitch_result.dart';
import '../services/audio_analysis_service.dart';
import '../services/metronome_service.dart';
import '../services/drill_comparator.dart';
import 'practice_session_provider.dart';

enum DrillState { idle, countdown, recording, finished }

class DrillSession {
  final DrillState state;
  final DrillLesson? lesson;
  final double elapsed;
  final int countdown;       // 剩余节拍数（倒计时用）
  final PitchResult currentPitch;
  final DrillResult? result;
  final int currentBeatIndex;
  final String? audioPath;
  final bool recordAudio;    // 是否录音
  final String? errorMsg;    // 错误信息

  const DrillSession({
    this.state = DrillState.idle,
    this.lesson,
    this.elapsed = 0,
    this.countdown = 2,
    this.currentPitch = PitchResult.empty,
    this.result,
    this.currentBeatIndex = -1,
    this.audioPath,
    this.recordAudio = false,
    this.errorMsg,
  });

  DrillSession copyWith({
    DrillState? state,
    DrillLesson? lesson,
    double? elapsed,
    int? countdown,
    PitchResult? currentPitch,
    DrillResult? result,
    int? currentBeatIndex,
    String? audioPath,
    bool? recordAudio,
    String? errorMsg,
  }) =>
      DrillSession(
        state: state ?? this.state,
        lesson: lesson ?? this.lesson,
        elapsed: elapsed ?? this.elapsed,
        countdown: countdown ?? this.countdown,
        currentPitch: currentPitch ?? this.currentPitch,
        result: result ?? this.result,
        currentBeatIndex: currentBeatIndex ?? this.currentBeatIndex,
        audioPath: audioPath ?? this.audioPath,
        recordAudio: recordAudio ?? this.recordAudio,
        errorMsg: errorMsg,
      );
}

class DrillSessionNotifier extends StateNotifier<DrillSession> {
  final AudioAnalysisService _audio;
  final AudioRecorder _recorder = AudioRecorder();
  final MetronomeService _metronome = MetronomeService();

  DrillComparator? _comparator;
  Timer? _ticker;
  Timer? _countdownTimer;
  StreamSubscription<PitchResult>? _pitchSub;
  double _elapsed = 0;
  int _beatCount = 0;

  DrillSessionNotifier(this._audio) : super(const DrillSession()) {
    _metronome.init();
  }

  void selectLesson(DrillLesson lesson) {
    state = DrillSession(lesson: lesson, state: DrillState.idle, recordAudio: state.recordAudio);
  }

  void setRecordAudio(bool value) {
    state = state.copyWith(recordAudio: value);
  }

  /// 点击开始：节拍器打2拍倒计时，再正式录音
  Future<void> startCountdown() async {
    if (state.lesson == null) return;
    final bpm = state.lesson!.bpm;
    final beatInterval = Duration(milliseconds: (60000 / bpm).round());

    _beatCount = 2;
    state = state.copyWith(state: DrillState.countdown, countdown: _beatCount);

    // 启动节拍器（强制开启，不依赖用户设置）
    _metronome.setEnabled(true);
    _metronome.setVolume(0.8);
    _metronome.start(bpm: bpm);

    _countdownTimer = Timer.periodic(beatInterval, (t) async {
      _beatCount--;
      if (_beatCount <= 0) {
        t.cancel();
        _metronome.stop();
        await _startRecording();
      } else {
        state = state.copyWith(countdown: _beatCount);
      }
    });
  }

  Future<void> _startRecording() async {
    final lesson = state.lesson!;

    final hasPermission = await _audio.requestPermission();
    if (!hasPermission) {
      state = state.copyWith(state: DrillState.idle, errorMsg: '需要麦克风权限，请在浏览器地址栏允许麦克风访问');
      return;
    }

    final ok = await _audio.start();
    if (!ok) {
      state = state.copyWith(state: DrillState.idle, errorMsg: '麦克风启动失败，请检查设备或浏览器权限');
      return;
    }

    // 仅在用户开启录音时启动文件录音
    if (state.recordAudio) {
      final dir = await getTemporaryDirectory();
      final audioFile = p.join(dir.path, 'drill_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: audioFile,
      );
    }

    _elapsed = 0;
    _comparator = DrillComparator(lesson: lesson);
    state = state.copyWith(
      state: DrillState.recording,
      elapsed: 0,
      currentBeatIndex: 0,
    );

    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _elapsed += 0.05;
      final beats = lesson.beats;
      int idx = beats.length - 1;
      for (int i = 0; i < beats.length; i++) {
        if (_elapsed < beats[i].time + beats[i].duration) {
          idx = i;
          break;
        }
      }
      state = state.copyWith(elapsed: _elapsed, currentBeatIndex: idx);
      if (_elapsed >= lesson.totalDuration + 0.5) {
        _finishRecording();
      }
    });

    _pitchSub = _audio.pitchStream.listen((pitch) {
      _comparator?.addFrame(_elapsed, pitch);
      state = state.copyWith(currentPitch: pitch);
    });
  }

  void _finishRecording() {
    _ticker?.cancel();
    _pitchSub?.cancel();
    _audio.stop();
    _stopFileRecording();

    final result = _comparator?.evaluate();
    state = state.copyWith(
      state: DrillState.finished,
      result: result,
    );
  }

  Future<void> _stopFileRecording() async {
    if (!state.recordAudio) return;
    final path = await _recorder.stop();
    if (path != null) {
      state = state.copyWith(audioPath: path);
    }
  }

  Future<void> stopEarly() async {
    _countdownTimer?.cancel();
    _metronome.stop();
    _finishRecording();
  }

  void reset() {
    _countdownTimer?.cancel();
    _ticker?.cancel();
    _pitchSub?.cancel();
    _metronome.stop();
    _comparator = null;
    _elapsed = 0;
    final lesson = state.lesson;
    final recordAudio = state.recordAudio;
    state = DrillSession(lesson: lesson, state: DrillState.idle, recordAudio: recordAudio);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker?.cancel();
    _pitchSub?.cancel();
    _metronome.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

final drillSessionProvider =
    StateNotifierProvider<DrillSessionNotifier, DrillSession>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return DrillSessionNotifier(audio);
});
