import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/video_session_provider.dart';

/// 摄像头预览层
class CameraPreviewLayer extends StatelessWidget {
  final VideoSessionNotifier notifier;
  const CameraPreviewLayer({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final controller = notifier.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }
    return CameraPreview(controller);
  }
}

/// 顶部工具栏
class RecordTopBar extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onSwitch;
  final VoidCallback onBack;
  const RecordTopBar({
    super.key,
    required this.isRecording,
    required this.onSwitch,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            RecordIconBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
            const Spacer(),
            if (!isRecording)
              RecordIconBtn(icon: Icons.flip_camera_ios_outlined, onTap: onSwitch),
          ],
        ),
      ),
    );
  }
}

class RecordIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const RecordIconBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 录制中实时音符悬浮提示
class LiveNoteOverlay extends StatelessWidget {
  final String noteName;
  final double centsOffset;
  final bool isInTune;
  const LiveNoteOverlay({
    super.key,
    required this.noteName,
    required this.centsOffset,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    final color = isInTune ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              noteName,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${centsOffset >= 0 ? '+' : ''}${centsOffset.toStringAsFixed(0)}c',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// FFmpeg 处理中遮罩
class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 20),
            Text('正在合成视频...', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// 底部录制控制区
class BottomControls extends StatelessWidget {
  final VideoState videoState;
  final double? practiceScore;
  final VoidCallback onStartStop;
  final VoidCallback onReset;

  const BottomControls({
    super.key,
    required this.videoState,
    required this.practiceScore,
    required this.onStartStop,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32, left: 40, right: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 完成后显示得分
            if (videoState == VideoState.done && practiceScore != null) ...[
              Text(
                '得分 ${practiceScore!.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 重置按钮（完成后显示）
                if (videoState == VideoState.done) ...[
                  CircleBtn(
                    icon: Icons.refresh,
                    color: Colors.white24,
                    size: 52,
                    onTap: onReset,
                  ),
                  const SizedBox(width: 32),
                ],
                // 主录制按钮
                RecordBtn(state: videoState, onTap: onStartStop),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecordBtn extends StatelessWidget {
  final VideoState state;
  final VoidCallback onTap;
  const RecordBtn({super.key, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRecording = state == VideoState.recording;
    final isProcessing = state == VideoState.processing;

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: isRecording
              ? const Color(0xFFFF5722)
              : isProcessing
                  ? Colors.white24
                  : Colors.transparent,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isRecording ? 24 : 52,
            height: isRecording ? 24 : 52,
            decoration: BoxDecoration(
              color: isRecording ? const Color(0xFFFF5722) : Colors.white,
              borderRadius: BorderRadius.circular(isRecording ? 4 : 26),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const CircleBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
