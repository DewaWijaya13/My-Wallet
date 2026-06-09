import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class ExportService {
  // Export CSV
  static Future<void> exportTransactionsCSV(List<TransactionModel> transactions) async {
    List<List<dynamic>> rows = [];
    rows.add(["ID Transaksi", "Nominal", "Tipe", "Kategori ID", "Tanggal", "Catatan"]);
    
    for (var tx in transactions) {
      rows.add([
        tx.trxId,
        tx.nominal,
        tx.tipeTrx,
        tx.kategoriId,
        tx.tanggalTrx.toIso8601String(),
        tx.catatan ?? '',
      ]);
    }

    StringBuffer sb = StringBuffer();
    for (var row in rows) {
      sb.writeln(row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
    }
    String csvStr = sb.toString();
    
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/my_wallet_data.csv');
    await file.writeAsString(csvStr);

    await Share.shareXFiles([XFile(file.path)], text: 'Export Data My Wallet');
  }

  // Export PDF Report
  static Future<void> exportPDFReport({
    required UserModel user,
    required List<TransactionModel> transactions,
    required String periodName,
    required String walletName,
    required double totalIncome,
    required double totalExpense,
    required double initialBalance,
    required String currencySymbol,
    required double Function(double) currencyConverter,
  }) async {
    final pdf = pw.Document();

    String formatCurrency(double amount) {
      final converted = currencyConverter(amount);
      return '$currencySymbol${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(converted)}';
    }

    final double endingBalance = initialBalance + totalIncome - totalExpense;

    final totalTransactions = transactions.length;
    
    // Most frequent category (expense only)
    final expenseTransactions = transactions.where((t) => t.tipeTrx == 'expense').toList();
    final Map<String, double> categorySums = {};
    for (var t in expenseTransactions) {
      final cat = t.category?.namaKategori ?? 'Lainnya';
      categorySums[cat] = (categorySums[cat] ?? 0) + t.nominal;
    }
    String topCategory = '-';
    double topCategoryAmount = 0;
    categorySums.forEach((cat, amount) {
      if (amount > topCategoryAmount) {
        topCategoryAmount = amount;
        topCategory = cat;
      }
    });

    // Date with most transactions
    final Map<String, int> dateCounts = {};
    for (var t in transactions) {
      final dateStr = DateFormat('dd MMM yyyy').format(t.tanggalTrx);
      dateCounts[dateStr] = (dateCounts[dateStr] ?? 0) + 1;
    }
    String topDate = '-';
    int topDateCount = 0;
    dateCounts.forEach((date, count) {
      if (count > topDateCount) {
        topDateCount = count;
        topDate = date;
      }
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header: Company / App Name
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MY WALLET INC.', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                    pw.Text('Personal Financial Statement', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Statement of Cash Flows', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                    pw.Text('For the Period: $periodName', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ]
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            
            // Client Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prepared For:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(user.namaLengkap, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(user.email, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated On:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(DateFormat('dd MMMM yyyy').format(DateTime.now()), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Wallet:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(walletName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Statistics Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Trx', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('$totalTransactions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Top Category', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(topCategory, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                    ]
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Busiest Day', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('$topDate ($topDateCount trx)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 32),

            // Financial Summary (Balancing)
            pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Beginning Balance', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(formatCurrency(initialBalance), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cash Inflows (Income)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.green700)),
                      pw.Text(formatCurrency(totalIncome), style: pw.TextStyle(fontSize: 12, color: PdfColors.green700)),
                    ]
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Cash Outflows (Expense)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.red700)),
                      pw.Text('(${formatCurrency(totalExpense)})', style: pw.TextStyle(fontSize: 12, color: PdfColors.red700)),
                    ]
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Ending Balance', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(formatCurrency(endingBalance), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 32),
            
            // Details Table
            pw.Text('Transaction Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              data: <List<String>>[
                <String>['Date', 'Ref ID', 'Description', 'Category', 'Type', 'Amount'],
                ...transactions.map((tx) => [
                  DateFormat('dd-MMM-yyyy').format(tx.tanggalTrx),
                  tx.trxId.substring(0, 8),
                  tx.catatan ?? '-',
                  tx.kategoriId.toString(), // Ideally joined with category name
                  tx.tipeTrx == 'income' ? 'Inflow' : 'Outflow',
                  tx.tipeTrx == 'income' ? formatCurrency(tx.nominal) : '(${formatCurrency(tx.nominal)})',
                ])
              ],
            ),

            pw.SizedBox(height: 48),
            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 10)),
                  ]
                )
              ]
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Financial_Statement_${periodName.replaceAll(' ', '_')}.pdf');
  }
}
