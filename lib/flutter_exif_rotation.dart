import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class FlutterExifRotation {
  static const MethodChannel _channel = MethodChannel('flutter_exif_rotation');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Get the [path] of the image and fix the orientation.
  /// Return the [File] with the exif data fixed
  static Future<File> rotateImage({required String? path}) async {
    assert(path != null);
    String filePath = await (_channel.invokeMethod(
      'rotateImage',
      <String, dynamic>{'path': path, 'save': false},
    ));

    return File(filePath);
  }

  /// Get the [path] of the image, fix the orientation and
  /// saves the file in the device.
  /// Return the [File] with the exif data fixed
  static Future<File> rotateAndSaveImage({required String? path}) async {
    assert(path != null);
    String filePath = await (_channel.invokeMethod(
      'rotateImage',
      <String, dynamic>{'path': path, 'save': true},
    ));

    return File(filePath);
  }
}
