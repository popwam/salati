import 'package:flutter/foundation.dart';

import '../../../core/services/analytics_service.dart';
import '../data/firestore_adhkar_repository.dart';
import '../data/local_adhkar_progress_repository.dart';
import '../data/local_adhkar_repository.dart';
import '../models/adhkar_category.dart';
import '../models/adhkar_item.dart';

class AdhkarController extends ChangeNotifier {
  AdhkarController({
    required LocalAdhkarRepository repository,
    required LocalAdhkarProgressRepository progressRepository,
    required FirestoreAdhkarRepository firestoreRepository,
    required AnalyticsService analyticsService,
  }) : _repository = repository,
       _progressRepository = progressRepository,
       _firestoreRepository = firestoreRepository,
       _analyticsService = analyticsService;

  final LocalAdhkarRepository _repository;
  final LocalAdhkarProgressRepository _progressRepository;
  final FirestoreAdhkarRepository _firestoreRepository;
  final AnalyticsService _analyticsService;

  bool _isLoading = true;
  List<AdhkarCategory> _categories = const [];
  Set<String> _favorites = {};
  Set<String> _completedCategories = {};
  Map<String, int> _counts = const {};
  Map<String, AdhkarCategoryState> _categoryStates =
      const <String, AdhkarCategoryState>{};

