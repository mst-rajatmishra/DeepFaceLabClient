// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Answer _$AnswerFromJson(Map<String, dynamic> json) => Answer(
      value: json['value'] as String,
      outputs:
          (json['outputs'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$AnswerToJson(Answer instance) => <String, dynamic>{
      'value': instance.value,
      'outputs': instance.outputs,
    };
