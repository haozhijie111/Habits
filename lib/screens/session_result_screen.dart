import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/score_note.dart';
import '../models/check_in_record.dart';
import '../providers/practice_session_provider.dart';
import '../services/check_in_storage.dart';

class SessionResultScreen extends ConsumerStatefulWidget {
  final SessionResult result;
  final String songTitle;
  final String? audioPath;

  const SessionResultScreen({
    super.key,
    required this.result,
    required this.songTitle,
    this.audioPath,
  });

  @override
  ConsumerState<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.audioPath != null) {
      _saveCheckIn();
    }
  }

  Future<void> _saveCheckIn() async {
    final record = CheckInRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      filePath: widget.audioPath!,
      type: 'practice',
      score: widget.result.pitchScore,
      songTitle: widget.songTitle,
    );
    await CheckInStorage().save(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(
        backgroundColor: KidColors.bg,
        automaticallyImplyLeading: false,
        title: const Text('🎉 练习结果',
            style: TextStyle(
                color: KidColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _ScoreSummary(result: widget.result),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('📝 每个音的表现',
                  style: TextStyle(
                      color: KidColors.textMid,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _NoteList(judgements: widget.result.judgements)),
          if (widget.audioPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: KidColors.green, size: 16),
                  const SizedBox(width: 6),
                  const Text('已保存到我的打卡',
                      style: TextStyle(color: KidColors.green, fontSize: 13)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(practiceSessionProvider.notifier).reset();
                  Navigator.pop(context);
                },
                child: const Text('🔄 再练一次'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  final SessionResult result;
  const _ScoreSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.pitchScore;
    final (emoji, label, bg, border) = _scoreStyle(score);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
              color: border.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 4),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: border,
              height: 1,
            ),
          ),
          Text(label,
              style: TextStyle(
                  color: border,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip('⭐', '完美', result.perfectCount, KidColors.green),
              _StatChip('👍', '良好', result.goodCount, KidColors.secondary),
              _StatChip('🎯', '偏差', result.offCount, KidColors.primary),
              _StatChip('😅', '漏音', result.missedCount, KidColors.red),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('正确率',
                      style: TextStyle(
                          color: KidColors.textMid,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('${result.accuracyRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: border,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: result.accuracyRate / 100,
                  backgroundColor: KidColors.textLight.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(border),
                  minHeight: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, String, Color, Color) _scoreStyle(double s) {
    if (s >= 80) return ('🏆', '太棒了！', const Color(0xFFFFFDE7), const Color(0xFFFFB300));
    if (s >= 60) return ('🌟', '很不错！', const Color(0xFFE8F5E9), KidColors.green);
    return ('💪', '继续加油！', const Color(0xFFFCE4EC), KidColors.pink);
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.emoji, this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text('$count',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                color: KidColors.textMid, fontSize: 11)),
      ],
    );
  }
}

class _NoteList extends StatelessWidget {
  final List<NoteJudgement> judgements;
  const _NoteList({required this.judgements});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: judgements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _NoteRow(judgement: judgements[i], index: i),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final NoteJudgement judgement;
  final int index;
  const _NoteRow({required this.judgement, required this.index});

  static const _gradeEmoji = {
    NoteGrade.perfect: '⭐',
    NoteGrade.good: '👍',
    NoteGrade.off: '🎯',
    NoteGrade.missed: '😅',
  };
  static const _gradeLabel = {
    NoteGrade.perfect: '完美',
    NoteGrade.good: '良好',
    NoteGrade.off: '偏差',
    NoteGrade.missed: '漏音',
  };
  static const _gradeColor = {
    NoteGrade.perfect: KidColors.green,
    NoteGrade.good: KidColors.secondary,
    NoteGrade.off: KidColors.primary,
    NoteGrade.missed: KidColors.red,
  };

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor[judgement.grade]!;
    final offsetText = judgement.isMissed
        ? '--'
        : '${judgement.avgCentsOffset >= 0 ? '+' : ''}'
            '${judgement.avgCentsOffset.toStringAsFixed(0)}c';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Text(judgement.target.note,
              style: const TextStyle(
                  color: KidColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (!judgement.isMissed) ...[
            const SizedBox(width: 6),
            const Text('→',
                style: TextStyle(color: KidColors.textLight, fontSize: 14)),
            const SizedBox(width: 6),
            Text(judgement.playedNote ?? '',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
          const Spacer(),
          Text(offsetText,
              style: const TextStyle(
                  color: KidColors.textLight, fontSize: 11)),
          const SizedBox(width: 10),
          Text(_gradeEmoji[judgement.grade]!,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(_gradeLabel[judgement.grade]!,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
