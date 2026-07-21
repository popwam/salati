class FirebaseStatus {
  const FirebaseStatus({
    required this.isConfigured,
    this.missingItems = const [],
    this.message,
  });

  final bool isConfigured;
  final List<String> missingItems;
  final String? message;
}
