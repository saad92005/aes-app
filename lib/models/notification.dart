part of '../main.dart';

// ---------------- IN-APP NOTIFICATIONS ----------------
class AppNotification {
  final String id;
  final String recipientUsername;
  final String title;
  final String message;
  final String? workOrderId;
  bool read;
  final String timestamp;

  AppNotification({
    required this.id,
    required this.recipientUsername,
    required this.title,
    required this.message,
    this.workOrderId,
    this.read = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipientUsername': recipientUsername,
        'title': title,
        'message': message,
        'workOrderId': workOrderId,
        'read': read,
        'timestamp': timestamp,
      };

  static AppNotification fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'],
        recipientUsername: m['recipientUsername'] ?? '',
        title: m['title'] ?? '',
        message: m['message'] ?? '',
        workOrderId: m['workOrderId'],
        read: m['read'] ?? false,
        timestamp: m['timestamp'] ?? '',
      );
}

int _notificationCounter = 1;
final List<AppNotification> sampleNotifications = [];

