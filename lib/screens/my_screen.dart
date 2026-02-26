import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../models/check_in_record.dart';
import '../services/check_in_storage.dart';
import '../main.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final checkInRecordsProvider =
    FutureProvider<List<CheckInRecord>>((ref) => CheckInStorage().loadAll());

// ── Screen ────────────────────────────────────────────────────────────────────
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(checkInRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的打卡')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Text('还没有打卡记录\n去打卡页录制吧 🎵',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: KidColors.textMid)),
            );
          }
          // 按日期分组
          final grouped = <String, List<CheckInRecord>>{};
          for (final r in records) {
            final key = DateFormat('yyyy-MM-dd').format(r.createdAt);
            grouped.putIfAbsent(key, () => []).add(r);
          }
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (ctx, i) {
              final date = dates[i];
              final dayRecords = grouped[date]!;
              return _DateGroup(date: date, records: dayRecords, onDeleted: () {
                ref.invalidate(checkInRecordsProvider);
              });
            },
          );
        },
      ),
    );
  }
}

// ── Date Group ────────────────────────────────────────────────────────────────
class _DateGroup extends StatelessWidget {
  final String date;
  final List<CheckInRecord> records;
  final VoidCallback onDeleted;

  const _DateGroup({required this.date, required this.records, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(date,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KidColors.textMid)),
        ),
        ...records.map((r) => _RecordCard(record: r, onDeleted: onDeleted)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Record Card ───────────────────────────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final CheckInRecord record;
  final VoidCallback onDeleted;

  const _RecordCard({required this.record, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(record.createdAt);
    final isVideo = record.type == 'video';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVideo
              ? KidColors.primary.withValues(alpha: 0.15)
              : KidColors.secondary.withValues(alpha: 0.15),
          child: Text(isVideo ? '🎬' : '🎵',
              style: const TextStyle(fontSize: 20)),
        ),
        title: Text(record.songTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$time  ·  得分 ${record.score.toStringAsFixed(0)}',
            style: const TextStyle(color: KidColors.textMid, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline,
                  color: KidColors.primary, size: 28),
              onPressed: () => _openPlayer(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: KidColors.textLight, size: 22),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    if (record.type == 'video') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => _VideoPlayerPage(record: record)));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => _AudioPlayerPage(record: record)));
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条打卡记录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await CheckInStorage().delete(record.id);
                onDeleted();
              },
              child: const Text('删除',
                  style: TextStyle(color: KidColors.red))),
        ],
      ),
    );
  }
}

// ── Audio Player Page ─────────────────────────────────────────────────────────
class _AudioPlayerPage extends StatefulWidget {
  final CheckInRecord record;
  const _AudioPlayerPage({required this.record});

  @override
  State<_AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<_AudioPlayerPage> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.setFilePath(widget.record.filePath).then((_) {
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.record.songTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎵', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            Text(widget.record.songTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('得分 ${widget.record.score.toStringAsFixed(0)}',
                style: const TextStyle(color: KidColors.textMid)),
            const SizedBox(height: 32),
            IconButton(
              iconSize: 64,
              icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
                  color: KidColors.primary),
              onPressed: () => _playing ? _player.pause() : _player.play(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video Player Page ─────────────────────────────────────────────────────────
class _VideoPlayerPage extends StatefulWidget {
  final CheckInRecord record;
  const _VideoPlayerPage({required this.record});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.record.filePath))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.record.songTitle)),
      backgroundColor: Colors.black,
      body: Center(
        child: _initialized
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: _ctrl.value.aspectRatio,
                    child: VideoPlayer(_ctrl),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder(
                    valueListenable: _ctrl,
                    builder: (_, value, __) => IconButton(
                      iconSize: 56,
                      icon: Icon(
                          value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white),
                      onPressed: () =>
                          value.isPlaying ? _ctrl.pause() : _ctrl.play(),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
