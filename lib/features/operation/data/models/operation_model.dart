import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/operation/domain/entities/Author.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'operation_model.g.dart';

@JsonSerializable()
class OperationModel extends Operation implements JsonObject<Map<String, dynamic>> {
  OperationModel({
    @required String uuid,
    @required String name,
    @required Location ipp,
    @required Author author,
    @required Location meetup,
    @required OperationType type,
    @required Passcodes passcodes,
    @required String justification,
    @required OperationStatus status,
    @required List<TalkGroup> talkgroups,
    @required OperationResolution resolution,
    @required AggregateRef<Incident> incident,
    @required AggregateRef<Personnel> commander,
    String reference,
  }) : super(
          ipp: ipp,
          uuid: uuid,
          name: name,
          type: type,
          author: author,
          status: status,
          meetup: meetup,
          incident: incident,
          passcodes: passcodes,
          reference: reference,
          commander: commander,
          resolution: resolution,
          talkgroups: talkgroups,
          justification: justification,
        );

  /// Factory constructor for creating a new `OperationModel` instance
  factory OperationModel.fromJson(Map<String, dynamic> json) => _$OperationModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OperationModelToJson(this);

  /// Clone with json
  Operation mergeWith(Map<String, dynamic> json) {
    var clone = OperationModel.fromJson(json);
    return OperationModel(
      uuid: clone.uuid ?? this.uuid,
      name: clone.name ?? this.name,
      type: clone.type ?? this.type,
      author: clone.author ?? this.author,
      status: clone.status ?? this.status,
      reference: clone.reference ?? this.reference,
      resolution: clone.resolution ?? this.resolution,
      ipp: clone.ipp ?? this.ipp,
      meetup: clone.meetup ?? this.meetup,
      justification: clone.justification ?? this.justification,
      passcodes: clone.passcodes ?? this.passcodes,
      incident: clone.incident ?? this.incident,
      commander: clone.commander ?? this.commander,
      talkgroups: clone.talkgroups ?? this.talkgroups,
    );
  }

  /// Clone with author
  Operation withAuthor(String userId) {
    var now = DateTime.now();
    return OperationModel(
      ipp: this.ipp,
      uuid: this.uuid,
      name: this.name,
      type: this.type,
      meetup: this.meetup,
      status: this.status,
      reference: this.reference,
      passcodes: this.passcodes,
      resolution: this.resolution,
      justification: this.justification,
      incident: incident ?? this.incident,
      commander: commander ?? this.commander,
      author: Author(userId: userId, timestamp: now),
      talkgroups: this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }

  /// Clone with author
  Operation copyWith({
    String name,
    Location ipp,
    bool exercise,
    Author author,
    Location meetup,
    String reference,
    DateTime occurred,
    OperationType type,
    Passcodes passcodes,
    String justification,
    OperationStatus status,
    List<TalkGroup> talkGroups,
    OperationResolution resolution,
    AggregateRef<Incident> incident,
    AggregateRef<Personnel> commander,
  }) {
    return OperationModel(
      uuid: this.uuid,
      name: name ?? this.name,
      type: type ?? this.type,
      passcodes: passcodes ??
          Passcodes.fromJson(
            this.passcodes?.toJson() ?? {},
          ),
      author: author ?? this.author,
      status: status ?? this.status,
      incident: incident ?? this.incident,
      commander: commander ?? this.commander,
      reference: reference ?? this.reference,
      resolution: resolution ?? this.resolution,
      ipp: ipp ?? Location.fromJson(this.ipp.toJson()),
      justification: justification ?? this.justification,
      meetup: meetup ?? Location.fromJson(this.meetup.toJson()),
      talkgroups: talkGroups ?? this.talkgroups.map((tg) => TalkGroup.fromJson(tg.toJson())).toList(),
    );
  }
}
