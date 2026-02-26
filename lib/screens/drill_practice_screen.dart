import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/drill_lesson.dart';
import '../providers/drill_session_provider.dart';
import 'drill_result_screen.dart';

class DrillPracticeScreen extends ConsumerStatefulWidget {
  const DrillPracticeScreen({super.key});

  @override
  ConsumerState<DrillPracticeScreen> createState() =>
      _DrillPracticeScreenState();
}

class _DrillPracticeScreenState extends ConsumerState<DrillPracticeScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(drillSessionProvider);
    final notifier = ref.read(drillSessionProvider.notifier);

    ref.listen(drillSessionProvider, (prev, next) {
      if (next.state == DrillState.finished && next.result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => DrillResultScreen(
                    result: next.result!,
                    audioPath: next.audioPath,
                  )),
        );
      }
      if (next.errorMsg != null && next.errorMsg != prev?.errorMsg) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMsg!),
          backgroundColor: KidColors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    });

    final lesson = session.lesson;
    if (lesson == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(
        backgroundColor: KidColors.bg,
        leading: GestureDetector(
          onTap: () {
            notifier.reset();
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('←', style: TextStyle(fontSize: 24)),
          ),
        ),
        title: Text('🎵 ${lesson.title}',
            style: const TextStyle(
                color: KidColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        actions: [
          if (session.state == DrillState.recording)
            GestureDetector(
              onTap: () => notifier.stopEarly(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: KidColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('结束',
                    style: TextStyle(
                        color: KidColors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _NoteDisplay(session: session),
          const SizedBox(height: 20),
          _BeatRow(lesson: lesson, currentIndex: session.currentBeatIndex),
          const SizedBox(height: 28),
          _StatusArea(session: session, notifier: notifier),
          const Spacer(),
          _ProgressBar(session: session, lesson: lesson),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NoteDisplay extends StatelessWidget {
  final DrillSession session;
  const _NoteDisplay({required this.session});

  @override
  Widget build(BuildContext context) {
    final pitch = session.currentPitch;
    final hasSound = pitch.confidence > 0.1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasSound ? pitch.noteName : '--',
            style: TextStyle(
              color: hasSound ? KidColors.primary : KidColors.textLight,
              fontSize: 52,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasSound) ...[
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pitch.isInTune ? '✅ 准了！' : '🎯 调整一下',
                  style: TextStyle(
                    color:
                        pitch.isInTune ? KidColors.green : KidColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pitch.centsOffset >= 0 ? '+' : ''}${pitch.centsOffset.toStringAsFixed(0)} cents',
                  style: const TextStyle(
                      color: KidColors.textMid, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BeatRow extends StatelessWidget {
  final DrillLesson lesson;
  final int currentIndex;
  const _BeatRow({required this.lesson, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(lesson.beats.length, (i) {
            final beat = lesson.beats[i];
            final isActive = i == currentIndex;
            final isDone = i < currentIndex;
            final isLong = beat.type == BeatType.long;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: isLong ? 64 : 40,
              height: isLong ? 64 : 40,
              decoration: BoxDecoration(
                color: isActive
                    ? KidColors.primary
                    : isDone
                        ? KidColors.secondary.withValues(alpha: 0.4)
                        : KidColors.card,
                borderRadius: BorderRadius.circular(isLong ? 16 : 10),
                border: Border.all(
                  color: isActive
                      ? KidColors.primary
                      : isDone
                          ? KidColors.secondary
                          : KidColors.textLight,
                  width: isActive ? 3 : 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: KidColors.primary.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  isDone ? '✓' : isLong ? '—' : '♩',
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : isDone
                            ? KidColors.secondary
                            : KidColors.textMid,
                    fontSize: isLong ? 20 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatusArea extends ConsumerWidget {
  final DrillSession session;
  final DrillSessionNotifier notifier;
  const _StatusArea({required this.session, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (session.state) {
      DrillState.idle => _IdleControls(session: session, notifier: notifier),
      DrillState.countdown => _CountdownWidget(count: session.countdown),
      DrillState.recording => _RecordingIndicator(elapsed: session.elapsed),
      _ => const SizedBox.shrink(),
    };
  }
}

class _IdleControls extends StatelessWidget {
  final DrillSession session;
  final DrillSessionNotifier notifier;
  const _IdleControls({required this.session, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 录音开关
        GestureDetector(
          onTap: () => notifier.setRecordAudio(!session.recordAudio),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: session.recordAudio
                  ? KidColors.primary.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: session.recordAudio ? KidColors.primary : KidColors.textLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.recordAudio ? '🎙' : '🔇',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  session.recordAudio ? '录音 开' : '录音 关',
                  style: TextStyle(
                    color: session.recordAudio ? KidColors.primary : KidColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 开始按钮
        GestureDetector(
          onTap: () => notifier.startCountdown(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: KidColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: KidColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text('▶', style: TextStyle(color: Colors.white, fontSize: 32)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '点击开始练习',
          style: TextStyle(color: KidColors.textMid, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CountdownWidget extends StatelessWidget {
  final int count;
  const _CountdownWidget({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: KidColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: KidColors.accent.withValues(alpha: 0.5),
                  blurRadius: 20)
            ],
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: KidColors.textDark,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '听节拍，准备好～',
          style: TextStyle(
              color: KidColors.textMid,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final double elapsed;
  const _RecordingIndicator({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: KidColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
                color: KidColors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '吹奏中  ${elapsed.toStringAsFixed(1)}s',
            style: const TextStyle(
                color: KidColors.red,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final DrillSession session;
  final DrillLesson lesson;
  const _ProgressBar({required this.session, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final total = lesson.totalDuration;
    final progress =
        total == 0 ? 0.0 : (session.elapsed / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: KidColors.textLight.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(KidColors.secondary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${session.elapsed.toStringAsFixed(1)}s',
                  style: const TextStyle(
                      color: KidColors.textLight, fontSize: 11)),
              Text('${total.toStringAsFixed(1)}s',
                  style: const TextStyle(
                      color: KidColors.textLight, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
