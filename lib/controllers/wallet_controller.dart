import '../models/wallet.dart';
import '../database/database_helper.dart';
import 'package:uuid/uuid.dart';

class WalletController {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Future<List<WalletModel>> getWalletsByUser(String userId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wallets',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'tanggal_dibuat ASC',
    );
    return List.generate(maps.length, (i) => WalletModel.fromMap(maps[i]));
  }

  Future<WalletModel?> getWalletById(String walletId) async {
    final db = await _db.database;
    final maps = await db.query(
      'wallets',
      where: 'wallet_id = ?',
      whereArgs: [walletId],
    );
    if (maps.isNotEmpty) {
      return WalletModel.fromMap(maps.first);
    }
    return null;
  }

  Future<WalletModel> createWallet({
    required String userId,
    required String namaDompet,
    String? deskripsi,
    required String warna,
    required String ikon,
    double saldoAwal = 0.0,
  }) async {
    final db = await _db.database;
    final newWallet = WalletModel(
      walletId: _uuid.v4(),
      userId: userId,
      namaDompet: namaDompet,
      deskripsi: deskripsi,
      warna: warna,
      ikon: ikon,
      saldoAwal: saldoAwal,
      tanggalDibuat: DateTime.now(),
    );

    await db.insert('wallets', newWallet.toMap());
    return newWallet;
  }

  Future<void> updateWallet(WalletModel wallet) async {
    final db = await _db.database;
    await db.update(
      'wallets',
      wallet.toMap(),
      where: 'wallet_id = ?',
      whereArgs: [wallet.walletId],
    );
  }

  Future<void> deleteWallet(String walletId) async {
    final db = await _db.database;
    // Note: should also handle transactions related to this wallet.
    // For now, simply delete the wallet. Or reassign transactions.
    await db.delete(
      'wallets',
      where: 'wallet_id = ?',
      whereArgs: [walletId],
    );
  }
}
