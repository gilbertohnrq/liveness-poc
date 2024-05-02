import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

extension ListGetExtension<T> on List<T> {
  T? tryGet(int? index) =>
      index == null || index < 0 || index >= length ? null : this[index];
}

Future<List<CameraDescription>?> getCameras() async {
  try {
    final cameras = await availableCameras();
    return cameras;
  } catch (e) {
    debugPrint(e.toString());
    return null;
  }
}

Future<CameraDescription?> getFrontCamera() async {
  try {
    final availableCameras = await getCameras();
    if (availableCameras == null) {
      return null;
    }

    return availableCameras.tryGet(1);
  } catch (e) {
    debugPrint(e.toString());
    return null;
  }
}

Future<CameraDescription?> getBackCamera() async {
  try {
    final availableCameras = await getCameras();
    if (availableCameras == null) {
      return null;
    }

    return availableCameras.tryGet(0);
  } catch (e) {
    debugPrint(e.toString());
    return null;
  }
}

CameraController createController(
  CameraDescription camera, {
  ResolutionPreset resolutionPreset = ResolutionPreset.veryHigh,
  bool enableAudio = false,
}) {
  return CameraController(
    camera,
    resolutionPreset,
    enableAudio: enableAudio,
  );
}

class Controller {
  bool isBackCamera = true;

  bool enableAudio = false;

  ResolutionPreset resolutionPreset = ResolutionPreset.veryHigh;

  DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp;

  bool allowedToCapture = true;

  bool camerasUnavailable = false;

  bool cameraInitialized = false;

  CameraController? cameraController;

  CameraDescription? camera;

  List<int>? takedImage;

  File? recordedVideo;

  Timer? timer;

  int seconds = 0;

  bool isRecording = false;

  bool isPlaying = false;

  void dispose() {
    cameraController?.dispose();
  }

  void setCamerasUnavailable(dynamic value) {
    camerasUnavailable = value as bool;
  }

  void setCameraInitialized(dynamic value) {
    cameraInitialized = value as bool;
  }

  Future<void> initializeCamera() async {
    camerasUnavailable = false;
    cameraInitialized = false;

    camera = await (isBackCamera ? getBackCamera() : getFrontCamera());
    if (camera != null) {
      cameraController = createController(
        camera!,
        resolutionPreset: resolutionPreset,
        enableAudio: enableAudio,
      );
      await cameraController!.initialize();
      cameraController!.setFlashMode(FlashMode.off);
      cameraController!.lockCaptureOrientation(deviceOrientation);
      if (enableAudio) {
        cameraController!.prepareForVideoRecording();
      }

      setCameraInitialized(true);
    } else {
      setCamerasUnavailable(true);
    }
  }

  Future<void> reloadCamera() async {
    if (cameraController != null) {
      await cameraController!.dispose();
    }
    initializeCamera();
  }
}
