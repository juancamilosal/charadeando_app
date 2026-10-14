import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme.dart';
import 'category_card.dart';

/// Lo que trae Premium, para mostrarlo igual en todas partes.
const premiumBenefits = [
  'Todas las categorías de pago, también las que vengan',
  'Videos en Full HD y calidad máxima',
  'Categorías propias sin límite',
];

/// Abre desde abajo la invitación a Premium. Con [category], muestra esa
/// categoría de pago arriba. Devuelve verdadero si quedó desbloqueado.
Future<bool?> showPremiumSheet(
  BuildContext context, {
  GameCategory? category,
  Color? color,
}) => showModalBottomSheet<bool>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => PremiumSheet(category: category, color: color),
);

/// "Charadeando Premium": pago único con Google Play, "Restaurar compras" y
/// "Tengo un código". Se cierra sola cuando queda desbloqueado.
class PremiumSheet extends ConsumerStatefulWidget {
  const PremiumSheet({super.key, this.category, this.color});

  /// La categoría de pago que se tocó, o null si se abrió desde Ajustes.
  final GameCategory? category;

  /// Color de su tarjeta (el de su sección).
  final Color? color;

  @override
  ConsumerState<PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends ConsumerState<PremiumSheet> {
  late final Future<String?> _price = ref.read(premiumBillingProvider).price();
  StreamSubscription<BillingEvent>? _events;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(premiumProvider.notifier).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _onEvent(BillingEvent event) {
    if (!mounted) return;
    setState(() => _buying = false);
    switch (event) {
      case BillingEvent.owned:
        _done('¡Listo! Ya tienes Charadeando Premium.');
      case BillingEvent.failed:
        _say('No se pudo completar la compra. Inténtalo otra vez.');
      case BillingEvent.canceled:
        break;
    }
  }

  /// Quedó desbloqueado: se cierra y se avisa.
  void _done(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final started = await ref.read(premiumProvider.notifier).buy();
    if (!mounted) return;
    if (!started) {
      setState(() => _buying = false);
      _say(
        'Las compras no están disponibles en este celular. Revisa que '
        'tenga Google Play.',
      );
    }
  }

  Future<void> _restore() async {
    _say('Buscando tus compras en Google Play…');
    await ref.read(premiumProvider.notifier).restore();
  }

  Future<void> _code() async {
    final unlock = await showRedeemCodeDialog(context);
    if (unlock == null || !mounted) return;
    final category = widget.category;
    if (unlock.all ||
        (category != null && unlock.categories.contains(category.code))) {
      _done(redeemedMessage(unlock));
    } else {
      _say(redeemedMessage(unlock));
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3D7F7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (category != null) ...[
              Center(
                child: SizedBox(
                  width: 112,
                  height: 140,
                  child: CategoryCard.game(
                    category,
                    compact: true,
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              category != null
                  ? '${category.label} es Premium'
                  : 'Charadeando Premium',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category != null
                  ? 'Desbloquéala con Premium, junto con todo lo demás.'
                  : 'Un solo pago y es tuyo para siempre.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B5A86),
              ),
            ),
            const SizedBox(height: 14),
            _PremiumBox(price: _price, buying: _buying, onBuy: _buy),
            const SizedBox(height: 6),
            // En celulares angostos (o con letra grande) los dos botones
            // pasan uno debajo del otro.
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                  ),
                  onPressed: _restore,
                  child: const Text('Restaurar compras'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                  ),
                  onPressed: _code,
                  child: const Text('Tengo un código'),
                ),
              ],
            ),
            const Text(
              'Pago único con Google Play.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF8E80A6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// El recuadro morado de Premium: lo que trae y el botón con el precio.
class _PremiumBox extends StatelessWidget {
  const _PremiumBox({
    required this.price,
    required this.buying,
    required this.onBuy,
  });

  final Future<String?> price;
  final bool buying;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.purple, AppColors.magenta],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.yellow, size: 26),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Charadeando Premium',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final benefit in premiumBenefits)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 17,
                    color: AppColors.yellow,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: price,
            builder: (context, snapshot) {
              final price = snapshot.data;
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: buying ? null : onBuy,
                child: buying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(
                        price == null
                            ? 'Desbloquear todo'
                            : 'Desbloquear todo · $price',
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Qué se desbloqueó con un código, para avisarlo.
String redeemedMessage(CodeUnlock unlock) {
  if (unlock.all) return '¡Listo! Desbloqueaste todo Charadeando.';
  final names = [
    for (final code in unlock.categories)
      GameCategory.byCode(code)?.label ?? code,
  ];
  if (names.isEmpty) return '¡Listo! Código canjeado.';
  final list = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
  return '¡Listo! Desbloqueaste $list.';
}

/// Pide un código y lo canjea. Devuelve lo que abrió, o null si se cerró.
Future<CodeUnlock?> showRedeemCodeDialog(BuildContext context) =>
    showDialog<CodeUnlock>(
      context: context,
      builder: (_) => const RedeemCodeDialog(),
    );

/// "Canjear código": un campo y el botón. Los errores del servidor ("Este
/// código ya venció.") se muestran debajo del campo.
class RedeemCodeDialog extends ConsumerStatefulWidget {
  const RedeemCodeDialog({super.key});

  @override
  ConsumerState<RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends ConsumerState<RedeemCodeDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Escribe el código.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final unlock = await ref.read(premiumProvider.notifier).redeem(code);
      if (mounted) Navigator.pop(context, unlock);
    } on CodeException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Canjear código'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_\- ]')),
          LengthLimitingTextInputFormatter(40),
        ],
        onSubmitted: (_) => _redeem(),
        decoration: InputDecoration(
          labelText: 'Código',
          hintText: 'Por ejemplo, FAMILIA2026',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          // El tema pone los botones de texto en blanco, para los fondos.
          style: TextButton.styleFrom(foregroundColor: AppColors.purple),
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _redeem,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Canjear'),
        ),
      ],
    );
  }
}
