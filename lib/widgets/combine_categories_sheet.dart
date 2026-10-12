import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme.dart';
import 'category_art.dart';

/// Aviso de que algo se desbloquea con premium.
void showPremiumNotice(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Para $what necesitas premium.')));
}

/// Abre "Combinar categorías" desde abajo. Devuelve verdadero si se eligió
/// una combinación para jugar (queda configurada).
Future<bool?> showCombineCategories(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => const CombineCategoriesSheet(),
  );
}

/// "Combinar categorías": se marcan dos o más categorías (del juego y
/// propias) y se juega una partida con palabras de todas. Libre no está:
/// sus frases son de cualquier tema. La última combinación se recuerda.
class CombineCategoriesSheet extends ConsumerStatefulWidget {
  const CombineCategoriesSheet({super.key});

  /// Mínimo de categorías para combinar.
  static const minCategories = 2;

  @override
  ConsumerState<CombineCategoriesSheet> createState() =>
      _CombineCategoriesSheetState();
}

class _CombineCategoriesSheetState
    extends ConsumerState<CombineCategoriesSheet> {
  final _games = <GameCategory>{};
  final _custom = <String>{};

  @override
  void initState() {
    super.initState();
    _restore();
  }

  bool get _premium => ref.read(premiumUnlockedProvider);

  bool _locked(GameCategory c) =>
      !_premium && ref.read(premiumCategoriesProvider).contains(c);

  List<CustomCategory> get _customCategories =>
      ref.read(customCategoriesProvider).value?.categories ?? const [];

  /// Marca la última combinación, sin las que ya no se pueden jugar.
  Future<void> _restore() async {
    final saved = await ref.read(mixStoreProvider).load();
    // Se espera a que carguen las categorías propias, si todavía no.
    final data = await ref.read(customCategoriesProvider.future);
    if (!mounted) return;
    final custom = {
      for (final c in data.categories)
        if (c.playable) c.id,
    };
    setState(() {
      for (final code in saved.categories) {
        final c = GameCategory.byCode(code);
        if (c != null && c != GameCategory.free && !_locked(c)) _games.add(c);
      }
      _custom.addAll(saved.custom.where(custom.contains));
    });
  }

  int get _count => _games.length + _custom.length;

  Future<void> _start() async {
    final games = [
      for (final c in GameCategory.themed)
        if (_games.contains(c)) c,
    ];
    final custom = [
      for (final c in _customCategories)
        if (_custom.contains(c.id)) c,
    ];
    ref
        .read(mixStoreProvider)
        .save(
          SavedMix(
            categories: [for (final c in games) c.code],
            custom: [for (final c in custom) c.id],
          ),
        )
        .ignore();
    final controller = ref.read(gameControllerProvider.notifier);
    controller.configure(
      ref
          .read(gameControllerProvider)
          .config
          .copyWith(
            category: GameCategory.free,
            clearCustomCategory: true,
            wordSource: WordSource.random,
            // Por defecto se juega sin grupos, como en las demás.
            inGroups: false,
            mixCategories: games,
            mixCustom: custom,
          ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customCategoriesProvider);
    final custom = _customCategories;
    final count = _count;
    final ready = count >= CombineCategoriesSheet.minCategories;
    // Un Scaffold propio para que los avisos se vean encima de la ventana.
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3D7F7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(
                  'Combinar categorías',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Marca al menos 2. Las palabras se reparten en partes '
                  'iguales entre las que elijas.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B5A86)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  children: [
                    const _SectionTitle('Categorías del juego'),
                    for (final c in GameCategory.themed)
                      _PickRow(
                        leading: _GameArt(category: c),
                        title: c.label,
                        checked: _games.contains(c),
                        locked: _locked(c),
                        onTap: () => _locked(c)
                            ? showPremiumNotice(context, 'jugar ${c.label}')
                            : setState(
                                () => _games.contains(c)
                                    ? _games.remove(c)
                                    : _games.add(c),
                              ),
                      ),
                    if (custom.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const _SectionTitle('Mis categorías'),
                      for (final c in custom)
                        _PickRow(
                          leading: _CustomArt(category: c),
                          title: c.name,
                          subtitle: c.playable ? null : 'Faltan palabras',
                          checked: _custom.contains(c.id),
                          enabled: c.playable,
                          onTap: () => setState(
                            () => _custom.contains(c.id)
                                ? _custom.remove(c.id)
                                : _custom.add(c.id),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A2B0A57),
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFEDE6F8),
                      disabledForegroundColor: const Color(0xFF8A7AA6),
                    ),
                    icon: const Icon(Icons.shuffle),
                    // En un solo renglón: si no cabe, la letra se achica.
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ready
                            ? 'Empezar a jugar · $count categorías'
                            : 'Elige al menos 2 categorías',
                      ),
                    ),
                    onPressed: ready ? _start : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.purple,
        ),
      ),
    );
  }
}

/// Una categoría de la lista. Tocar la fila entera la marca o desmarca.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.leading,
    required this.title,
    required this.checked,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.locked = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback onTap;

  /// Falso si no se puede marcar (una categoría propia con pocas palabras).
  final bool enabled;

  /// Premium sin desbloquear: lleva candado y al tocarla se avisa.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !locked;
    return Opacity(
      opacity: active ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coral,
                        ),
                      ),
                  ],
                ),
              ),
              if (locked)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.lock, color: AppColors.ink),
                )
              else
                Checkbox(
                  value: checked,
                  activeColor: AppColors.purple,
                  onChanged: active ? (_) => onTap() : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dibujo de una categoría del juego, quieto, en su color.
class _GameArt extends StatelessWidget {
  const _GameArt({required this.category});

  final GameCategory category;

  @override
  Widget build(BuildContext context) {
    final hasArt = CategoryArt.restFrames.containsKey(category);
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: hasArt
          ? Image.asset(
              CategoryArt.restAsset(category),
              errorBuilder: (_, _, _) =>
                  Icon(category.icon, color: Colors.white),
            )
          : Icon(category.icon, color: Colors.white),
    );
  }
}

/// Ícono de una categoría propia en su color.
class _CustomArt extends StatelessWidget {
  const _CustomArt({required this.category});

  final CustomCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(category.icon, color: Colors.white, size: 30),
    );
  }
}
