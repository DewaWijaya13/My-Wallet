import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../models/schedule.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

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

        int idCounter = 0;
        for (var schedule in _upcomingSchedules) {
          if (schedule.isReminderActive) {
            final prefs = await SharedPreferences.getInstance();
            final reminderTime = prefs.getString('reminder_time') ?? '08:00';
            final parts = reminderTime.split(':');
            final h = int.tryParse(parts[0]) ?? 8;
            final m = int.tryParse(parts[1]) ?? 0;
            
            // Set notification time on H-1 at the specified time
            final dateH1 = schedule.tanggalJatuhTempo.subtract(const Duration(days: 1));
            final scheduledDate = DateTime(dateH1.year, dateH1.month, dateH1.day, h, m);
            
            await notifService.scheduleNotification(
              id: idCounter++,
              title: 'Pengingat Tagihan Besok!',
              body: 'Halo ${user.namaLengkap}, jadwal "${schedule.namaTagihan}" akan jatuh tempo besok lho. Yuk disiapkan dananya!',
              scheduledDate: scheduledDate,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
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
