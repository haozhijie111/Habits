import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/score_note.dart';
import '../models/song_library.dart';
import '../providers/practice_session_provider.dart';
import '../providers/metronome_provider.dart';
import '../services/song_synthesizer.dart';
import 'widgets/tuner_gauge.dart';
import 'session_result_screen.dart';

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(practiceSessionProvider);
    final metro = ref.watch(metronomeProvider);

    ref.listen(practiceSessionProvider, (prev, next) {
      if (next.state == RecordingState.finished && next.result != null) {
        ref.read(metronomeProvider.notifier).stopBeat();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionResultScreen(result: next.result!),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(
        backgroundColor: KidColors.bg,
        title: const Text('🎵 小笛手练习',
            style: TextStyle(
                color: KidColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _SongSelector(
              currentSong: session.currentSong,
              enabled: session.state != RecordingState.recording,
              onSelect: (song) =>
                  ref.read(practiceSessionProvider.notifier).selectSong(song),
            ),
            _ScoreScrollBar(
              scoreSheet: session.currentSong.notes,
              elapsed: session.elapsed,
              isRecording: session.state == RecordingState.recording,
            ),
            const SizedBox(height: 6),
            TunerGauge(result: session.currentPitch),
            const SizedBox(height: 16),
            _MetronomeBar(metro: metro, bpm: session.currentSong.bpm),
            const SizedBox(height: 16),
            if (session.state == RecordingState.recording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: KidColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '⏱ ${_formatTime(session.elapsed)}',
                  style: const TextStyle(
                      color: KidColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 20),
            _RecordButton(
              state: session.state,
              onStart: () {
                if (metro.enabled) {
                  ref
                      .read(metronomeProvider.notifier)
                      .startWith(metro.bpm);
                }
                ref.read(practiceSessionProvider.notifier).startRecording(
                  bpm: metro.enabled ? metro.bpm : null,
                );
              },
              onStop: () {
                ref.read(metronomeProvider.notifier).stopBeat();
                ref.read(practiceSessionProvider.notifier).stopRecording();
              },
            ),
            const SizedBox(height: 14),
            Text(
              session.state == RecordingState.recording
                  ? '吹完后点停止 🎶'
                  : session.state == RecordingState.idle
                      ? '点击开始练习吧！'
                      : '',
              style: const TextStyle(
                  color: KidColors.textMid,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}

// ── 曲目选择器 ────────────────────────────────────────────────────────────────
class _SongSelector extends StatefulWidget {
  final Song currentSong;
  final bool enabled;
  final ValueChanged<Song> onSelect;

  const _SongSelector({
    required this.currentSong,
    required this.enabled,
    required this.onSelect,
  });

  @override
  State<_SongSelector> createState() => _SongSelectorState();
}

class _SongSelectorState extends State<_SongSelector> {
  final SongSynthesizer _synth = SongSynthesizer();
  String? _previewingId;

  @override
  void dispose() {
    _synth.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(Song song) async {
    if (_previewingId == song.id) {
      await _synth.stop();
      setState(() => _previewingId = null);
      return;
    }
    await _synth.stop();
    setState(() => _previewingId = song.id);
    final notes = song.notes.map((n) => (note: n.note, time: n.time, duration: n.duration)).toList();
    await _synth.play(notes);
    if (mounted) setState(() => _previewingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final songs = SongLibrary.all;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final song = songs[i];
          final isSelected = song.id == widget.currentSong.id;
          final isPreviewing = _previewingId == song.id;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: widget.enabled ? () => widget.onSelect(song) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? KidColors.primary : KidColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? KidColors.primary : KidColors.textLight,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: KidColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(song.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        song.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : KidColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 试听按钮
              GestureDetector(
                onTap: () => _togglePreview(song),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isPreviewing
                        ? KidColors.secondary
                        : KidColors.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isPreviewing ? '⏹' : '🔊',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 节拍器控件 ────────────────────────────────────────────────────────────────
class _MetronomeBar extends ConsumerWidget {
  final MetronomeState metro;
  final int bpm;

  const _MetronomeBar({required this.metro, required this.bpm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(metronomeProvider.notifier);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 开关按钮
              GestureDetector(
                onTap: () => notifier.toggle(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: metro.enabled
                        ? KidColors.secondary
                        : KidColors.textLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(metro.enabled ? '🥁' : '🔇',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        metro.enabled ? '节拍器 开' : '节拍器 关',
                        style: TextStyle(
                          color: metro.enabled ? Colors.white : KidColors.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // BPM 调节
              _BpmControl(bpm: metro.bpm, notifier: notifier),
            ],
          ),
          // 音量滑块（仅开启时显示）
          if (metro.enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('🔈', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: KidColors.secondary,
                      inactiveTrackColor: KidColors.textLight.withValues(alpha: 0.3),
                      thumbColor: KidColors.secondary,
                      overlayColor: KidColors.secondary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: metro.volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) => notifier.setVolume(v),
                    ),
                  ),
                ),
                const Text('🔊', style: TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BpmControl extends StatelessWidget {
  final int bpm;
  final MetronomeNotifier notifier;
  const _BpmControl({required this.bpm, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BpmBtn(label: '−', onTap: notifier.bpmDown),
        Container(
          width: 64,
          alignment: Alignment.center,
          child: Text(
            '$bpm BPM',
            style: const TextStyle(
                color: KidColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w800),
          ),
        ),
        _BpmBtn(label: '+', onTap: notifier.bpmUp),
      ],
    );
  }
}

class _BpmBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BpmBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: KidColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: KidColors.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ── 简谱滚动条 ────────────────────────────────────────────────────────────────
class _ScoreScrollBar extends StatefulWidget {
  final List<ScoreNote> scoreSheet;
  final double elapsed;
  final bool isRecording;

  const _ScoreScrollBar({
    required this.scoreSheet,
    required this.elapsed,
    required this.isRecording,
  });

  @override
  State<_ScoreScrollBar> createState() => _ScoreScrollBarState();
}

class _ScoreScrollBarState extends State<_ScoreScrollBar> {
  final _controller = ScrollController();
  static const double _noteWidth = 64.0;

  @override
  void didUpdateWidget(_ScoreScrollBar old) {
    super.didUpdateWidget(old);
    if (widget.isRecording) _scrollToCurrent();
  }

  void _scrollToCurrent() {
    int activeIdx = 0;
    for (int i = 0; i < widget.scoreSheet.length; i++) {
      if (widget.scoreSheet[i].time <= widget.elapsed) activeIdx = i;
    }
    final target = (activeIdx * _noteWidth - 120).clamp(0.0, double.infinity);
    _controller.animateTo(target,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.scoreSheet.length,
        itemBuilder: (_, i) {
          final note = widget.scoreSheet[i];
          final isActive = widget.elapsed >= note.time &&
              widget.elapsed < note.time + note.duration;
          final isPast = widget.elapsed >= note.time + note.duration;

          return SizedBox(
            width: _noteWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? KidColors.primary
                        : isPast
                            ? KidColors.secondary.withValues(alpha: 0.3)
                            : KidColors.bg,
                    border: Border.all(
                      color: isActive
                          ? KidColors.primary
                          : isPast
                              ? KidColors.secondary
                              : KidColors.textLight,
                      width: isActive ? 3 : 1.5,
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: KidColors.primary.withValues(alpha: 0.4), blurRadius: 10)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      note.note,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : isPast
                                ? KidColors.secondary
                                : KidColors.textMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: KidColors.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ── 录制按钮 ──────────────────────────────────────────────────────────────────
class _RecordButton extends StatelessWidget {
  final RecordingState state;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _RecordButton({
    required this.state,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = state == RecordingState.recording;
    return GestureDetector(
      onTap: isRecording ? onStop : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? KidColors.red : KidColors.primary,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? KidColors.red : KidColors.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            isRecording ? '⏹' : '▶',
            style: const TextStyle(fontSize: 36),
          ),
        ),
      ),
    );
  }
}
