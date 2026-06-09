import 'category.dart';

class TransactionModel {
  final String trxId;
  String userId;
  int kategoriId;
  String? walletId;
  String tipeTrx; // 'income' | 'expense'
  double nominal;
  DateTime tanggalTrx;
  String? catatan;

  // Joined relation (optional, for display)
  CategoryModel? category;

  TransactionModel({
    required this.trxId,
    required this.userId,
    required this.kategoriId,
    this.walletId,
    required this.tipeTrx,
    required this.nominal,
    required this.tanggalTrx,
    this.catatan,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'trx_id': trxId,
      'user_id': userId,
      'kategori_id': kategoriId,
      'wallet_id': walletId,
      'tipe_trx': tipeTrx,
      'nominal': nominal,
      'tanggal_trx': tanggalTrx.toIso8601String(),
      'catatan': catatan,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
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

    return TransactionModel(
      trxId: map['trx_id'] as String,
      userId: map['user_id'] as String,
      kategoriId: map['kategori_id'] as int,
      walletId: map['wallet_id'] as String?,
      tipeTrx: map['tipe_trx'] as String,
      nominal: (map['nominal'] as num).toDouble(),
      tanggalTrx: DateTime.parse(map['tanggal_trx'] as String),
      catatan: map['catatan'] as String?,
      category: cat,
    );
  }
}