  bool get isLoading => _isLoading;
  List<AdhkarCategory> get categories => _categories;
  Set<String> get favorites => _favorites;
  bool isCategoryCompleted(String categoryId) =>
      _completedCategories.contains(_categoryCompletionKey(categoryId));

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final localCategories = await _repository.getCategories();
    var remoteCategories = const <AdhkarCategory>[];
    try {
      remoteCategories = await _firestoreRepository.loadCategories();
    } catch (_) {
      remoteCategories = const <AdhkarCategory>[];
    }
    _categories = _mergeCategories(localCategories, remoteCategories);
    _favorites = await _progressRepository.loadFavorites();
    _completedCategories = (await _progressRepository.loadCompleted())
        .where((item) => item.startsWith('category:'))
        .toSet();
    _counts = await _progressRepository.loadCounts();
    _isLoading = false;
    notifyListeners();
  }

  AdhkarCategoryState stateFor(String categoryId) {
    return _categoryStates[categoryId] ?? const AdhkarCategoryState();
  }

  int progressFor(String itemId) => _counts[itemId] ?? 0;

  bool isCompleted(AdhkarItem item) =>
      progressFor(item.id) >= item.requiredCount;

  Future<void> loadCategory(
    AdhkarCategory category, {
    bool force = false,
  }) async {
    final current = stateFor(category.id);
    if (!force && (current.isLoading || current.hasResolved)) {
      return;
    }

    _setCategoryState(
      category.id,
      current.copyWith(isLoading: true, clearError: true),
    );

    if (category.isFavorites) {
      await _loadFavoritesCategory();
      return;
    }

    final fallbackItems = await _repository.getFallbackItems(category.id);
    if (fallbackItems.isNotEmpty) {
      _setCategoryState(
        category.id,
        AdhkarCategoryState(
          items: fallbackItems,
          sourceLabel: 'المحتوى المحلي',
          isLoaded: true,
        ),
      );
    }

    try {
      final remoteItems = await _firestoreRepository.loadItemsForCategory(
        category.id,
      );
      if (remoteItems.isNotEmpty) {
        final mergedItems = _mergeItems(fallbackItems, remoteItems);
        _setCategoryState(
          category.id,
          AdhkarCategoryState(
            items: mergedItems,
            sourceLabel: 'Firestore',
            isLoaded: true,
          ),
        );
        return;
      }

      _setCategoryState(
        category.id,
        AdhkarCategoryState(
          items: fallbackItems,
          sourceLabel: fallbackItems.isNotEmpty ? 'المحتوى الافتراضي' : null,
          isLoaded: true,
        ),
      );
    } catch (error) {
      if (fallbackItems.isNotEmpty) {
        _setCategoryState(
          category.id,
          AdhkarCategoryState(
            items: fallbackItems,
            sourceLabel: 'المحتوى الافتراضي',
            isLoaded: true,
          ),
        );
        return;
      }

      _setCategoryState(
        category.id,
        AdhkarCategoryState(errorMessage: error.toString(), isLoaded: true),
      );
    }
  }

  Future<void> toggleFavorite(String itemId) async {
    final next = {..._favorites};
    if (next.contains(itemId)) {
      next.remove(itemId);
    } else {
      next.add(itemId);
    }
    _favorites = next;
    await _progressRepository.saveFavorites(_favorites);
    if (stateFor('favorites').hasResolved) {
      await _loadFavoritesCategory();
    }
    notifyListeners();
  }

  Future<void> incrementItem(AdhkarItem item) async {
    final current = progressFor(item.id);
    if (current >= item.requiredCount) {
      return;
    }

    final updated = {..._counts, item.id: current + 1};
    _counts = updated;
    await _progressRepository.saveCounts(_counts);
    await _syncCompletedItems();
    notifyListeners();

    if (current + 1 == item.requiredCount) {
      await _analyticsService.trackEvent(
        'adhkar_completed',
        parameters: {'item_id': item.id, 'category_id': item.categoryId},
      );
    }
  }

  Future<void> resetItem(AdhkarItem item) async {
    final updated = {..._counts};
    updated.remove(item.id);
    _counts = updated;
    await _progressRepository.saveCounts(_counts);
    await _syncCompletedItems();
    notifyListeners();
  }

  Future<bool> markCategoryCompleted(String categoryId) async {
    final key = _categoryCompletionKey(categoryId);
    if (_completedCategories.contains(key)) {
      return false;
    }

    _completedCategories = {..._completedCategories, key};
    await _syncCompletedItems();
    notifyListeners();
    return true;
  }

  Future<void> _loadFavoritesCategory() async {
    if (_favorites.isEmpty) {
      _setCategoryState(
        'favorites',
        const AdhkarCategoryState(
          items: [],
          sourceLabel: 'المفضلة',
          isLoaded: true,
        ),
      );
      return;
    }

    final collected = <AdhkarItem>[];
    var firstError = '';
    for (final category in _categories.where((item) => !item.isFavorites)) {
      final fallbackItems = await _repository.getFallbackItems(category.id);
      try {
        // TODO(server-sync): keep favorites compatible with remote adhkar IDs.
        final remoteItems = await _firestoreRepository.loadItemsForCategory(
          category.id,
        );
        final source = remoteItems.isNotEmpty
            ? _mergeItems(fallbackItems, remoteItems)
            : fallbackItems;
        collected.addAll(source.where((item) => _favorites.contains(item.id)));
      } catch (error) {
        if (firstError.isEmpty) {
          firstError = error.toString();
        }
        collected.addAll(
          fallbackItems.where((item) => _favorites.contains(item.id)),
        );
      }
    }

    collected.sort((a, b) {
      if (a.categoryId != b.categoryId) {
        return a.categoryId.compareTo(b.categoryId);
      }
      return a.sortOrder.compareTo(b.sortOrder);
    });

    _setCategoryState(
      'favorites',
      AdhkarCategoryState(
        items: collected,
        sourceLabel: collected.isEmpty ? 'المفضلة' : null,
        errorMessage: collected.isEmpty && firstError.isNotEmpty
            ? firstError
            : null,
        isLoaded: true,
      ),
    );
  }

  Future<void> _syncCompletedItems() async {
    final fallbackItems = await _repository.getAllFallbackItems();
    final allItems = <String, AdhkarItem>{
      for (final item in fallbackItems) item.id: item,
      for (final state in _categoryStates.values)
        for (final item in state.items) item.id: item,
    }.values;
    final completed = <String>{};
    completed.addAll(_completedCategories);
    for (final item in allItems) {
      if (progressFor(item.id) >= item.requiredCount) {
        completed.add(item.id);
      }
    }
    await _progressRepository.saveCompleted(completed);
  }

  String _categoryCompletionKey(String categoryId) {
    return 'category:${categoryId.trim().toLowerCase()}';
  }

  void _setCategoryState(String categoryId, AdhkarCategoryState state) {
    _categoryStates = {..._categoryStates, categoryId: state};
    notifyListeners();
  }

  List<AdhkarCategory> _mergeCategories(
    List<AdhkarCategory> localCategories,
    List<AdhkarCategory> remoteCategories,
  ) {
    if (remoteCategories.isEmpty) {
      return localCategories;
    }

    final byId = <String, AdhkarCategory>{
      for (final category in localCategories) category.id: category,
    };
    for (final remote in remoteCategories) {
      final local = byId[remote.id];
      byId[remote.id] = local == null
          ? remote
          : AdhkarCategory(
              id: remote.id,
              title: remote.title.trim().isEmpty ? local.title : remote.title,
              subtitle: remote.subtitle.trim().isEmpty
                  ? local.subtitle
                  : remote.subtitle,
              isPremium: remote.isPremium || local.isPremium,
            );
    }

    final ordered = <AdhkarCategory>[];
    for (final local in localCategories) {
      final merged = byId.remove(local.id);
      if (merged != null) {
        ordered.add(merged);
      }
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  List<AdhkarItem> _mergeItems(
    List<AdhkarItem> fallbackItems,
    List<AdhkarItem> remoteItems,
  ) {
    final byId = <String, AdhkarItem>{
      for (final item in fallbackItems) item.id: item,
    };
    for (final item in remoteItems) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return merged;
  }
}

class AdhkarCategoryState {
  const AdhkarCategoryState({
    this.isLoading = false,
    this.items = const [],
    this.sourceLabel,
    this.errorMessage,
    this.isLoaded = false,
  });

  final bool isLoading;
  final List<AdhkarItem> items;
  final String? sourceLabel;
  final String? errorMessage;
  final bool isLoaded;

  bool get hasResolved => !isLoading && isLoaded;

  AdhkarCategoryState copyWith({
    bool? isLoading,
    List<AdhkarItem>? items,
    String? sourceLabel,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdhkarCategoryState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isLoaded: isLoaded,
    );
  }
}
