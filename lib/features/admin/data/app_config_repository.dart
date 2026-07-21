import '../../../core/models/operational_config.dart';

abstract class AppConfigRepository {
  Stream<OperationalConfig> watchOperationalConfig();

  Future<OperationalConfig> loadOperationalConfig();

  Future<void> saveOperationalConfig(OperationalConfig config);

  Future<void> ensureDefaults();
}
