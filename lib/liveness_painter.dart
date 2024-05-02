import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:liveness/coordinates_translator.dart';
import 'package:liveness/math_helper.dart';

class LivenessPainter extends CustomPainter {
  final Face? face;
  final CoordinatesTranslator? coordinatesTranslator;
  final List<TickModel> ticks;
  final ParamsModel? parameters;
  final Animation listenable;
  final bool detectionEnabled;

  LivenessPainter({
    this.face,
    this.coordinatesTranslator,
    required this.ticks,
    required this.parameters,
    required this.listenable,
    required this.detectionEnabled,
  }) : super(repaint: listenable);

  Point<int> offsetToPoint(Offset offset) {
    return Point<int>(offset.dx.round(), offset.dy.round());
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (parameters == null) {
      return;
    }

    final params = parameters!;

    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()
        ..addRRect(RRect.fromLTRBR(0, 0, size.width, size.height, Radius.zero)),
      Path()
        ..addArc(
          Rect.fromLTRB(
            params.center.dx - params.radius,
            params.center.dy - params.radius,
            params.center.dx + params.radius,
            params.center.dy + params.radius,
          ),
          0,
          math.pi * 2,
        ),
    );

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );

    if (ticks.isEmpty || !detectionEnabled) {
      for (final tick in ticks) {
        tick.draw(canvas);
      }
      return;
    }

    var originalCenter = face!.getLandmark(FaceLandmarkType.noseBase)?.position;
    var leftEar = face!.getLandmark(FaceLandmarkType.leftEar)?.position;
    var rightEar = face!.getLandmark(FaceLandmarkType.rightEar)?.position;

    if (originalCenter != null && leftEar != null && rightEar != null) {
      originalCenter = Offset(
        coordinatesTranslator!.translateX(originalCenter.dx),
        coordinatesTranslator!.translateY(originalCenter.dy),
      );

      leftEar = Offset(
        coordinatesTranslator!.translateX(leftEar.dx),
        coordinatesTranslator!.translateY(leftEar.dy),
      );

      rightEar = Offset(
        coordinatesTranslator!.translateX(rightEar.dx),
        coordinatesTranslator!.translateY(rightEar.dy),
      );

      final originalTop = (leftEar.dy + rightEar.dy) / 2;
      final centerToTop = originalCenter.dy - originalTop;

      final centerToLeft = originalCenter.dx - leftEar.dx;
      final centerToRight = originalCenter.dx - rightEar.dx;
      final totalHorizontal = centerToLeft + centerToRight;

      final horizontalValue =
          useValue(value: totalHorizontal, min: -80, max: 80);
      final horizontalInterpolatedBottom = MathHelper.remap(
        -horizontalValue,
        -80,
        80,
        0,
        math.pi,
      );

      final horizontalInterpolatedTop =
          math.pi - horizontalInterpolatedBottom + math.pi;

      const distanceVertical = 30.0;

      final verticalValue = useValue(
          value: centerToTop,
          min: -distanceVertical,
          max: distanceVertical + 20);

      final vRemaped = MathHelper.remap(verticalValue, -distanceVertical,
          distanceVertical + 10, -(math.pi / 2), math.pi / 2);

      for (final entry in ticks.asMap().entries) {
        final hBottomRemaped = entry.value.angle > math.pi / 2
            ? math.pi - entry.value.angle
            : entry.value.angle;

        final hTopRemaped = entry.value.angle - math.pi > math.pi / 2
            ? math.pi * 2 - entry.value.angle
            : entry.value.angle - math.pi;

        if (!entry.value.animated) {
          //Looking to top
          if ((entry.value.angle <= math.pi * 1.5 &&
                  horizontalInterpolatedTop < entry.value.angle) ||
              (entry.value.angle >= math.pi * 1.5 &&
                  horizontalInterpolatedTop > entry.value.angle)) {
            if (vRemaped <= 0 && vRemaped.abs() >= hTopRemaped.abs()) {
              entry.value.animated = true;
            }
          }

          //Looking to bottom
          if ((entry.value.angle <= math.pi / 2 &&
                  horizontalInterpolatedBottom < entry.value.angle) ||
              (entry.value.angle >= math.pi / 2 &&
                  horizontalInterpolatedBottom > entry.value.angle)) {
            if (vRemaped > 0 && vRemaped >= hBottomRemaped) {
              entry.value.animated = true;
            }
          }

          final maxKey =
              (useValue(value: entry.key + 8, min: 0, max: ticks.length - 1) -
                      entry.key)
                  .toInt();
          try {
            if (!entry.value.animated && entry.key > 0) {
              if (ticks[entry.key - 1].animated &&
                  List.generate(
                    maxKey,
                    (index) => ticks[entry.key + index].animated,
                  ).any((element) => element)) {
                entry.value.animated = true;
                for (var i = 0; i <= maxKey; i++) {
                  ticks[entry.key + i].animated = true;
                }
              }
            }
          } catch (e) {
            debugPrint(e.toString());
          }

          if (entry.key == 0 && ticks[1].animated) {
            entry.value.animated = true;
          }
        }
      }
    }
    final arcPainter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.grey.shade900;

    canvas.drawArc(
      Rect.fromLTRB(
        params.center.dx - params.radius,
        params.center.dy - params.radius,
        params.center.dx + params.radius,
        params.center.dy + params.radius,
      ),
      0,
      math.pi * 2,
      false,
      arcPainter,
    );

    for (final tick in ticks) {
      tick.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant LivenessPainter oldDelegate) {
    return oldDelegate.listenable.value != listenable.value;
  }
}

