import 'dart:async';
import 'package:just_audio/just_audio.dart';

class MetronomeService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;

  bool _enabled = false;
  double _volume = 0.8;
  int _bpm = 80;

  bool get enabled => _enabled;
  double get volume => _volume;
  int get bpm => _bpm;

  Future<void> init() async {
    await _player.setAsset('assets/sounds/metronome_tick.wav');
    await _player.setVolume(_volume);
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) _stop();
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  void setBpm(int bpm) {
    _bpm = bpm;
    if (_enabled && _timer != null) {
      _stop();
      _start();
    }
  }

  void start({int? bpm}) {
    if (bpm != null) _bpm = bpm;
    if (_enabled) _start();
  }

  void stop() => _stop();

  void _start() {
    _stop();
    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _tick(); // 立即打第一拍
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    _player.seek(Duration.zero).then((_) => _player.play());
  }

  void dispose() {
    _stop();
    _player.dispose();
  }
}
