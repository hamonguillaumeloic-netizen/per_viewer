import 'dart:typed_data';

class BinaryReader {
  final ByteData _data;
  int _pos = 0;

  BinaryReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);

  int get position => _pos;

  void skip(int n) {
    _pos += n;
  }

  String readChars(int n) {
    final buf = StringBuffer();
    for (int i = 0; i < n; i++) {
      final b = _data.getUint8(_pos + i);
      if (b == 0) {
        _pos += n;
        return buf.toString();
      }
      buf.writeCharCode(b);
    }
    _pos += n;
    return buf.toString();
  }

  int readInt32() {
    final v = _data.getInt32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

    int readInt16() {
    final v = _data.getInt16(_pos, Endian.little);
    _pos += 2;
    return v;
  }

  List<double> readSingleArray(int count) {
    final result = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      result[i] = _data.getFloat32(_pos, Endian.little);
      _pos += 4;
    }
    return result;
  }

  List<double> readLongArray(int count) {
    final result = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      result[i] = _data.getInt32(_pos, Endian.little).toDouble();
      _pos += 4;
    }
    return result;
  }

  List<double> readDoubleArray(int count) {
    final result = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      result[i] = _data.getFloat64(_pos, Endian.little);
      _pos += 8;
    }
    return result;
  }
}