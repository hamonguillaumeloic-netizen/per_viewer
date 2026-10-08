import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/flicker_utils.dart';

class FlickerScreen extends StatefulWidget {
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
  State<FlickerScreen> createState() => _FlickerScreenState();
}

class _FlickerScreenState extends State<FlickerScreen> {
  static const double _leftMargin = 50.0;
  static const double _rightMargin = 6.0;
  static const double _cursorHitTolerance = 24.0;

  late List<double> _flicker;
  double _maxFlicker = 1;

  int _viewStart = 0;
  int _viewEnd = 1;
  double? _scaleBaseWidth;
  double? _scaleBaseFocalFraction;
  bool _draggingCursor = false;

  int? _cursorIndex;

  @override
  void initState() {
    super.initState();
    final sampleRate = 1.0 / widget.periodSeconds;
    final end = (widget.windowEnd + 1).clamp(0, widget.signal.values.length);
    final segment = widget.signal.values.sublist(widget.windowStart, end);
    _flicker = FlickerUtils.computeInstantaneousFlicker(segment, sampleRate);
    _maxFlicker = _flicker.isEmpty
        ? 1
        : _flicker.reduce((a, b) => a > b ? a : b);
    if (_maxFlicker == 0) _maxFlicker = 1;

    _viewStart = 0;
    _viewEnd = _flicker.length > 1 ? _flicker.length - 1 : 1;
  }

  void _resetZoom() {
    setState(() {
      _viewStart = 0;
      _viewEnd = _flicker.length > 1 ? _flicker.length - 1 : 1;
    });
  }

  double _plotWidth(double width) => width - _leftMargin - _rightMargin;

  double? _cursorPixelX(double width) {
    if (_cursorIndex == null) return null;
    if (_cursorIndex! < _viewStart || _cursorIndex! > _viewEnd) return null;
    final windowLength = (_viewEnd - _viewStart).clamp(1, 1 << 30);
    final plotWidth = _plotWidth(width);
    return _leftMargin + (_cursorIndex! - _viewStart) / windowLength * plotWidth;
  }

  int _indexFromPixelX(double localX, double width) {
    final plotWidth = _plotWidth(width);
    final fraction = ((localX - _leftMargin) / plotWidth).clamp(0.0, 1.0);
    return (_viewStart + fraction * (_viewEnd - _viewStart))
        .round()
        .clamp(0, _flicker.length - 1);
  }

  void _onScaleStart(ScaleStartDetails details, double width) {
    final touchX = details.localFocalPoint.dx;
    final cx = _cursorPixelX(width);

    if (cx != null && (cx - touchX).abs() <= _cursorHitTolerance) {
      _draggingCursor = true;
      return;
    }

    _draggingCursor = false;
    _scaleBaseWidth = (_viewEnd - _viewStart).toDouble();
    final plotWidth = _plotWidth(width);
    _scaleBaseFocalFraction =
        ((touchX - _leftMargin) / plotWidth).clamp(0.0, 1.0);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_draggingCursor && details.pointerCount == 1) {
      final idx = _indexFromPixelX(details.localFocalPoint.dx, width);
      setState(() => _cursorIndex = idx);
      return;
    }

    if (_draggingCursor) return;
    if (_scaleBaseWidth == null) return;

    final total = _flicker.length;
    if (total < 4) return;
    final plotWidth = _plotWidth(width);

    double newWidth = _scaleBaseWidth! / details.scale;
    newWidth = newWidth.clamp(4.0, total.toDouble());

    final focalFraction = _scaleBaseFocalFraction ?? 0.5;
    final focalIndex = _viewStart + focalFraction * (_viewEnd - _viewStart);

    double newStart = focalIndex - focalFraction * newWidth;
    double newEnd = newStart + newWidth;

    if (newStart < 0) {
      newEnd -= newStart;
      newStart = 0;
    }
    if (newEnd > total - 1) {
      newStart -= (newEnd - (total - 1));
      newEnd = (total - 1).toDouble();
    }
    newStart = newStart.clamp(0.0, (total - 1).toDouble());

    final panDx = details.focalPointDelta.dx;
    final panFraction = panDx / plotWidth;
    final panIndices = -panFraction * newWidth;