double useValue({
  required double value,
  required double min,
  required double max,
}) {
  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}

bool isAproximated(double value1, double value2) {
  final v1 = double.parse(value1.toStringAsFixed(1));
  final v2 = double.parse(value2.toStringAsFixed(1));

  if (v1 == v2 ||
      v1 - 0.1 == v2 ||
      v1 - 0.2 == v2 ||
      v1 - 0.3 == v2 ||
      v1 + 0.1 == v2 ||
      v1 + 0.2 == v2 ||
      v1 + 0.3 == v2) {
    return true;
  }

  return false;
}

class TickModel {
  final double angle;
  final double x;
  final double y;
  final Offset center;
  bool animated;
  bool _animationExtraCompleted;
  final double _startIncrement;
  double _currentIncrement;
  final double _maxIncrement;
  final double _extraIncrement;

  TickModel({
    required this.angle,
    required this.x,
    required this.y,
    required this.center,
  })  : _startIncrement = 1.04,
        _currentIncrement = 1.04,
        _maxIncrement = 1.10,
        _extraIncrement = 1.14,
        animated = false,
        _animationExtraCompleted = false;

  bool get animationCompleted =>
      _currentIncrement == _maxIncrement && _animationExtraCompleted;

  void draw(Canvas canvas) {
    if (!_animationExtraCompleted && _currentIncrement >= _extraIncrement) {
      _animationExtraCompleted = true;
    }

    if (animated) {
      if (!_animationExtraCompleted && _currentIncrement < _extraIncrement) {
        _currentIncrement += 0.01;
      } else if (_animationExtraCompleted &&
          _currentIncrement > _maxIncrement) {
        _currentIncrement -= 0.005;
      }
    }
    if ((_currentIncrement == _startIncrement) ||
        (animated && !animationCompleted)) {
      final path = Path();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          Colors.white70,
          const Color(0xFFFFFF00),
          MathHelper.remap(
              _currentIncrement, _startIncrement, _maxIncrement, 0, 1),
        )!;

      path.moveTo(center.dx + x, center.dy + y);
      path.lineTo(
          center.dx + x * _currentIncrement, center.dy + y * _currentIncrement);
      canvas.drawPath(path, paint);
    }
  }
}

class ParamsModel {
  final Size size;
  final double radius;
  final Offset center;

  ParamsModel({
    required this.size,
    required this.radius,
    required this.center,
  });
}
