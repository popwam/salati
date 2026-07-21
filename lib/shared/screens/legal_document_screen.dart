import 'package:flutter/material.dart';

enum LegalDocumentType { privacy, terms, childSafety, accountDeletion }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.type});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final document = _documentFor(type);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            document.updatedAt,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(document.intro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          for (final section in document.sections) ...[
            Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(section.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  _LegalDocument _documentFor(LegalDocumentType type) {
    return switch (type) {
      LegalDocumentType.privacy => _privacyPolicy,
      LegalDocumentType.terms => _termsOfUse,
      LegalDocumentType.childSafety => _childSafety,
      LegalDocumentType.accountDeletion => _accountDeletion,
    };
  }
}

const _privacyPolicy = _LegalDocument(
  title: 'سياسة الخصوصية',
  updatedAt: 'آخر تحديث: 14 مايو 2026',
  intro:
      'صلاتي تطبيق يساعدك على متابعة مواقيت الصلاة، الأذكار، القرآن، والتنبيهات اليومية. نحرص على جمع أقل قدر ممكن من البيانات اللازمة لتشغيل التجربة.',
  sections: [
    _LegalSection(
      title: 'البيانات التي نستخدمها',
      body:
          'قد يستخدم التطبيق الموقع التقريبي أو اليدوي لحساب مواقيت الصلاة. إذا ربطت حسابك، قد نخزن معرف الحساب، البريد أو الهاتف، الخطة، النقاط، وتقدم الاستخدام حتى تتمكن من الاستعادة والمزامنة.',
    ),
    _LegalSection(
      title: 'الموقع',
      body:
          'يستخدم الموقع لحساب مواقيت الصلاة والقبلة حسب مدينتك. يمكنك تعطيل استخدام موقع الجهاز واختيار الدولة والمدينة يدويًا من الإعدادات.',
    ),
    _LegalSection(
      title: 'الإشعارات',
      body:
          'نستخدم الإشعارات لتذكيرك بالصلاة والأذكار والمحتوى الذي تختاره. يمكنك تعطيل الإشعارات من التطبيق أو من إعدادات النظام في أي وقت.',
    ),
    _LegalSection(
      title: 'الإعلانات والتحليلات',
      body:
          'قد نستخدم تحليلات وإعلانات لتحسين المنتج وتمويل تشغيله. لا نبيع بياناتك الشخصية، ونحاول إبقاء الأحداث التحليلية عامة وغير حساسة.',
    ),
    _LegalSection(
      title: 'حفظ البيانات',
      body:
          'تخزن بعض الإعدادات على جهازك، وقد تخزن بيانات الحساب والمزامنة في Firebase عند تفعيل الحساب المرتبط. يمكنك تسجيل الخروج والعودة للحساب المجاني.',
    ),
    _LegalSection(
      title: 'التواصل',
      body:
          'لأي طلب حذف بيانات أو سؤال خصوصية، استخدم شاشة الدعم داخل التطبيق أو البريد المخصص للدعم عند نشر النسخة التجارية.',
    ),
  ],
);

const _termsOfUse = _LegalDocument(
  title: 'شروط الاستخدام',
  updatedAt: 'آخر تحديث: 14 مايو 2026',
  intro:
      'باستخدام صلاتي، توافق على استخدام التطبيق كأداة مساعدة يومية، مع فهم أن المستخدم مسؤول عن مراجعة المواقيت والإعدادات بما يناسب بلده ومذهبه.',
  sections: [
    _LegalSection(
      title: 'طبيعة الخدمة',
      body:
          'صلاتي يقدم مواقيت صلاة، أذكار، قراءة قرآن، تنبيهات، وخصائص تخصيص. قد تختلف المواقيت حسب طريقة الحساب والموقع والإعدادات المحلية.',
    ),
    _LegalSection(
      title: 'الحساب والمزامنة',
      body:
          'ربط الحساب يساعدك على الاستعادة والمزامنة. عند استخدام حساب موجود، قد نستخدم بيانات الحساب المرتبط بدل الحساب المؤقت.',
    ),
    _LegalSection(
      title: 'المحتوى الديني',
      body:
          'نبذل جهدًا لتقديم محتوى دقيق ومحترم، ومع ذلك يجب مراجعة أي محتوى حساس أو فتوى مع مصدر موثوق. التطبيق ليس بديلًا عن أهل العلم.',
    ),
    _LegalSection(
      title: 'المشتريات والاشتراكات',
      body:
          'أي مزايا مدفوعة أو اشتراكات يجب أن تتم عبر متجر المنصة الرسمي. الأسعار والمزايا قد تتغير مع توضيحها قبل الشراء.',
    ),
    _LegalSection(
      title: 'الاستخدام المقبول',
      body:
          'لا يجوز إساءة استخدام التطبيق أو محاولة الوصول غير المصرح به لبيانات مستخدمين آخرين أو أنظمة الإدارة.',
    ),
    _LegalSection(
      title: 'تغييرات الشروط',
      body:
          'قد يتم تحديث هذه الشروط مع تطور المنتج. استمرار استخدام التطبيق بعد التحديث يعني قبول النسخة الجديدة.',
    ),
  ],
);

const _childSafety = _LegalDocument(
  title: 'رقابة الأطفال وسلامة الأسرة',
  updatedAt: 'آخر تحديث: 14 مايو 2026',
  intro:
      'صلاتي تطبيق ديني يومي للعائلة، وقد يستخدمه الأطفال بإشراف ولي الأمر. هذه الصفحة توضح ما يجب مراجعته قبل السماح لطفل باستخدام التطبيق.',
  sections: [
    _LegalSection(
      title: 'إشراف ولي الأمر',
      body:
          'ننصح أن يضبط ولي الأمر إعدادات الموقع، الإشعارات، الإعلانات، والذكاء الإسلامي قبل تسليم التطبيق لطفل. التطبيق لا يستهدف جمع بيانات الأطفال بشكل مستقل.',
    ),
    _LegalSection(
      title: 'الإعلانات والمشتريات',
      body:
          'قبل النشر التجاري، يجب تفعيل إعدادات مناسبة للعائلة ومنع أي شراء بدون موافقة ولي الأمر. يجب استخدام أنظمة المتجر الرسمية لإدارة موافقة الشراء.',
    ),
    _LegalSection(
      title: 'الذكاء الإسلامي والمحتوى',
      body:
          'أي إجابات أو محتوى ذكي يجب التعامل معه كمساعدة عامة وليس فتوى. للأطفال، يفضل أن يراجع ولي الأمر الأسئلة والإجابات أو يعطل المزايا غير المناسبة.',
    ),
    _LegalSection(
      title: 'الخصوصية',
      body:
          'لا ينبغي إدخال بيانات شخصية لطفل إلا عند الحاجة وبموافقة ولي الأمر. يمكن استخدام الحساب المجاني المؤقت أو إعداد المدينة يدويًا لتقليل البيانات.',
    ),
    _LegalSection(
      title: 'المتاجر',
      body:
          'عند نشر التطبيق، راجع متطلبات Families Policy في Google Play وKids/Privacy في App Store إذا كان التطبيق سيُسوّق للأطفال أو العائلة.',
    ),
  ],
);

const _accountDeletion = _LegalDocument(
  title: 'حذف الحساب والبيانات',
  updatedAt: 'آخر تحديث: 19 مايو 2026',
  intro:
      'يمكن لمستخدم صلاتي طلب حذف حسابه والبيانات المرتبطة به من خلال التواصل مع الدعم.',
  sections: [
    _LegalSection(
      title: 'طريقة الطلب',
      body:
          'أرسل طلب حذف الحساب من البريد المرتبط بالحساب إلى support@salati.popwam.com.',
    ),
    _LegalSection(
      title: 'ما الذي يتم حذفه',
      body:
          'يتم حذف بيانات الحساب الأساسية، تفضيلات التطبيق المحفوظة سحابيًا، وبيانات التقدم والمزامنة المرتبطة بالحساب.',
    ),
    _LegalSection(
      title: 'ما الذي قد يبقى',
      body:
          'قد تبقى سجلات محدودة مطلوبة للأمان، منع الاحتيال، أو الامتثال القانوني، ثم تُحذف أو تُجهّل عندما لا تعود مطلوبة.',
    ),
  ],
);

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.updatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final String intro;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}
