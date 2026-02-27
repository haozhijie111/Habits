import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';

// ── 音符定义 ──────────────────────────────────────────────────────────────────
class _FluteNote {
  final String solfege;
  final String noteName;
  final Color color;
  const _FluteNote({required this.solfege, required this.noteName, required this.color});
}

const _notes = [
  _FluteNote(solfege: '1',  noteName: 'C4', color: Color(0xFFFF6B6B)),
  _FluteNote(solfege: '2',  noteName: 'D4', color: Color(0xFFFF9F43)),
  _FluteNote(solfege: '3',  noteName: 'E4', color: Color(0xFFFFE030)),
  _FluteNote(solfege: '4',  noteName: 'F4', color: Color(0xFF69D44B)),
  _FluteNote(solfege: '5',  noteName: 'G4', color: Color(0xFF4ECDC4)),
  _FluteNote(solfege: '6',  noteName: 'A4', color: Color(0xFFB388FF)),
  _FluteNote(solfege: '7',  noteName: 'B4', color: Color(0xFFFF8FAB)),
  _FluteNote(solfege: "1'", noteName: 'C5', color: Color(0xFFFF6B6B)),
  _FluteNote(solfege: "2'", noteName: 'D5', color: Color(0xFFFF9F43)),
  _FluteNote(solfege: "3'", noteName: 'E5', color: Color(0xFFFFE030)),
];

// ── 音频合成 ──────────────────────────────────────────────────────────────────
double _noteToFreq(String note) {
  const m = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  final r = RegExp(r'^([A-G][#b]?)(\d)$').firstMatch(note);
  if (r == null) return 440.0;
  final midi = (int.parse(r.group(2)!) + 1) * 12 + (m[r.group(1)!] ?? 0);
  return 440.0 * math.pow(2, (midi - 69) / 12);
}

Uint8List _buildWav(String noteName) {
  const sr = 22050;
  const dur = 0.65;
  final freq = _noteToFreq(noteName);
  final n = (dur * sr).round();
  final fade = (sr * 0.015).round();
  final s = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    double a = 0.55;
    if (i < fade) a *= i / fade;
    if (i > n - fade) a *= (n - i) / fade;
    s[i] = a * (0.55 * math.sin(2 * math.pi * freq * i / sr) +
        0.28 * math.sin(4 * math.pi * freq * i / sr) +
        0.12 * math.sin(6 * math.pi * freq * i / sr) +
        0.05 * math.sin(8 * math.pi * freq * i / sr));
  }
  final ds = n * 2;
  final b = ByteData(44 + ds);
  for (final e in {0: 0x52, 1: 0x49, 2: 0x46, 3: 0x46}.entries) b.setUint8(e.key, e.value);
  b.setUint32(4, 36 + ds, Endian.little);
  for (final e in {8: 0x57, 9: 0x41, 10: 0x56, 11: 0x45}.entries) b.setUint8(e.key, e.value);
  for (final e in {12: 0x66, 13: 0x6D, 14: 0x74, 15: 0x20}.entries) b.setUint8(e.key, e.value);
  b.setUint32(16, 16, Endian.little); b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little); b.setUint32(24, sr, Endian.little);
  b.setUint32(28, sr * 2, Endian.little); b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  for (final e in {36: 0x64, 37: 0x61, 38: 0x74, 39: 0x61}.entries) b.setUint8(e.key, e.value);
  b.setUint32(40, ds, Endian.little);
  for (int i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (s[i] * 32767).clamp(-32768, 32767).toInt(), Endian.little);
  }
  return b.buffer.asUint8List();
}


// ── 主页面 ────────────────────────────────────────────────────────────────────
class FluteKeyboardScreen extends StatefulWidget {
  const FluteKeyboardScreen({super.key});
  @override
  State<FluteKeyboardScreen> createState() => _FluteKeyboardScreenState();
}

