import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/fft_utils.dart';

class FFTScreen extends StatelessWidget {
  final List<PerSignal> signals;
  final double periodSeconds;
  final int windowStart;
  final int windowEnd;

  const FFTScreen({
    super.key,
    required this.signals,
    required this.periodSeconds,
    required this.windowStart,
    required this.windowEnd,
  });

  static const List<Color> _palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final sampleRate = 1.0 / periodSeconds;
    final results = <FFTResult>[];

    for (final sig in signals) {
      final end = (windowEnd + 1).clamp(0, sig.values.length);
      final segment = sig.values.sublist(windowStart, end);
      results.add(FftUtils.computeFFT(segment, sampleRate));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("FFT")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < signals.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          color: _palette[i % _palette.length]),
                      const SizedBox(width: 4),
                      Text(signals[i].name,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _FFTPainter(results: results, colors: _palette),
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

class _FFTPainter extends CustomPainter {
  final List<FFTResult> results;
  final List<Color> colors;

  _FFTPainter({required this.results, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const leftMargin = 55.0;
    const bottomMargin = 25.0;
    final plotWidth = size.width - leftMargin - 8;
    final plotHeight = size.height - bottomMargin - 8;

    double maxFreq = 0;
    double maxMag = 0;
    for (final r in results) {
      if (r.frequencies.isNotEmpty && r.frequencies.last > maxFreq) {
        maxFreq = r.frequencies.last;
      }
      for (final m in r.magnitudes) {
        if (m > maxMag) maxMag = m;
      }
    }
    if (maxFreq == 0) maxFreq = 1;
    if (maxMag == 0) maxMag = 1;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = 8 + plotHeight * i / 4;
      canvas.drawLine(Offset(leftMargin, y),
          Offset(leftMargin + plotWidth, y), gridPaint);

      final labelValue = maxMag * (1 - i / 4);
      final tp = TextPainter(
        text: TextSpan(
            text: labelValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 6));
    }

    for (int i = 0; i <= 4; i++) {
      final x = leftMargin + plotWidth * i / 4;
      final freqValue = maxFreq * i / 4;
      final tp = TextPainter(
        text: TextSpan(
            text: "${freqValue.toStringAsFixed(1)}Hz",
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - 10, size.height - bottomMargin + 4));
    }

    for (int r = 0; r < results.length; r++) {
      final result = results[r];
      final path = Path();
      bool first = true;
      for (int i = 0; i < result.frequencies.length; i++) {
        final x = leftMargin + (result.frequencies[i] / maxFreq) * plotWidth;
        final y =
            8 + plotHeight - (result.magnitudes[i] / maxMag) * plotHeight;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..color = colors[r % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FFTPainter oldDelegate) => true;
}