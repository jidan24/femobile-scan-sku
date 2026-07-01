import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sheets_service.dart';
import '../services/storage_service.dart';
import '../models/spreadsheet_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SheetsService _sheets = SheetsService();
  final StorageService _storage = StorageService();

  List<SpreadsheetConfig> _spreadsheets = [];

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _appsScriptUrlController = TextEditingController();
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpreadsheets();
    _loadAppsScriptUrl();
  }

  Future<void> _loadAppsScriptUrl() async {
    final url = await _storage.getAppsScriptUrl();
    if (url != null) {
      _appsScriptUrlController.text = url;
    }
  }

  Future<void> _saveAppsScriptUrl() async {
    final url = _appsScriptUrlController.text.trim();
    await _storage.setAppsScriptUrl(url);
    _showSuccess('URL Apps Script berhasil disimpan!');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _appsScriptUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSpreadsheets() async {
    final sheets = await _storage.getSpreadsheets();
    if (mounted) {
      setState(() {
        _spreadsheets = sheets;
      });
    }
  }

  String? _extractId(String url) {
    // Ekstrak ID dari format: https://docs.google.com/spreadsheets/d/ID_SPREADSHEET/edit
    final regex = RegExp(r'/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  Future<void> _connectUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final id = _extractId(url);
    if (id == null) {
      setState(() => _error = 'URL tidak valid. Pastikan copy URL utuh dari Google Sheets.');
      return;
    }

    if (_spreadsheets.any((s) => s.id == id)) {
       setState(() => _error = 'Spreadsheet ini sudah ada di daftar.');
       return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      // Verifikasi akses
      final title = await _sheets.verifySpreadsheet(id);
      final cleanUrl = 'https://docs.google.com/spreadsheets/d/$id';
      // Ambil tabs
      List<String> tabs = [];
      try {
        tabs = await _sheets.getSheetTabs(id);
      } catch (_) {}

      final initialSheetName = tabs.isNotEmpty ? tabs.first : null;

      // Ambil headers
      List<String> headers = [];
      try {
        headers = await _sheets.getSheetHeaders(id, sheetName: initialSheetName);
      } catch (_) {
        // Abaikan jika error ambil header, mungkin sheet kosong
      }

      final config = SpreadsheetConfig(
        id: id,
        title: title,
        url: cleanUrl,
        isActive: true,
        sheetName: initialSheetName,
        availableSheets: tabs,
        mapping: {},
        headers: headers,
      );

      await _storage.addOrUpdateSpreadsheet(config);
      
      if (mounted) {
        setState(() {
          _spreadsheets.add(config);
          _urlController.clear();
        });
        _showSuccess('Spreadsheet "$title" berhasil ditambahkan!');
      }
    } catch (e) {
      if (mounted) {
        // Tampilkan pesan error aslinya agar lebih jelas
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _toggleSpreadsheetActive(SpreadsheetConfig config, bool value) async {
    final updated = config.copyWith(isActive: value);
    await _storage.addOrUpdateSpreadsheet(updated);
    _loadSpreadsheets();
  }

  Future<void> _deleteSpreadsheet(String id) async {
    await _storage.removeSpreadsheet(id);
    _loadSpreadsheets();
  }

  Future<void> _updateMapping(SpreadsheetConfig config, String fieldKey, int? colIndex) async {
    final newMapping = Map<String, int>.from(config.mapping);
    if (colIndex == null) {
      newMapping.remove(fieldKey);
    } else {
      newMapping[fieldKey] = colIndex;
    }
    
    final updated = config.copyWith(mapping: newMapping);
    await _storage.addOrUpdateSpreadsheet(updated);
    _loadSpreadsheets();
  }

  Future<void> _changeSheetTab(SpreadsheetConfig config, String? newTab) async {
    if (newTab == null || config.sheetName == newTab) return;
    
    setState(() => _isConnecting = true);
    try {
      final headers = await _sheets.getSheetHeaders(config.id, sheetName: newTab);
      final updated = config.copyWith(
        sheetName: newTab,
        mapping: {}, // Reset mapping if tab changes
        headers: headers,
      );
      await _storage.addOrUpdateSpreadsheet(updated);
      await _loadSpreadsheets();
    } catch (e) {
      if (mounted) {
        _showError('Gagal mengambil header untuk tab "$newTab"');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF34D399),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F23),
        elevation: 0,
        title: Text(
          'Pengaturan',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BACKEND URL
            _SectionLabel(label: 'KONEKSI BACKEND (APPS SCRIPT URL)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste URL Web App dari Google Apps Script di sini.',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _appsScriptUrlController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://script.google.com/macros/s/...',
                      hintStyle: GoogleFonts.outfit(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0x14FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F8EF7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _saveAppsScriptUrl,
                      child: Text(
                        'Simpan',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // DAFTAR SPREADSHEET
            _SectionLabel(label: 'DAFTAR SPREADSHEET'),
            const SizedBox(height: 8),
            
            if (_spreadsheets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada spreadsheet terhubung',
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._spreadsheets.map((sheet) => _buildSheetCard(sheet)),

            const SizedBox(height: 32),

            // HUBUNGKAN SPREADSHEET BARU
            _SectionLabel(label: 'TAMBAH SPREADSHEET (PASTE URL)'),
            const SizedBox(height: 8),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kamu bisa menghubungkan banyak spreadsheet. Data scan akan dikirim ke semua spreadsheet yang menyala (ON).',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://docs.google.com/spreadsheets/d/...',
                      hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0x14FFFFFF),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4F8EF7)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isConnecting ? null : _connectUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F8EF7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Tambahkan',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _buildSheetCard(SpreadsheetConfig sheet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: sheet.isActive ? const Color(0xFF1E3A5F) : const Color(0xFF111128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: sheet.isActive
                ? const Color(0xFF4F8EF7).withValues(alpha: 0.3)
                : Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sheet.isActive
                      ? const Color(0xFF34D399).withValues(alpha: 0.15)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.table_chart_rounded,
                    color: sheet.isActive ? const Color(0xFF34D399) : Colors.white38,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sheet.isActive ? 'Aktif - Menerima Data' : 'Nonaktif',
                      style: GoogleFonts.outfit(
                        color: sheet.isActive ? const Color(0xFF34D399) : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: sheet.isActive,
                onChanged: (val) => _toggleSpreadsheetActive(sheet, val),
                activeColor: const Color(0xFF34D399),
                activeTrackColor: const Color(0xFF34D399).withValues(alpha: 0.3),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x08FFFFFF),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mapping Kolom',
                        style: GoogleFonts.outfit(
                            color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () => _deleteSpreadsheet(sheet.id),
                        child: Text(
                          'Hapus',
                          style: GoogleFonts.outfit(
                              color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sheet.availableSheets.isNotEmpty) ...[
                    Text(
                      'Pilih Tab Sheet',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: sheet.sheetName,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A3E),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          onChanged: (val) => _changeSheetTab(sheet, val),
                          items: sheet.availableSheets.map((tab) {
                            return DropdownMenuItem<String>(
                              value: tab,
                              child: Text(tab),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),
                  ],
                  if (sheet.headers.isEmpty)
                    Text(
                      'Tidak menemukan header. Pastikan baris 1 diisi nama kolom.',
                      style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                    )
                  else ...[
                    _buildMappingRow(sheet, 'Data Barcode', 'barcode'),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMappingRow(sheet, 'Waktu Scan', 'timestamp'),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMappingRow(sheet, 'Format Barcode', 'format'),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMappingRow(sheet, 'Catatan', 'note'),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingRow(SpreadsheetConfig sheet, String title, String key) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _ColumnInputField(
            initialIndex: sheet.mapping[key],
            onChanged: (idx) => _updateMapping(sheet, key, idx),
          ),
        ),
      ],
    );
  }
}

class _ColumnInputField extends StatefulWidget {
  final int? initialIndex;
  final ValueChanged<int?> onChanged;

  const _ColumnInputField({required this.initialIndex, required this.onChanged});

  @override
  State<_ColumnInputField> createState() => _ColumnInputFieldState();
}

class _ColumnInputFieldState extends State<_ColumnInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _indexToColumn(widget.initialIndex));
  }

  @override
  void didUpdateWidget(covariant _ColumnInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      final newText = _indexToColumn(widget.initialIndex);
      if (newText != _controller.text) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _indexToColumn(int? index) {
    if (index == null || index < 0) return '';
    String column = '';
    int temp = index + 1;
    while (temp > 0) {
      int modulo = (temp - 1) % 26;
      column = String.fromCharCode(65 + modulo) + column;
      temp = (temp - modulo) ~/ 26;
    }
    return column;
  }

  int? _columnToIndex(String column) {
    if (column.isEmpty) return null;
    column = column.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (column.isEmpty) return null;
    
    int index = 0;
    for (int i = 0; i < column.length; i++) {
      index *= 26;
      index += column.codeUnitAt(i) - 64;
    }
    return index - 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'A, B, AA...',
          hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
        ),
        onChanged: (val) {
          final idx = _columnToIndex(val);
          widget.onChanged(idx);
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
