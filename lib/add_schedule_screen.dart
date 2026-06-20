import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'providers/schedule_provider.dart';
import 'providers/user_provider.dart';
import 'providers/category_provider.dart';
import 'models/schedule.dart';

class AddScheduleScreen extends StatefulWidget {
  final ScheduleModel? existingSchedule;
  const AddScheduleScreen({super.key, this.existingSchedule});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  bool _isReminderOn = true;
  bool _isH1On = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      final s = widget.existingSchedule!;
      final formatter = NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0);
      _amountController.text = formatter.format(s.nominal);
      _titleController.text = s.namaTagihan;
      _notesController.text = s.catatan ?? '';
      _selectedDate = s.tanggalJatuhTempo;
      _isReminderOn = s.isReminderActive;
      _isH1On = s.isH1Active;
      _selectedCategoryId = s.kategoriId;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF3366FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingSchedule != null ? 'Ubah Jadwal' : 'Tambah Jadwal',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: const Color(0xFF3366FF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'NOMINAL',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rp',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      NumberTextInputFormatter(),
                    ],
                    style: GoogleFonts.inter(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -1.0,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Form Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
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
                  _buildFormLabel('NAMA JADWAL'),
                  _buildInputField(
                    icon: Icons.insert_drive_file_outlined,
                    controller: _titleController,
                    hint: 'Misal: Bayar Listrik',
                  ),
                  const SizedBox(height: 20),

                  _buildFormLabel('DESKRIPSI (OPSIONAL)'),
                  _buildInputField(
                    icon: Icons.notes_outlined,
                    controller: _notesController,
                    hint: 'Tambahkan catatan...',
                  ),
                  const SizedBox(height: 20),

                  _buildFormLabel('TANGGAL'),
                  _buildDatePickerField(),
                  const SizedBox(height: 20),

                  _buildFormLabel('KATEGORI'),
                  Consumer<CategoryProvider>(
                    builder: (context, catProvider, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: catProvider.categories.map((cat) {
                          return _buildCategoryChip(
                            CategoryProvider.getIconData(cat.ikon),
                            cat.namaKategori,
                            cat.kategoriId!,
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Reminder Toggle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengingat',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Consumer<UserProvider>(
                              builder: (context, userProvider, _) {
                                if (!userProvider.isNotificationEnabled) {
                                  return Text(
                                    'Nonaktif (aktifkan di Profil > Pengingat Jadwal)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFFE11D48),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }
                                if (_isReminderOn) {
                                  if (_isH1On) {
                                    return Text(
                                      'H-1 sebelum tanggal jatuh tempo pukul ${userProvider.reminderTime}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  } else {
                                    return Text(
                                      'Pada tanggal jatuh tempo pukul ${userProvider.reminderTime}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  }
                                } else {
                                  return Text(
                                    'Pengingat tidak aktif',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: context.watch<UserProvider>().isNotificationEnabled ? _isReminderOn : false,
                        onChanged: context.watch<UserProvider>().isNotificationEnabled
                            ? (val) {
                                setState(() {
                                  _isReminderOn = val;
                                });
                              }
                            : null,
                        activeColor: const Color(0xFF3366FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // H-1 Toggle Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (context.watch<UserProvider>().isNotificationEnabled && _isReminderOn)
                              ? const Color(0xFFE0F2FE)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_toggle_off_outlined,
                          color: (context.watch<UserProvider>().isNotificationEnabled && _isReminderOn)
                              ? const Color(0xFF0284C7)
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengingat H-1',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: (context.watch<UserProvider>().isNotificationEnabled && _isReminderOn)
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !context.watch<UserProvider>().isNotificationEnabled
                                  ? 'Pengingat jadwal tidak aktif secara global'
                                  : !_isReminderOn
                                      ? 'Pengingat jadwal tidak aktif'
                                      : _isH1On
                                          ? 'Diingatkan sehari sebelum tanggal jatuh tempo'
                                          : 'Diingatkan tepat pada tanggal jatuh tempo',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: (context.watch<UserProvider>().isNotificationEnabled && _isReminderOn) ? _isH1On : false,
                        onChanged: (context.watch<UserProvider>().isNotificationEnabled && _isReminderOn)
                            ? (val) {
                                setState(() {
                                  _isH1On = val;
                                });
                              }
                            : null,
                        activeColor: const Color(0xFF3366FF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3366FF), Color(0xFF8B5CF6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    final amountText = _amountController.text.replaceAll('.', '');
                    final amountVal = double.tryParse(amountText) ?? 0;
                    final title = _titleController.text.trim();
                    final notes = _notesController.text.trim();
                    if (amountVal <= 0 || title.isEmpty) return;

                    if (_selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
                      );
                      return;
                    }

                    final userId = context.read<UserProvider>().userId;
                    if (userId != null) {
                      if (widget.existingSchedule != null) {
                        final updated = widget.existingSchedule!;
                        updated.namaTagihan = title;
                        updated.kategoriId = _selectedCategoryId!;
                        updated.tanggalJatuhTempo = _selectedDate;
                        updated.isReminderActive = _isReminderOn;
                        updated.isH1Active = _isH1On;
                        updated.nominal = amountVal;
                        updated.catatan = notes;
                        context.read<ScheduleProvider>().updateSchedule(updated, userId).then((_) {
                          if (context.mounted) {
                            context.read<UserProvider>().checkUnreadNotifications();
                            Navigator.pop(context);
                          }
                        });
                      } else {
                        context.read<ScheduleProvider>().addSchedule(
                          userId: userId,
                          namaTagihan: title,
                          kategoriId: _selectedCategoryId!,
                          tanggalJatuhTempo: _selectedDate,
                          isReminderActive: _isReminderOn,
                          isH1Active: _isH1On,
                          nominal: amountVal,
                          catatan: notes,
                        ).then((_) {
                          if (context.mounted) {
                            context.read<UserProvider>().checkUnreadNotifications();
                            Navigator.pop(context);
                          }
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    widget.existingSchedule != null ? 'UBAH JADWAL' : 'SIMPAN JADWAL',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    TextEditingController? controller,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black54, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: Colors.black54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(IconData icon, String label, int categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = categoryId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE0E7FF)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF3366FF) : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF3366FF) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final int selectionIndexFromRight = newValue.text.length - newValue.selection.end;
    
    // Remove all non-digits
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    
    final int value = int.parse(text);
    final String newText = NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: newText.length - selectionIndexFromRight,
      ),
    );
  }
}
