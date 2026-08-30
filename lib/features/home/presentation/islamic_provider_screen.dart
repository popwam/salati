import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/islamic_content_provider.dart';

class IslamicProviderScreen extends StatefulWidget {
  const IslamicProviderScreen({super.key, required this.kind});

  final IslamicProviderKind kind;

  @override
  State<IslamicProviderScreen> createState() => _IslamicProviderScreenState();
}

class _IslamicProviderScreenState extends State<IslamicProviderScreen> {
  late Future<IslamicProviderResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = IslamicContentProvider().load(widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خدمات صلاتي')),
      body: FutureBuilder<IslamicProviderResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProviderError(
              message: snapshot.error.toString(),
              onRetry: () => setState(_load),
            );
          }
          final result = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _ProviderHeader(result: result),
                const SizedBox(height: 16),
                if (result.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'لا توجد نتائج متاحة حاليًا.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...result.items.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFDCEBFF),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            color: Color(0xFF7446B8),
                          ),
                        ),
                        title: Text(item.title),
                        subtitle: item.subtitle.isEmpty
                            ? null
                            : Text(item.subtitle),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({required this.result});
  final IslamicProviderResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF447DB7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (result.direction != null)
            Transform.rotate(
              angle: result.direction! * math.pi / 180,
              child: const Icon(
                Icons.navigation_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
          Text(
            result.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'المصدر: ${result.source}',
            style: const TextStyle(color: Color(0xFFD8E7FA)),
          ),
        ],
      ),
    );
  }
}

class _ProviderError extends StatelessWidget {
  const _ProviderError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
