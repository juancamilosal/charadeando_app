import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// Muestra las categorías una tras otra, para contar que también se puede
/// jugar por categorías.
class CategoryTicker extends StatefulWidget {
  const CategoryTicker({super.key});

  @override
  State<CategoryTicker> createState() => _CategoryTickerState();
}

class _CategoryTickerState extends State<CategoryTicker> {
  static const _interval = Duration(milliseconds: 1600);

  final _categories = GameCategory.themed;
  late final Timer _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      setState(() => _index = (_index + 1) % _categories.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = _categories[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '¡También puedes jugar por categorías!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.6), end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _Pill(key: ValueKey(category), category: category),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.category});

  final GameCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, color: category.color),
          const SizedBox(width: 8),
          Text(
            category.label,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
