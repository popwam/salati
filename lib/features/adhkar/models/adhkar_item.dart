class AdhkarItem {
  const AdhkarItem({
    required this.id,
    required this.categoryId,
    required this.text,
    required this.requiredCount,
    this.title,
    this.source,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String categoryId;
  final String text;
  final int requiredCount;
  final String? title;
  final String? source;
  final bool isActive;
  final int sortOrder;

  factory AdhkarItem.fromMap(
    String id,
    String categoryId,
    Map<String, dynamic> map,
  ) {
    return AdhkarItem(
      id: id,
      categoryId: categoryId,
      title: map['title'] as String?,
      text: map['text'] as String? ?? '',
      source: map['source'] as String?,
      requiredCount: (map['count'] as num?)?.toInt() ?? 1,
      isActive: map['isActive'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
