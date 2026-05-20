import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'currency_alert_settings.dart';
import 'currency_alert_settings_repository.dart';

final currencyAlertSettingsRepositoryProvider =
    Provider<CurrencyAlertSettingsRepository>(
  (ref) => CurrencyAlertSettingsRepository(),
);

class CurrencyAlertSettingsNotifier
    extends AsyncNotifier<CurrencyAlertSettings> {
  CurrencyAlertSettingsRepository get _repo =>
      ref.read(currencyAlertSettingsRepositoryProvider);

  @override
  Future<CurrencyAlertSettings> build() => _repo.load();

  Future<void> completeSetup({
    required int dayAlertDays,
    required int nightAlertDays,
  }) async {
    await _repo.completeSetup(
      dayAlertDays: dayAlertDays,
      nightAlertDays: nightAlertDays,
    );
    state = AsyncData(
      CurrencyAlertSettings(
        dayAlertDays: dayAlertDays,
        nightAlertDays: nightAlertDays,
        hasCompletedSetup: true,
      ),
    );
  }

  Future<void> updateIntervals({
    required int dayAlertDays,
    required int nightAlertDays,
  }) async {
    await _repo.updateIntervals(
      dayAlertDays: dayAlertDays,
      nightAlertDays: nightAlertDays,
    );
    final current = state.valueOrNull ?? CurrencyAlertSettings.defaults;
    state = AsyncData(
      current.copyWith(
        dayAlertDays: dayAlertDays,
        nightAlertDays: nightAlertDays,
      ),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.load());
  }
}

final currencyAlertSettingsProvider =
    AsyncNotifierProvider<CurrencyAlertSettingsNotifier, CurrencyAlertSettings>(
  CurrencyAlertSettingsNotifier.new,
);
