import 'package:flutter_riverpod/flutter_riverpod.dart';



import 'domain/notification_preferences.dart';

import 'schedulers/currency_expiry_scheduler.dart';



final notificationPreferencesRepositoryProvider =

    Provider<NotificationPreferencesRepository>(

  (ref) => NotificationPreferencesRepository(),

);



class NotificationPreferencesNotifier

    extends AsyncNotifier<NotificationPreferences> {

  NotificationPreferencesRepository get _repo =>

      ref.read(notificationPreferencesRepositoryProvider);



  @override

  Future<NotificationPreferences> build() => _repo.load();



  Future<bool> setEnableNotifications(bool enabled) async {

    final current = state.valueOrNull ?? NotificationPreferences.defaults;

    final updated = current.copyWith(enableNotifications: enabled);

    await _saveAndReschedule(updated);

    return updated.enableNotifications;

  }



  Future<void> setBackupNotificationsEnabled(bool enabled) async {

    final current = state.valueOrNull ?? NotificationPreferences.defaults;

    await _saveAndReschedule(

      current.copyWith(backupNotificationsEnabled: enabled),

    );

  }



  Future<void> setCurrencyExpiryNotificationsEnabled(bool enabled) async {

    final current = state.valueOrNull ?? NotificationPreferences.defaults;

    await _saveAndReschedule(

      current.copyWith(currencyExpiryNotificationsEnabled: enabled),

    );

  }



  Future<void> _saveAndReschedule(NotificationPreferences updated) async {

    await _repo.save(updated);

    state = AsyncData(updated);

    await CurrencyExpiryScheduler.rescheduleFromHive();

  }

}



final notificationPreferencesProvider = AsyncNotifierProvider<

    NotificationPreferencesNotifier, NotificationPreferences>(

  NotificationPreferencesNotifier.new,

);

