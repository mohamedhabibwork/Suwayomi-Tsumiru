import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/features/browse_center/domain/extension/top_extensions.dart';
import 'package:tsumiru/src/features/settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import 'package:tsumiru/src/features/settings/presentation/security/app_lock_gate.dart';
import 'package:tsumiru/src/features/settings/presentation/security/security_settings_dialog.dart';
import 'package:tsumiru/src/features/settings/presentation/security/security_settings_provider.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';

void main() {
  group('computeLockCooldownSeconds', () {
    test('returns 0 for fewer than 3 failed attempts', () {
      expect(computeLockCooldownSeconds(0), 0);
      expect(computeLockCooldownSeconds(1), 0);
      expect(computeLockCooldownSeconds(2), 0);
    });

    test('returns exponential tiers for 3+ failed attempts', () {
      expect(computeLockCooldownSeconds(3), 5);
      expect(computeLockCooldownSeconds(4), 15);
      expect(computeLockCooldownSeconds(5), 30);
      expect(computeLockCooldownSeconds(6), 60);
      expect(computeLockCooldownSeconds(10), 60);
    });
  });

  group('SecuritySettingsDialog & AppLockGate', () {
    testWidgets(
      'enables Passcode App Lock with PIN confirmation, verifies PIN before disabling, and toggles screenshot/save-image settings',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SecuritySettingsDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default values
        expect(container.read(appLockEnabledProvider), isFalse);
        expect(container.read(blockScreenshotsProvider), isTrue);
        expect(container.read(disableSaveImagesProvider), isTrue);
        expect(container.read(disableContentSharingProvider), isFalse);
        expect(container.read(autoHideNsfwOnCloseProvider), isTrue);

        // Toggle Passcode App Lock ON -> opens Set 4-Digit Passcode dialog
        await tester.tap(find.text('Passcode App Lock'));
        await tester.pumpAndSettle();
        expect(find.text('Set 4-Digit Passcode'), findsOneWidget);

        // Enter mismatched PINs -> shows error
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '1234');
        await tester.enterText(fields.at(1), '9999');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('PINs do not match.'), findsOneWidget);

        // Enter matching PINs -> saves and enables lock
        await tester.enterText(fields.at(1), '1234');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(container.read(appLockEnabledProvider), isTrue);
        expect(container.read(appLockPinProvider), '1234');

        // Toggle Passcode App Lock OFF -> requires current PIN verification
        await tester.tap(find.text('Passcode App Lock'));
        await tester.pumpAndSettle();
        expect(find.text('Verify Current Passcode'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, '1234');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(container.read(appLockEnabledProvider), isFalse);

        // Toggle Black Screen on Screenshot & Recording and Do Not Allow Saving Images
        await tester.tap(find.text('Black Screen on Screenshot & Recording'));
        await tester.pumpAndSettle();
        expect(container.read(blockScreenshotsProvider), isFalse);

        await tester.tap(find.text('Do Not Allow Saving Images'));
        await tester.pumpAndSettle();
        expect(container.read(disableSaveImagesProvider), isFalse);
      },
    );

    testWidgets('AppLockGate locks and unlocks with 4-digit PIN keypad', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockPin': '2580',
        'blockScreenshots': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppLockGate(child: Scaffold(body: Text('Protected Content'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overlay is shown
      expect(find.text('Enter Passcode'), findsOneWidget);
      expect(find.text('Unlock with Face ID'), findsOneWidget);

      // Enter wrong PIN -> increments failedAttempts
      for (final d in ['1', '1', '1', '1']) {
        await tester.tap(find.widgetWithText(OutlinedButton, d));
        await tester.pump();
      }
      expect(find.textContaining('Incorrect passcode'), findsOneWidget);

      // Enter correct PIN 2580 -> unlocks
      for (final d in ['2', '5', '8', '0']) {
        await tester.tap(find.widgetWithText(OutlinedButton, d));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Enter Passcode'), findsNothing);
      expect(container.read(appLockSessionUnlockedProvider), isTrue);
    });

    testWidgets(
      '+18 Mode (Show Only +18) links with Enable/Disable +18 and deduplicates extension store URLs',
      (tester) async {
        resetNsfwFaceIdSession();
        debugNsfwFaceIdAuthOverride = ({String reason = ''}) async => true;
        addTearDown(() {
          debugNsfwFaceIdAuthOverride = null;
          resetNsfwFaceIdSession();
        });

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Column(
                  children: [
                    ShowNSFWTile(),
                    OnlyNsfwModeTile(),
                    NsfwFilterChipsRow(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(showNSFWProvider), isFalse);
        expect(container.read(onlyNsfwModeProvider), isFalse);

        // Tapping "+18 Mode (Show Only +18)" automatically unlocks +18 and enables Only +18
        await tester.tap(find.text('+18 Mode (Show Only +18)'));
        await tester.pumpAndSettle();
        expect(container.read(showNSFWProvider), isTrue);
        expect(container.read(onlyNsfwModeProvider), isTrue);

        // Disabling +18 automatically disables Only +18
        await tester.tap(find.text('+18 Enabled'));
        await tester.pumpAndSettle();
        expect(container.read(showNSFWProvider), isFalse);
        expect(container.read(onlyNsfwModeProvider), isFalse);

        // Verify extension store URL normalization and duplicate detection
        expect(
          normalizeExtensionStoreUrl(
            'https://github.com/keiyoushi/extensions/raw/repo/index.pb',
          ),
          normalizeExtensionStoreUrl(
            'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb',
          ),
        );
        expect(
          isExtensionStoreUrlPresent(
            'https://github.com/keiyoushi/extensions/raw/repo/index.pb',
            const [
              'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb',
            ],
          ),
          isTrue,
        );
        expect(
          isRedundantDuplicateStoreUrl(
            'https://raw.githubusercontent.com/MO350AZ/extensions-no-nsfw/repo/repo.json',
          ),
          isTrue,
        );
      },
    );
  });
}
