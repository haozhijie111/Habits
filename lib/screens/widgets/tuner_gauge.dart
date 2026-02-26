import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/pitch_result.dart';

/// 音准指针仪表盘
class TunerGauge extends StatelessWidget {
  final PitchResult result;

  const TunerGauge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 音符名称
        Text(
          result.noteName,
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        // 频率显示
        Text(
          result.frequency > 0
              ? '${result.frequency.toStringAsFixed(1)} Hz'
              : '-- Hz',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 24),
        // 指针仪表盘
        SizedBox(
          width: 280,
          height: 140,
          child: CustomPaint(
            painter: _GaugePainter(
              offset: result.offsetPercent,
              isActive: result.confidence > 0.1,
              isInTune: result.isInTune,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // cents 偏移文字
        _CentsLabel(cents: result.centsOffset, isActive: result.confidence > 0.1),
      ],
    );
  }
}

class _CentsLabel extends StatelessWidget {
  final double cents;
  final bool isActive;

  const _CentsLabel({required this.cents, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Text('等待吹奏...', style: TextStyle(color: Colors.white38, fontSize: 14));
    }
    final sign = cents >= 0 ? '+' : '';
    final color = cents.abs() <= 25 ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
    return Text(
      '$sign${cents.toStringAsFixed(1)} cents',
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double offset; // -1.0 ~ 1.0
  final bool isActive;
  final bool isInTune;

  _GaugePainter({
    required this.offset,
    required this.isActive,
    required this.isInTune,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final radius = size.width / 2 - 10;

    // 背景弧
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi, pi, false, bgPaint,
    );

    // 绿色中心区域（±25 cents）
    final greenPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi + pi * 0.375, pi * 0.25, false, greenPaint,
    );

    // 刻度线
    _drawTicks(canvas, cx, cy, radius);

    // 指针
    if (isActive) {
      final angle = pi + pi * (0.5 + offset * 0.5);
      final needleColor = isInTune ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
      final needlePaint = Paint()
        ..color = needleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final tipX = cx + (radius - 10) * cos(angle);
      final tipY = cy + (radius - 10) * sin(angle);
      canvas.drawLine(Offset(cx, cy), Offset(tipX, tipY), needlePaint);

      // 指针圆心
      canvas.drawCircle(
        Offset(cx, cy), 6,
        Paint()..color = needleColor,
      );
    }
  }

  void _drawTicks(Canvas canvas, double cx, double cy, double radius) {
    final tickPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.5;

    for (int i = -5; i <= 5; i++) {
      final angle = pi + pi * (0.5 + i / 10.0);
      final isMain = i == 0;
      final inner = radius - (isMain ? 20 : 12);
      final outer = radius + 2;
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        tickPaint..strokeWidth = isMain ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.offset != offset || old.isActive != isActive || old.isInTune != isInTune;
}
