import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';

import 'flutter_camera_processing.dart';
import 'image_converter.dart';

// Inspired from https://github.com/am15h/object_detection_flutter

/// Bundles data to pass between Isolate
class IsolateData {
  CameraImage cameraImage;
  double cropPercent;

  SendPort? responsePort;

  IsolateData(
    this.cameraImage,
    this.cropPercent,
  );
}

/// Manages separate Isolate instance for inference
class IsolateUtils {
  static const String kDebugName = "InferenceIsolate";

  // ignore: unused_field
  Isolate? _isolate;
  final _receivePort = ReceivePort();
  SendPort? _sendPort;

  SendPort? get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: kDebugName,
    );

    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final IsolateData? isolateData in port) {
      if (isolateData != null) {
        final image = isolateData.cameraImage;
        final cropPercent = isolateData.cropPercent;
        final bytes = await convertImage(image);
        final cropSize = (min(image.width, image.height) * cropPercent).round();
        final result = FlutterCameraProcessing.zxingProcessStream(
            bytes, image.width, image.height, cropSize);
        isolateData.responsePort?.send(result);
      }
    }
  }
}
