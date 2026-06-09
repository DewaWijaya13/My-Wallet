import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/database_helper.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Melakukan pencadangan (backup) seluruh isi database lokal ke Firestore.
  /// Ini dipanggil setiap ada perubahan data. Jika sedang offline, 
  /// Firestore akan menyimpannya di antrean lokal (cache) lalu 
  /// mengunggahnya otomatis saat online.
  Future<void> backupToCloud(String userId) async {
    try {
      final Map<String, dynamic> localData = await _dbHelper.exportUserDataToJson(userId);
      
      // Simpan data dalam bentuk JSON ke Firestore pada path: users/{userId}/backup/data
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('backup')
          .doc('data')
          .set(localData);

    } catch (e) {
      print("Gagal backup ke cloud: $e");
    }
  }

  /// Menarik data cadangan dari Firestore dan menimpakannya ke SQLite lokal.
  /// Ini biasa dipanggil saat pengguna baru saja Login (terutama di device baru).
  Future<bool> restoreFromCloud(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('backup')
          .doc('data')
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        await _dbHelper.importUserDataFromJson(userId, data);
        return true;
      }
      return false;
    } catch (e) {
      print("Gagal restore dari cloud: $e");
      return false;
    }
  }
}