class _FluteKeyboardScreenState extends State<FluteKeyboardScreen> {
  final _player = AudioPlayer();
  String? _active;
  final List<String> _history = [];

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _play(_FluteNote note) async {
    setState(() {
      _active = note.noteName;
      _history.add(note.solfege);
      if (_history.length > 24) _history.removeAt(0);
    });
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/flute_note.wav');
    await file.writeAsBytes(_buildWav(note.noteName));
    await _player.setFilePath(file.path);
    await _player.seek(Duration.zero);
    await _player.play();
    await Future.delayed(const Duration(milliseconds: 550));
    if (mounted && _active == note.noteName) setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidColors.bg,
      appBar: AppBar(title: const Text('🎶 玩笛子')),
      body: Column(
        children: [
          _HistoryBar(history: _history, onClear: () => setState(() => _history.clear())),
          const SizedBox(height: 6),
          _FluteBody(activeNote: _active),
          const SizedBox(height: 10),
          Expanded(child: _KeyGrid(activeNote: _active, onTap: _play)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── 历史条 ────────────────────────────────────────────────────────────────────
class _HistoryBar extends StatelessWidget {
  final List<String> history;
  final VoidCallback onClear;
  const _HistoryBar({required this.history, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: history.isEmpty
                ? const Text('点下面的按钮开始演奏 🎵',
                    style: TextStyle(color: KidColors.textLight, fontSize: 13))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: history.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(history[i],
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900,
                              color: KidColors.primary)),
                    ),
                  ),
          ),
          if (history.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear, size: 18, color: KidColors.textLight),
            ),
        ],
      ),
    );
  }
}

// ── 笛子管身图示 ──────────────────────────────────────────────────────────────
class _FluteBody extends StatelessWidget {
  final String? activeNote;
  const _FluteBody({this.activeNote});

  @override
  Widget build(BuildContext context) {
    final activeIdx = activeNote == null
        ? -1
        : _notes.indexWhere((n) => n.noteName == activeNote);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: KidColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 吹口
              Container(
                width: 22, height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A853),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Center(child: Text('💨', style: TextStyle(fontSize: 9))),
              ),
              // 管身
              Expanded(
                child: Container(
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFD4A853), Color(0xFFB8860B)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_notes.length, (i) {
                      final active = i == activeIdx;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: active ? 20 : 14,
                        height: active ? 20 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? _notes[i].color : const Color(0xFF5C3D11),
                          boxShadow: active
                              ? [BoxShadow(color: _notes[i].color.withValues(alpha: 0.7), blurRadius: 10)]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // 笛尾
              Container(
                width: 10, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8860B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          if (activeIdx >= 0) ...[
            const SizedBox(height: 5),
            Text(
              '♪  ${_notes[activeIdx].solfege}  ·  ${_notes[activeIdx].noteName}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _notes[activeIdx].color),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 音符按键网格 ──────────────────────────────────────────────────────────────
class _KeyGrid extends StatelessWidget {
  final String? activeNote;
  final void Function(_FluteNote) onTap;
  const _KeyGrid({required this.activeNote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 两行排列：低音 1-5 / 高音 6-3'
    final row1 = _notes.sublist(0, 5);
    final row2 = _notes.sublist(5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _KeyRow(notes: row1, activeNote: activeNote, onTap: onTap),
          _KeyRow(notes: row2, activeNote: activeNote, onTap: onTap),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<_FluteNote> notes;
  final String? activeNote;
  final void Function(_FluteNote) onTap;
  const _KeyRow({required this.notes, required this.activeNote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: notes.map((n) => _NoteKey(note: n, active: activeNote == n.noteName, onTap: onTap)).toList(),
    );
  }
}

class _NoteKey extends StatelessWidget {
  final _FluteNote note;
  final bool active;
  final void Function(_FluteNote) onTap;
  const _NoteKey({required this.note, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(note),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: active ? 68 : 62,
        height: active ? 68 : 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? note.color : note.color.withValues(alpha: 0.18),
          border: Border.all(color: note.color, width: active ? 3 : 2),
          boxShadow: active
              ? [BoxShadow(color: note.color.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2)]
              : [const BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              note.solfege,
              style: TextStyle(
                fontSize: note.solfege.length > 1 ? 18 : 24,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : note.color,
              ),
            ),
            Text(
              note.noteName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white70 : note.color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
