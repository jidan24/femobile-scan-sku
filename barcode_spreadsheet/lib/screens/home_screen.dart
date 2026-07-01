import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scan_entry.dart';
import '../services/sheets_service.dart';
import '../services/storage_service.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SheetsService _sheets = SheetsService();
  final StorageService _storage = StorageService();

  bool _hasSpreadsheets = false;
  int _activeCount = 0;

  final List<ScanEntry> _scans = [];
  bool _isLoadingSheet = true;

  @override
  void initState() {
    super.initState();
    _loadSheetInfo();
  }

  Future<void> _loadSheetInfo() async {
    setState(() => _isLoadingSheet = true);
    final sheets = await _storage.getSpreadsheets();
    _hasSpreadsheets = sheets.isNotEmpty;
    _activeCount = sheets.where((s) => s.isActive).length;
    if (mounted) setState(() => _isLoadingSheet = false);
  }

  Future<void> _openScanner() async {
    if (_activeCount == 0) {
      _showNoSheetDialog();
      return;
    }

    final results = await Navigator.of(context).push<List<ScanEntry>>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (results != null && results.isNotEmpty) {
      setState(() => _scans.insertAll(0, results));
    }
  }

  void _showNoSheetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pilih Spreadsheet',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Kamu belum memilih Google Sheet. Pilih atau buat sheet baru di halaman Settings.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F8EF7)),
            onPressed: () {
              Navigator.pop(ctx);
              _openSettings();
            },
            child: Text('Buka Settings',
                style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _loadSheetInfo();
  }



  Future<void> _retrySync(ScanEntry entry) async {
    if (_activeCount == 0) return;
    setState(() => entry.status = ScanStatus.syncing);
    try {
      await _sheets.appendScan(entry);
      if (mounted) setState(() => entry.status = ScanStatus.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          entry.status = ScanStatus.failed;
          entry.errorMessage = e.toString();
        });
      }
    }
  }

  int get _successCount =>
      _scans.where((s) => s.status == ScanStatus.success).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(child: _buildHeader()),

          // Sheet card
          SliverToBoxAdapter(child: _buildSheetCard()),

          // Stats row
          if (_scans.isNotEmpty)
            SliverToBoxAdapter(child: _buildStatsRow()),

          // List header
          if (_scans.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Riwayat Scan',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

          // Scan list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ScanTile(
                scan: _scans[i],
                onRetry: () => _retrySync(_scans[i]),
              ),
              childCount: _scans.length,
            ),
          ),

          // Empty state
          if (_scans.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        backgroundColor: const Color(0xFF4F8EF7),
        elevation: 8,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: Text(
          'Scan Barcode',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo!',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Selamat bekerja',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Settings button
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _hasSpreadsheets ? null : _openSettings,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _activeCount > 0
                ? const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF1A2A4A)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _activeCount > 0
                  ? const Color(0xFF4F8EF7).withValues(alpha: 0.3)
                  : Colors.white12,
            ),
          ),
          child: _isLoadingSheet
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4F8EF7),
                    ),
                  ),
                )
              : !_hasSpreadsheets
                  ? Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_chart_rounded,
                              color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum ada spreadsheet',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Tap untuk tambah spreadsheet baru',
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white38),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _activeCount > 0 ? const Color(0xFF34D399).withValues(alpha: 0.15) : Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.table_chart_rounded,
                              color: _activeCount > 0 ? const Color(0xFF34D399) : Colors.white38, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_activeCount Spreadsheet Aktif',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Terhubung ke Google Sheets',
                                style: GoogleFonts.outfit(
                                  color: _activeCount > 0 ? const Color(0xFF34D399) : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.edit_rounded,
                              color: Colors.white38, size: 18),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final failedCount =
        _scans.where((s) => s.status == ScanStatus.failed).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            label: 'Total Scan',
            value: '${_scans.length}',
            color: const Color(0xFF4F8EF7),
            icon: Icons.qr_code_2_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Berhasil',
            value: '$_successCount',
            color: const Color(0xFF34D399),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Gagal',
            value: '$failedCount',
            color: failedCount > 0 ? Colors.redAccent : Colors.white24,
            icon: Icons.error_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF4F8EF7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                size: 40, color: Color(0xFF4F8EF7)),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada scan',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol "Scan Barcode" untuk mulai',
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final ScanEntry scan;
  final VoidCallback onRetry;

  const _ScanTile({required this.scan, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111128),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // Status indicator
            _StatusDot(status: scan.status),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.barcode,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F8EF7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          scan.format,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF4F8EF7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${scan.formattedDate} ${scan.formattedTime}',
                        style: GoogleFonts.outfit(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Retry button
            if (scan.status == ScanStatus.failed)
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Coba lagi',
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ScanStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ScanStatus.success => const Icon(Icons.check_circle_rounded,
          color: Color(0xFF34D399), size: 20),
      ScanStatus.failed =>
        const Icon(Icons.error_rounded, color: Colors.redAccent, size: 20),
      ScanStatus.syncing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Color(0xFF4F8EF7))),
      ScanStatus.pending =>
        const Icon(Icons.schedule_rounded, color: Colors.white30, size: 20),
    };
  }
}
