import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import '../models/drill_lesson.dart';
import '../providers/drill_session_provider.dart';

class DrillResultScreen extends ConsumerWidget {
  final DrillResult result;
  final String? audioPath;
  const DrillResultScreen({super.key, required this.result, this.audioPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(
        backgroundColor: KidColors.bg,
        automaticallyImplyLeading: false,
        title: Text('🏆 ${result.lesson.title} 结果',
            style: const TextStyle(
                color: KidColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _TrophyCard(result: result),
            const SizedBox(height: 20),
            if (audioPath != null) ...[
              _AudioPlayerCard(audioPath: audioPath!),
              const SizedBox(height: 20),
            ],
            _BeatList(result: result),
            const SizedBox(height: 24),
            _ActionButtons(result: result),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  final DrillResult result;
  const _TrophyCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.totalScore;
    final (emoji, label, bg, border) = _scoreStyle(score);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
              color: border.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              color: border,
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
                color: border, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBubble(
                  emoji: '🎵',
                  label: '音准',
                  value: result.pitchScore.toStringAsFixed(1),
                  color: KidColors.primary),
              _StatBubble(
                  emoji: '🥁',
                  label: '节奏',
                  value: result.rhythmScore.toStringAsFixed(1),
                  color: KidColors.secondary),
              _StatBubble(
                  emoji: '🎯',
                  label: '准确率',
                  value: '${result.accuracyRate.toStringAsFixed(0)}%',
                  color: KidColors.purple),
            ],
          ),
        ],
      ),
    );
  }

  (String, String, Color, Color) _scoreStyle(double s) {
    if (s >= 90) return ('🏆', '太棒了！', const Color(0xFFFFFDE7), const Color(0xFFFFB300));
    if (s >= 75) return ('🌟', '很不错！', const Color(0xFFE8F5E9), KidColors.green);
    if (s >= 60) return ('👍', '继续加油！', const Color(0xFFE3F2FD), KidColors.secondary);
    return ('💪', '再练练！', const Color(0xFFFCE4EC), KidColors.pink);
  }
}

class _StatBubble extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _StatBubble(
      {required this.emoji,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: KidColors.textMid, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BeatList extends StatelessWidget {
  final DrillResult result;
  const _BeatList({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '📋 每一拍的表现',
              style: TextStyle(
                  color: KidColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(color: Colors.black12, height: 1),
          ...result.judgements.asMap().entries.map(
              (e) => _BeatRow(index: e.key + 1, judgement: e.value)),
        ],
      ),
    );
  }
}

class _BeatRow extends StatelessWidget {
  final int index;
  final BeatJudgement judgement;
  const _BeatRow({required this.index, required this.judgement});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (judgement.grade) {
      BeatGrade.perfect => ('⭐', '完美', KidColors.green),
      BeatGrade.good    => ('👍', '良好', KidColors.secondary),
      BeatGrade.off     => ('🎯', '偏音', KidColors.primary),
      BeatGrade.missed  => ('😅', '没吹到', KidColors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$index',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            judgement.target.note,
            style: const TextStyle(
                color: KidColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: KidColors.bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              judgement.target.type == BeatType.long ? '长音' : '短音',
              style: const TextStyle(
                  color: KidColors.textLight, fontSize: 10),
            ),
          ),
          const Spacer(),
          if (judgement.hasSound)
            Text(
              '${judgement.avgCentsOffset >= 0 ? '+' : ''}${judgement.avgCentsOffset.toStringAsFixed(0)}c',
              style: const TextStyle(
                  color: KidColors.textLight, fontSize: 11),
            ),
          const SizedBox(width: 10),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── 音频回听播放器 ─────────────────────────────────────────────────────────────
class _AudioPlayerCard extends StatefulWidget {
  final String audioPath;
  const _AudioPlayerCard({required this.audioPath});

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  late final AudioPlayer _player;
  bool _loading = true;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.audioPath);
      _duration = _player.duration ?? Duration.zero;
      _posSub = _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (mounted) {
          setState(() => _playing = s.playing);
          if (s.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
          }
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎙 回听录音',
            style: TextStyle(
                color: KidColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (_playing) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KidColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: KidColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _playing ? '⏸' : '▶',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: KidColors.primary,
                          inactiveTrackColor:
                              KidColors.textLight.withValues(alpha: 0.3),
                          thumbColor: KidColors.primary,
                          overlayColor:
                              KidColors.primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (v) {
                            final ms =
                                (v * _duration.inMilliseconds).round();
                            _player.seek(Duration(milliseconds: ms));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_position),
                                style: const TextStyle(
                                    color: KidColors.textLight, fontSize: 11)),
                            Text(_fmt(_duration),
                                style: const TextStyle(
                                    color: KidColors.textLight, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final DrillResult result;
  const _ActionButtons({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ref.read(drillSessionProvider.notifier).reset();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: KidColors.textMid,
              side: const BorderSide(color: KidColors.textLight, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: const Text('📋 返回列表'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ref.read(drillSessionProvider.notifier).reset();
              Navigator.pop(context);
              ref.read(drillSessionProvider.notifier).startCountdown();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KidColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: const Text('🔄 再练一次'),
          ),
        ),
      ],
    );
  }
}
