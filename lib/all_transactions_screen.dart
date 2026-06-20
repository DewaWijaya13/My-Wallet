import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';
import 'providers/category_provider.dart';

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Semua Transaksi',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.transactions.isEmpty) {
            return Center(
              child: Text(
                'Belum ada transaksi',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: provider.transactions.length,
            itemBuilder: (context, index) {
              final trx = provider.transactions[index];
              final isPemasukan = trx.tipeTrx == 'income';
              
              IconData icon;
              Color iconColor;
              Color bgColor;

              final cat = trx.category;
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

              return Dismissible(
                key: Key(trx.trxId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (direction) {
                  final userId = context.read<UserProvider>().userId;
                  if (userId != null) {
                    context.read<TransactionProvider>().deleteTransaction(trx.trxId, userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaksi dihapus')),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
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
                              trx.category?.namaKategori ?? 'Lainnya',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (trx.catatan != null && trx.catatan!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                trx.catatan!,
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
                              DateFormat('dd MMM yyyy, HH:mm').format(trx.tanggalTrx),
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
                        child: Consumer<UserProvider>(
                          builder: (context, userProvider, _) {
                            final nominal = userProvider.convert(trx.nominal);
                            final symbol = userProvider.currency == 'IDR' ? 'Rp ' : '${userProvider.currency} ';
                            return Text(
                              '${isPemasukan ? '+' : '-'}$symbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(nominal)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isPemasukan ? const Color(0xFF10B981) : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
