import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'app_icon.dart';

/// Bosilganda yengil kichrayadigan, to'lqinli sirt — barcha tugma va
/// kartochkalarning asosi.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.radius = 16,
    this.border,
    this.shadow,
    this.padding,
    this.haptic = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double radius;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final br = BorderRadius.circular(widget.radius);
    Widget body = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        onHighlightChanged: (v) => setState(() => _down = v),
        child: widget.padding == null ? widget.child : Padding(padding: widget.padding!, child: widget.child),
      ),
    );
    body = DecoratedBox(
      decoration: BoxDecoration(color: widget.color, borderRadius: br, border: widget.border, boxShadow: widget.shadow),
      child: ClipRRect(borderRadius: br, child: body),
    );
    if (widget.semanticLabel != null) {
      body = Semantics(button: true, label: widget.semanticLabel, enabled: enabled, child: body);
    }
    return AnimatedScale(
      scale: _down && enabled ? 0.975 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: body,
    );
  }
}

/// Oq kartochka (radius 16–24, soyasiz).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (onTap != null) {
      return Pressable(onTap: onTap, color: color ?? c.card, radius: radius, padding: padding, child: child);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? c.card, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}

/// Rangli fonli ikonka qutisi (36×36, radius 11).
class IconBox extends StatelessWidget {
  const IconBox(
    this.icon, {
    super.key,
    required this.color,
    this.size = 36,
    this.iconSize = 18,
    this.radius = 11,
    this.child,
  });

  final AppIcons? icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.c.soft(color), borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: child ?? AppIcon(icon!, size: iconSize, color: color),
    );
  }
}

/// Sarlavhadagi 42×42 kvadrat tugma.
class SquareButton extends StatelessWidget {
  const SquareButton(
    this.icon, {
    super.key,
    required this.onTap,
    required this.label,
    this.size = 42,
    this.color,
    this.iconColor,
    this.child,
  });

  final AppIcons icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final Color? color;
  final Color? iconColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        color: color ?? c.card,
        radius: 12,
        semanticLabel: label,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child:
                child ?? AppIcon(icon, size: 20, color: onTap == null ? c.sec.withAlpha(0x80) : (iconColor ?? c.ink)),
          ),
        ),
      ),
    );
  }
}

/// Ekran sarlavhasi: orqaga — nom — o'ng tugma.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SquareButton(AppIcons.back, label: 'Orqaga', onTap: onBack ?? () => Navigator.of(context).maybePop()),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: T.text(16, w: FontWeight.w700, color: context.c.ink),
          ),
        ),
        trailing ?? const SizedBox(width: 42),
      ],
    );
  }
}

enum ButtonKind { primary, secondary, danger }

/// Pastki katta tugma (52–54 px, radius 15).
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = ButtonKind.primary,
    this.height = 52,
    this.color,
    this.foreground,
  });

  final String label;
  final VoidCallback? onTap;
  final AppIcons? icon;
  final ButtonKind kind;
  final double height;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = onTap == null;
    final (bg, fg, border) = switch (kind) {
      ButtonKind.primary => (color ?? c.accent, foreground ?? c.onAccent, null),
      ButtonKind.danger => (color ?? c.red, foreground ?? (c.isDark ? c.bg : Colors.white), null),
      ButtonKind.secondary => (color ?? c.card, foreground ?? c.ink, Border.all(color: c.line)),
    };
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        color: bg,
        radius: 15,
        border: border,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[AppIcon(icon!, size: 19, color: fg, stroke: 2.1), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.text(15, color: fg, w: kind == ButtonKind.secondary ? FontWeight.w600 : FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastki tugmalar paneli (fon rangida, xavfsiz hudud bilan).
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.c.bg,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Kartochka ichidagi ro'yxat qatori: ikonka — sarlavha/izoh — o'ng qism.
class RowItem extends StatelessWidget {
  const RowItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.divider = true,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.line)) : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: T.text(14, w: FontWeight.w600, color: titleColor ?? c.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: T.text(12, color: c.sec, height: 1.35)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Bir nechta [RowItem] uchun kartochka (oxirgisida chiziq yo'q).
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children, this.header});

  final List<RowItem> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final r = children[i];
      items.add(
        RowItem(
          title: r.title,
          subtitle: r.subtitle,
          leading: r.leading,
          trailing: r.trailing,
          onTap: r.onTap,
          titleColor: r.titleColor,
          divider: i < children.length - 1,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: context.c.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) Padding(padding: const EdgeInsets.only(top: 14, bottom: 2), child: header!),
              ...items,
            ],
          ),
        ),
      ),
    );
  }
}

/// "KUNLIK CHEGARA" kabi bo'lim sarlavhasi.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
    child: Text(
      text.toUpperCase(),
      style: T.text(12, w: FontWeight.w700, color: context.c.sec, spacing: 0.5),
    ),
  );
}

/// Kichik yumaloq belgi: "3-bosqich", "yangi", "qiyin".
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.filled = true, this.size = 10});

  final String text;
  final Color color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: filled ? context.c.soft(color) : null, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: T.text(size, w: FontWeight.w600, color: color),
    ),
  );
}

/// Filtr chipi (bosiladigan).
class FilterChipX extends StatelessWidget {
  const FilterChipX({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        radius: 999,
        color: selected ? c.accent : c.card,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        child: Text(
          label,
          style: T.text(13, w: FontWeight.w600, color: selected ? c.onAccent : c.ink),
        ),
      ),
    );
  }
}

/// Maketdagi kalit (46×28).
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: value ? c.accent : c.line, borderRadius: BorderRadius.circular(999)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x2E000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ma'lumot kartochkasi: ikonka + izoh (maketdagi pastki maslahatlar).
class HintCard extends StatelessWidget {
  const HintCard({super.key, required this.text, this.icon = AppIcons.warning, this.color, this.child});

  final String text;
  final AppIcons icon;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBox(icon, color: color ?? c.amber),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(text, style: T.text(13, color: c.sec, height: 1.5)),
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

/// Kichik statistik plitka: "Jami 814".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color, this.onTap});

  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: T.text(11, color: c.sec),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(value, style: T.display(19, color: color ?? c.ink)),
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
    ),
  );
}
