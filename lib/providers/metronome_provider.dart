import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/metronome_service.dart';

class MetronomeState {
  final bool enabled;
  final double volume;
  final int bpm;

  const MetronomeState({
    this.enabled = false,
    this.volume = 0.8,
    this.bpm = 80,
  });

  MetronomeState copyWith({bool? enabled, double? volume, int? bpm}) =>
      MetronomeState(
        enabled: enabled ?? this.enabled,
        volume: volume ?? this.volume,
        bpm: bpm ?? this.bpm,
      );
}

class MetronomeNotifier extends StateNotifier<MetronomeState> {
  final MetronomeService _service;

  MetronomeNotifier(this._service) : super(const MetronomeState()) {
    _service.init();
  }

  void toggle() {
    final next = !state.enabled;
    _service.setEnabled(next);
    state = state.copyWith(enabled: next);
  }

  void setVolume(double v) {
    _service.setVolume(v);
    state = state.copyWith(volume: v);
  }

  void setBpm(int bpm) {
    final clamped = bpm.clamp(40, 240);
    _service.setBpm(clamped);
    state = state.copyWith(bpm: clamped);
  }

  void bpmUp() => setBpm(state.bpm + 5);
  void bpmDown() => setBpm(state.bpm - 5);

  /// 开始节拍（练习开始时调用，传入当前曲目 BPM）
  void startWith(int bpm) {
    _service.setBpm(bpm);
    _service.start(bpm: bpm);
    state = state.copyWith(bpm: bpm);
  }

  void stopBeat() => _service.stop();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

final metronomeProvider =
    StateNotifierProvider<MetronomeNotifier, MetronomeState>((ref) {
  final svc = MetronomeService();
  ref.onDispose(() => svc.dispose());
  return MetronomeNotifier(svc);
});
