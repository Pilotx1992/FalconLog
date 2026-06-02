// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BackupMetadataAdapter extends TypeAdapter<BackupMetadata> {
  @override
  final int typeId = 100;

  @override
  BackupMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BackupMetadata(
      id: fields[0] as String,
      fileName: fields[1] as String,
      location: fields[2] as BackupLocation,
      createdAt: fields[3] as DateTime,
      sizeBytes: fields[4] as int,
      flightLogsCount: fields[5] as int,
      checksum: fields[6] as String,
      driveFileId: fields[7] as String?,
      localPath: fields[8] as String?,
      isEncrypted: fields[9] as bool,
      encryptionAlgorithm: fields[10] as String,
      health: fields[11] as BackupHealth,
      lastVerified: fields[12] as DateTime?,
      deviceId: fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BackupMetadata obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.sizeBytes)
      ..writeByte(5)
      ..write(obj.flightLogsCount)
      ..writeByte(6)
      ..write(obj.checksum)
      ..writeByte(7)
      ..write(obj.driveFileId)
      ..writeByte(8)
      ..write(obj.localPath)
      ..writeByte(9)
      ..write(obj.isEncrypted)
      ..writeByte(10)
      ..write(obj.encryptionAlgorithm)
      ..writeByte(11)
      ..write(obj.health)
      ..writeByte(12)
      ..write(obj.lastVerified)
      ..writeByte(13)
      ..write(obj.deviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BackupLocationAdapter extends TypeAdapter<BackupLocation> {
  @override
  final int typeId = 101;

  @override
  BackupLocation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BackupLocation.none;
      case 1:
        return BackupLocation.cloud;
      case 2:
        return BackupLocation.local;
      case 3:
        return BackupLocation.both;
      default:
        return BackupLocation.none;
    }
  }

  @override
  void write(BinaryWriter writer, BackupLocation obj) {
    switch (obj) {
      case BackupLocation.none:
        writer.writeByte(0);
        break;
      case BackupLocation.cloud:
        writer.writeByte(1);
        break;
      case BackupLocation.local:
        writer.writeByte(2);
        break;
      case BackupLocation.both:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BackupHealthAdapter extends TypeAdapter<BackupHealth> {
  @override
  final int typeId = 102;

  @override
  BackupHealth read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BackupHealth.verified;
      case 1:
        return BackupHealth.unverified;
      case 2:
        return BackupHealth.failed;
      case 3:
        return BackupHealth.cancelled;
      case 4:
        return BackupHealth.corrupted;
      default:
        return BackupHealth.verified;
    }
  }

  @override
  void write(BinaryWriter writer, BackupHealth obj) {
    switch (obj) {
      case BackupHealth.verified:
        writer.writeByte(0);
        break;
      case BackupHealth.unverified:
        writer.writeByte(1);
        break;
      case BackupHealth.failed:
        writer.writeByte(2);
        break;
      case BackupHealth.cancelled:
        writer.writeByte(3);
        break;
      case BackupHealth.corrupted:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupHealthAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
