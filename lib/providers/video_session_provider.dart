import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/video_recording_service.dart';
import '../services/ffmpeg_composer_service.dart';
import '../services/check_in_storage.dart';
import '../models/check_in_record.dart';

enum VideoState { idle, recording, processing, done, error }

enum CheckInMode { video, audio }

class VideoSession {
  final VideoState state;
  final CheckInMode mode;
  final String? outputPath;
  final String? errorMsg;
  final double progress;

  const VideoSession({
    this.state = VideoState.idle,
    this.mode = CheckInMode.video,
    this.outputPath,
    this.errorMsg,
    this.progress = 0,
  });

  VideoSession copyWith({
    VideoState? state,
    CheckInMode? mode,
    String? outputPath,
    String? errorMsg,
    double? progress,
  }) =>
      VideoSession(
        state: state ?? this.state,
        mode: mode ?? this.mode,
        outputPath: outputPath ?? this.outputPath,
        errorMsg: errorMsg ?? this.errorMsg,
        progress: progress ?? this.progress,
      );
}

class VideoSessionNotifier extends StateNotifier<VideoSession> {
  final VideoRecordingService _video;
  final FFmpegComposerService _composer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final CheckInStorage _storage = CheckInStorage();
  String _songTitle = '打卡';

  VideoSessionNotifier(this._video, this._composer)
      : super(const VideoSession());

  Future<void> initialize() => _video.initialize();

  void setMode(CheckInMode mode) {
    state = state.copyWith(mode: mode);
  }

  Future<void> startRecording() async {
    if (state.mode == CheckInMode.video) {
      await _video.startRecording();
    } else {
      // 检查并请求麦克风权限
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(state: VideoState.error, errorMsg: '需要麦克风权限才能录音');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'checkin_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    }
    state = state.copyWith(state: VideoState.recording);
  }

  void setSongTitle(String title) => _songTitle = title;

  Future<void> stopAndCompose({
    required double score,
    String? bgmPath,
  }) async {
    final now = DateTime.now();
    if (state.mode == CheckInMode.audio) {
      final audioPath = await _audioRecorder.stop();
      if (audioPath != null) {
        await _storage.save(CheckInRecord(
          id: now.millisecondsSinceEpoch.toString(),
          createdAt: now,
          filePath: audioPath,
          type: 'checkin_audio',
          score: score,
          songTitle: _songTitle,
        ));
      }
      state = state.copyWith(
        state: VideoState.done,
        outputPath: audioPath,
        progress: 1,
      );
      return;
    }

    final rawPath = await _video.stopRecording();
    if (rawPath == null) {
      state = state.copyWith(state: VideoState.error, errorMsg: '录制文件丢失');
      return;
    }

    state = state.copyWith(state: VideoState.processing, progress: 0);

    final date = DateFormat('yyyy-MM-dd').format(now);
    final out = await _composer.compose(
      videoPath: rawPath,
      bgmPath: bgmPath,
      score: score,
      date: date,
    );

    if (out != null) {
      await _storage.save(CheckInRecord(
        id: now.millisecondsSinceEpoch.toString(),
        createdAt: now,
        filePath: out,
        type: 'checkin_video',
        score: score,
        songTitle: _songTitle,
      ));
      state = state.copyWith(state: VideoState.done, outputPath: out, progress: 1);
    } else {
      state = state.copyWith(state: VideoState.error, errorMsg: 'FFmpeg 合成失败');
    }
  }

  void reset() {
    state = VideoSession(mode: state.mode);
  }

  VideoRecordingService get cameraService => _video;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _video.dispose();
    super.dispose();
  }
}

final videoSessionProvider =
    StateNotifierProvider<VideoSessionNotifier, VideoSession>((ref) {
  final notifier = VideoSessionNotifier(
    VideoRecordingService(),
    FFmpegComposerService(),
  );
  notifier.initialize();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

