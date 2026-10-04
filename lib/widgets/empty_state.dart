import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_card.dart';
import 'app_icon.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.text,
    this.icon,
    this.logo = false,
    this.actions = const [],
  });

  final String title;
  final String text;
  final AppIcons? icon;
  final bool logo;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        children: [
          if (logo)
            AppLogo(size: 64, color: c.accent)
          else if (icon != null)
            IconBox(icon, color: c.accent, size: 56, iconSize: 26, radius: 16),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: T.display(20, color: c.ink)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: T.text(13, color: c.sec, height: 1.55)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }
}
