import 'dart:math' as math;

class FFTResult {
  final List<double> frequencies;
  final List<double> magnitudes;
  FFTResult(this.frequencies, this.magnitudes);
}

class FftUtils {
  static int _nextPowerOfTwo(int n) {
    int p = 1;
    while (p < n) {
      p *= 2;
    }
    return p;
  }

  static FFTResult computeFFT(List<double> input, double sampleRate) {
    final n = _nextPowerOfTwo(input.length);
    final real = List<double>.filled(n, 0.0);
    final imag = List<double>.filled(n, 0.0);

    for (int i = 0; i < input.length; i++) {
      real[i] = input[i];
    }

    _fftInPlace(real, imag);

    final half = n ~/ 2;
    final frequencies = List<double>.filled(half, 0.0);
    final magnitudes = List<double>.filled(half, 0.0);

    for (int k = 0; k < half; k++) {
      frequencies[k] = k * sampleRate / n;
      magnitudes[k] = math.sqrt(real[k] * real[k] + imag[k] * imag[k]) / n;
    }

    return FFTResult(frequencies, magnitudes);
  }

  static void _fftInPlace(List<double> real, List<double> imag) {
    final n = real.length;
    if (n <= 1) return;

    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wCos = math.cos(ang);
      final wSin = math.sin(ang);

      for (int start = 0; start < n; start += len) {
        double curCos = 1.0;
        double curSin = 0.0;
        final half = len >> 1;
        for (int k = 0; k < half; k++) {
          final evenIndex = start + k;
          final oddIndex = start + k + half;

          final evenRe = real[evenIndex];
          final evenIm = imag[evenIndex];
          final oddRe = real[oddIndex];
          final oddIm = imag[oddIndex];

          final rotRe = oddRe * curCos - oddIm * curSin;
          final rotIm = oddRe * curSin + oddIm * curCos;

          real[evenIndex] = evenRe + rotRe;
          imag[evenIndex] = evenIm + rotIm;
          real[oddIndex] = evenRe - rotRe;
          imag[oddIndex] = evenIm - rotIm;

          final newCos = curCos * wCos - curSin * wSin;
          final newSin = curCos * wSin + curSin * wCos;
          curCos = newCos;
          curSin = newSin;
        }
      }
    }
  }
}