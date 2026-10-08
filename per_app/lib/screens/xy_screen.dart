import 'package:flutter/material.dart';
import '../per_parser/per_file_parser.dart';

class XYScreen extends StatelessWidget {
  final PerSignal xSignal;
  final PerSignal ySignal;

  const XYScreen({super.key, required this.xSignal, required this.ySignal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("XY : ${ySignal.name} = f(${xSignal.name})")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _XYPainter(xSignal: xSignal, ySignal: ySignal),
            );
          },
        ),
      ),
    );
  }
}

class _XYPainter extends CustomPainter {
  final PerSignal xSignal;
  final PerSignal ySignal;

  _XYPainter({required this.xSignal, required this.ySignal});

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

    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftMargin, 8),
        Offset(leftMargin, 8 + plotHeight), axisPaint);
    canvas.drawLine(Offset(leftMargin, 8 + plotHeight),
        Offset(leftMargin + plotWidth, 8 + plotHeight), axisPaint);
  }

  @override
  bool shouldRepaint(covariant _XYPainter oldDelegate) => false;
}