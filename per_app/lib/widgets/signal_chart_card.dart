import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../per_parser/per_file_parser.dart';
import '../screens/fft_screen.dart';

class SignalChartCard extends StatefulWidget {
  final List<PerSignal> signals;
  final double periodSeconds;
  final String title;

  const SignalChartCard({
    super.key,
    required this.signals,
    required this.periodSeconds,
    required this.title,
  });

  @override
  State<SignalChartCard> createState() => _SignalChartCardState();
}

class _SignalChartCardState extends State<SignalChartCard> {
  final GlobalKey _chartKey = GlobalKey();

  late int _windowStart;
  late int _windowEnd;
  double? _scaleBaseWidth;
  double? _scaleBaseFocalFraction;

  int? _cursor1Index;
  int? _cursor2Index;
  bool _twoCursors = false;
  int _activeCursor = 1;

  static const List<Color> _palette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
  ];

  static const Color _cursor1Color = Colors.black;
  static const Color _cursor2Color = Colors.deepOrange;
  static const double _leftMargin = 50.0;
  static const double _bottomMargin = 20.0;

  int get _totalPoints =>
      widget.signals.isEmpty ? 0 : widget.signals.first.values.length;

  @override
  void initState() {
    super.initState();
    _windowStart = 0;
    _windowEnd = _totalPoints > 1 ? _totalPoints - 1 : 1;
  }

  Color _colorFor(int index) => _palette[index % _palette.length];

  void _resetZoom() {
    setState(() {
      _windowStart = 0;
      _windowEnd = _totalPoints > 1 ? _totalPoints - 1 : 1;
    });
  }

  void _onScaleStart(ScaleStartDetails details, double width) {
    _scaleBaseWidth = (_windowEnd - _windowStart).toDouble();
    final plotWidth = width - _leftMargin - 6;
    _scaleBaseFocalFraction =
        ((details.localFocalPoint.dx - _leftMargin) / plotWidth)
            .clamp(0.0, 1.0);
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_scaleBaseWidth == null) return;
    final total = _totalPoints;
    if (total < 4) return;
    final plotWidth = width - _leftMargin - 6;

    double newWidth = _scaleBaseWidth! / details.scale;
    newWidth = newWidth.clamp(4.0, total.toDouble());

    final focalFraction = _scaleBaseFocalFraction ?? 0.5;
    final focalIndex =
        _windowStart + focalFraction * (_windowEnd - _windowStart);

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
      _windowStart = newStart.round().clamp(0, total - 2);
      _windowEnd = newEnd.round().clamp(_windowStart + 1, total - 1);
    });
  }

  void _onTapUp(TapUpDetails details, double width) {
    final total = _totalPoints;
    if (total == 0) return;
    final plotWidth = width - _leftMargin - 6;
    final localX = details.localPosition.dx - _leftMargin;
    final fraction = (localX / plotWidth).clamp(0.0, 1.0);
    final idx = (_windowStart + fraction * (_windowEnd - _windowStart))
        .round()
        .clamp(0, total - 1);

    setState(() {
      if (_activeCursor == 1) {
        _cursor1Index = idx;
      } else {
        _cursor2Index = idx;
      }
    });
  }

  Future<void> _captureScreenshot() async {
    try {
      final boundary = _chartKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final decoded = img.decodePng(pngBytes);
      if (decoded == null) return;
      final jpgBytes = img.encodeJpg(decoded, quality: 90);

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/graphique_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(jpgBytes);

      await Share.shareXFiles([XFile(filePath)], text: 'Graphique PER Viewer');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur capture : $e")),
        );
      }
    }
  }

  void _openFFT() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FFTScreen(
          signals: widget.signals,
          periodSeconds: widget.periodSeconds,
          windowStart: _windowStart,
          windowEnd: _windowEnd,
        ),
      ),
    );
  }

  List<double> _minMaxOf(PerSignal sig) {
    double minV = double.infinity;
    double maxV = -double.infinity;
    for (final v in sig.values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    return [minV, maxV];
  }

  @override
  Widget build(BuildContext context) {
    if (_totalPoints == 0) {
      return const Center(child: Text("Aucune donnée."));
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                for (int i = 0; i < widget.signals.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: _colorFor(i)),
                      const SizedBox(width: 4),
                      Builder(builder: (context) {
                        final mm = _minMaxOf(widget.signals[i]);
                        return Text(
                          "${widget.signals[i].name} (min=${mm[0].toStringAsFixed(2)}, max=${mm[1].toStringAsFixed(2)})",
                          style: const TextStyle(fontSize: 10),
                        );
                      }),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return RepaintBoundary(
                  key: _chartKey,
                  child: GestureDetector(
                    onScaleStart: (d) => _onScaleStart(d, width),
                    onScaleUpdate: (d) => _onScaleUpdate(d, width),
                    onTapUp: (d) => _onTapUp(d, width),
                    child: Container(
                      height: 260,
                      color: Colors.white,
                      child: CustomPaint(
                        size: Size(width, 260),
                        painter: _ChartPainter(
                          signals: widget.signals,
                          windowStart: _windowStart,
                          windowEnd: _windowEnd,
                          periodSeconds: widget.periodSeconds,
                          cursor1Index: _cursor1Index,
                          cursor2Index: _twoCursors ? _cursor2Index : null,
                          colorFor: _colorFor,
                          cursor1Color: _cursor1Color,
                          cursor2Color: _cursor2Color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _activeCursor = 1),
                  icon: const Icon(Icons.looks_one, size: 16),
                  label: const Text("Curseur 1"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _activeCursor == 1 ? _cursor1Color : null,
                    foregroundColor: _activeCursor == 1 ? Colors.white : null,
                  ),
                ),
                if (_twoCursors)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _activeCursor = 2),
                    icon: const Icon(Icons.looks_two, size: 16),
                    label: const Text("Curseur 2"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _activeCursor == 2 ? _cursor2Color : null,
                      foregroundColor:
                          _activeCursor == 2 ? Colors.white : null,
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("2e curseur", style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _twoCursors,
                      onChanged: (v) => setState(() {
                        _twoCursors = v;
                        if (!v) _cursor2Index = null;
                      }),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.zoom_out_map),
                  tooltip: "Réinitialiser le zoom",
                ),
                IconButton(
                  onPressed: _captureScreenshot,
                  icon: const Icon(Icons.camera_alt),
                  tooltip: "Capturer en JPEG",
                ),
                IconButton(
                  onPressed: _openFFT,
                  icon: const Icon(Icons.graphic_eq),
                  tooltip: "Calculer la FFT",
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCursorInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildCursorInfo() {
    if (_cursor1Index == null) {
      return const Text("Touchez le graphique pour placer le curseur 1.",
          style: TextStyle(fontSize: 11, color: Colors.grey));
    }

    final t1 = _cursor1Index! * widget.periodSeconds;
    final rows = <Widget>[
      Text("Curseur 1 (noir) : t = ${t1.toStringAsFixed(4)} s",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ];

    for (int i = 0; i < widget.signals.length; i++) {
      final v1 = widget.signals[i].values[_cursor1Index!];
      rows.add(Text("  ${widget.signals[i].name} : ${v1.toStringAsFixed(4)}",
          style: TextStyle(fontSize: 11, color: _colorFor(i))));
    }

    if (_cursor2Index != null) {
      final t2 = _cursor2Index! * widget.periodSeconds;
      rows.add(const SizedBox(height: 4));
      rows.add(Text("Curseur 2 (orange) : t = ${t2.toStringAsFixed(4)} s",
          style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
      for (int i = 0; i < widget.signals.length; i++) {
        final v2 = widget.signals[i].values[_cursor2Index!];
        rows.add(Text(
            "  ${widget.signals[i].name} : ${v2.toStringAsFixed(4)}",
            style: TextStyle(fontSize: 11, color: _colorFor(i))));
      }

      rows.add(const SizedBox(height: 4));
      rows.add(Text("ΔT = ${(t2 - t1).toStringAsFixed(4)} s",
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple)));
      for (int i = 0; i < widget.signals.length; i++) {
        final v1 = widget.signals[i].values[_cursor1Index!];
        final v2 = widget.signals[i].values[_cursor2Index!];
        rows.add(Text(
            "  Δ ${widget.signals[i].name} : ${(v2 - v1).toStringAsFixed(4)}",
            style: TextStyle(fontSize: 11, color: _colorFor(i))));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _ChartPainter extends CustomPainter {
  final List<PerSignal> signals;
  final int windowStart;
  final int windowEnd;
  final double periodSeconds;
  final int? cursor1Index;
  final int? cursor2Index;
  final Color Function(int) colorFor;
  final Color cursor1Color;
  final Color cursor2Color;

  _ChartPainter({
    required this.signals,
    required this.windowStart,
    required this.windowEnd,
    required this.periodSeconds,
    required this.cursor1Index,
    required this.cursor2Index,
    required this.colorFor,
    required this.cursor1Color,
    required this.cursor2Color,
  });

  static const double leftMargin = 50.0;
  static const double bottomMargin = 20.0;
  static const double rightMargin = 6.0;
  static const double topMargin = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    final windowLength = (windowEnd - windowStart).clamp(1, 1 << 30);

    final bool singleSignal = signals.length == 1;
    double refMin = 0;
    double refMax = 1;
    if (singleSignal) {
      refMin = double.infinity;
      refMax = -double.infinity;
      final values = signals[0].values;
      for (int i = windowStart; i <= windowEnd && i < values.length; i++) {
        if (values[i] < refMin) refMin = values[i];
        if (values[i] > refMax) refMax = values[i];
      }
      if (refMin == refMax) {
        refMin -= 1;
        refMax += 1;
      }
      if (!refMin.isFinite || !refMax.isFinite) {
        refMin = 0;
        refMax = 1;
      }
    }

    for (int i = 0; i <= 4; i++) {
      final y = topMargin + plotHeight * i / 4;
      canvas.drawLine(
          Offset(leftMargin, y), Offset(leftMargin + plotWidth, y), gridPaint);

      String label;
      if (singleSignal) {
        final v = refMax - (refMax - refMin) * i / 4;
        label = v.toStringAsFixed(2);
      } else {
        label = "${(100 - i * 25)}%";
      }

      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftMargin - 4);
      tp.paint(canvas, Offset(2, y - 6));
    }

    for (int i = 0; i <= 4; i++) {
      final x = leftMargin + plotWidth * i / 4;
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), gridPaint);

      final idx = windowStart + windowLength * i / 4;
      final timeValue = idx * periodSeconds;
      final tp = TextPainter(
        text: TextSpan(
            text: "${timeValue.toStringAsFixed(2)}s",
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      double tx = x - tp.width / 2;
      if (tx < leftMargin) tx = leftMargin;
      if (tx + tp.width > size.width) tx = size.width - tp.width;
      tp.paint(canvas, Offset(tx, topMargin + plotHeight + 4));
    }

    for (int s = 0; s < signals.length; s++) {
      final values = signals[s].values;

      double minV = double.infinity;
      double maxV = -double.infinity;
      for (int i = windowStart; i <= windowEnd && i < values.length; i++) {
        final v = values[i];
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      if (minV == maxV) {
        minV -= 1;
        maxV += 1;
      }
      if (!minV.isFinite || !maxV.isFinite) continue;

      final path = Path();
      bool first = true;

      for (int i = windowStart; i <= windowEnd && i < values.length; i++) {
        final x = leftMargin + (i - windowStart) / windowLength * plotWidth;
        final normalized = (values[i] - minV) / (maxV - minV);
        final y = topMargin + plotHeight - (normalized * plotHeight);

        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..color = colorFor(s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawPath(path, linePaint);
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

    void drawCursor(int? idx, Color color) {
      if (idx == null) return;
      if (idx < windowStart || idx > windowEnd) return;
      final x = leftMargin + (idx - windowStart) / windowLength * plotWidth;
      final cursorPaint = Paint()
        ..color = color
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, topMargin),
          Offset(x, topMargin + plotHeight), cursorPaint);
    }

    drawCursor(cursor1Index, cursor1Color);
    drawCursor(cursor2Index, cursor2Color);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.windowStart != windowStart ||
        oldDelegate.windowEnd != windowEnd ||
        oldDelegate.cursor1Index != cursor1Index ||
        oldDelegate.cursor2Index != cursor2Index;
  }
}