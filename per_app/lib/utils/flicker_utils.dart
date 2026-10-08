import 'dart:math' as math;

class FlickerUtils {
  /// Calcul simplifie du flicker instantane.
  /// ATTENTION : ceci est une approximation pedagogique inspiree de la
  /// norme IEC 61000-4-15, PAS une mesure certifiee conforme.
  static List<double> computeInstantaneousFlicker(
      List<double> values, double sampleRate) {
    final n = values.length;
    if (n < 4) return List<double>.filled(n, 0.0);

    final mean = values.reduce((a, b) => a + b) / n;
    final meanAbs = mean.abs() < 1e-9 ? 1.0 : mean.abs();

    final demodulated = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      demodulated[i] = (values[i] - mean) / meanAbs;
    }

    final centerFreq = 8.8;
    final bandwidth = 5.0;
    final filtered =
        _bandpassFilter(demodulated, sampleRate, centerFreq, bandwidth);

    final squared = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      squared[i] = filtered[i] * filtered[i];
    }

    final windowSize = (sampleRate * 0.3).round().clamp(1, n);
    final smoothed = _movingAverage(squared, windowSize);

    const scaleFactor = 1300.0;
    final result = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      result[i] = math.sqrt(smoothed[i].abs()) * scaleFactor;
    }

    return result;
  }

  static double _sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2;
  }

  static List<double> _bandpassFilter(
      List<double> input, double sampleRate, double centerFreq, double bw) {
    final n = input.length;
    final output = List<double>.filled(n, 0.0);

    final omega = 2 * math.pi * centerFreq / sampleRate;
    final alpha = math.sin(omega) * _sinh(
        (math.log(2) / 2) * (bw / centerFreq) * (omega / math.sin(omega)));

    final b0 = alpha;
    final b1 = 0.0;
    final b2 = -alpha;
    final a0 = 1 + alpha;
    final a1 = -2 * math.cos(omega);
    final a2 = 1 - alpha;

    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < n; i++) {
      final x0 = input[i];
      final y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
      output[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return output;
  }

  static List<double> _movingAverage(List<double> input, int windowSize) {
    final n = input.length;
    final output = List<double>.filled(n, 0.0);
    double sum = 0;
    for (int i = 0; i < n; i++) {
      sum += input[i];
      if (i >= windowSize) sum -= input[i - windowSize];
      output[i] = sum / math.min(i + 1, windowSize);
    }
    return output;
  }
}