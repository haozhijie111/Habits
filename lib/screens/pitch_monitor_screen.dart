import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../models/pitch_result.dart';
import 'widgets/tuner_gauge.dart';

class PitchMonitorScreen extends ConsumerWidget {
  const PitchMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isListening = ref.watch(isListeningProvider);
    final pitchAsync = ref.watch(pitchStreamProvider);

    final result = pitchAsync.when(
      data: (r) => r,
      loading: () => PitchResult.empty,
      error: (_, __) => PitchResult.empty,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('实时音准检测', style: TextStyle(color: Colors.white70)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // 仪表盘
          TunerGauge(result: result),
          const SizedBox(height: 48),
          // 笛子音域参考
          _NoteReferenceBar(currentNote: result.noteName),
          const Spacer(),
          // 开始/停止按钮
          _ListenButton(
            isListening: isListening,
            onToggle: () => _toggleListening(ref, isListening),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _toggleListening(WidgetRef ref, bool isListening) async {
    final service = ref.read(audioServiceProvider);
    if (isListening) {
      await service.stop();
      ref.read(isListeningProvider.notifier).state = false;
    } else {
      final ok = await service.start();
      if (ok) ref.read(isListeningProvider.notifier).state = true;
    }
  }
}

class _ListenButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onToggle;

  const _ListenButton({required this.isListening, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? const Color(0xFFFF5722) : const Color(0xFF4CAF50),
          boxShadow: [
            BoxShadow(
              color: (isListening ? const Color(0xFFFF5722) : const Color(0xFF4CAF50))
                  .withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

/// 笛子常用音域参考条
class _NoteReferenceBar extends StatelessWidget {
  final String currentNote;

  const _NoteReferenceBar({required this.currentNote});

  static const _fluteNotes = ['D4', 'E4', 'F#4', 'G4', 'A4', 'B4', 'C5', 'D5', 'E5'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('笛子常用音域',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _fluteNotes.map((note) {
              final isActive = currentNote == note;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isActive
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: isActive ? const Color(0xFF4CAF50) : Colors.white12,
                  ),
                ),
                child: Center(
                  child: Text(
                    note,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
