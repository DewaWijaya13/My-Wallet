import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'providers/wallet_provider.dart';
import 'models/wallet.dart';

class ManageWalletScreen extends StatefulWidget {
  final WalletModel? wallet;
  final bool isInitial;

  const ManageWalletScreen({super.key, this.wallet, this.isInitial = false});

  @override
  State<ManageWalletScreen> createState() => _ManageWalletScreenState();
}

class _ManageWalletScreenState extends State<ManageWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _deskripsiController;
  late TextEditingController _saldoController;

  String _selectedIcon = 'account_balance_wallet';
  String _selectedColor = '#3366FF';
  bool _isLoading = false;

  final List<Map<String, String>> _availableIcons = [
    {'icon': 'account_balance_wallet', 'label': 'Dompet'},
    {'icon': 'account_balance', 'label': 'Bank'},
    {'icon': 'credit_card', 'label': 'Kartu'},
    {'icon': 'savings', 'label': 'Tabungan'},
  ];

  final List<String> _availableColors = [
    '#3366FF', // Blue
    '#10B981', // Green
    '#F59E0B', // Orange
    '#8B5CF6', // Purple
    '#EF4444', // Red
    '#000000', // Black
  ];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.wallet?.namaDompet ?? '');
    _deskripsiController = TextEditingController(text: widget.wallet?.deskripsi ?? '');
    _saldoController = TextEditingController(
      text: widget.wallet?.saldoAwal.toInt().toString() ?? '0'
    );
    if (widget.wallet != null) {
      _selectedIcon = widget.wallet!.ikon;
      _selectedColor = widget.wallet!.warna;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'account_balance': return Icons.account_balance;
      case 'credit_card': return Icons.credit_card;
      case 'savings': return Icons.savings;
      default: return Icons.account_balance_wallet;
    }
  }

  Color _getColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Future<void> _saveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final userId = context.read<UserProvider>().userId;
    final provider = context.read<WalletProvider>();
    final saldo = double.tryParse(_saldoController.text) ?? 0.0;

    bool success;
    if (widget.wallet == null) {
      success = await provider.createWallet(
        userId: userId,
        namaDompet: _namaController.text,
        deskripsi: _deskripsiController.text,
        warna: _selectedColor,
        ikon: _selectedIcon,
        saldoAwal: saldo,
      );
    } else {
      final updated = WalletModel(
        walletId: widget.wallet!.walletId,
        userId: userId,
        namaDompet: _namaController.text,
        deskripsi: _deskripsiController.text,
        warna: _selectedColor,
        ikon: _selectedIcon,
        saldoAwal: saldo,
        tanggalDibuat: widget.wallet!.tanggalDibuat,
      );
      success = await provider.updateWallet(updated);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        if (widget.isInitial) {
          Navigator.pop(context); // Go back to dashboard
        } else {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan dompet.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isInitial ? const SizedBox() : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.wallet == null ? (widget.isInitial ? 'Buat Dompet Pertamamu' : 'Tambah Dompet') : 'Edit Dompet',
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isInitial)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Halo! Untuk mulai mengatur keuangan, mari buat dompet pertama kamu. Kamu bisa menamainya "Dompet Pribadi", "Rekening BCA", dll.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
              Text('Nama Dompet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  hintText: 'Cth: Dompet Utama',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Nama dompet wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              Text('Deskripsi (Opsional)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                decoration: InputDecoration(
                  hintText: 'Cth: Rekening BCA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Text('Saldo Awal', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _saldoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Cth: 1000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 20),
              Text('Ikon Dompet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _availableIcons.map((iconData) {
                  final isSelected = _selectedIcon == iconData['icon'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconData['icon']!),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _getColor(_selectedColor).withOpacity(0.1) : Colors.grey.shade100,
                        border: Border.all(
                          color: isSelected ? _getColor(_selectedColor) : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconData(iconData['icon']!),
                        color: isSelected ? _getColor(_selectedColor) : Colors.grey.shade600,
                        size: 32,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Warna Dompet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _availableColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColor(colorHex),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.grey.shade800, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Simpan Dompet',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
