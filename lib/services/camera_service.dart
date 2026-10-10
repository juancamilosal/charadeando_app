import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Graba a los participantes con la cámara frontal durante cada turno.
class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  /// Abre la cámara frontal. Si el celular no soporta [resolution], el
  /// plugin usa la más cercana disponible.
  Future<void> initialize(VideoResolution resolution) async {
    await dispose();
    final preset = resolution.preset;
    if (preset == null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('noCamera', 'El dispositivo no tiene cámara.');
    }
    final front = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(front, preset);
    _controller = controller;
    await controller.initialize();
    await controller.prepareForVideoRecording();
  }

  /// Graba con la orientación fija en [orientation], para que el video no
  /// gire cuando el jugador incline el celular.
  Future<void> startRecording(DeviceOrientation orientation) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.lockCaptureOrientation(orientation);
    await controller.startVideoRecording();
  }

  /// Detiene la grabación y devuelve el archivo grabado, o null si no se
  /// estaba grabando.
  Future<XFile?> stopRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) return null;
    return controller.stopVideoRecording();
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
