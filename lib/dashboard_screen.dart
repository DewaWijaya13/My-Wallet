import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'edit_profile_screen.dart';
import 'add_schedule_screen.dart';
import 'add_transaction_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/category_provider.dart';
import 'manage_category_screen.dart';
import 'providers/transaction_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/wallet_provider.dart';
import 'manage_wallet_screen.dart';
import 'services/export_service.dart';
import 'all_transactions_screen.dart';
import 'package:intl/intl.dart';
import 'main.dart'; // For LoginScreen
import 'models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/schedule.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _bottomNavIndex = 0;
  String _selectedReportPeriod = 'Bulan';
  bool _isNotificationEnabled = true;
  String? _selectedCategoryFilter; // null = show all
  int _reportOffset = 0; // 0 = current period, -1 = previous, etc.
  late DateTime _currentCalendarMonth;
  late DateTime _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentCalendarMonth = DateTime(now.year, now.month, 1);
    _selectedCalendarDate = DateTime(now.year, now.month, now.day);
    _loadNotificationSetting();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWallets();
    });
  }

  Future<void> _checkWallets() async {
    final userProvider = context.read<UserProvider>();
    final walletProvider = context.read<WalletProvider>();
    await walletProvider.loadWallets(userProvider.userId);
    
    if (walletProvider.wallets.isEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ManageWalletScreen(isInitial: true)),
      );
    }
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('is_notification_enabled') ?? true;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notification_enabled', value);
    setState(() {
      _isNotificationEnabled = value;
    });
  }

  Map<String, dynamic> _getReportData(List<TransactionModel> transactions) {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    if (_selectedReportPeriod == 'Minggu') {
      int daysSinceMonday = now.weekday - 1;
      DateTime currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
      start = currentWeekStart.add(Duration(days: 7 * _reportOffset));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else if (_selectedReportPeriod == 'Bulan') {
      DateTime base = DateTime(now.year, now.month + _reportOffset, 1);
      start = base;
      end = DateTime(base.year, base.month + 1, 0, 23, 59, 59);
    } else {
      int targetYear = now.year + _reportOffset;
      start = DateTime(targetYear, 1, 1);
      end = DateTime(targetYear, 12, 31, 23, 59, 59);
    }

    double totalExpense = 0;
    double totalIncome = 0;
    Map<String, double> expenseByCategory = {};
    Map<String, Map<String, dynamic>> categoryDetails = {};

    for (var trx in transactions) {
      if (trx.tanggalTrx.isAfter(start.subtract(const Duration(seconds: 1))) && trx.tanggalTrx.isBefore(end.add(const Duration(seconds: 1)))) {
        if (trx.tipeTrx == 'expense') {
          totalExpense += trx.nominal;
          String catName = trx.category?.namaKategori ?? 'Lainnya';
          expenseByCategory[catName] = (expenseByCategory[catName] ?? 0) + trx.nominal;

          if (!categoryDetails.containsKey(catName)) {
            final cat = trx.category;
            IconData icon;
            Color iconColor;
            Color bgColor;

            if (cat != null && cat.ikon.isNotEmpty) {
              icon = CategoryProvider.getIconData(cat.ikon);
              iconColor = CategoryProvider.parseColor(cat.warna);
              bgColor = CategoryProvider.parseColor(cat.warna).withOpacity(0.15);
            } else {
              icon = Icons.receipt_long;
              iconColor = const Color(0xFF7C3AED);
              bgColor = const Color(0xFFF3E8FF);
            }

            categoryDetails[catName] = {
              'icon': icon,
              'iconColor': iconColor,
              'bgColor': bgColor,
              'barColor': iconColor.withOpacity(0.6),
            };
          }
        } else {
          totalIncome += trx.nominal;
        }
      }
    }

    var sortedEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> sortedCategories = [];
    for (var entry in sortedEntries) {
      sortedCategories.add({
        'name': entry.key,
        'amount': entry.value,
        'percent': totalExpense > 0 ? entry.value / totalExpense : 0.0,
        ...categoryDetails[entry.key]!,
      });
    }

    return {
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'categories': sortedCategories,
      'startDate': start,
      'endDate': end,
    };
  }

  String _getFormattedPeriod(DateTime start, DateTime end) {
    if (_selectedReportPeriod == 'Minggu') {
      return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
    } else if (_selectedReportPeriod == 'Bulan') {
      return DateFormat('MMMM yyyy', 'id').format(start);
    } else {
      return DateFormat('yyyy').format(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch UserProvider so that when currency/live-conversion changes, 
    // the whole dashboard rebuilds and updates the currency symbols/values.
    context.watch<UserProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.97, // Sedikit membesar (zoom-in)
                  end: 1.0,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _getScreenContent(),
        ),
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF3366FF), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const AddTransactionBottomSheet(),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 5;
              int positionIndex = _bottomNavIndex;
              if (_bottomNavIndex >= 2) positionIndex = _bottomNavIndex + 1;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: positionIndex * tabWidth + (tabWidth / 2) - 28,
                    top: 6,
                    child: Container(
                      width: 56,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(Icons.home_filled, 'BERANDA', 0),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          Icons.analytics_outlined,
                          'LAPORAN',
                          1,
                        ),
                      ),
                      const Expanded(child: SizedBox()), // Space for FAB
                      Expanded(
                        child: _buildNavItem(
                          Icons.calendar_today_outlined,
                          'JADWAL',
                          2,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(Icons.person_outline, 'PROFIL', 3),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _getScreenContent() {
    if (_bottomNavIndex == 0) {
      return KeyedSubtree(key: const ValueKey(0), child: _buildHomeContent());
    }
    if (_bottomNavIndex == 1) {
      return KeyedSubtree(key: const ValueKey(1), child: _buildReportContent());
    }
    if (_bottomNavIndex == 2) {
      return KeyedSubtree(
        key: const ValueKey(2),
        child: _buildScheduleContent(),
      );
    }
    if (_bottomNavIndex == 3) {
      return KeyedSubtree(
        key: const ValueKey(3),
        child: _buildProfileContent(),
      );
    }
    return KeyedSubtree(
      key: const ValueKey(4),
      child: Center(child: Text('Coming Soon', style: GoogleFonts.inter())),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: const Color(0xFF3366FF),
                    fontWeight: FontWeight.bold,
                  ),
                  children: const [
                    TextSpan(text: 'My '),
                    TextSpan(
                      text: 'Wallet',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showNotificationBottomSheet(context),
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF3366FF),
                      size: 28,
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFAFAFC), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Balance Card Carousel
          Consumer2<WalletProvider, TransactionProvider>(
            builder: (context, walletProvider, trxProvider, _) {
              if (walletProvider.wallets.isEmpty) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              
              return SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: walletProvider.wallets.length + 1, // +1 for "Add Wallet"
                  onPageChanged: (index) {
                    if (index < walletProvider.wallets.length) {
                      walletProvider.setActiveWallet(walletProvider.wallets[index].walletId);
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index == walletProvider.wallets.length) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ManageWalletScreen()),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, size: 48, color: Colors.grey.shade500),
                                const SizedBox(height: 8),
                                Text('Tambah Dompet', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    
                    final wallet = walletProvider.wallets[index];
                    final balance = trxProvider.getBalanceForWallet(wallet.walletId, wallet.saldoAwal);
                    final income = trxProvider.getIncomeForWallet(wallet.walletId);
                    final expense = trxProvider.getExpenseForWallet(wallet.walletId);
                    
                    // Parse color from wallet
                    Color hexToColor(String hexString) {
                      final buffer = StringBuffer();
                      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
                      buffer.write(hexString.replaceFirst('#', ''));
                      return Color(int.parse(buffer.toString(), radix: 16));
                    }
                    
                    final walletColor = hexToColor(wallet.warna);
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [walletColor, walletColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: walletColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                wallet.namaDompet.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ManageWalletScreen(wallet: wallet)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatCompactCurrency(balance),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _buildBalancePill(
                                icon: Icons.arrow_downward,
                                iconColor: Colors.green,
                                label: 'Income',
                                amount: _formatCompactCurrency(income),
                              ),
                              const SizedBox(width: 12),
                              _buildBalancePill(
                                icon: Icons.arrow_upward,
                                iconColor: Colors.red,
                                label: 'Expense',
                                amount: _formatCompactCurrency(expense),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Budget Card
          Consumer2<TransactionProvider, UserProvider>(
            builder: (context, trxProvider, userProvider, _) {
              final batasBudget = userProvider.batasBudget;
              final terpakai = trxProvider.totalExpense;
              final percent = batasBudget > 0 ? (terpakai / batasBudget).clamp(0.0, 1.0) : 0.0;
              
              return GestureDetector(
                onTap: () => _showSetBudgetBottomSheet(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget Bulan Ini',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              batasBudget > 0 ? 'Aktif' : 'Atur',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Terpakai',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(
                                  text: '${_formatRawCurrency(terpakai)} ',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: '/ ${_formatRawCurrency(batasBudget)}',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: percent >= 0.9 ? const Color(0xFFE11D48) : const Color(0xFFF5A623),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(percent * 100).toStringAsFixed(0)}% of budget',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Color(0xFFF0F0F0)),
                      ),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          children: [
                            const TextSpan(text: 'Sisa budget: '),
                            TextSpan(
                              text: _formatRawCurrency((batasBudget - terpakai) > 0 ? batasBudget - terpakai : 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Category Filter Chips
          _buildCategoryFilterSection(),
          const SizedBox(height: 24),

          // Recent Transactions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaksi Terakhir',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllTransactionsScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Lihat Semua',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF3366FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer2<TransactionProvider, WalletProvider>(
                  builder: (context, provider, walletProvider, _) {
                    // Apply category filter and wallet filter
                    final activeWalletId = walletProvider.activeWalletId;
                    var baseTransactions = activeWalletId != null 
                        ? provider.getRecentTransactionsForWallet(activeWalletId) 
                        : provider.recentTransactions;

                    final filteredTransactions = _selectedCategoryFilter == null
                        ? baseTransactions
                        : baseTransactions.where((trx) {
                            final catName = trx.category?.namaKategori ?? 'Lainnya';
                            return catName == _selectedCategoryFilter;
                          }).toList();

                    if (filteredTransactions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            _selectedCategoryFilter != null
                                ? 'Tidak ada transaksi untuk kategori "$_selectedCategoryFilter"'
                                : 'Belum ada transaksi',
                            style: GoogleFonts.inter(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: filteredTransactions.map((trx) {
                        final isPemasukan = trx.tipeTrx == 'income';
                        // Dynamic category icon mapping
                        final cat = trx.category;
                        IconData icon;
                        Color iconColor;
                        Color bgColor;

                        if (cat != null && cat.ikon.isNotEmpty) {
                          icon = CategoryProvider.getIconData(cat.ikon);
                          iconColor = CategoryProvider.parseColor(cat.warna);
                          bgColor = CategoryProvider.parseColor(cat.warna).withOpacity(0.15);
                        } else if (isPemasukan) {
                          icon = Icons.account_balance;
                          iconColor = const Color(0xFF10B981);
                          bgColor = const Color(0xFFE1F5E9);
                        } else {
                          icon = Icons.receipt_long;
                          iconColor = const Color(0xFF7C3AED);
                          bgColor = const Color(0xFFF3E8FF);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Dismissible(
                            key: Key(trx.trxId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              final userId = context.read<UserProvider>().userId;
                              if (userId.isNotEmpty) {
                                context.read<TransactionProvider>().deleteTransaction(trx.trxId, userId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Transaksi dihapus')),
                                );
                              }
                            },
                            child: _buildTransactionItem(
                              icon: icon,
                              iconColor: iconColor,
                              bgColor: bgColor,
                              title: trx.category?.namaKategori ?? 'Lainnya',
                              catatan: trx.catatan,
                              time: DateFormat('dd MMM, HH:mm').format(trx.tanggalTrx),
                              amount: _formatTransactionAmount(trx.nominal, isPemasukan),
                              isPositive: isPemasukan,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 100), // padding for FAB
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    return Consumer2<TransactionProvider, WalletProvider>(
      builder: (context, provider, walletProvider, _) {
        final activeWalletId = walletProvider.activeWalletId;
        final transactions = activeWalletId != null 
            ? provider.transactions.where((t) => t.walletId == activeWalletId).toList()
            : provider.transactions;
            
        final reportData = _getReportData(transactions);
        final totalExpense = reportData['totalExpense'] as double;
        final categories = reportData['categories'] as List<Map<String, dynamic>>;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan Keuangan',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (activeWalletId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B5BDB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3B5BDB).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 12, color: Color(0xFF3B5BDB)),
                          const SizedBox(width: 6),
                          Text(
                            walletProvider.wallets.firstWhere((w) => w.walletId == activeWalletId).namaDompet,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B5BDB),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Period toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: ['Minggu', 'Bulan', 'Tahun'].map((period) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedReportPeriod = period;
                    _reportOffset = 0; // Reset to current period
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _selectedReportPeriod == period ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ) : null,
                    child: Center(
                      child: Text(
                        period,
                        style: GoogleFonts.inter(
                          color: _selectedReportPeriod == period ? Colors.black87 : Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: _selectedReportPeriod == period ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Period Navigation (← date range →)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _reportOffset--),
                icon: const Icon(Icons.chevron_left, color: Color(0xFF3366FF)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEef2ff),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _reportOffset = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _reportOffset == 0 ? const Color(0xFF3366FF).withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getFormattedPeriod(
                      reportData['startDate'] as DateTime,
                      reportData['endDate'] as DateTime,
                    ),
                    style: GoogleFonts.inter(
                      color: _reportOffset == 0 ? const Color(0xFF3366FF) : Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _reportOffset < 0 ? () => setState(() => _reportOffset++) : null,
                icon: Icon(Icons.chevron_right, color: _reportOffset < 0 ? const Color(0xFF3366FF) : Colors.grey.shade300),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEef2ff),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            'TOTAL PENGELUARAN',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatCompactCurrency(totalExpense),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Income vs Expense summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      _formatCompactCurrency(reportData['totalIncome'] as double),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_downward, size: 14, color: Color(0xFFE11D48)),
                    const SizedBox(width: 4),
                    Text(
                      _formatCompactCurrency(totalExpense),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE11D48),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Donut Chart Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: DonutChartPainter(categories),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          categories.isNotEmpty ? '${(categories.first['percent'] * 100).toStringAsFixed(0)}%' : '0%',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          categories.isNotEmpty ? categories.first['name'] : 'Belum Ada',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rincian per Kategori
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian per Kategori',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                if (categories.isEmpty)
                  Text(
                    'Belum ada pengeluaran di periode ini',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  )
                else
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _buildCategoryItem(
                          icon: cat['icon'] as IconData,
                          iconBgColor: cat['bgColor'] as Color,
                          iconColor: cat['iconColor'] as Color,
                          title: cat['name'] as String,
                          amount: _formatRawCurrency(cat['amount']),
                          percent: cat['percent'] as double,
                          barColor: cat['barColor'] as Color,
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Download Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                final userProvider = context.read<UserProvider>();
                final user = userProvider.currentUser;
                if (user != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mengunduh laporan PDF...')),
                  );
                  String activeWalletName = "Semua Dompet";
                  if (activeWalletId != null) {
                    final w = walletProvider.wallets.firstWhere((w) => w.walletId == activeWalletId, orElse: () => walletProvider.wallets.first);
                    activeWalletName = w.namaDompet;
                  }

                  var periodTransactions = provider.getTransactionsForPeriod(reportData['startDate'] as DateTime, reportData['endDate'] as DateTime);
                  if (activeWalletId != null) {
                    periodTransactions = periodTransactions.where((t) => t.walletId == activeWalletId).toList();
                  }

                  await ExportService.exportPDFReport(
                    user: user,
                    transactions: periodTransactions,
                    periodName: _getFormattedPeriod(reportData['startDate'] as DateTime, reportData['endDate'] as DateTime),
                    walletName: activeWalletName,
                    totalIncome: reportData['totalIncome'] as double,
                    totalExpense: totalExpense,
                    initialBalance: provider.getInitialBalanceBefore(reportData['startDate'] as DateTime, walletId: activeWalletId),
                    currencySymbol: userProvider.currency == 'IDR' ? 'Rp ' : '${userProvider.currency} ',
                    currencyConverter: userProvider.convert,
                  );
                }
              },
              icon: const Icon(
                Icons.file_download_outlined,
                color: Color(0xFF3366FF),
              ),
              label: Text(
                'Download Laporan PDF',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3366FF),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100), // padding for FAB
        ],
      ),
    );
    });
  }

  Widget _buildCategoryItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String amount,
    required double percent,
    required Color barColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(percent * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalancePill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String amount,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amount,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: format currency with compact notation for large numbers
  String _formatCompactCurrency(double amount) {
    final provider = context.read<UserProvider>();
    amount = provider.convert(amount);
    String symbol = provider.currency == 'IDR' ? 'Rp ' : '${provider.currency} ';
    String prefix = amount < 0 ? '-' : '';
    double absAmount = amount.abs();
    
    if (!provider.showCompactNumbers) {
      return '$prefix$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(absAmount)}';
    }
    
    if (absAmount >= 1000000000000) {
      return '$prefix$symbol${(absAmount / 1000000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}T';
    } else if (absAmount >= 1000000000) {
      return '$prefix$symbol${(absAmount / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (absAmount >= 1000000) {
      return '$prefix$symbol${(absAmount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}JT';
    } else {
      return '$prefix$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(absAmount)}';
    }
  }

  // Helper: format transaction amount with overflow protection
  String _formatTransactionAmount(double nominal, bool isIncome) {
    final provider = context.read<UserProvider>();
    nominal = provider.convert(nominal);
    String symbol = provider.currency == 'IDR' ? 'Rp ' : '${provider.currency} ';
    String prefix = isIncome ? '+' : '-';
    double absAmount = nominal.abs();
    
    if (!provider.showCompactNumbers) {
      return '$prefix$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(absAmount)}';
    }
    
    if (absAmount >= 1000000000) { // >= 1 Milyar
      return '$prefix$symbol${(absAmount / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (absAmount >= 1000000) { // >= 1 Juta
      return '$prefix$symbol${(absAmount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}JT';
    } else {
      return '$prefix$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(absAmount)}';
    }
  }

  // Helper: format plain currency without compacting
  String _formatRawCurrency(double amount) {
    final provider = context.read<UserProvider>();
    amount = provider.convert(amount);
    String symbol = provider.currency == 'IDR' ? 'Rp ' : '${provider.currency} ';
    return '$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(amount)}';
  }

  // Category filter section with chips
  Widget _buildCategoryFilterSection() {
    final filterItems = [
      {'icon': Icons.swap_horiz, 'color': const Color(0xFF3366FF), 'bg': const Color(0xFFEef2ff), 'label': 'Transfer Masuk', 'display': 'Transfer'},
      {'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFFF3E8FF), 'label': 'Tagihan', 'display': 'Tagihan'},
      {'icon': Icons.savings_outlined, 'color': const Color(0xFF10B981), 'bg': const Color(0xFFE1F5E9), 'label': 'Gaji', 'display': 'Nabung'},
      {'icon': Icons.more_horiz, 'color': Colors.grey.shade700, 'bg': Colors.grey.shade100, 'label': '_lainnya', 'display': 'Lainnya'},
    ];

    return Column(
      children: [
        Row(
          children: [
            ...filterItems.take(2).map((item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: filterItems.indexOf(item) == 0 ? 8 : 0,
                  left: filterItems.indexOf(item) == 1 ? 8 : 0,
                ),
                child: _buildFilterChip(
                  icon: item['icon'] as IconData,
                  iconColor: item['color'] as Color,
                  bgColor: item['bg'] as Color,
                  label: item['display'] as String,
                  filterKey: item['label'] as String,
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ...filterItems.skip(2).map((item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item['label'] == 'Gaji' ? 8 : 0,
                  left: item['label'] == '_lainnya' ? 8 : 0,
                ),
                child: _buildFilterChip(
                  icon: item['icon'] as IconData,
                  iconColor: item['color'] as Color,
                  bgColor: item['bg'] as Color,
                  label: item['display'] as String,
                  filterKey: item['label'] as String,
                ),
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String filterKey,
  }) {
    final isActive = _selectedCategoryFilter == filterKey;
    return GestureDetector(
      onTap: () {
        if (filterKey == '_lainnya') {
          _showAllCategoriesFilter(context);
        } else {
          setState(() {
            _selectedCategoryFilter = isActive ? null : filterKey;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? iconColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: iconColor.withOpacity(0.4), width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? iconColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCategoriesFilter(BuildContext context) {
    final catProvider = context.read<CategoryProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Kategori', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_selectedCategoryFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedCategoryFilter = null);
                      Navigator.pop(ctx);
                    },
                    child: Text('Reset', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: catProvider.categories.map((cat) {
                final isActive = _selectedCategoryFilter == cat.namaKategori;
                final catColor = CategoryProvider.parseColor(cat.warna);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryFilter = isActive ? null : cat.namaKategori;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? catColor.withOpacity(0.15) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive ? Border.all(color: catColor, width: 1.5) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CategoryProvider.getIconData(cat.ikon), size: 16, color: catColor),
                        const SizedBox(width: 6),
                        Text(
                          cat.namaKategori,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? catColor : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    String? catatan,
    required String time,
    required String amount,
    required bool isPositive,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (catatan != null && catatan.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  catatan,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 0,
          child: Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF10B981) : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomNavIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey.shade400,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent() {
    final List<DateTime> calendarDays = [];
    final firstDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0);

    // Weekday is 1-7 (Mon-Sun). We want Sun-Sat (0-6).
    int firstWeekday = firstDayOfMonth.weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday;

    // Add previous month days
    for (int i = 0; i < offset; i++) {
      calendarDays.add(firstDayOfMonth.subtract(Duration(days: offset - i)));
    }
    // Add current month days
    for (int i = 0; i < lastDayOfMonth.day; i++) {
      calendarDays.add(DateTime(firstDayOfMonth.year, firstDayOfMonth.month, i + 1));
    }
    // Add next month days to complete the grid (42 cells)
    int remainingCells = 42 - calendarDays.length;
    for (int i = 0; i < remainingCells; i++) {
      calendarDays.add(lastDayOfMonth.add(Duration(days: i + 1)));
    }

    final List<String> daysOfWeek = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kalender & Jadwal',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Calendar Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Month Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy', 'id').format(_currentCalendarMonth),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month - 1, 1);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 1);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Days of week
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: daysOfWeek
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Calendar Grid
                Consumer<ScheduleProvider>(
                  builder: (context, provider, _) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.85,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: calendarDays.length,
                      itemBuilder: (context, index) {
                        final date = calendarDays[index];
                        final isCurrentMonth = date.month == _currentCalendarMonth.month;
                        final isSelected = date.year == _selectedCalendarDate.year && date.month == _selectedCalendarDate.month && date.day == _selectedCalendarDate.day;
                        
                        // Check if there are any schedules on this date
                        final hasEvent = provider.schedules.any((s) => s.tanggalJatuhTempo.year == date.year && s.tanggalJatuhTempo.month == date.month && s.tanggalJatuhTempo.day == date.day);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCalendarDate = date;
                              _currentCalendarMonth = DateTime(date.year, date.month, 1);
                            });
                            _showScheduleDetailsForDate(context, date, provider);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF3366FF)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    date.day.toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : isCurrentMonth
                                          ? Colors.black87
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                              if (hasEvent)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8B5CF6),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else
                                const SizedBox(height: 6),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Jadwal Mendatang',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Consumer<ScheduleProvider>(
            builder: (context, provider, _) {
              if (provider.schedules.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Belum ada jadwal',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                );
              }
              return Column(
                children: provider.schedules.map((schedule) {
                  // Dynamic category mapping
                  final cat = schedule.category;
                  IconData icon;
                  Color iconColor;
                  Color iconBgColor;

                  if (cat != null && cat.ikon.isNotEmpty) {
                    icon = CategoryProvider.getIconData(cat.ikon);
                    iconColor = CategoryProvider.parseColor(cat.warna);
                    iconBgColor = CategoryProvider.parseColor(cat.warna).withOpacity(0.15);
                  } else {
                    icon = Icons.receipt_long;
                    iconColor = const Color(0xFF8B5CF6);
                    iconBgColor = const Color(0xFFF3E8FF);
                  }

                  // Countdown logic
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final target = DateTime(schedule.tanggalJatuhTempo.year, schedule.tanggalJatuhTempo.month, schedule.tanggalJatuhTempo.day);
                  final difference = target.difference(today).inDays;
                  
                  String countdownText;
                  Color countdownColor;
                  if (difference < 0) {
                    countdownText = 'Terlewat ${-difference} hari';
                    countdownColor = const Color(0xFFE11D48);
                  } else if (difference == 0) {
                    countdownText = 'Hari Ini';
                    countdownColor = const Color(0xFF10B981);
                  } else if (difference == 1) {
                    countdownText = 'Besok';
                    countdownColor = const Color(0xFFF59E0B);
                  } else {
                    countdownText = 'H-$difference';
                    countdownColor = Colors.grey.shade600;
                  }

                  // Amount formatting based on income/expense
                  final isIncome = cat?.tipe == 'income';
                  final amountPrefix = isIncome ? '+' : '-';
                  final amountColor = isIncome ? const Color(0xFF10B981) : Colors.black87;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildScheduleItem(
                      schedule: schedule,
                      icon: icon,
                      iconColor: iconColor,
                      iconBgColor: iconBgColor,
                      title: schedule.namaTagihan,
                      date: DateFormat('dd MMM yyyy').format(schedule.tanggalJatuhTempo),
                      amount: '$amountPrefix${_formatCompactCurrency(schedule.nominal)}',
                      amountColor: amountColor,
                      countdownText: countdownText,
                      countdownColor: countdownColor,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddScheduleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: Text(
                'Tambah Jadwal Baru',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 100), // padding for FAB
        ],
      ),
    );
  }

  Widget _buildScheduleItem({
    required ScheduleModel schedule,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String date,
    required String amount,
    Color amountColor = Colors.black87,
    String? countdownText,
    Color countdownColor = Colors.grey,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (countdownText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: countdownColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          countdownText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: countdownColor,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black45, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddScheduleScreen(existingSchedule: schedule),
                  ),
                );
              } else if (value == 'delete') {
                final userId = context.read<UserProvider>().userId;
                context.read<ScheduleProvider>().deleteSchedule(schedule.jadwalId, userId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showScheduleDetailsForDate(BuildContext context, DateTime date, ScheduleProvider provider) {
    final schedulesForDate = provider.schedules.where((s) => s.tanggalJatuhTempo.year == date.year && s.tanggalJatuhTempo.month == date.month && s.tanggalJatuhTempo.day == date.day).toList();
    
    if (schedulesForDate.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Jadwal: ${DateFormat('dd MMMM yyyy', 'id').format(date)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...schedulesForDate.map((schedule) {
              final cat = schedule.category;
              IconData icon = Icons.receipt_long;
              Color iconColor = const Color(0xFF8B5CF6);
              Color iconBgColor = const Color(0xFFF3E8FF);

              if (cat != null && cat.ikon.isNotEmpty) {
                icon = CategoryProvider.getIconData(cat.ikon);
                iconColor = CategoryProvider.parseColor(cat.warna);
                iconBgColor = CategoryProvider.parseColor(cat.warna).withOpacity(0.15);
              }

              final isIncome = cat?.tipe == 'income';
              final amountPrefix = isIncome ? '+' : '-';
              final amountColor = isIncome ? const Color(0xFF10B981) : Colors.black87;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildScheduleItem(
                  schedule: schedule,
                  icon: icon,
                  iconColor: iconColor,
                  iconBgColor: iconBgColor,
                  title: schedule.namaTagihan,
                  date: DateFormat('HH:mm').format(schedule.tanggalJatuhTempo),
                  amount: '$amountPrefix${_formatCompactCurrency(schedule.nominal)}',
                  amountColor: amountColor,
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // App Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      final fotoProfil = userProvider.currentUser?.fotoProfil;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          image: fotoProfil != null
                              ? DecorationImage(
                                  image: FileImage(File(fotoProfil)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: fotoProfil == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Consumer<UserProvider>(
                    builder: (context, userProvider, _) => Text(
                      userProvider.currentUser?.namaLengkap ?? 'My Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5A44F3),
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showNotificationBottomSheet(context),
                child: const Icon(Icons.notifications_none, color: Color(0xFF3366FF)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Pengaturan',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // Profile Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) {
                        final fotoProfil = userProvider.currentUser?.fotoProfil;
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            image: fotoProfil != null
                                ? DecorationImage(
                                    image: FileImage(File(fotoProfil)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: fotoProfil == null
                              ? const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3366FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<UserProvider>(
                        builder: (context, userProvider, _) => Text(
                          userProvider.currentUser?.namaLengkap ?? 'Pengguna My Wallet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<UserProvider>(
                        builder: (context, userProvider, _) => Text(
                          userProvider.currentUser?.email ?? 'pengguna@fintrack.id',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Edit Profil',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3366FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('KEUANGAN'),
          _buildSettingsCard(
            children: [
              Consumer<UserProvider>(
                builder: (context, userProvider, _) => GestureDetector(
                  onTap: () => _showSetBudgetBottomSheet(context),
                  child: _buildSettingsItem(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF3366FF),
                    title: 'Batas Pengeluaran\nBulanan',
                    trailingValue: '${userProvider.currency}\n${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(userProvider.convert(userProvider.batasBudget))}',
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              Consumer<UserProvider>(
                builder: (context, userProvider, _) => GestureDetector(
                  onTap: () => _showCurrencyBottomSheet(context),
                  child: _buildSettingsItem(
                    icon: Icons.monetization_on_outlined,
                    iconColor: const Color(0xFF3366FF),
                    title: 'Mata Uang',
                    trailingValue: userProvider.currency,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              Consumer<UserProvider>(
                builder: (context, userProvider, _) => _buildSettingsItem(
                  icon: Icons.sync_alt_outlined,
                  iconColor: const Color(0xFF3366FF),
                  title: 'Live Conversion Kurs',
                  trailingWidget: Switch(
                    value: userProvider.useLiveConversion,
                    onChanged: (val) => userProvider.toggleLiveConversion(val),
                    activeColor: const Color(0xFF3366FF),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              Consumer<UserProvider>(
                builder: (context, userProvider, _) => _buildSettingsItem(
                  icon: Icons.numbers_outlined,
                  iconColor: const Color(0xFF3366FF),
                  title: 'Singkat Angka (JT/M)',
                  trailingWidget: Switch(
                    value: userProvider.showCompactNumbers,
                    onChanged: (val) => userProvider.toggleCompactNumbers(val),
                    activeColor: const Color(0xFF3366FF),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('KATEGORI'),
          _buildSettingsCard(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageCategoryScreen()),
                  );
                },
                child: _buildSettingsItem(
                  icon: Icons.category_outlined,
                  iconColor: const Color(0xFF3366FF),
                  title: 'Kelola Kategori',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('NOTIFIKASI'),
          _buildSettingsCard(
            children: [
              _buildSettingsItem(
                icon: Icons.notifications_active_outlined,
                iconColor: const Color(0xFF3366FF),
                title: 'Pengingat Jadwal',
                trailingWidget: Switch(
                  value: _isNotificationEnabled,
                  onChanged: (val) => _toggleNotification(val),
                  activeColor: const Color(0xFF3366FF),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              Consumer<UserProvider>(
                builder: (context, userProvider, _) => GestureDetector(
                  onTap: () async {
                    final parts = userProvider.reminderTime.split(':');
                    final initialTime = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 8,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                    
                    final TimeOfDay? newTime = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );
                    
                    if (newTime != null) {
                      final timeStr = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
                      await userProvider.updateReminderTime(timeStr);
                      // Reschedule notifications based on new time
                      if (context.mounted) {
                        await context.read<ScheduleProvider>().loadSchedules(userProvider.userId);
                      }
                    }
                  },
                  child: _buildSettingsItem(
                    icon: Icons.access_time,
                    iconColor: const Color(0xFF3366FF),
                    title: 'Waktu Pengingat',
                    trailingValue: userProvider.reminderTime,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('DATA'),
          _buildSettingsCard(
            children: [
              GestureDetector(
                onTap: () => _exportData(context),
                child: _buildSettingsItem(
                  icon: Icons.file_download_outlined,
                  iconColor: const Color(0xFF3366FF),
                  title: 'Export Semua Data',
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              GestureDetector(
                onTap: () => _confirmDeleteAllData(context),
                child: _buildSettingsItem(
                  icon: Icons.delete_sweep_outlined,
                  iconColor: const Color(0xFFE11D48),
                  title: 'Hapus Semua Data',
                  titleColor: const Color(0xFFE11D48),
                  hideChevron: true,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              GestureDetector(
                onTap: () => _confirmDeleteAccount(context),
                child: _buildSettingsItem(
                  icon: Icons.person_remove_outlined,
                  iconColor: const Color(0xFFE11D48),
                  title: 'Hapus Akun',
                  titleColor: const Color(0xFFE11D48),
                  hideChevron: true,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              GestureDetector(
                onTap: () {
                  context.read<UserProvider>().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: _buildSettingsItem(
                  icon: Icons.logout,
                  iconColor: const Color(0xFFE11D48),
                  title: 'Logout',
                  titleColor: const Color(0xFFE11D48),
                  hideChevron: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showCurrencyBottomSheet(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final currencies = ['IDR', 'USD', 'EUR', 'SGD', 'JPY'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Mata Uang',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...currencies.map((curr) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(
                    curr,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: userProvider.currency == curr ? FontWeight.bold : FontWeight.normal,
                      color: userProvider.currency == curr ? const Color(0xFF3366FF) : Colors.black87,
                    ),
                  ),
                  trailing: userProvider.currency == curr
                      ? const Icon(Icons.check_circle, color: Color(0xFF3366FF))
                      : null,
                  onTap: () {
                    userProvider.updateCurrency(curr);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showInitialBalanceBottomSheet(BuildContext context) {
    final amountController = TextEditingController();
    final userProvider = context.read<UserProvider>();
    final currencySymbol = userProvider.currency == 'IDR' ? 'Rp ' : '${userProvider.currency} ';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atur Saldo Awal',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15), // Max 15 digits (quadrillion)
                ],
                decoration: InputDecoration(
                  labelText: 'Nominal Saldo',
                  prefixText: currencySymbol,
                  helperText: 'Maksimal 15 digit',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount > 0) {
                      final userId = context.read<UserProvider>().userId;
                      context.read<TransactionProvider>().addTransaction(
                        userId: userId,
                        tipeTrx: 'income',
                        kategoriId: 9, // using Gaji category approx
                        nominal: amount,
                        tanggalTrx: DateTime.now(),
                        catatan: 'Saldo Awal',
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Simpan Saldo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetBudgetBottomSheet(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atur Batas Pengeluaran',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal Budget',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount > 0) {
                      context.read<UserProvider>().updateBudget(amount);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Simpan Budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    String? trailingValue,
    Widget? trailingWidget,
    bool hideChevron = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: titleColor ?? Colors.black87,
              ),
            ),
          ),
          if (trailingValue != null) ...[
            Text(
              trailingValue,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (trailingWidget != null) ...[
            trailingWidget,
          ] else if (!hideChevron) ...[
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ],
      ),
    );
  }

  void _showNotificationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Notifikasi',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada notifikasi',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final transactions = provider.transactions;
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport')),
      );
      return;
    }
    
    await ExportService.exportTransactionsCSV(transactions);
  }

  void _confirmDeleteAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Semua Data?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus seluruh data transaksi dan jadwal? Akun Anda akan tetap ada.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await context.read<UserProvider>().deleteAllData();
              if (context.mounted) {
                // Refresh data providers
                context.read<TransactionProvider>().loadTransactions(context.read<UserProvider>().userId);
                context.read<ScheduleProvider>().loadSchedules(context.read<UserProvider>().userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus Data', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Akun?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus akun Anda dan seluruh data secara permanen? Data tidak dapat dikembalikan.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await context.read<UserProvider>().deleteAccount();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Donut Chart
class DonutChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;

  DonutChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    const strokeWidth = 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (categories.isEmpty) {
      paint.color = Colors.grey.shade200;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi / 2,
        2 * pi,
        false,
        paint,
      );
      return;
    }

    double startAngle = -pi / 2; // Start from top

    for (var cat in categories) {
      final sweepAngle = (cat['percent'] as double) * 2 * pi;
      paint.color = cat['barColor'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => true;
}
