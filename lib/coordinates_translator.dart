import 'dart:io';
import 'dart:ui';

import 'package:google_ml_kit/google_ml_kit.dart';

class CoordinatesTranslator {
  final InputImageRotation rotation;
  final Size size;
  final Size absoluteImageSize;

  CoordinatesTranslator({
    required this.rotation,
    required this.size,
    required this.absoluteImageSize,
  });

  double translateX(double x) {
    switch (rotation) {
      case InputImageRotation.Rotation_90deg:
        return x *
            size.width /
            (Platform.isIOS
                ? absoluteImageSize.width
                : absoluteImageSize.height);
      case InputImageRotation.Rotation_270deg:
        return size.width -
            x *
                size.width /
                (Platform.isIOS
                    ? absoluteImageSize.width
                    : absoluteImageSize.height);
      default:
        return x * size.width / absoluteImageSize.width;
    }
  }

  double translateY(double y) {
    switch (rotation) {
      case InputImageRotation.Rotation_90deg:
      case InputImageRotation.Rotation_270deg:
        return y *
            size.height /
            (Platform.isIOS
                ? absoluteImageSize.height
                : absoluteImageSize.width);
      default:
        return y * size.height / absoluteImageSize.height;
    }
  }
}
