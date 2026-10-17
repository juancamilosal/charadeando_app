import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../theme.dart';
import 'premium_sheet.dart';

/// "Celular juez" en la configuración: se enciende con el interruptor, se
/// crea la sala y se muestra el QR (y el código, por si no pueden
/// escanearlo) para que otra persona sea el juez desde su celular. Dice si
/// el juez ya se conectó; se puede seguir sin él. Es de pago: sin Premium
/// lleva candado y abre la compra.
class JudgeSetupView extends ConsumerWidget {
  const JudgeSetupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(judgeProvider);
    final unlocked = ref.watch(judgeUnlockedProvider);
    final controller = ref.read(judgeProvider.notifier);
    final room = setup.room;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Usar celular juez',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!unlocked) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lock,
                          size: 18,
                          color: AppColors.orange,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Otra persona marca los aciertos desde su celular, '
                    'sin instalar nada. Así nadie tiene que inclinar el '
                    'celular.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: setup.on,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.purple,
              onChanged: (on) {
                if (!unlocked) {
                  showPremiumSheet(context);
                  return;
                }
                on ? controller.start() : controller.stop();
              },
            ),
          ],
        ),
        if (setup.creating)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 10),
                Text('Creando la sala…'),
              ],
            ),
          ),
        if (setup.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: AppColors.coral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                  ),
                  onPressed: controller.start,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        if (room != null) _RoomView(room: room),
      ],
    );
  }
}

class _RoomView extends ConsumerWidget {
  const _RoomView({required this.room});

  final JudgeRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: room.gone,
      builder: (context, gone, _) {
        if (gone) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'La sala ya no existe.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                  ),
                  onPressed: ref.read(judgeProvider.notifier).start,
                  child: const Text('Crear otra'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            children: [
              const Text(
                'El juez escanea este código con la cámara de su celular:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDE7F6), width: 2),
                ),
                child: QrImageView(
                  data: room.judgeUrl,
                  size: 190,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.ink,
                  ),
                  semanticsLabel: 'Código QR del celular juez',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'O que abra esta página y escriba el código:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              SelectableText(
                room.baseUrl.replaceFirst(RegExp('^https?://'), ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                room.code,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 40,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<int>(
                valueListenable: room.judges,
                builder: (context, judges, _) {
                  final ready = judges > 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ready
                          ? AppColors.green.withValues(alpha: 0.15)
                          : const Color(0xFFF3EEFB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      judgeStatus(judges),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ready ? const Color(0xFF0E7A40) : AppColors.ink,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Pueden seguir sin esperar: el juez puede entrar en '
                'cualquier momento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Esperando al juez…", "Juez conectado ✓" o "2 jueces conectados ✓".
String judgeStatus(int judges) => switch (judges) {
  0 => 'Esperando al juez…',
  1 => 'Juez conectado ✓',
  _ => '$judges jueces conectados ✓',
};
