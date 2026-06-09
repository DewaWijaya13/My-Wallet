import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';

class TransactionController {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _uuid = Uuid();

  Future<TransactionModel> addTransaction({
    required String userId,
    required int kategoriId,
    String? walletId,
    required String tipeTrx,
    required double nominal,
    required DateTime tanggalTrx,
    String? catatan,
  }) async {
    if (nominal <= 0) {
      throw Exception('Nominal harus lebih dari 0');
    }

    final trx = TransactionModel(
      trxId: _uuid.v4(),
      userId: userId,
      kategoriId: kategoriId,
      walletId: walletId,
      tipeTrx: tipeTrx,
      nominal: nominal,
      tanggalTrx: tanggalTrx,
      catatan: catatan,
    );

    await _db.insertTransaction(trx);
    return trx;
  }

  Future<List<TransactionModel>> getRecentTransactions(String userId, {int limit = 5}) async {
    return await _db.getTransactionsByUser(userId, limit: limit);
  }

  Future<Map<String, double>> getIncomeExpenseSummary(String userId, int month, int year) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final income = await _db.getTotalByType(userId, 'income', start, end);
    final expense = await _db.getTotalByType(userId, 'expense', start, end);

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  Future<Map<int, double>> getMonthlyExpenseByCategory(String userId, int month, int year) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return await _db.getExpenseByCategory(userId, start, end);
  }

  Future<void> deleteTransaction(String trxId) async {
    await _db.deleteTransaction(trxId);
  }
}
