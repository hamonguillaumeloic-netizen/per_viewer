class ResampleUtils {
  static List<double> linearResample(List<double> input, int factor) {
    if (factor <= 1) return List<double>.from(input);
    final n = input.length;
    final outLength = (n - 1) * factor + 1;
    final result = List<double>.filled(outLength, 0.0);

    for (int i = 0; i < n - 1; i++) {
      final a = input[i];
      final b = input[i + 1];
      for (int k = 0; k < factor; k++) {
        final t = k / factor;
        result[i * factor + k] = a + (b - a) * t;
      }
    }
    result[outLength - 1] = input[n - 1];
    return result;
  }

  static List<double> polynomialResample(List<double> input, int factor) {
    if (factor <= 1) return List<double>.from(input);
    final n = input.length;
    final outLength = (n - 1) * factor + 1;
    final result = List<double>.filled(outLength, 0.0);

    for (int i = 0; i < n - 1; i++) {
      final p0 = input[i == 0 ? 0 : i - 1];
      final p1 = input[i];
      final p2 = input[i + 1];
      final p3 = input[i + 2 >= n ? n - 1 : i + 2];

      for (int k = 0; k < factor; k++) {
        final t = k / factor;
        result[i * factor + k] = _catmullRom(p0, p1, p2, p3, t);
      }
    }
    result[outLength - 1] = input[n - 1];
    return result;
  }

  static double _catmullRom(
      double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return 0.5 *
        ((2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}