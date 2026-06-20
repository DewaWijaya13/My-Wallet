import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../models/schedule.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final ScheduleController _controller = ScheduleController();

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _upcomingSchedules = [];
  bool _isLoading = false;

  List<ScheduleModel> get schedules => _schedules;
  List<ScheduleModel> get upcomingSchedules => _upcomingSchedules;
  bool get isLoading => _isLoading;

  Future<void> loadSchedules(String userId) async {
    _isLoading = true;
    notifyListeners();

    _schedules = await _controller.getAllSchedules(userId);
    _upcomingSchedules = await _controller.getUpcomingSchedules(userId);

    try {
      final db = DatabaseHelper.instance;
      final user = await db.getUserById(userId);
      if (user != null) {
        final notifService = NotificationService();
        // Cancel all existing to avoid duplicates
        await notifService.cancelAllNotifications();

        final prefs = await SharedPreferences.getInstance();
        final isNotifEnabled = prefs.getBool('is_notification_enabled') ?? true;

        if (isNotifEnabled) {
          int idCounter = 0;
          for (var schedule in _upcomingSchedules) {
            if (schedule.isReminderActive) {
              try {
                final reminderTime = prefs.getString('reminder_time') ?? '08:00';
                final parts = reminderTime.split(':');
                final h = int.tryParse(parts[0]) ?? 8;
                final m = int.tryParse(parts[1]) ?? 0;
                
                // Set notification time on H-1 or Hari H at the specified time (offset by 10s)
                final baseDate = schedule.isH1Active
                    ? schedule.tanggalJatuhTempo.subtract(const Duration(days: 1))
                    : schedule.tanggalJatuhTempo;
                final baseScheduledDate = DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
                final scheduledDate = baseScheduledDate.add(const Duration(seconds: 10));
                
                final notifId = 'notif_${schedule.jadwalId}_${schedule.tanggalJatuhTempo.toIso8601String()}';
                final title = schedule.isH1Active ? 'Pengingat Tagihan Besok!' : 'Pengingat Tagihan Hari Ini!';
                final body = schedule.isH1Active
                    ? 'Halo ${user.namaLengkap}, jadwal "${schedule.namaTagihan}" akan jatuh tempo besok lho. Yuk disiapkan dananya!'
                    : 'Halo ${user.namaLengkap}, jadwal "${schedule.namaTagihan}" jatuh tempo hari ini lho. Jangan lupa dibayar ya!';

                // Save notification to SQLite so it appears in the Notification Center
                await db.insertNotification(
                  notifId,
                  userId,
                  title,
                  body,
                  scheduledDate.toIso8601String(),
                );

                await notifService.scheduleNotification(
                  id: idCounter++,
                  title: title,
                  body: body,
                  scheduledDate: scheduledDate,
                );
              } catch (e) {
                debugPrint('Error scheduling notification for schedule ${schedule.jadwalId}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }

    try {
      await CloudSyncService().backupToCloud(userId);
    } catch (e) {
      debugPrint('Error backing up to cloud in loadSchedules: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addSchedule({
    required String userId,
    required int kategoriId,
    required String namaTagihan,
    required double nominal,
    required DateTime tanggalJatuhTempo,
    bool isReminderActive = true,
    bool isH1Active = true,
    String? catatan,
  }) async {
    try {
      await _controller.addSchedule(
        userId: userId,
        kategoriId: kategoriId,
        namaTagihan: namaTagihan,
        nominal: nominal,
        tanggalJatuhTempo: tanggalJatuhTempo,
        isReminderActive: isReminderActive,
        isH1Active: isH1Active,
        catatan: catatan,
      );
      await loadSchedules(userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateSchedule(ScheduleModel schedule, String userId) async {
    await _controller.updateSchedule(schedule);
    await loadSchedules(userId);
  }

  Future<void> deleteSchedule(String jadwalId, String userId) async {
    await _controller.deleteSchedule(jadwalId);
    await loadSchedules(userId);
  }
}
