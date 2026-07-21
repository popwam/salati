import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _shareFeedback() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب ملاحظتك أولًا')));
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        subject: 'ملاحظة على تطبيق صلاتي',
        text: 'ملاحظة على تطبيق صلاتي:\n\n$message',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الدعم والملاحظات')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'ساعدنا نحسن صلاتي',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اكتب المشكلة أو الاقتراح، ثم أرسله عبر وسيلة المشاركة المناسبة عندك.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            minLines: 7,
            maxLines: 12,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'ملاحظتك',
              hintText:
                  'مثال: الأذان لم يعمل على جهازي، أو الويجت يحتاج حجم أكبر...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _shareFeedback,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('إرسال الملاحظة'),
          ),
          const SizedBox(height: 12),
          Text(
            'عند نشر النسخة التجارية، أضف بريد دعم رسمي مثل support@salati.app داخل بيانات المتجر وهذه الشاشة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
