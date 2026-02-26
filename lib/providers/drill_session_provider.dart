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
  final int countdown;
  final PitchResult currentPitch;
  final DrillResult? result;
  final int currentBeatIndex;
  final String? audioPath;
  final bool recordAudio;
  final String? errorMsg;
  final int repeatCount;   // 循环次数设置
  final int currentRepeat; // 当前第几次
  final int bpmOverride;   // 用户自定义BPM（0=用课程默认）

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
    this.repeatCount = 3,
    this.currentRepeat = 0,
    this.bpmOverride = 0,
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
    int? repeatCount,
    int? currentRepeat,
    int? bpmOverride,
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
        repeatCount: repeatCount ?? this.repeatCount,
        currentRepeat: currentRepeat ?? this.currentRepeat,
        bpmOverride: bpmOverride ?? this.bpmOverride,
      );

  int get effectiveBpm => bpmOverride > 0 ? bpmOverride : (lesson?.bpm ?? 80);
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
    state = DrillSession(
      lesson: lesson,
      state: DrillState.idle,
      recordAudio: state.recordAudio,
      repeatCount: state.repeatCount,
      bpmOverride: state.bpmOverride,
    );
  }

  void setRecordAudio(bool value) => state = state.copyWith(recordAudio: value);
  void setRepeatCount(int value) => state = state.copyWith(repeatCount: value.clamp(1, 10));
  void setBpmOverride(int value) => state = state.copyWith(bpmOverride: value);

  /// 点击开始：节拍器打2拍倒计时，再正式录音
  Future<void> startCountdown() async {
    if (state.lesson == null) return;
    final bpm = state.effectiveBpm;
    final beatInterval = Duration(milliseconds: (60000 / bpm).round());

    _beatCount = 2;
    state = state.copyWith(state: DrillState.countdown, countdown: _beatCount, currentRepeat: 1);

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

    // 按用户设定 BPM 与课程原始 BPM 的比例缩放进度速度
    final bpm = state.effectiveBpm;
    final speedRatio = bpm / lesson.bpm;

    // 录音阶段继续播放节拍器
    _metronome.setEnabled(true);
    _metronome.setVolume(0.8);
    _metronome.start(bpm: bpm);

    state = state.copyWith(
      state: DrillState.recording,
      elapsed: 0,
      currentBeatIndex: 0,
    );

    final totalWithRepeats = lesson.totalDuration * state.repeatCount;

    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _elapsed += 0.05 * speedRatio;
      // 当前循环内的时间偏移
      final loopDur = lesson.totalDuration;
      final loopElapsed = _elapsed % loopDur;
      final currentRepeat = (_elapsed / loopDur).floor() + 1;

      final beats = lesson.beats;
      int idx = beats.length - 1;
      for (int i = 0; i < beats.length; i++) {
        if (loopElapsed < beats[i].time + beats[i].duration) {
          idx = i;
          break;
        }
      }
      state = state.copyWith(
        elapsed: _elapsed,
        currentBeatIndex: idx,
        currentRepeat: currentRepeat.clamp(1, state.repeatCount),
      );
      if (_elapsed >= totalWithRepeats + 0.3) {
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
    _metronome.stop();
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
    state = DrillSession(
      lesson: state.lesson,
      state: DrillState.idle,
      recordAudio: state.recordAudio,
      repeatCount: state.repeatCount,
      bpmOverride: state.bpmOverride,
    );
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
