import 'category.dart';

class ScheduleModel {
  final String jadwalId;
  String userId;
  int kategoriId;
  String namaTagihan;
  double nominal;
  DateTime tanggalJatuhTempo;
  bool isReminderActive;
  bool isH1Active;
  String? catatan;

  // Joined relation (optional, for display)
  CategoryModel? category;

  ScheduleModel({
    required this.jadwalId,
    required this.userId,
    required this.kategoriId,
    required this.namaTagihan,
    required this.nominal,
    required this.tanggalJatuhTempo,
    this.isReminderActive = true,
    this.isH1Active = true,
    this.catatan,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'jadwal_id': jadwalId,
      'user_id': userId,
      'kategori_id': kategoriId,
      'nama_tagihan': namaTagihan,
      'nominal': nominal,
      'tanggal_jatuh_tempo': tanggalJatuhTempo.toIso8601String(),
      'is_reminder_active': isReminderActive ? 1 : 0,
      'is_h1_active': isH1Active ? 1 : 0,
      'catatan': catatan,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    CategoryModel? cat;
    if (map.containsKey('nama_kategori')) {
      cat = CategoryModel(
        kategoriId: map['kategori_id'] as int?,
        namaKategori: map['nama_kategori'] as String,
        tipe: map['tipe'] as String? ?? '',
        ikon: map['ikon'] as String? ?? '',
        warna: map['warna'] as String? ?? '',
      );
    }

    return ScheduleModel(
      jadwalId: map['jadwal_id'] as String,
      userId: map['user_id'] as String,
      kategoriId: map['kategori_id'] as int,
      namaTagihan: map['nama_tagihan'] as String,
      nominal: (map['nominal'] as num).toDouble(),
      tanggalJatuhTempo: DateTime.parse(map['tanggal_jatuh_tempo'] as String),
      isReminderActive: (map['is_reminder_active'] as int) == 1,
      isH1Active: map.containsKey('is_h1_active') ? (map['is_h1_active'] as int) == 1 : true,
      catatan: map['catatan'] as String?,
      category: cat,
    );
  }
}
