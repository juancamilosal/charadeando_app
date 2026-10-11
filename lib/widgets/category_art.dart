import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'art_cycle.dart';

/// Dibujo animado de la categoría (`assets/img/categorias/<categoría>.gif`).
/// Las categorías que todavía no tienen GIF muestran su ícono. Dentro de un
/// [ArtCycle] se anima solo cuando le toca y el resto del tiempo se queda
/// quieto; si no, se anima sin parar.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    required this.size,
    this.color = Colors.white,
  });

  /// Categorías que ya tienen su GIF en la carpeta, con el cuadro en el
  /// que se quedan quietas: el que mejor las muestra.
  static const restFrames = {
    GameCategory.free: 28, // La hoja con todas sus líneas.
    GameCategory.animals: 0,
    GameCategory.geography: 0,
    GameCategory.movies: 0,
    GameCategory.celebrities: 0,
    GameCategory.brands: 28,
    GameCategory.sports: 22, // El balón rebota y queda en el centro.
    GameCategory.soccerTeams: 0,
  };

  final GameCategory category;
  final double size;

  /// Color del ícono cuando no hay GIF.
  final Color color;

  static String asset(GameCategory category) =>
      'assets/img/categorias/${category.code.toLowerCase()}.gif';

  @override
  Widget build(BuildContext context) {
    final icon = Icon(category.icon, size: size, color: color);
    if (!restFrames.containsKey(category)) return icon;
    if (ArtCycle.maybeOf(context) != null) {
      return _CycledGif(category: category, size: size, fallback: icon);
    }
    return Image.asset(
      asset(category),
      width: size,
      height: size,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => icon,
    );
  }
}

/// El GIF cuadro por cuadro, para animarlo una vuelta cuando le toca en el
/// ciclo.
class _CycledGif extends StatefulWidget {
  const _CycledGif({
    required this.category,
    required this.size,
    required this.fallback,
  });

  final GameCategory category;
  final double size;
  final Widget fallback;

  @override
  State<_CycledGif> createState() => _CycledGifState();
}

class _CycledGifState extends State<_CycledGif> implements CycleMember {
  /// Los GIF muy cortos dan vueltas hasta animarse al menos este tiempo.
  static const _minPlay = Duration(milliseconds: 1500);

  ArtCycleState? _cycle;
  ui.Codec? _codec;

  /// El cuadro de reposo, y el que se ve mientras se anima.
  ui.Image? _rest;
  ui.Image? _frame;
  bool _failed = false;
  bool _disposed = false;

  Timer? _wait;
  Completer<void>? _waiting;

  @override
  int get order => widget.category.index;

  @override
  bool get canPlay {
    if (_codec == null || _rest == null || !mounted) return false;
    // Una ruta encima (por ejemplo, la bienvenida) apaga TickerMode.
    if (!TickerMode.valuesOf(context).enabled) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final seen = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    // Se salta si se ve menos de la mitad.
    return !seen.isEmpty && seen.height >= rect.height / 2;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cycle = ArtCycle.maybeOf(context);
    if (cycle != _cycle) {
      _cycle?.remove(this);
      _cycle = cycle?..add(this);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cycle?.remove(this);
    _wait?.cancel();
    if (_waiting?.isCompleted == false) _waiting!.complete();
    _frame?.dispose();
    _rest?.dispose();
    _codec?.dispose();
    super.dispose();
  }

  /// Decodifica el GIF y avanza hasta el cuadro de reposo.
  Future<void> _load() async {
    try {
      final data = await rootBundle.load(CategoryArt.asset(widget.category));
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final restIndex =
          CategoryArt.restFrames[widget.category]! % codec.frameCount;
      ui.Image? rest;
      for (var i = 0; i <= restIndex; i++) {
        final frame = await codec.getNextFrame();
        rest?.dispose();
        rest = frame.image;
      }
      if (_disposed) {
        rest?.dispose();
        codec.dispose();
        return;
      }
      setState(() {
        _codec = codec;
        _rest = rest;
      });
    } on Exception catch (e) {
      debugPrint('[Categorías] No se pudo cargar el GIF: $e');
      if (!_disposed) setState(() => _failed = true);
    }
  }

  /// Una vuelta completa desde el cuadro de reposo hasta volver a él. El
  /// códec queda listo para la próxima vuelta.
  @override
  Future<void> play() async {
    final codec = _codec;
    if (codec == null) return;
    final watch = Stopwatch()..start();
    do {
      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        if (_disposed) {
          frame.image.dispose();
          return;
        }
        final old = _frame;
        setState(() => _frame = frame.image);
        old?.dispose();
        await _sleep(frame.duration);
        if (_disposed) return;
      }
    } while (watch.elapsed < _minPlay);
    // El último cuadro es el de reposo: se vuelve a mostrar el guardado.
    final old = _frame;
    setState(() => _frame = null);
    old?.dispose();
  }

  /// Espera [duration], o hasta que se cierre la pantalla.
  Future<void> _sleep(Duration duration) {
    final waiting = _waiting = Completer<void>();
    _wait = Timer(duration, waiting.complete);
    return waiting.future;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    return RawImage(
      image: _frame ?? _rest,
      width: widget.size,
      height: widget.size,
      // Como Image.asset: se achica para caber, pero no se agranda.
      fit: BoxFit.scaleDown,
    );
  }
}
