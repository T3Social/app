// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PushEventData _$PushEventDataFromJson(Map<String, dynamic> json) {
  return PushEventData(
    json['notification_title'] as String?,
    json['notification_body'] as String?,
    json['channel'] as String?,
    PushEventData._storesFromJson(json['refresh_stores']),
    json['channel_payload'] as String?,
  );
}

SimpleNotification _$SimpleNotificationFromJson(Map<String, dynamic> json) {
  return SimpleNotification(
    json['title'] as String,
    json['body'] as String,
  );
}

PushEventRefreshStore _$PushEventRefreshStoreFromJson(Map<String, dynamic> json) {
  return PushEventRefreshStore(
    json['store_id'] as String?,
    json['family_id'],
  );
}