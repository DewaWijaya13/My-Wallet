class WalletModel {
  final String walletId;
  final String userId;
  final String namaDompet;
  final String? deskripsi;
  final String warna;
  final String ikon;
  final double saldoAwal;
  final DateTime tanggalDibuat;

  WalletModel({
    required this.walletId,
    required this.userId,
    required this.namaDompet,
    this.deskripsi,
    required this.warna,
    required this.ikon,
    this.saldoAwal = 0.0,
    required this.tanggalDibuat,
  });

  Map<String, dynamic> toMap() {
    return {
      'wallet_id': walletId,
      'user_id': userId,
      'nama_dompet': namaDompet,
      'deskripsi': deskripsi,
      'warna': warna,
      'ikon': ikon,
      'saldo_awal': saldoAwal,
      'tanggal_dibuat': tanggalDibuat.toIso8601String(),
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      walletId: map['wallet_id'],
      userId: map['user_id'],
      namaDompet: map['nama_dompet'],
      deskripsi: map['deskripsi'],
      warna: map['warna'],
      ikon: map['ikon'],
      saldoAwal: map['saldo_awal']?.toDouble() ?? 0.0,
      tanggalDibuat: DateTime.parse(map['tanggal_dibuat']),
    );
  }
}
