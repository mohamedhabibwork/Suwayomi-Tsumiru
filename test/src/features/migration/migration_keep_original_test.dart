import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/features/migration/presentation/widgets/migration_config_sheet.dart';

void main() {
  group('MigrationRunConfig keepOriginal', () {
    test('keepOriginal flips deleteSource to false in toOption', () {
      const configKeep = MigrationRunConfig(
        migrateChapters: true,
        migrateCategories: true,
        migrateTracking: true,
        migrateReaderSettings: true,
        migrateOfflineSettings: true,
        migrateDownloads: false,
        hideUnmatched: false,
        hideWithoutUpdates: false,
        keepOriginal: true,
      );
      expect(configKeep.toOption(deleteSource: !configKeep.keepOriginal).deleteSource, isFalse);

      const configReplace = MigrationRunConfig.defaults;
      expect(configReplace.keepOriginal, isFalse);
      expect(
        configReplace.toOption(deleteSource: !configReplace.keepOriginal).deleteSource,
        isTrue,
      );
    });
  });
}
