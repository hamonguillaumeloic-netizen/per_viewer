import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/flicker_utils.dart';

class FlickerScreen extends StatelessWidget {
  final PerSignal signal;
  final double periodSeconds;
  final int windowStart;
  final int windowEnd;

  const FlickerScreen({
    super.key,
    required this.signal,
    required this.periodSeconds,
    required this.windowStart,
    required this.windowEnd,
  });

  @override
  Widget build(BuildContext context) {
    final sampleRate = 1.0 / periodSeconds;
    final end = (windowEnd + 1).clamp(0, signal.values.length);
    final segment = signal.values.sublist(windowStart, end);
    final flicker =
        FlickerUtils.computeInstantaneousFlicker(segment, sampleRate);

    final maxFlicker = flicker.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text("Flicker instantané : ${signal.name}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "⚠️ Approximation pédagogique inspirée de la norme IEC 61000-4-15. "
                  "Ce n'est PAS une mesure certifiée conforme — à utiliser uniquement "
                  "à titre de diagnostic indicatif.",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text("Pst approximatif (max) : ${maxFlicker.toStringAsFixed(4)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _FlickerPainter(
                        values: flicker, periodSeconds: periodSeconds),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlickerPainter extends CustomPainter {
  final List<double> values;
  final double periodSeconds;

  _FlickerPainter({required this.values, required this.periodSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    double maxV = 0;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (maxV == 0) maxV = 1;

    const margin = 10.0;
    final plotW = size.width - margin * 2;
    final plotH = size.height - margin * 2;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = margin + i / (values.length - 1) * plotW;
      final y = margin + plotH - (values[i] / maxV) * plotH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.deepOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _FlickerPainter oldDelegate) => true;
}