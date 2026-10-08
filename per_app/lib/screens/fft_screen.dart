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

  static const double _leftMargin = 55.0;
  static const double _rightMargin = 8.0;
  static const double _cursorHitTolerance = 24.0;

  late List<FFTResult> _results;
  double? _cursorFreq;

  double _viewMinFreq = 0;
  double _viewMaxFreq = 1;
  double? _scaleBaseWidth;
  double? _scaleBaseFocalFraction;
  bool _draggingCursor = false;

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
    _viewMinFreq = 0;
    _viewMaxFreq = _fullMaxFreq;
  }

  double get _fullMaxFreq {
    double m = 0;
    for (final r in _results) {
      if (r.frequencies.isNotEmpty && r.frequencies.last > m) {
        m = r.frequencies.last;
      }
    }
    return m == 0 ? 1 : m;
  }

  void _resetZoom() {
    setState(() {
      _viewMinFreq = 0;
      _viewMaxFreq = _fullMaxFreq;
    });
  }

  double _plotWidth(double width) => width - _leftMargin - _rightMargin;

  double? _cursorPixelX(double width) {
    if (_cursorFreq == null) return null;
    if (_cursorFreq! < _viewMinFreq || _cursorFreq! > _viewMaxFreq) return null;
    final plotWidth = _plotWidth(width);
    final fraction = (_cursorFreq! - _viewMinFreq) / (_viewMaxFreq - _viewMinFreq);
    return _leftMargin + fraction * plotWidth;
  }

  double _freqFromPixelX(double localX, double width) {
    final plotWidth = _plotWidth(width);
    final fraction = ((localX - _leftMargin) / plotWidth).clamp(0.0, 1.0);
    return _viewMinFreq + fraction * (_viewMaxFreq - _viewMinFreq);
  }

  void _onScaleStart(ScaleStartDetails details, double width) {
    final touchX = details.localFocalPoint.dx;
    final cx = _cursorPixelX(width);

    if (cx != null && (cx - touchX).abs() <= _cursorHitTolerance) {
      _draggingCursor = true;
      return;
    }

    _draggingCursor = false;
    _scaleBaseWidth = _viewMaxFreq - _viewMinFreq;
    final plotWidth = _plotWidth(width);
    _scaleBaseFocalFraction =
        ((touchX - _leftMargin) / plotWidth).clamp(0.0, 1.0);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_draggingCursor && details.pointerCount == 1) {
      final freq = _freqFromPixelX(details.localFocalPoint.dx, width);
      setState(() => _cursorFreq = freq);
      return;
    }

    if (_draggingCursor) return;
    if (_scaleBaseWidth == null) return;

    final fullMax = _fullMaxFreq;
    final plotWidth = _plotWidth(width);

    double newWidth = _scaleBaseWidth! / details.scale;
    newWidth = newWidth.clamp(fullMax / 500, fullMax);

    final focalFraction = _scaleBaseFocalFraction ?? 0.5;
    final focalFreq = _viewMinFreq + focalFraction * (_viewMaxFreq - _viewMinFreq);

    double newMin = focalFreq - focalFraction * newWidth;
    double newMax = newMin + newWidth;

    if (newMin < 0) {
      newMax -= newMin;
      newMin = 0;
    }
    if (newMax > fullMax) {
      newMin -= (newMax - fullMax);
      newMax = fullMax;
    }
    newMin = newMin.clamp(0.0, fullMax);

    final panDx = details.focalPointDelta.dx;
    final panFraction = panDx / plotWidth;
    final panFreq = -panFraction * newWidth;

    newMin += panFreq;
    newMax += panFreq;
    if (newMin < 0) {
      newMax -= newMin;
      newMin = 0;
    }
    if (newMax > fullMax) {
      newMin -= (newMax - fullMax);
      newMax = fullMax;
    }

    setState(() {
      _viewMinFreq = newMin.clamp(0.0, fullMax - 0.001);
      _viewMaxFreq = newMax.clamp(_viewMinFreq + 0.001, fullMax);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _draggingCursor = false;
    _scaleBaseWidth = null;
    _scaleBaseFocalFraction = null;
  }

  void _onTapUp(TapUpDetails details, double width) {
    final freq = _freqFromPixelX(details.localPosition.dx, width);
    setState(() => _cursorFreq = freq);
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
      appBar: AppBar(
        title: const Text("FFT"),
        actions: [
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map),
            tooltip: "Réinitialiser le zoom",
          ),
        ],
      ),
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
            const SizedBox(height: 4),
            const Text(
              "Pincer pour zoomer/dézoomer. Maintenez le curseur orange pour le glisser.",
              style: TextStyle(fontSize: 10, color: Colors.grey),
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
                  final width = constraints.maxWidth;
                  return GestureDetector(
                    onScaleStart: (d) => _onScaleStart(d, width),
                    onScaleUpdate: (d) => _onScaleUpdate(d, width),
                    onScaleEnd: _onScaleEnd,
                    onTapUp: (d) => _onTapUp(d, width),
                    child: CustomPaint(
                      size: Size(width, constraints.maxHeight),
                      painter: _FFTPainter(
                        results: _results,
                        colors: _palette,
                        cursorFreq: _cursorFreq,
                        viewMinFreq: _viewMinFreq,
                        viewMaxFreq: _viewMaxFreq,
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
  final double viewMinFreq;
  final double viewMaxFreq;

  _FFTPainter({
    required this.results,
    required this.colors,
    required this.cursorFreq,
    required this.viewMinFreq,
    required this.viewMaxFreq,
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
    final freqRange = (viewMaxFreq - viewMinFreq).clamp(0.0001, double.infinity);

    double maxMag = 0;
    for (final r in results) {
      for (int i = 0; i < r.frequencies.length; i++) {
        if (r.frequencies[i] >= viewMinFreq &&
            r.frequencies[i] <= viewMaxFreq &&
            r.magnitudes[i] > maxMag) {
          maxMag = r.magnitudes[i];
        }
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
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), gridPaint);

      final freqValue = viewMinFreq + freqRange * i / 4;
      final tp = TextPainter(
        text: TextSpan(
            text: "${freqValue.toStringAsFixed(1)}Hz",
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      double tx = x - tp.width / 2;
      if (tx < leftMargin) tx = leftMargin;
      tp.paint(canvas, Offset(tx, size.height - bottomMargin + 4));
    }

    for (int r = 0; r < results.length; r++) {
      final result = results[r];
      final path = Path();
      bool first = true;
      for (int i = 0; i < result.frequencies.length; i++) {
        final f = result.frequencies[i];
        if (f < viewMinFreq || f > viewMaxFreq) continue;
        final x = leftMargin + (f - viewMinFreq) / freqRange * plotWidth;
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

    if (cursorFreq != null &&
        cursorFreq! >= viewMinFreq &&
        cursorFreq! <= viewMaxFreq) {
      final x = leftMargin + (cursorFreq! - viewMinFreq) / freqRange * plotWidth;
      final cursorPaint = Paint()
        ..color = Colors.deepOrange
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), cursorPaint);

      final handlePaint = Paint()..color = Colors.deepOrange;
      canvas.drawCircle(Offset(x, topMargin + 6), 5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FFTPainter oldDelegate) => true;
}