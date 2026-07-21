class AdhkarCategory {
  const AdhkarCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    this.isPremium = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isPremium;

  bool get isFavorites => id == 'favorites';
}
