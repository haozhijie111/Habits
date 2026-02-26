import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../main.dart';
import '../models/song_library.dart';
import '../providers/video_session_provider.dart';
import '../providers/practice_session_provider.dart';
import '../providers/metronome_provider.dart';
import 'widgets/record_widgets.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  @override
  Widget build(BuildContext context) {
    final videoSession = ref.watch(videoSessionProvider);
    final practiceSession = ref.watch(practiceSessionProvider);
    final metro = ref.watch(metronomeProvider);
    final isRecording = videoSession.state == VideoState.recording;

    ref.listen(videoSessionProvider, (prev, next) {
      if (next.state == VideoState.done) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.mode == CheckInMode.video ? '视频已保存到相册' : '音频打卡已保存'),
          backgroundColor: const Color(0xFF4CAF50),
        ));
      }
      if (next.state == VideoState.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMsg ?? '未知错误'),
          backgroundColor: const Color(0xFFFF5722),
        ));
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景：视频模式显示摄像头，音频模式显示纯色
          if (videoSession.mode == CheckInMode.video)
            CameraPreviewLayer(notifier: ref.read(videoSessionProvider.notifier))
          else
            Container(color: const Color(0xFF1A1A2E)),

          // 顶部工具栏
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(
              mode: videoSession.mode,
              isRecording: isRecording,
              onSwitchCamera: () =>
                  ref.read(videoSessionProvider.notifier).cameraService.switchCamera(),
              onToggleMode: isRecording
                  ? null
                  : () {
                      final next = videoSession.mode == CheckInMode.video
                          ? CheckInMode.audio
                          : CheckInMode.video;
                      ref.read(videoSessionProvider.notifier).setMode(next);
                    },
            ),
          ),

          // 录制前：设置面板（曲目 + 节拍器）
          if (!isRecording && videoSession.state == VideoState.idle)
            Positioned(
              top: 100, left: 0, right: 0,
              child: _SetupPanel(metro: metro),
            ),

          // 录制中：实时音符提示
          if (isRecording)
            Positioned(
              top: 100, left: 0, right: 0,
              child: LiveNoteOverlay(
                noteName: practiceSession.currentPitch.noteName,
                centsOffset: practiceSession.currentPitch.centsOffset,
                isInTune: practiceSession.currentPitch.isInTune,
              ),
            ),

          // 处理中遮罩
          if (videoSession.state == VideoState.processing)
            const ProcessingOverlay(),

          // 底部控制区
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BottomControls(
              videoState: videoSession.state,
              practiceScore: practiceSession.result?.pitchScore,
              onStartStop: () => _handleStartStop(ref, videoSession.state, practiceSession),
              onReset: () {
                ref.read(videoSessionProvider.notifier).reset();
                ref.read(practiceSessionProvider.notifier).reset();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartStop(
    WidgetRef ref,
    VideoState videoState,
    PracticeSession practiceSession,
  ) async {
    final videoNotifier = ref.read(videoSessionProvider.notifier);
    final practiceNotifier = ref.read(practiceSessionProvider.notifier);
    final metroNotifier = ref.read(metronomeProvider.notifier);
    final metro = ref.read(metronomeProvider);
    final session = ref.read(practiceSessionProvider);

    if (videoState == VideoState.idle || videoState == VideoState.done) {
      if (metro.enabled) {
        metroNotifier.startWith(session.currentSong.bpm);
      }
      await Future.wait([
        videoNotifier.startRecording(),
        practiceNotifier.startRecording(),
      ]);
    } else if (videoState == VideoState.recording) {
      metroNotifier.stopBeat();
      await practiceNotifier.stopRecording();
      final score = ref.read(practiceSessionProvider).result?.pitchScore ?? 0;
      await videoNotifier.stopAndCompose(score: score);
    }
  }
}

// ── 顶部工具栏 ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final CheckInMode mode;
  final bool isRecording;
  final VoidCallback onSwitchCamera;
  final VoidCallback? onToggleMode;

  const _TopBar({
    required this.mode,
    required this.isRecording,
    required this.onSwitchCamera,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Spacer(),
            // 模式切换按钮
            if (onToggleMode != null)
              GestureDetector(
                onTap: onToggleMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode == CheckInMode.video ? '📹 视频' : '🎙 音频',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.swap_horiz, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            if (!isRecording && mode == CheckInMode.video) ...[
              const SizedBox(width: 8),
              RecordIconBtn(icon: Icons.flip_camera_ios_outlined, onTap: onSwitchCamera),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 录制前设置面板（曲目 + 节拍器）────────────────────────────────────────────
class _SetupPanel extends ConsumerWidget {
  final MetronomeState metro;
  const _SetupPanel({required this.metro});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(practiceSessionProvider);
    final songs = SongLibrary.all;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 曲目选择
          const Text('🎵 选择曲目',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final song = songs[i];
                final selected = song.id == session.currentSong.id;
                return GestureDetector(
                  onTap: () => ref.read(practiceSessionProvider.notifier).selectSong(song),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF7C4DFF) : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFF7C4DFF) : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '${song.emoji} ${song.title}',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 节拍器设置
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(metronomeProvider.notifier).toggle(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: metro.enabled ? const Color(0xFF4CAF50) : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      metro.enabled ? '🥁 节拍器 开' : '🔇 节拍器 关',
                      style: TextStyle(
                        color: metro.enabled ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${session.currentSong.bpm} BPM',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                if (metro.enabled) ...[
                  const Text('🔈', style: TextStyle(fontSize: 13)),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF4CAF50),
                        overlayColor: const Color(0x224CAF50),
                      ),
                      child: Slider(
                        value: metro.volume,
                        min: 0,
                        max: 1,
                        onChanged: (v) => ref.read(metronomeProvider.notifier).setVolume(v),
                      ),
                    ),
                  ),
                  const Text('🔊', style: TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
