// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SecuritySettingsAdapter extends TypeAdapter<SecuritySettings> {
  @override
  final int typeId = 10;

  @override
  SecuritySettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SecuritySettings(
      isPinEnabled: fields[0] as bool,
      isAppLockBiometricEnabled: fields[1] as bool,
      failedAttempts: fields[2] as int,
      lockoutUntil: fields[3] as DateTime?,
      lastUnlockedAt: fields[4] as DateTime?,
      autoLockTimeoutSeconds: fields[5] as int,
      sessionStartTime: fields[6] as DateTime?,
      lastInteractionTime: fields[7] as DateTime?,
      sessionDurationSeconds: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SecuritySettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.isPinEnabled)
      ..writeByte(1)
      ..write(obj.isAppLockBiometricEnabled)
      ..writeByte(2)
      ..write(obj.failedAttempts)
      ..writeByte(3)
      ..write(obj.lockoutUntil)
      ..writeByte(4)
      ..write(obj.lastUnlockedAt)
      ..writeByte(5)
      ..write(obj.autoLockTimeoutSeconds)
      ..writeByte(6)
      ..write(obj.sessionStartTime)
      ..writeByte(7)
      ..write(obj.lastInteractionTime)
      ..writeByte(8)
      ..write(obj.sessionDurationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecuritySettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
