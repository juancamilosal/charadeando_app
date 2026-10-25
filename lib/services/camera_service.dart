import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'screen_orientation.dart';

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
    // La pantalla de antes del turno ya va en horizontal: la vista de la
    // cámara se fija en la misma orientación del juego. Si no, sigue al
    // sensor y, con el celular todavía vertical, se ve como una franja
    // angosta en el centro.
    try {
      await controller.lockCaptureOrientation(ScreenOrientation.game);
    } on CameraException catch (e) {
      debugPrint('[Cámara] No se pudo fijar la orientación: $e');
    }
  }

  /// La pantalla de antes del turno giró hacia el otro lado: la vista de
  /// la cámara gira con ella (mientras graba no se toca).
  Future<void> follow(DeviceOrientation orientation) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isRecordingVideo) {
      return;
    }
    try {
      await controller.lockCaptureOrientation(orientation);
    } on CameraException catch (e) {
      debugPrint('[Cámara] No se pudo girar la vista: $e');
    }
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
