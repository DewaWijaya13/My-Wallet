import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';

class ScheduleController {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _uuid = Uuid();

  Future<ScheduleModel> addSchedule({
    required String userId,
    required int kategoriId,
    required String namaTagihan,
    required double nominal,
    required DateTime tanggalJatuhTempo,
    bool isReminderActive = true,
    bool isH1Active = true,
    String? catatan,
  }) async {
    if (nominal <= 0) {
      throw Exception('Nominal harus lebih dari 0');
    }
    if (namaTagihan.trim().isEmpty) {
      throw Exception('Nama tagihan tidak boleh kosong');
    }

    final schedule = ScheduleModel(
      jadwalId: _uuid.v4(),
      userId: userId,
      kategoriId: kategoriId,
      namaTagihan: namaTagihan,
      nominal: nominal,
      tanggalJatuhTempo: tanggalJatuhTempo,
      isReminderActive: isReminderActive,
      isH1Active: isH1Active,
      catatan: catatan,
    );

    await _db.insertSchedule(schedule);
    return schedule;
  }

  Future<List<ScheduleModel>> getAllSchedules(String userId) async {
    return await _db.getSchedulesByUser(userId);
  }

  Future<List<ScheduleModel>> getUpcomingSchedules(String userId) async {
    return await _db.getUpcomingSchedules(userId);
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    await _db.updateSchedule(schedule);
  }

  Future<void> deleteSchedule(String jadwalId) async {
    await _db.deleteSchedule(jadwalId);
  }
}
