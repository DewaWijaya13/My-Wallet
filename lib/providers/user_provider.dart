import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/user.dart';
import '../database/database_helper.dart';
import '../services/cloud_sync_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthController _authController = AuthController();
  final ProfileController _profileController = ProfileController();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  String _currency = 'IDR';
  bool _useLiveConversion = false;
  Map<String, double>? _exchangeRates;

  bool _showCompactNumbers = true;
  String _reminderTime = '08:00';
  bool _isNotificationEnabled = true;
  bool _hasUnreadNotifications = false;
  int _unreadCount = 0;
  Timer? _unreadCheckTimer;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get batasBudget => _currentUser?.batasBudget ?? 0;
  String get userId => _currentUser?.userId ?? '';
  bool get showCompactNumbers => _showCompactNumbers;
  String get reminderTime => _reminderTime;
  bool get isNotificationEnabled => _isNotificationEnabled;
  bool get hasUnreadNotifications => _hasUnreadNotifications;
  int get unreadCount => _unreadCount;
  
  String get currency => _currency;
  bool get useLiveConversion => _useLiveConversion;

  void setHasUnreadNotifications(bool value) {
    _hasUnreadNotifications = value;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authController.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.userId);

      // -- AUTO RESTORE CLOUD SYNC --
      try {
        final cloudSync = CloudSyncService();
        await cloudSync.restoreFromCloud(_currentUser!.userId);
        
        // Re-fetch user in case local DB was updated from Cloud
        final db = DatabaseHelper.instance;
        _currentUser = await db.getUserByEmail(email) ?? _currentUser;
      } catch (_) {}

      await loadUser(_currentUser!.userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('unverified_email')) {
        _errorMessage = 'Email belum diverifikasi. Silakan cek kotak masuk email Anda.';
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authController.loginWithGoogle();
      if (user != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _currentUser!.userId);

        // -- AUTO RESTORE CLOUD SYNC --
        // Check and pull backup from cloud if any
        try {
          final cloudSync = CloudSyncService();
          await cloudSync.restoreFromCloud(_currentUser!.userId);
        } catch (_) {}

        await loadUser(_currentUser!.userId);
        _isLoading = false;
        return true;
      } else {
        _errorMessage = null; // Canceled explicitly
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('canceled')) {
        _errorMessage = null; // Ignore canceled exception
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> sendVerificationEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final tempPassword = await _authController.sendEmailVerificationLink(email);
      _errorMessage = 'Tautan verifikasi telah dikirim. Silakan cek email Anda.';
      _isLoading = false;
      notifyListeners();
      return tempPassword;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkEmailVerified(String email, String tempPassword) async {
    _isLoading = true;
    notifyListeners();
    final verified = await _authController.isEmailVerified(email, tempPassword);
    if (!verified) {
      _errorMessage = 'Email belum terverifikasi.';
    } else {
      _errorMessage = null;
    }
    _isLoading = false;
    notifyListeners();
    return verified;
  }

  Future<bool> finalizeRegistration({
    required String namaLengkap,
    required String email,
    required String tempPassword,
    required String realPassword,
    String? noHp,
    DateTime? tanggalLahir,
    String? jenisKelamin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authController.finalizeRegistration(
        namaLengkap: namaLengkap,
        email: email,
        tempPassword: tempPassword,
        realPassword: realPassword,
        noHp: noHp,
        tanggalLahir: tanggalLahir,
        jenisKelamin: jenisKelamin,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.userId);

      // Trigger cloud sync upload immediately for new profile
      try {
        final cloudSync = CloudSyncService();
        await cloudSync.backupToCloud(_currentUser!.userId);
      } catch (_) {}

      await loadUser(_currentUser!.userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      _errorMessage = 'Tautan reset sandi telah dikirim ke email Anda.';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? namaLengkap,
    String? email,
    String? noHp,
    String? fotoProfil,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _profileController.updateProfile(
        userId: _currentUser!.userId,
        namaLengkap: namaLengkap,
        email: email,
        noHp: noHp,
        fotoProfil: fotoProfil,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBudget(double newBudget) async {
    if (_currentUser == null) return false;

    try {
      _currentUser = await _profileController.updateBudget(
        _currentUser!.userId,
        newBudget,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteAllData() async {
    if (_currentUser == null) return;
    await _profileController.deleteAllData(_currentUser!.userId);
    notifyListeners();
  }

  Future<void> loadUser(String userId) async {
    try {
      final db = DatabaseHelper.instance;
      _currentUser = await db.getUserById(userId);
      
      final prefs = await SharedPreferences.getInstance();
      _currency = prefs.getString('currency') ?? 'IDR';
      _useLiveConversion = prefs.getBool('use_live_conversion') ?? false;
      _showCompactNumbers = prefs.getBool('show_compact_numbers') ?? true;
      _reminderTime = prefs.getString('reminder_time') ?? '08:00';
      _isNotificationEnabled = prefs.getBool('is_notification_enabled') ?? true;
      
      if (_useLiveConversion) {
        await fetchExchangeRates();
      }
      
      await checkUnreadNotifications();
      startUnreadCheckTimer();
      
      // -- AUTO CLOUD SYNC ON START --
      try {
        final cloudSync = CloudSyncService();
        cloudSync.backupToCloud(userId);
      } catch (_) {}

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchExchangeRates() async {
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/IDR'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rates'] != null) {
          _exchangeRates = Map<String, double>.from(data['rates'].map((key, value) => MapEntry(key, value.toDouble())));
        }
      }
    } catch (_) {}
  }

  double convert(double amountInIdr) {
    if (!_useLiveConversion || _currency == 'IDR' || _exchangeRates == null) return amountInIdr;
    final rate = _exchangeRates![_currency] ?? 1.0;
    return amountInIdr * rate;
  }

  Future<void> updateCurrency(String newCurrency) async {
    _currency = newCurrency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', newCurrency);
    notifyListeners();
  }

  Future<void> toggleLiveConversion(bool value) async {
    _useLiveConversion = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_live_conversion', value);
    if (value && _exchangeRates == null) {
      await fetchExchangeRates();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    stopUnreadCheckTimer();
    _currentUser = null;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) return;
    try {
      final db = DatabaseHelper.instance;
      await db.deleteAccount(_currentUser!.userId);
      await logout();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> toggleCompactNumbers(bool value) async {
    _showCompactNumbers = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_compact_numbers', value);
    notifyListeners();
  }

  Future<void> updateReminderTime(String newTime) async {
    _reminderTime = newTime;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_time', newTime);
    notifyListeners();
  }

  Future<void> toggleNotification(bool value) async {
    _isNotificationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notification_enabled', value);
    notifyListeners();
  }

  Future<void> checkUnreadNotifications() async {
    if (_currentUser == null) return;
    final db = DatabaseHelper.instance;
    try {
      _unreadCount = await db.getUnreadNotificationsCount(_currentUser!.userId);
      _hasUnreadNotifications = _unreadCount > 0;
      notifyListeners();
    } catch (e) {
      debugPrint('DEBUG NOTIFS ERROR: $e');
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    if (_currentUser == null) return;
    final db = DatabaseHelper.instance;
    await db.markNotificationAsRead(notifId);
    await checkUnreadNotifications();
    CloudSyncService().backupToCloud(_currentUser!.userId);
  }

  Future<void> markAllNotificationsAsRead() async {
    if (_currentUser == null) return;
    final db = DatabaseHelper.instance;
    await db.markAllNotificationsAsRead(_currentUser!.userId);
    await checkUnreadNotifications();
    CloudSyncService().backupToCloud(_currentUser!.userId);
  }

  void startUnreadCheckTimer() {
    _unreadCheckTimer?.cancel();
    _unreadCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      checkUnreadNotifications();
    });
  }

  void stopUnreadCheckTimer() {
    _unreadCheckTimer?.cancel();
    _unreadCheckTimer = null;
  }

  Future<void> deleteNotification(String notifId) async {
    if (_currentUser == null) return;
    final db = DatabaseHelper.instance;
    await db.deleteNotification(notifId);
    await checkUnreadNotifications();
    CloudSyncService().backupToCloud(_currentUser!.userId);
  }

  Future<void> clearAllNotifications() async {
    if (_currentUser == null) return;
    final db = DatabaseHelper.instance;
    await db.deleteAllNotifications(_currentUser!.userId);
    await checkUnreadNotifications();
    CloudSyncService().backupToCloud(_currentUser!.userId);
  }

  @override
  void dispose() {
    stopUnreadCheckTimer();
    super.dispose();
  }
}
