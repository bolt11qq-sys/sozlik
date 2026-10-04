import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ingichka chiziqli ikonkalar — maketdagi SVG yo'llari aynan ko'chirilgan.
/// Emoji ishlatilmaydi (TZ 7-bo'lim).
enum AppIcons {
  settings('<circle cx="12" cy="12" r="3.2"/><path d="M19.4 14.5a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1v.3a2 2 0 1 1-4 0v-.2a1.6 1.6 0 0 0-2.8-1.1l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H3.4a2 2 0 1 1 0-4h.2a1.6 1.6 0 0 0 1.1-2.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 2.7-1.1V3.4a2 2 0 1 1 4 0v.2a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 1.1 2.7h.3a2 2 0 1 1 0 4h-.2a1.6 1.6 0 0 0-1.5 1z"/>'),
  play('<path d="M7 4.5v15l12-7.5z"/>'),
  book('<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V3H6.5A2.5 2.5 0 0 0 4 5.5z"/><path d="M4 19.5A2.5 2.5 0 0 0 6.5 22H20v-5"/>'),
  pencil('<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>'),
  swap('<path d="M7 7h13l-4-4"/><path d="M17 17H4l4 4"/>'),
  ear('<path d="M6 8a6 6 0 1 1 12 0c0 3-2 4-3 6s-1 4-3 4a3 3 0 0 1-3-3"/><path d="M9 8a3 3 0 0 1 6 0"/>'),
  warning('<path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2.4 17a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/>'),
  chevronRight('<path d="m9 6 6 6-6 6"/>'),
  chevronDown('<path d="m6 9 6 6 6-6"/>'),
  back('<path d="M15 18l-6-6 6-6"/>'),
  brain('<path d="M9.5 3a3 3 0 0 0-3 3 3 3 0 0 0-2 5.2A3 3 0 0 0 6 16.5 3 3 0 0 0 9 20a2.5 2.5 0 0 0 3-2.4V5.5A2.5 2.5 0 0 0 9.5 3z"/><path d="M14.5 3a3 3 0 0 1 3 3 3 3 0 0 1 2 5.2 3 3 0 0 1-1.5 5.3A3 3 0 0 1 15 20a2.5 2.5 0 0 1-3-2.4"/>'),
  list('<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>'),
  chart('<path d="M3 21h18"/><path d="M6 17v-6M11 17V7M16 17v-9M21 17v-3"/>'),
  plus('<path d="M12 5v14M5 12h14"/>'),
  minus('<path d="M5 12h14"/>'),
  download('<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>'),
  upload('<path d="M12 21V9M7 14l5-5 5 5M5 3h14"/>'),
  check('<path d="M20 6 9 17l-5-5"/>'),
  close('<path d="M18 6 6 18M6 6l12 12"/>'),
  tag('<path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.5"/>'),
  target('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.4"/>'),
  undo('<path d="M3 7v6h6"/><path d="M3 13a9 9 0 1 0 3-7.7L3 8"/>'),
  speaker('<path d="M11 5 6 9H3v6h3l5 4z"/><path d="M16 9a4 4 0 0 1 0 6"/><path d="M19 6a8 8 0 0 1 0 12"/>'),
  slow('<path d="M4 16a8 8 0 0 1 16 0z"/><path d="M4 16h16M8 16v3M16 16v3M20 13h2M4 13H2"/>'),
  bell('<path d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>'),
  clock('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  save('<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8M7 3v5h8"/>'),
  flame('<path d="M12 22a7 7 0 0 0 7-7c0-4-3-6-4-9-2.5 1.5-3 4-3 4s-1-1-1-3c-3 2-6 5-6 8a7 7 0 0 0 7 7z"/>'),
  sort('<path d="M3 5h18M6 12h12M10 19h4"/>'),
  search('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
  trash('<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/>'),
  archive('<path d="M3 4h18v4H3z"/><path d="M5 8v12h14V8"/><path d="M10 12h4"/>'),
  moon('<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>'),
  calendar('<path d="M4 5h16v16H4z"/><path d="M16 3v4M8 3v4M4 10h16"/>'),
  history('<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/>'),
  file('<path d="M14 3H6v18h12V7z"/><path d="M14 3v4h4"/><path d="M9 13h6M9 17h6"/>'),
  reset('<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>'),
  message('<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>'),
  info('<circle cx="12" cy="12" r="9"/><path d="M12 16v-4M12 8h.01"/>'),
  layers('<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>');

  const AppIcons(this.body);
  final String body;
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 20, this.color, this.stroke = 1.8});

  final AppIcons icon;
  final double size;
  final Color? color;
  final double stroke;

  static final Map<String, String> _cache = {};

  String get _svg => _cache.putIfAbsent(
        '${icon.name}/$stroke',
        () => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
            'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      );

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF151B18);
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// So'zlik logosi: S shaklidagi takrorlash yo'li va uch nuqta (1-konsept).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, required this.color, this.inverse = false});

  final double size;
  final Color color;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final bg = inverse ? '#FFFFFF' : hex(color);
    final fg = inverse ? hex(color) : '#FFFFFF';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="12 12 96 96" fill="none">'
        '<rect x="12" y="12" width="96" height="96" rx="26" fill="$bg"/>'
        '<path d="M78 44c0-7-8-12-18-12s-18 5-18 11c0 14 36 8 36 23 0 7-8 12-18 12s-18-5-18-12" stroke="$fg" stroke-width="7" stroke-linecap="round"/>'
        '<circle cx="42" cy="43" r="4.5" fill="$fg"/><circle cx="78" cy="66" r="4.5" fill="$fg"/><circle cx="42" cy="78" r="4.5" fill="$fg"/>'
        '</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
