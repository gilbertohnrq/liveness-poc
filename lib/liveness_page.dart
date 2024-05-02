import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
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
  final controller = Controller();

  CustomPaint? customPaint;

  List<TickModel> ticks = [];
  ParamsModel? params;
  bool isCompleted = false;
  bool isSubmited = false;
  String errorMessage = '';

  late final AnimationController _animationController;
  late final Animation<double> animation;
  CoordinatesTranslator? coordinatesTranslator;

  final horizontalPositions = <double>[];
  final verticalPositions = <double>[];

  final faceDetector = GoogleMlKit.vision.faceDetector(
    const FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
    ),
  );

  Future<InputImage> _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final imageRotation = InputImageRotationMethods.fromRawValue(
            controller.camera!.sensorOrientation) ??
        InputImageRotation.Rotation_0deg;

    final inputImageFormat =
        InputImageFormatMethods.fromRawValue(image.format.raw as int) ??
            InputImageFormat.NV21;

    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

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
      controller.cameraController!.startImageStream((img) async {
        if (isProcessing || isSubmited) {
          return;
        }

        isProcessing = true;

        try {
          if (ticks.isNotEmpty && ticks.every((element) => element.animated)) {
            isCompleted = true;
          }

          final inputImage = await _processCameraImage(img);

          final List<Face> faces = await faceDetector.processImage(inputImage);

          if (inputImage.inputImageData?.size != null &&
              inputImage.inputImageData?.imageRotation != null) {
            if (coordinatesTranslator == null) {
              coordinatesTranslator = CoordinatesTranslator(
                rotation: inputImage.inputImageData!.imageRotation,
                size: params!.size,
                absoluteImageSize: inputImage.inputImageData!.size,
              );

              await Future.delayed(const Duration(seconds: 1));
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
                final topFace = coordinatesTranslator!
                    .translateY(faces.first.boundingBox.top);
                final bottomFace = coordinatesTranslator!
                    .translateY(faces.first.boundingBox.bottom);

                final topCircle =
                    params!.size.height - params!.center.dy - params!.radius;
                final bottomCircle = params!.center.dy + params!.radius;

                final sizeFace = bottomFace - topFace;

                final sizeCircle = params!.radius * 2;

                if (sizeFace > sizeCircle * 1.2) {
                  errorMessage = 'Afaste um pouco seu rosto';
                  return;
                }

                if (sizeFace < sizeCircle * 0.6) {
                  errorMessage = 'Aproxime um pouco seu rosto';
                  return;
                }

                if (topFace * 1.4 < topCircle ||
                    bottomFace * 0.85 > bottomCircle) {
                  errorMessage = 'Posicione seu rosto no centro do circulo';
                  return;
                }

                if (errorMessage.isNotEmpty) {
                  Future.delayed(const Duration(seconds: 1)).then((_) {
                    errorMessage = '';
                  });
                }

                if (isCompleted) {
                  debugPrint('completed');
                  return;
                }

                customPaint = CustomPaint(
                  painter: LivenessPainter(
                    face: faces.tryGet(0),
                    coordinatesTranslator: coordinatesTranslator,
                    parameters: params,
                    ticks: ticks,
                    listenable: animation,
                    detectionEnabled: faces.length == 1 && !isCompleted,
                  ),
                );
              }
            });
          }
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

  double scaffoldBodyHeight(BuildContext context) {
    return MediaQuery.of(context).size.height -
        (Scaffold.of(context).appBarMaxHeight ?? 0.0) -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;
  }

  @override
  void initState() {
    super.initState();

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller.cameraController == null ||
        !controller.cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      controller.reloadCamera();
    }
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
        if (params == null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            if (!mounted) {
              return;
            }
            setState(() {
              final screenSize = MediaQuery.of(context).size;
              final size = Size(screenSize.width, scaffoldBodyHeight(context));
              const amountTicks = 150;

              params = ParamsModel(
                size: size,
                radius: size.width / 2.55,
                center: Offset(size.width / 2, size.height / 2),
              );

              ticks = List.generate(
                amountTicks,
                (index) {
                  final angle = index * (math.pi * 2 / amountTicks);
                  return TickModel(
                    angle: angle,
                    x: (math.cos(angle) * params!.radius) * 1.02,
                    y: (math.sin(angle) * params!.radius) * 1.02,
                    center: params!.center,
                  );
                },
              );
              customPaint = CustomPaint(
                painter: LivenessPainter(
                  parameters: params,
                  ticks: ticks,
                  listenable: animation,
                  detectionEnabled: false,
                ),
              );
            });
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Center(
                child: CameraPreview(
                  controller.cameraController!,
                  child: customPaint ?? Container(),
                ),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  margin: const EdgeInsets.only(top: 80),
                  child: Text(
                    isCompleted
                        ? 'Agora Sorria!'
                        : 'Vire seu rosto de modo que complete o circulo',
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.yellow,
                        ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Future<void> submit() async {
    // await controller.submit();
    // if (controller.requestStatus is RequestSuccess) {
    //   DryveUI.setStatusBarDark();
    //   DryveUI.setPortraitOrientation();
    //   final nextRoute =
    //       controller.stepsRoutes.tryGet(widget.currentStep.index + 1);
    //   if (nextRoute == null) {
    //     Dryver.to.pushReplacementNamed(AppRoute.shieldValidationCompleted);
    //   } else {
    //     Dryver.to.pushReplacementNamed(
    //       nextRoute.route,
    //       arguments: {'currentStep': nextRoute},
    //     );
    //   }
    // } else {
    // HenrySnackbar.show(
    //   text: 'Ocorreu um erro ao enviar a prova de vida!',
    //   status: HenrySnackbarStatus.error,
    //   context: context,
    // );
    // }
  }
}
