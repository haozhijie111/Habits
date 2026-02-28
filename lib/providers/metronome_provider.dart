import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _keyEnabled = 'metro_enabled';
  static const _keyVolume  = 'metro_volume';
  static const _keyBpm     = 'metro_bpm';

  MetronomeNotifier(this._service) : super(const MetronomeState()) {
    _service.init();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final volume  = prefs.getDouble(_keyVolume) ?? 0.8;
    final bpm     = prefs.getInt(_keyBpm) ?? 80;
    _service.setEnabled(enabled);
    _service.setVolume(volume);
    _service.setBpm(bpm);
    state = MetronomeState(enabled: enabled, volume: volume, bpm: bpm);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, state.enabled);
    await prefs.setDouble(_keyVolume, state.volume);
    await prefs.setInt(_keyBpm, state.bpm);
  }

  void toggle() {
    final next = !state.enabled;
    _service.setEnabled(next);
    state = state.copyWith(enabled: next);
    _savePrefs();
  }

  void setVolume(double v) {
    _service.setVolume(v);
    state = state.copyWith(volume: v);
    _savePrefs();
  }

  void setBpm(int bpm) {
    final clamped = bpm.clamp(40, 240);
    _service.setBpm(clamped);
    state = state.copyWith(bpm: clamped);
    _savePrefs();
  }

  void bpmUp() => setBpm(state.bpm + 5);
  void bpmDown() => setBpm(state.bpm - 5);

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
