import 'package:camera/camera.dart';

class VideoRecordingService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high, // 720p
      enableAudio: true,
    );
    await _controller!.initialize();
  }

  Future<String?> startRecording() async {
    if (_controller == null || !isInitialized || isRecording) return null;
    await _controller!.startVideoRecording();
    return null;
  }

  /// 停止录制，返回原始视频文件路径
  Future<String?> stopRecording() async {
    if (!isRecording) return null;
    final file = await _controller!.stopVideoRecording();
    return file.path;
  }

  /// 切换前后摄像头
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _controller!.description;
    final next = _cameras.firstWhere((c) => c != current, orElse: () => _cameras.first);
    await _controller?.dispose();
    _controller = CameraController(next, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();
  }

  void dispose() {
    _controller?.dispose();
  }
}
