import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_content_management_repository.dart';
import 'admin_guard.dart';
import 'admin_scaffold.dart';

class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  late final FirestoreContentManagementRepository _repository;
  final _categoryIdController = TextEditingController();
  final _itemIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '1');

  String _contentType = 'adhkar_item';
  String _locale = 'ar';
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreContentManagementRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
  }

  @override
  void dispose() {
    _categoryIdController.dispose();
    _itemIdController.dispose();
    _titleController.dispose();
    _textController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _repository.saveContent(path: _path, data: _payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ المحتوى')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String get _path {
    final categoryId = _categoryIdController.text.trim();
    final itemId = _itemIdController.text.trim();
    switch (_contentType) {
      case 'adhkar_category':
        return 'content/adhkar/categories/$categoryId';
      case 'adhkar_item':
        return 'content/adhkar/categories/$categoryId/items/$itemId';
      case 'dua_category':
        return 'content/dua/categories/$categoryId';
      case 'dua_item':
        return 'content/dua/categories/$categoryId/items/$itemId';
      case 'quran_item':
        return 'content/quran/modes/$categoryId/items/$itemId';
      default:
        return '';
    }
  }

  Map<String, dynamic> get _payload {
    final title = _titleController.text.trim();
    final text = _textController.text.trim();
    final description = _descriptionController.text.trim();
    final reference = _referenceController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 1;
    final categoryId = _categoryIdController.text.trim();
    final itemId = _itemIdController.text.trim();

    if (_contentType.endsWith('category')) {
      return {
        'id': categoryId,
        'title': title,
        'description': description,
        'icon': 'auto',
        'isActive': _isActive,
        'sortOrder': sortOrder,
        'titleLocales': {_locale: title},
        'descriptionLocales': {_locale: description},
      };
    }

    final base = <String, dynamic>{
      'id': itemId,
      'categoryId': categoryId,
      'title': title,
      'text': text,
      'isActive': _isActive,
      'sortOrder': sortOrder,
      'titleLocales': {_locale: title},
      'textLocales': {_locale: text},
    };
    if (_contentType == 'adhkar_item') {
      base['source'] = reference;
      base['count'] = sortOrder;
    } else if (_contentType == 'dua_item') {
      base['source'] = reference;
    } else if (_contentType == 'quran_item') {
      base['reference'] = reference;
      base['imageUrl'] = _imageUrlController.text.trim();
      base['mode'] = categoryId;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة المحتوى',
      currentRoute: AppRouter.adminContentRoute,
      services: widget.services,
      firebaseConfigured: widget.firebaseConfigured,
      child: AdminGuard(
        services: widget.services,
        firebaseConfigured: widget.firebaseConfigured,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _contentType,
              decoration: const InputDecoration(labelText: 'نوع المحتوى'),
              items: const [
                DropdownMenuItem(
                  value: 'adhkar_category',
                  child: Text('فئة أذكار'),
                ),
                DropdownMenuItem(value: 'adhkar_item', child: Text('عنصر ذكر')),
                DropdownMenuItem(
                  value: 'dua_category',
                  child: Text('فئة دعاء'),
                ),
                DropdownMenuItem(value: 'dua_item', child: Text('عنصر دعاء')),
                DropdownMenuItem(value: 'quran_item', child: Text('عنصر قرآن')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _contentType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'ar', label: Text('ar')),
                ButtonSegment<String>(value: 'en', label: Text('en')),
                ButtonSegment<String>(value: 'fr', label: Text('fr')),
              ],
              selected: {_locale},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() {
                    _locale = selection.first;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryIdController,
              decoration: InputDecoration(
                labelText: _contentType == 'quran_item'
                    ? 'mode: ayah/word/page'
                    : 'categoryId',
              ),
            ),
            const SizedBox(height: 12),
            if (!_contentType.endsWith('category'))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _itemIdController,
                  decoration: const InputDecoration(labelText: 'itemId'),
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(labelText: 'source/reference'),
            ),
            if (_contentType == 'quran_item') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'imageUrl (optional)',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'sortOrder'),
            ),
            SwitchListTile.adaptive(
              value: _isActive,
              title: const Text('isActive'),
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            Text('Path: $_path'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
