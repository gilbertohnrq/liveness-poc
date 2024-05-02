import 'dart:io';

class MathHelper {
  static double? fixedDecimais(
      {required double value, required int decimalPlaces}) {
    return double.tryParse(value.toStringAsFixed(decimalPlaces));
  }

  static double? percentage(
      {required double value, required double total, int? round}) {
    final result = (value * 100) / total;
    if (round == null) {
      return result;
    } else {
      return fixedDecimais(value: result, decimalPlaces: round);
    }
  }

  static double? percentageReverse(
      {required double percentage, required double total, int? round}) {
    final result = (percentage / 100) * total;

    if (round == null) {
      return result;
    } else {
      return fixedDecimais(value: result, decimalPlaces: round);
    }
  }

  ///This funcion is like a lerp and unlerp, but is general. Its expect a number
  /// and a range for interpolate, after the result is interpolated with a second range
  static double remap(
    double value,
    double start1,
    double stop1,
    double start2,
    double stop2,
  ) {
    final outgoing =
        start2 + (stop2 - start2) * ((value - start1) / (stop1 - start1));

    return outgoing;
  }

  static Future<int> byteToMb(File file) async {
    final bytes = (await file.readAsBytes()).lengthInBytes;

    final kb = bytes / 1024;
    final mb = kb / 1024;
    return mb.toInt();
  }
}
