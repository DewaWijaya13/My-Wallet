import 'package:flutter/material.dart';
import '../controllers/wallet_controller.dart';
import '../models/wallet.dart';
import '../services/cloud_sync_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletController _controller = WalletController();

  List<WalletModel> _wallets = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? _activeWalletId; // To track which wallet is currently viewed in dashboard

  List<WalletModel> get wallets => _wallets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get activeWalletId => _activeWalletId;

  // Active Wallet logic
  void setActiveWallet(String walletId) {
    _activeWalletId = walletId;
    notifyListeners();
  }

  WalletModel? get activeWallet {
    if (_wallets.isEmpty) return null;
    if (_activeWalletId == null) return _wallets.first;
    try {
      return _wallets.firstWhere((w) => w.walletId == _activeWalletId);
    } catch (_) {
      return _wallets.first;
    }
  }

  Future<void> loadWallets(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _wallets = await _controller.getWalletsByUser(userId);
      // Set active wallet to first if null or not found
      if (_wallets.isNotEmpty) {
        if (_activeWalletId == null || !_wallets.any((w) => w.walletId == _activeWalletId)) {
          _activeWalletId = _wallets.first.walletId;
        }
      } else {
        _activeWalletId = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createWallet({
    required String userId,
    required String namaDompet,
    String? deskripsi,
    required String warna,
    required String ikon,
    double saldoAwal = 0.0,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newWallet = await _controller.createWallet(
        userId: userId,
        namaDompet: namaDompet,
        deskripsi: deskripsi,
        warna: warna,
        ikon: ikon,
        saldoAwal: saldoAwal,
      );
      _wallets.add(newWallet);
      
      // If it's the first wallet, make it active
      if (_wallets.length == 1) {
        _activeWalletId = newWallet.walletId;
      }
      
      // -- CLOUD SYNC --
      CloudSyncService().backupToCloud(userId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWallet(WalletModel wallet) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _controller.updateWallet(wallet);
      final index = _wallets.indexWhere((w) => w.walletId == wallet.walletId);
      if (index != -1) {
        _wallets[index] = wallet;
      }

      // -- CLOUD SYNC --
      CloudSyncService().backupToCloud(wallet.userId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? userId;
      if (_wallets.isNotEmpty) {
        userId = _wallets.firstWhere((w) => w.walletId == walletId).userId;
      }

      await _controller.deleteWallet(walletId);
      _wallets.removeWhere((w) => w.walletId == walletId);
      if (_activeWalletId == walletId) {
        _activeWalletId = _wallets.isNotEmpty ? _wallets.first.walletId : null;
      }

      // -- CLOUD SYNC --
      if (userId != null) {
        CloudSyncService().backupToCloud(userId);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
