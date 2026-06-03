import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/settings/currency_alert_settings.dart';
import 'package:falconlog/settings/currency_alert_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CurrencyAlertSettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = CurrencyAlertSettingsRepository();
  });

  test('load returns defaults when prefs missing', () async {
    final settings = await repository.load();
    expect(settings.dayAlertDays, CurrencyAlertSettings.defaultDayAlertDays);
    expect(settings.nightAlertDays, CurrencyAlertSettings.defaultNightAlertDays);
    expect(settings.hasCompletedSetup, false);
  });

  test('completeSetup saves values and marks completed', () async {
    await repository.completeSetup(dayAlertDays: 21, nightAlertDays: 15);
    final settings = await repository.load();
    expect(settings.dayAlertDays, 21);
    expect(settings.nightAlertDays, 15);
    expect(settings.hasCompletedSetup, true);
  });

  test('updateIntervals updates day and night', () async {
    await repository.completeSetup(dayAlertDays: 15, nightAlertDays: 10);
    await repository.updateIntervals(dayAlertDays: 30, nightAlertDays: 21);
    final settings = await repository.load();
    expect(settings.dayAlertDays, 30);
    expect(settings.nightAlertDays, 21);
    expect(settings.hasCompletedSetup, true);
  });

  test('resetSetupForTesting clears prefs', () async {
    await repository.completeSetup(dayAlertDays: 20, nightAlertDays: 12);
    await repository.resetSetupForTesting();
    final settings = await repository.load();
    expect(settings.hasCompletedSetup, false);
    expect(settings.dayAlertDays, CurrencyAlertSettings.defaultDayAlertDays);
  });
}
