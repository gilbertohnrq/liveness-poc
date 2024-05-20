import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:liveness/controller.dart';
import 'package:liveness/coordinates_translator.dart';
import 'package:liveness/liveness_painter.dart';

class LivenessPage extends StatefulWidget {
  const LivenessPage({super.key});

  @override
  State<LivenessPage> createState() => _LivenessPageState();
}

class _LivenessPageState extends State<LivenessPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final Controller controller = Controller();

  CustomPaint? customPaint;

  List<TickModel> ticks = [];
  ParamsModel? params;
  bool isCompleted = false;
  bool isSubmited = false;
  String errorMessage = '';

  late final AnimationController _animationController;
  late final Animation<double> animation;
  CoordinatesTranslator? coordinatesTranslator;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  late final FaceDetector faceDetector;
  late final FaceDetectorOptions options;

  Future<InputImage> _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    InputImageRotation? imageRotation;
    if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.cameraController!.value.deviceOrientation];
      if (controller.camera!.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (controller.camera!.sensorOrientation + rotationCompensation!) %
                360;
      } else {
        rotationCompensation = (controller.camera!.sensorOrientation -
                rotationCompensation! +
                360) %
            360;
      }
      imageRotation =
          InputImageRotationValue.fromRawValue(rotationCompensation);
    } else if (Platform.isIOS) {
      imageRotation = InputImageRotationValue.fromRawValue(
          controller.camera!.sensorOrientation);
    }

    InputImageFormat inputImageFormat =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

    // final planeData = image.planes.map((Plane plane) {
    //   return InputImageMetadata(
    //     bytesPerRow: plane.bytesPerRow,
    //     size: Size(plane.width!.toDouble(), plane.height!.toDouble()),
    //     format: inputImageFormat,
    //     rotation: imageRotation!,
    //   );
    // }).toList();

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation!,
      format: inputImageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, metadata: inputImageData);

    return inputImage;
  }

  Future<void> initializeCamera() async {
    try {
      controller.isBackCamera = false;
      controller.resolutionPreset = ResolutionPreset.high;
      await controller.initializeCamera();

      if (!mounted) {
        return;
      }

      bool isProcessing = false;
      controller.cameraController!.startImageStream((CameraImage img) async {
        if (isProcessing || isSubmited) {
          return;
        }

        isProcessing = true;

        try {
          final inputImage = await _processCameraImage(img);
          final List<Face> faces = await faceDetector.processImage(inputImage);

          if (faces.isNotEmpty && ticks.every((element) => element.animated)) {
            isCompleted = true;
          }

          if (!mounted) {
            return;
          }

          setState(() {
            if (faces.length > 1) {
              errorMessage =
                  'Se posicione em uma area que nao tenha mais pessoas ou objetos, como na frente de uma parede';
            } else if (faces.isEmpty) {
              errorMessage = 'Posicione seu rosto no centro do circulo';
            } else {
              customPaint = CustomPaint(
                painter: LivenessPainter(
                  face: faces.first,
                  coordinatesTranslator: coordinatesTranslator,
                  parameters: params,
                  ticks: ticks,
                  listenable: animation,
                  detectionEnabled: faces.length == 1 && !isCompleted,
                ),
              );
            }
          });
        } catch (e) {
          debugPrint(e.toString());
        }

        isProcessing = false;
      });

      setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
    );

    faceDetector = FaceDetector(options: options);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    animation = Tween(begin: 0.0, end: 150.0).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();

      _animationController.addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });

      initializeCamera();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Prova de vida'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                controller.reloadCamera();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(builder: (context) {
        return Stack(
          fit: StackFit.expand,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: CameraPreview(controller.cameraController!,
                  child: customPaint ?? Container()),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 100.0,
                  color: Colors.white,
                ),
              ),
            ),
            if (!isSubmited)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  margin: const EdgeInsets.only(top: 80),
                  child: Text(
                    isCompleted
                        ? 'Agora Sorria!'
                        : 'Vire seu rosto de modo que complete o circulo',
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: Colors.yellow),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
