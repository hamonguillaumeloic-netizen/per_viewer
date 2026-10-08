import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/regression_utils.dart';

class XYScreen extends StatefulWidget {
  final PerSignal xSignal;
  final PerSignal ySignal;

  const XYScreen({super.key, required this.xSignal, required this.ySignal});

  @override
  State<XYScreen> createState() => _XYScreenState();
}

class _XYScreenState extends State<XYScreen> {
  bool _showApprox = false;
  RegressionResult? _result;

  void _toggleApprox() {
    if (!_showApprox && _result == null) {
      final n = widget.xSignal.values.length < widget.ySignal.values.length
          ? widget.xSignal.values.length
          : widget.ySignal.values.length;
      final xValues = widget.xSignal.values.sublist(0, n);
      final yValues = widget.ySignal.values.sublist(0, n);
      _result = RegressionUtils.polynomialFit(xValues, yValues, 1);
    }
    setState(() => _showApprox = !_showApprox);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("XY : ${widget.ySignal.name} = f(${widget.xSignal.name})"),
        actions: [
          IconButton(
            onPressed: _toggleApprox,
            icon: Icon(_showApprox ? Icons.trending_up : Icons.show_chart),
            tooltip: "Approximation affine",
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showApprox && _result != null)
            Card(
              color: Colors.blue.shade50,
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_result!.formula,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                        "Coefficient directeur (A) = ${_result!.coefficients[1].toStringAsFixed(6)}"),
                    Text(
                        "Ordonnée à l'origine (B) = ${_result!.coefficients[0].toStringAsFixed(6)}"),
                    Text("R² = ${_result!.rSquared.toStringAsFixed(6)}"),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _XYPainter(
                      xSignal: widget.xSignal,
                      ySignal: widget.ySignal,
                      approx: _showApprox ? _result : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XYPainter extends CustomPainter {
  final PerSignal xSignal;
  final PerSignal ySignal;
  final RegressionResult? approx;

  _XYPainter({
    required this.xSignal,
    required this.ySignal,
    required this.approx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const leftMargin = 55.0;
    const bottomMargin = 25.0;
    final plotWidth = size.width - leftMargin - 8;
    final plotHeight = size.height - bottomMargin - 8;

    final n = xSignal.values.length < ySignal.values.length
        ? xSignal.values.length
        : ySignal.values.length;

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (int i = 0; i < n; i++) {
      final vx = xSignal.values[i];
      final vy = ySignal.values[i];
      if (vx < minX) minX = vx;
      if (vx > maxX) maxX = vx;
      if (vy < minY) minY = vy;
      if (vy > maxY) maxY = vy;
    }
    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = 8 + plotHeight * i / 4;
      canvas.drawLine(Offset(leftMargin, y),
          Offset(leftMargin + plotWidth, y), gridPaint);
      final labelValue = maxY - (maxY - minY) * i / 4;
      final tp = TextPainter(
        text: TextSpan(
            text: labelValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 6));

      final x = leftMargin + plotWidth * i / 4;
      canvas.drawLine(Offset(x, 8), Offset(x, 8 + plotHeight), gridPaint);
      final labelX = minX + (maxX - minX) * i / 4;
      final tpX = TextPainter(
        text: TextSpan(
            text: labelX.toStringAsFixed(2),
            style: const TextStyle(color: Colors.black, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpX.paint(canvas, Offset(x - 12, size.height - bottomMargin + 4));
    }

    final path = Path();
    bool first = true;
    for (int i = 0; i < n; i++) {
      final nx = (xSignal.values[i] - minX) / (maxX - minX);
      final ny = (ySignal.values[i] - minY) / (maxY - minY);
      final px = leftMargin + nx * plotWidth;
      final py = 8 + plotHeight - ny * plotHeight;
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }

    final linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, linePaint);

    if (approx != null) {
      final approxPath = Path();
      final yAtMinX = approx!.evaluate(minX);
      final yAtMaxX = approx!.evaluate(maxX);

      final nx1 = 0.0;
      final ny1 = (yAtMinX - minY) / (maxY - minY);
      final px1 = leftMargin + nx1 * plotWidth;
      final py1 = (8 + plotHeight - ny1 * plotHeight).clamp(8.0, 8 + plotHeight);

      final nx2 = 1.0;
      final ny2 = (yAtMaxX - minY) / (maxY - minY);
      final px2 = leftMargin + nx2 * plotWidth;
      final py2 = (8 + plotHeight - ny2 * plotHeight).clamp(8.0, 8 + plotHeight);

      approxPath.moveTo(px1, py1);
      approxPath.lineTo(px2, py2);

      final approxPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(approxPath, approxPaint);
    }

    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftMargin, 8),
        Offset(leftMargin, 8 + plotHeight), axisPaint);
    canvas.drawLine(Offset(leftMargin, 8 + plotHeight),
        Offset(leftMargin + plotWidth, 8 + plotHeight), axisPaint);
  }

  @override
  bool shouldRepaint(covariant _XYPainter oldDelegate) => true;
}