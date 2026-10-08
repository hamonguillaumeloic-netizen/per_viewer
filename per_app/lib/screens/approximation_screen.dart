import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';
import '../utils/regression_utils.dart';

class ApproximationScreen extends StatefulWidget {
  final PerSignal signal;
  final double periodSeconds;
  final int windowStart;
  final int windowEnd;

  const ApproximationScreen({
    super.key,
    required this.signal,
    required this.periodSeconds,
    required this.windowStart,
    required this.windowEnd,
  });

  @override
  State<ApproximationScreen> createState() => _ApproximationScreenState();
}

class _ApproximationScreenState extends State<ApproximationScreen> {
  int _degree = 1;
  RegressionResult? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    final end = (widget.windowEnd + 1).clamp(0, widget.signal.values.length);
    final yValues = widget.signal.values.sublist(widget.windowStart, end);
    final xValues = List<double>.generate(
        yValues.length, (i) => (widget.windowStart + i) * widget.periodSeconds);

    setState(() {
      _result = RegressionUtils.polynomialFit(xValues, yValues, _degree);
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = (widget.windowEnd + 1).clamp(0, widget.signal.values.length);
    final yValues = widget.signal.values.sublist(widget.windowStart, end);
    final xValues = List<double>.generate(
        yValues.length, (i) => (widget.windowStart + i) * widget.periodSeconds);

    return Scaffold(
      appBar: AppBar(title: Text("Approximation : ${widget.signal.name}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text("Degré du polynôme : "),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _degree,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("1 (affine)")),
                    DropdownMenuItem(value: 2, child: Text("2 (quadratique)")),
                    DropdownMenuItem(value: 3, child: Text("3 (cubique)")),
                    DropdownMenuItem(value: 4, child: Text("4")),
                    DropdownMenuItem(value: 5, child: Text("5")),
                  ],
                  onChanged: (v) {
                    setState(() => _degree = v!);
                    _compute();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_result != null) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_result!.formula,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("R² = ${_result!.rSquared.toStringAsFixed(6)}"),
                      if (_degree == 1) ...[
                        const SizedBox(height: 4),
                        Text(
                            "A (gain/pente) = ${_result!.coefficients[1].toStringAsFixed(6)}"),
                        Text(
                            "B (ordonnée à l'origine) = ${_result!.coefficients[0].toStringAsFixed(6)}"),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _ApproxPainter(
                        xValues: xValues,
                        yValues: yValues,
                        result: _result!,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApproxPainter extends CustomPainter {
  final List<double> xValues;
  final List<double> yValues;
  final RegressionResult result;

  _ApproxPainter(
      {required this.xValues, required this.yValues, required this.result});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    const margin = 10.0;
    final plotW = size.width - margin * 2;
    final plotH = size.height - margin * 2;

    double minX = xValues.first, maxX = xValues.last;
    double minY = double.infinity, maxY = -double.infinity;
    for (final v in yValues) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }
    for (final x in xValues) {
      final fit = result.evaluate(x);
      if (fit < minY) minY = fit;
      if (fit > maxY) maxY = fit;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    double px(double x) => margin + (x - minX) / (maxX - minX) * plotW;
    double py(double y) =>
        margin + plotH - (y - minY) / (maxY - minY) * plotH;

    final origPath = Path();
    for (int i = 0; i < xValues.length; i++) {
      final x = px(xValues[i]);
      final y = py(yValues[i]);
      if (i == 0) {
        origPath.moveTo(x, y);
      } else {
        origPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
        origPath,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    final fitPath = Path();
    for (int i = 0; i < xValues.length; i++) {
      final x = px(xValues[i]);
      final y = py(result.evaluate(xValues[i]));
      if (i == 0) {
        fitPath.moveTo(x, y);
      } else {
        fitPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
        fitPath,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _ApproxPainter oldDelegate) => true;
}