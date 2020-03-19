// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organization _$OrganizationFromJson(Map<String, dynamic> json) {
  return $checkedNew('Organization', json, () {
    final val = Organization(
        id: $checkedConvert(json, 'id', (v) => v as String),
        name: $checkedConvert(json, 'name', (v) => v as String),
        alias: $checkedConvert(json, 'alias', (v) => v as String),
        pattern: $checkedConvert(json, 'pattern', (v) => v as String),
        functions: $checkedConvert(json, 'functions', (v) => v),
        divisions: $checkedConvert(json, 'divisions', (v) => v),
        talkGroups: $checkedConvert(json, 'talk_groups', (v) => v));
    return val;
  }, fieldKeyMap: const {'talkGroups': 'talk_groups'});
}

Map<String, dynamic> _$OrganizationToJson(Organization instance) =>
    _$OrganizationJsonMapWrapper(instance);

class _$OrganizationJsonMapWrapper extends $JsonMapWrapper {
  final Organization _v;
  _$OrganizationJsonMapWrapper(this._v);

  @override
  Iterable<String> get keys => const [
        'id',
        'name',
        'alias',
        'pattern',
        'functions',
        'divisions',
        'talk_groups'
      ];

  @override
  dynamic operator [](Object key) {
    if (key is String) {
      switch (key) {
        case 'id':
          return _v.id;
        case 'name':
          return _v.name;
        case 'alias':
          return _v.alias;
        case 'pattern':
          return _v.pattern;
        case 'functions':
          return _v.functions;
        case 'divisions':
          return _v.divisions;
        case 'talk_groups':
          return _v.talkGroups;
      }
    }
    return null;
  }
}
