import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/fft_utils.dart';

class FFTScreen extends StatefulWidget {
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

  @override
  State<FFTScreen> createState() => _FFTScreenState();
}

class _FFTScreenState extends State<FFTScreen> {
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

  late List<FFTResult> _results;
  double? _cursorFreq;

  @override
  void initState() {
    super.initState();
    final sampleRate = 1.0 / widget.periodSeconds;
    _results = [];
    for (final sig in widget.signals) {
      final end = (widget.windowEnd + 1).clamp(0, sig.values.length);
      final segment = sig.values.sublist(widget.windowStart, end);
      _results.add(FftUtils.computeFFT(segment, sampleRate));
    }
  }

  double get _maxFreq {
    double m = 0;
    for (final r in _results) {
      if (r.frequencies.isNotEmpty && r.frequencies.last > m) {
        m = r.frequencies.last;
      }
    }
    return m == 0 ? 1 : m;
  }

  void _onTapUp(TapUpDetails details, double width, double leftMargin, double rightMargin) {
    final plotWidth = width - leftMargin - rightMargin;
    final localX = details.localPosition.dx - leftMargin;
    final fraction = (localX / plotWidth).clamp(0.0, 1.0);
    setState(() {
      _cursorFreq = fraction * _maxFreq;
    });
  }

  List<double> _magnitudeAtCursor() {
    if (_cursorFreq == null) return [];
    final values = <double>[];
    for (final r in _results) {
      if (r.frequencies.isEmpty) {
        values.add(0);
        continue;
      }
      int closestIndex = 0;
      double closestDist = double.infinity;
      for (int i = 0; i < r.frequencies.length; i++) {
        final dist = (r.frequencies[i] - _cursorFreq!).abs();
        if (dist < closestDist) {
          closestDist = dist;
          closestIndex = i;
        }
      }
      values.add(r.magnitudes[closestIndex]);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final cursorMags = _magnitudeAtCursor();

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
                for (int i = 0; i < widget.signals.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          color: _palette[i % _palette.length]),
                      const SizedBox(width: 4),
                      Text(widget.signals[i].name,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_cursorFreq != null)
              Card(
                color: Colors.deepOrange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fréquence : ${_cursorFreq!.toStringAsFixed(2)} Hz",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      for (int i = 0; i < widget.signals.length; i++)
                        Text(
                          "  ${widget.signals[i].name} : ${cursorMags[i].toStringAsFixed(4)}",
                          style: TextStyle(
                              fontSize: 11,
                              color: _palette[i % _palette.length]),
                        ),
                    ],
                  ),
                ),
              )
            else
              const Text(
                  "Touchez le graphique pour placer le curseur de fréquence.",
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const leftMargin = 55.0;
                  const rightMargin = 8.0;
                  return GestureDetector(
                    onTapUp: (d) => _onTapUp(
                        d, constraints.maxWidth, leftMargin, rightMargin),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _FFTPainter(
                        results: _results,
                        colors: _palette,
                        cursorFreq: _cursorFreq,
                        maxFreq: _maxFreq,
                      ),
                    ),
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
  final double? cursorFreq;
  final double maxFreq;

  _FFTPainter({
    required this.results,
    required this.colors,
    required this.cursorFreq,
    required this.maxFreq,
  });

  static const double leftMargin = 55.0;
  static const double rightMargin = 8.0;
  static const double bottomMargin = 25.0;
  static const double topMargin = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    double maxMag = 0;
    for (final r in results) {
      for (final m in r.magnitudes) {
        if (m > maxMag) maxMag = m;
      }
    }
    if (maxMag == 0) maxMag = 1;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topMargin + plotHeight * i / 4;
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
        final y = topMargin +
            plotHeight -
            (result.magnitudes[i] / maxMag) * plotHeight;
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

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftMargin, topMargin),
        Offset(leftMargin, topMargin + plotHeight), axisPaint);
    canvas.drawLine(
        Offset(leftMargin, topMargin + plotHeight),
        Offset(leftMargin + plotWidth, topMargin + plotHeight),
        axisPaint);

    if (cursorFreq != null) {
      final x = leftMargin + (cursorFreq! / maxFreq) * plotWidth;
      final cursorPaint = Paint()
        ..color = Colors.deepOrange
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), cursorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FFTPainter oldDelegate) => true;
}