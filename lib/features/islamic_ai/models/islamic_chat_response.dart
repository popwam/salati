class BackendHealth {
  const BackendHealth({
    required this.ok,
    required this.service,
    required this.version,
    required this.ai,
    required this.cache,
    required this.mcp,
    required this.time,
  });

  final bool ok;
  final String service;
  final String version;
  final bool? ai;
  final bool? cache;
  final String mcp;
  final String time;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    return BackendHealth(
      ok: _boolFromValue(json['ok']) ?? false,
      service: _stringFromValue(json['service']),
      version: _stringFromValue(json['version']),
      ai: _boolFromValue(json['ai']),
      cache: _boolFromValue(json['cache']),
      mcp: _stringFromValue(json['mcp']),
      time: _stringFromValue(json['time']),
    );
  }
}

class IslamicChatResponse {
  const IslamicChatResponse({
    required this.ok,
    required this.type,
    required this.version,
    required this.question,
    required this.language,
    required this.intent,
    required this.usedTool,
    required this.answer,
    required this.uiType,
    required this.direction,
    required this.cards,
    required this.sources,
    required this.remainingUserMessages,
    required this.errorMessage,
  });

  final bool ok;
  final String type;
  final String version;
  final String question;
  final String language;
  final String intent;
  final String usedTool;
  final String answer;
  final String uiType;
  final String direction;
  final List<IslamicChatCard> cards;
  final List<String> sources;
  final int? remainingUserMessages;
  final String? errorMessage;

  bool get hasError => errorMessage?.trim().isNotEmpty == true;

  factory IslamicChatResponse.fromJson(Map<String, dynamic> json) {
    final ui = _mapFromValue(json['ui']);
    final chat = _mapFromValue(ui['chat']);
    final conversation = _mapFromValue(json['conversation']);
    final answer = _firstNonEmpty([
      _stringFromValue(json['answer']),
      _stringFromValue(chat['text']),
    ]);
    final direction = _firstNonEmpty([
      _stringFromValue(ui['direction']),
      _stringFromValue(chat['direction']),
      _looksArabic(answer) ? 'rtl' : 'ltr',
    ]);

    return IslamicChatResponse(
      ok: _boolFromValue(json['ok']) ?? false,
      type: _stringFromValue(json['type']),
      version: _stringFromValue(json['version']),
      question: _stringFromValue(json['question']),
      language: _stringFromValue(json['language']),
      intent: _stringFromValue(json['intent']),
      usedTool: _stringFromValue(json['usedTool']),
      answer: answer,
      uiType: _stringFromValue(ui['type']),
      direction: direction,
      cards: _cardsFromValue(ui['cards']),
      sources: _sourcesFromValue(json['sources']),
      remainingUserMessages: _intFromValue(
        conversation['remainingUserMessages'],
      ),
      errorMessage: _errorMessageFromJson(json),
    );
  }

  factory IslamicChatResponse.error(String message) {
    return IslamicChatResponse(
      ok: false,
      type: '',
      version: '',
      question: '',
      language: '',
      intent: '',
      usedTool: '',
      answer: '',
      uiType: '',
      direction: 'rtl',
      cards: const [],
      sources: const [],
      remainingUserMessages: null,
      errorMessage: message,
    );
  }
}

class IslamicChatCard {
  const IslamicChatCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.reference,
    required this.source,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String body;
  final String reference;
  final String source;

  factory IslamicChatCard.fromJson(Map<String, dynamic> json) {
    return IslamicChatCard(
      kind: _stringFromValue(json['kind']),
      title: _stringFromValue(json['title']),
      subtitle: _stringFromValue(json['subtitle']),
      body: _stringFromValue(json['body']),
      reference: _stringFromValue(json['reference']),
      source: _stringFromValue(json['source']),
    );
  }
}

String _stringFromValue(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

bool? _boolFromValue(Object? value) {
  if (value is bool) return value;
  final text = _stringFromValue(value).toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

int? _intFromValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringFromValue(value));
}

Map<String, dynamic> _mapFromValue(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<IslamicChatCard> _cardsFromValue(Object? value) {
  if (value is! List) return const [];
  final cards = <IslamicChatCard>[];
  for (final item in value) {
    final map = _mapFromValue(item);
    if (map.isNotEmpty) {
      cards.add(IslamicChatCard.fromJson(map));
    }
  }
  return List.unmodifiable(cards);
}

List<String> _sourcesFromValue(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(
    value.map(_stringFromValue).where((source) => source.isNotEmpty).toList(),
  );
}

String? _errorMessageFromJson(Map<String, dynamic> json) {
  final error = _firstNonEmpty([
    _stringFromValue(json['errorMessage']),
    _stringFromValue(json['message']),
    _stringFromValue(json['error']),
  ]);
  if (error.isEmpty || _boolFromValue(json['ok']) == true) return null;
  return error;
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

bool _looksArabic(String value) {
  return RegExp(r'[\u0600-\u06ff]').hasMatch(value);
}
