import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback if unable to detect local timezone
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    // Default initialization for Android and iOS
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Request permissions and register high-importance channel explicitly for Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = 
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'my_wallet_schedule_channel_v4',
        'Pengingat Jadwal',
        description: 'Notifikasi H-1 untuk jadwal transaksi',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(channel);
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    print('=== DIAGNOSIS NOTIFIKASI ===');
    print('ID Notifikasi: $id');
    print('Judul: $title');
    print('Waktu Sekarang (Local): ${DateTime.now()}');
    print('Waktu Jadwal (Input): $scheduledDate');
    print('Apakah Waktu Sudah Lewat? ${scheduledDate.isBefore(DateTime.now())}');

    // Only schedule if it's in the future
    if (scheduledDate.isBefore(DateTime.now())) {
      print('Batal menjadwalkan notifikasi (ID: $id) karena waktunya sudah terlewat.');
      return;
    }

    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    print('Timezone Lokal: ${tz.local}');
    print('Waktu Konversi Timezone (tzDate): $tzDate');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'my_wallet_schedule_channel_v4',
      'Pengingat Jadwal',
      channelDescription: 'Notifikasi H-1 untuk jadwal transaksi',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print('Mencoba menjadwalkan dengan AndroidScheduleMode.exactAllowWhileIdle...');
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('Berhasil menjadwalkan notifikasi ID: $id (Exact)');
    } catch (e) {
      print('Gagal menjadwalkan dengan mode Exact. Error: $e');
      print('Mencoba fallback dengan AndroidScheduleMode.inexactAllowWhileIdle...');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDate,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        print('Berhasil menjadwalkan notifikasi ID: $id (Inexact fallback)');
      } catch (ex) {
        print('Gagal total menjadwalkan notifikasi ID: $id. Error fallback: $ex');
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
