// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightLogAdapter extends TypeAdapter<FlightLog> {
  @override
  final int typeId = 2;

  @override
  FlightLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlightLog(
      id: fields[0] as String?,
      date: fields[1] as DateTime,
      flightTypes: (fields[2] as List).cast<FlightType>(),
      durationHours: fields[3] as int,
      durationMinutes: fields[4] as int,
      aircraftType: fields[5] as String,
      pilotRole: fields[6] as PilotRole,
      isDayFlight: fields[7] as bool,
      isSimulated: fields[8] as bool,
      createdAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FlightLog obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.flightTypes)
      ..writeByte(3)
      ..write(obj.durationHours)
      ..writeByte(4)
      ..write(obj.durationMinutes)
      ..writeByte(5)
      ..write(obj.aircraftType)
      ..writeByte(6)
      ..write(obj.pilotRole)
      ..writeByte(7)
      ..write(obj.isDayFlight)
      ..writeByte(8)
      ..write(obj.isSimulated)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlightTypeAdapter extends TypeAdapter<FlightType> {
  @override
  final int typeId = 0;

  @override
  FlightType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FlightType.local;
      case 1:
        return FlightType.mission;
      case 2:
        return FlightType.xc;
      case 3:
        return FlightType.zone;
      case 4:
        return FlightType.range;
      case 5:
        return FlightType.formation;
      case 6:
        return FlightType.currencyFlight;
      case 7:
        return FlightType.landingGround;
      case 8:
        return FlightType.navalOps;
      case 9:
        return FlightType.lowLevel;
      default:
        return FlightType.local;
    }
  }

  @override
  void write(BinaryWriter writer, FlightType obj) {
    switch (obj) {
      case FlightType.local:
        writer.writeByte(0);
        break;
      case FlightType.mission:
        writer.writeByte(1);
        break;
      case FlightType.xc:
        writer.writeByte(2);
        break;
      case FlightType.zone:
        writer.writeByte(3);
        break;
      case FlightType.range:
        writer.writeByte(4);
        break;
      case FlightType.formation:
        writer.writeByte(5);
        break;
      case FlightType.currencyFlight:
        writer.writeByte(6);
        break;
      case FlightType.landingGround:
        writer.writeByte(7);
        break;
      case FlightType.navalOps:
        writer.writeByte(8);
        break;
      case FlightType.lowLevel:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PilotRoleAdapter extends TypeAdapter<PilotRole> {
  @override
  final int typeId = 1;

  @override
  PilotRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PilotRole.IP;
      case 1:
        return PilotRole.MTP;
      case 2:
        return PilotRole.PIC;
      case 3:
        return PilotRole.CPG_GUNNER;
      default:
        return PilotRole.IP;
    }
  }

  @override
  void write(BinaryWriter writer, PilotRole obj) {
    switch (obj) {
      case PilotRole.IP:
        writer.writeByte(0);
        break;
      case PilotRole.MTP:
        writer.writeByte(1);
        break;
      case PilotRole.PIC:
        writer.writeByte(2);
        break;
      case PilotRole.CPG_GUNNER:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PilotRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
