import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../islamic_ai/presentation/islamic_chat_screen.dart';
import 'quran_access.dart';
import 'quran_locked_feature_view.dart';

class QuranAiPlaceholderScreen extends StatelessWidget {
  const QuranAiPlaceholderScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return QuranAccessBuilder(
      services: services,
      builder: (context, access) {
        if (!access.hasPlusAccess) {
          return Scaffold(
            appBar: AppBar(title: const Text('Quran AI')),
            body: const QuranLockedFeatureView(
              title: 'Quran AI',
              message:
                  'هذه المساحة متاحة لباقة Plus. يمكنك متابعة القراءة الآن والعودة إلى المساعد الإسلامي بعد الترقية.',
            ),
          );
        }

        return IslamicChatScreen(services: services);
      },
    );
  }
}
