import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Fondo oscuro del turno de Fotomímica, para que la foto resalte.
const photoMimeBackground = Color(0xFF14121C);

/// Lo que se ve en el turno de Fotomímica: la foto del objeto lo más
/// grande posible (sin deformarla) y, debajo, su nombre en letra pequeña
/// para quien actúa. La foto ya está en el celular: no se carga nada.
class PhotoMimeView extends StatelessWidget {
  const PhotoMimeView({super.key, required this.word, this.nameSize = 18});

  final Word word;

  /// Tamaño de la letra del nombre.
  final double nameSize;

  @override
  Widget build(BuildContext context) {
    final image = word.image;
    return Column(
      children: [
        Expanded(
          child: image == null
              ? const SizedBox.expand()
              : Image.file(
                  File(image),
                  key: ValueKey(image),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  // Al cambiar de objeto no queda un instante en blanco.
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  // Si la foto se dañó en el celular, al menos queda el
                  // nombre.
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.white38,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          word.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.body,
            color: Colors.white70,
            fontSize: nameSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