    newStart += panIndices;
    newEnd += panIndices;
    if (newStart < 0) {
      newEnd -= newStart;
      newStart = 0;
    }
    if (newEnd > total - 1) {
      newStart -= (newEnd - (total - 1));
      newEnd = (total - 1).toDouble();
    }

    setState(() {
      _viewStart = newStart.round().clamp(0, total - 2);
      _viewEnd = newEnd.round().clamp(_viewStart + 1, total - 1);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _draggingCursor = false;
    _scaleBaseWidth = null;
    _scaleBaseFocalFraction = null;
  }

  void _onTapUp(TapUpDetails details, double width) {
    final idx = _indexFromPixelX(details.localPosition.dx, width);
    setState(() => _cursorIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flicker instantané : ${widget.signal.name}"),
        actions: [
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map),
            tooltip: "Réinitialiser le zoom",
          ),
        ],
      ),
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
            Text("Pst approximatif (max) : ${_maxFlicker.toStringAsFixed(4)}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              "Pincer pour zoomer/dézoomer. Maintenez le curseur pour le glisser.",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_cursorIndex != null)
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Builder(builder: (context) {
                    final t = _cursorIndex! * widget.periodSeconds;
                    final v = _flicker[_cursorIndex!];
                    return Text(
                      "t = ${t.toStringAsFixed(4)} s   |   Flicker = ${v.toStringAsFixed(4)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    );
                  }),
                ),
              ),
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
                      painter: _FlickerPainter(
                        values: _flicker,
                        periodSeconds: widget.periodSeconds,
                        viewStart: _viewStart,
                        viewEnd: _viewEnd,
                        cursorIndex: _cursorIndex,
                        maxFlicker: _maxFlicker,
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

class _FlickerPainter extends CustomPainter {
  final List<double> values;
  final double periodSeconds;
  final int viewStart;
  final int viewEnd;
  final int? cursorIndex;
  final double maxFlicker;

  _FlickerPainter({
    required this.values,
    required this.periodSeconds,
    required this.viewStart,
    required this.viewEnd,
    required this.cursorIndex,
    required this.maxFlicker,
  });

  static const double leftMargin = 50.0;
  static const double rightMargin = 6.0;
  static const double bottomMargin = 20.0;
  static const double topMargin = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;
    final windowLength = (viewEnd - viewStart).clamp(1, 1 << 30);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = topMargin + plotHeight * i / 4;
      canvas.drawLine(Offset(leftMargin, y),
          Offset(leftMargin + plotWidth, y), gridPaint);

      final labelValue = maxFlicker * (1 - i / 4);
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

      final idx = viewStart + windowLength * i / 4;
      final timeValue = idx * periodSeconds;
      final tp = TextPainter(
        text: TextSpan(
            text: "${timeValue.toStringAsFixed(2)}s",
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      double tx = x - tp.width / 2;
      if (tx < leftMargin) tx = leftMargin;
      tp.paint(canvas, Offset(tx, topMargin + plotHeight + 4));
    }

    final path = Path();
    bool first = true;
    for (int i = viewStart; i <= viewEnd && i < values.length; i++) {
      final x = leftMargin + (i - viewStart) / windowLength * plotWidth;
      final y = topMargin + plotHeight - (values[i] / maxFlicker) * plotHeight;
      if (first) {
        path.moveTo(x, y);
        first = false;
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

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftMargin, topMargin),
        Offset(leftMargin, topMargin + plotHeight), axisPaint);
    canvas.drawLine(
        Offset(leftMargin, topMargin + plotHeight),
        Offset(leftMargin + plotWidth, topMargin + plotHeight),
        axisPaint);

    if (cursorIndex != null &&
        cursorIndex! >= viewStart &&
        cursorIndex! <= viewEnd) {
      final x = leftMargin + (cursorIndex! - viewStart) / windowLength * plotWidth;
      final cursorPaint = Paint()
        ..color = Colors.deepPurple
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), cursorPaint);

      final handlePaint = Paint()..color = Colors.deepPurple;
      canvas.drawCircle(Offset(x, topMargin + 6), 5, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlickerPainter oldDelegate) => true;
}