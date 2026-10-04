class Tag {
  const Tag(this.name, this.count);

  final String name;
  final int count;

  /// Teglar ro'yxatini so'zlardan yig'adi: eng ko'p ishlatilgani birinchi.
  static List<Tag> collect(Iterable<List<String>> tagLists) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final list in tagLists) {
      for (final t in list) {
        final k = t.trim().toLowerCase();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
        display.putIfAbsent(k, () => t.trim());
      }
    }
    final out = counts.entries.map((e) => Tag(display[e.key]!, e.value)).toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return out;
  }
}
