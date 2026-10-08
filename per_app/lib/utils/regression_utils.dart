import 'dart:math' as math;

class RegressionResult {
  final List<double> coefficients; // [a0, a1, a2, ...] => a0 + a1*x + a2*x^2 ...
  final double rSquared;
  RegressionResult(this.coefficients, this.rSquared);

  double evaluate(double x) {
    double result = 0;
    double xp = 1;
    for (final c in coefficients) {
      result += c * xp;
      xp *= x;
    }
    return result;
  }

  String get formula {
    if (coefficients.length == 2) {
      return "y = ${coefficients[1].toStringAsFixed(5)} * x + ${coefficients[0].toStringAsFixed(5)}";
    }
    final parts = <String>[];
    for (int i = coefficients.length - 1; i >= 0; i--) {
      if (i == 0) {
        parts.add(coefficients[i].toStringAsFixed(5));
      } else if (i == 1) {
        parts.add("${coefficients[i].toStringAsFixed(5)}*x");
      } else {
        parts.add("${coefficients[i].toStringAsFixed(5)}*x^$i");
      }
    }
    return "y = ${parts.join(' + ')}";
  }
}

class RegressionUtils {
  static RegressionResult polynomialFit(
      List<double> xValues, List<double> yValues, int degree) {
    final n = xValues.length;
    final m = degree + 1;

    final matrix = List.generate(m, (_) => List<double>.filled(m, 0.0));
    final rhs = List<double>.filled(m, 0.0);

    for (int i = 0; i < m; i++) {
      for (int j = 0; j < m; j++) {
        double sum = 0;
        for (int k = 0; k < n; k++) {
          sum += math.pow(xValues[k], i + j);
        }
        matrix[i][j] = sum;
      }
      double sumB = 0;
      for (int k = 0; k < n; k++) {
        sumB += yValues[k] * math.pow(xValues[k], i);
      }
      rhs[i] = sumB;
    }

    final coeffs = _gaussianSolve(matrix, rhs);

    double meanY = yValues.reduce((a, b) => a + b) / n;
    double ssTot = 0;
    double ssRes = 0;
    for (int k = 0; k < n; k++) {
      double predicted = 0;
      double xp = 1;
      for (final c in coeffs) {
        predicted += c * xp;
        xp *= xValues[k];
      }
      ssRes += math.pow(yValues[k] - predicted, 2);
      ssTot += math.pow(yValues[k] - meanY, 2);
    }
    final rSquared = ssTot == 0 ? 1.0 : 1 - (ssRes / ssTot);

    return RegressionResult(coeffs, rSquared);
  }

  static List<double> _gaussianSolve(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = List.generate(n, (i) => [...a[i], b[i]]);

    for (int i = 0; i < n; i++) {
      int pivot = i;
      for (int k = i + 1; k < n; k++) {
        if (m[k][i].abs() > m[pivot][i].abs()) pivot = k;
      }
      final tmp = m[i];
      m[i] = m[pivot];
      m[pivot] = tmp;

      if (m[i][i].abs() < 1e-12) continue;

      for (int k = i + 1; k < n; k++) {
        final factor = m[k][i] / m[i][i];
        for (int j = i; j <= n; j++) {
          m[k][j] -= factor * m[i][j];
        }
      }
    }

    final x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      double sum = m[i][n];
      for (int j = i + 1; j < n; j++) {
        sum -= m[i][j] * x[j];
      }
      x[i] = m[i][i].abs() < 1e-12 ? 0 : sum / m[i][i];
    }
    return x;
  }
}