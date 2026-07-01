import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/scan_entry.dart';
import '../services/sheets_service.dart';
import '../services/storage_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final SheetsService _sheets = SheetsService();
  final StorageService _storage = StorageService();

  MobileScannerController? _controller;
  bool _isContinuous = false;
  bool _isFlashOn = false;
  bool _isCooldown = false;
  bool _isProcessing = false;

  final List<ScanEntry> _sessionScans = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  int _scanCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initScanner();
  }

  Future<void> _initScanner() async {
    final continuous = await _storage.getContinuousMode();
    if (mounted) {
      setState(() => _isContinuous = continuous);
    }
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal, // We handle dedupe locally
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isCooldown || _isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final value = barcode.rawValue;
    if (value == null || value.isEmpty) return;

    // We allow scanning the same barcode again after cooldown

    setState(() {
      _isCooldown = true;
      _isProcessing = true;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Pulse animation
    _pulseController.forward(from: 0).then((_) => _pulseController.reverse());

    final entry = ScanEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      barcode: value,
      format: barcode.format.name.toUpperCase(),
      timestamp: DateTime.now(),
      status: ScanStatus.syncing,
    );

    setState(() {
      _sessionScans.insert(0, entry);
      _scanCount++;
    });

    // Send to Google Sheets
    final sheets = await _storage.getSpreadsheets();
    final hasActive = sheets.any((s) => s.isActive);
    if (hasActive) {
      try {
        await _sheets.appendScan(entry);
        if (mounted) {
          setState(() => entry.status = ScanStatus.success);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            entry.status = ScanStatus.failed;
            entry.errorMessage = e.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan: $e', style: GoogleFonts.outfit(color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      setState(() => entry.status = ScanStatus.failed);
    }

    setState(() => _isProcessing = false);

    // Cooldown to prevent duplicate scans
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isCooldown = false);

    // If not continuous, close the scanner automatically
    if (!_isContinuous && mounted) {
      Navigator.of(context).pop(_sessionScans);
    }
  }

  void _toggleFlash() {
    _controller?.toggleTorch();
    setState(() => _isFlashOn = !_isFlashOn);
  }

  void _toggleContinuous() {
    setState(() => _isContinuous = !_isContinuous);
    _storage.setContinuousMode(_isContinuous);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onBarcodeDetected,
            ),

          // Dark overlay with hole
          _ScanOverlay(pulseAnim: _pulseAnim),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(_sessionScans),
                  ),
                  const Spacer(),
                  // Scan counter
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '$_scanCount scan',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Flash button
                  _GlassButton(
                    icon: _isFlashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    isActive: _isFlashOn,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          // Scan frame label
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 220),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isProcessing
                        ? const Color(0xFF4F8EF7).withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isProcessing
                        ? 'Menyimpan...'
                        : 'Arahkan ke barcode / QR code',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              isContinuous: _isContinuous,
              onToggleContinuous: _toggleContinuous,
              recentScans: _sessionScans.take(3).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _ScanOverlay({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return CustomPaint(
          painter: _OverlayPainter(scale: pulseAnim.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double scale;
  _OverlayPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
        24, 
        100, 
        size.width - 48, 
        size.height - 320 // Leave space for bottom panel
    );

    // Removed dark overlay to make it full screen focus

    // Corner brackets
    final linePaint = Paint()
      ..color = const Color(0xFF4F8EF7)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    const r = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + len, rect.top)
        ..lineTo(rect.left + r, rect.top)
        ..arcToPoint(Offset(rect.left, rect.top + r),
            radius: const Radius.circular(r))
        ..lineTo(rect.left, rect.top + len),
      linePaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - len, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(rect.right, rect.top + len),
      linePaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - len)
        ..lineTo(rect.left, rect.bottom - r)
        ..arcToPoint(Offset(rect.left + r, rect.bottom),
            radius: const Radius.circular(r), clockwise: false)
        ..lineTo(rect.left + len, rect.bottom),
      linePaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - len)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom),
            radius: const Radius.circular(r))
        ..lineTo(rect.right - len, rect.bottom),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.scale != scale;
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4F8EF7).withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? const Color(0xFF4F8EF7) : Colors.white24,
          ),
        ),
        child: Icon(icon,
            color: Colors.white, size: 22),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final bool isContinuous;
  final VoidCallback onToggleContinuous;
  final List<ScanEntry> recentScans;

  const _BottomPanel({
    required this.isContinuous,
    required this.onToggleContinuous,
    required this.recentScans,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F23).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode toggle
          Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mode Continuous',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Switch(
                value: isContinuous,
                onChanged: (_) => onToggleContinuous(),
                activeColor: const Color(0xFF4F8EF7),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
              ),
            ],
          ),
          if (recentScans.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 16),
            ...recentScans.map((scan) => _MiniScanTile(scan: scan)),
          ],
        ],
      ),
    );
  }
}

class _MiniScanTile extends StatelessWidget {
  final ScanEntry scan;
  const _MiniScanTile({required this.scan});

  @override
  Widget build(BuildContext context) {
    final statusIcon = switch (scan.status) {
      ScanStatus.success => const Icon(Icons.check_circle_rounded,
          color: Color(0xFF34D399), size: 16),
      ScanStatus.failed => const Icon(Icons.error_rounded,
          color: Colors.redAccent, size: 16),
      ScanStatus.syncing => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF4F8EF7))),
      ScanStatus.pending =>
        const Icon(Icons.schedule_rounded, color: Colors.white38, size: 16),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              scan.barcode,
              style: GoogleFonts.robotoMono(
                color: Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            scan.format,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
