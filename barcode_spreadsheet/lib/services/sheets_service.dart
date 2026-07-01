import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scan_entry.dart';
import 'storage_service.dart';
import 'package:intl/intl.dart';

class SheetsService {
  static final SheetsService _instance = SheetsService._internal();
  factory SheetsService() => _instance;
  SheetsService._internal();

  final StorageService _storage = StorageService();

  Future<String?> _getWebAppUrl() async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('URL Apps Script belum diatur di Pengaturan.');
    }
    return url;
  }

  /// Verifikasi spreadsheet bisa diakses
  Future<String> verifySpreadsheet(String spreadsheetId) async {
    final webAppUrl = await _getWebAppUrl();
    
    // Follow redirects manually if needed, but http package handles basic redirects
    final uri = Uri.parse('$webAppUrl?action=verify&spreadsheetId=$spreadsheetId');
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['error'] != null) throw Exception(json['error']);
      return json['title'] ?? 'Spreadsheet';
    } else {
      throw Exception('Gagal menghubungi Apps Script (Status: ${response.statusCode})');
    }
  }

  /// Ambil daftar nama sheet (tab) dari sebuah spreadsheet
  Future<List<String>> getSheetTabs(String spreadsheetId) async {
    final webAppUrl = await _getWebAppUrl();
    final uri = Uri.parse('$webAppUrl?action=getTabs&spreadsheetId=$spreadsheetId');
    
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['error'] != null) throw Exception(json['error']);
      return List<String>.from(json['tabs'] ?? []);
    }
    throw Exception('Gagal mengambil tab sheet.');
  }

  /// Ambil header dari baris pertama (Row 1)
  Future<List<String>> getSheetHeaders(String spreadsheetId, {String? sheetName}) async {
    final webAppUrl = await _getWebAppUrl();
    var urlString = '$webAppUrl?action=getHeaders&spreadsheetId=$spreadsheetId';
    if (sheetName != null && sheetName.isNotEmpty) {
      urlString += '&sheetName=${Uri.encodeComponent(sheetName)}';
    }
    
    final uri = Uri.parse(urlString);
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['error'] != null) {
        if (json['error'] == "Sheet not found") return [];
        throw Exception(json['error']);
      }
      return List<String>.from(json['headers'] ?? []);
    }
    throw Exception('Gagal mengambil header.');
  }

  /// Tambah baris data ke semua spreadsheet yang aktif
  Future<void> appendScan(ScanEntry entry) async {
    final spreadsheets = await _storage.getSpreadsheets();
    final activeSheets = spreadsheets.where((s) => s.isActive).toList();

    if (activeSheets.isEmpty) return;

    final timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(entry.timestamp);
    final webAppUrl = await _getWebAppUrl();

    List<String> errors = [];

    await Future.wait(activeSheets.map((sheet) async {
      try {
        final mapping = sheet.mapping;
        
        List<dynamic> rowValues = [];
        if (mapping.isEmpty) {
          rowValues = [timestamp, entry.barcode, entry.format, entry.note ?? ''];
        } else {
          int maxIndex = 0;
          for (final idx in mapping.values) {
            if (idx > maxIndex) maxIndex = idx;
          }
          rowValues = List.filled(maxIndex + 1, '');
          
          if (mapping.containsKey('barcode')) rowValues[mapping['barcode']!] = entry.barcode;
          if (mapping.containsKey('timestamp')) rowValues[mapping['timestamp']!] = timestamp;
          if (mapping.containsKey('format')) rowValues[mapping['format']!] = entry.format;
          if (mapping.containsKey('note')) rowValues[mapping['note']!] = entry.note ?? '';
        }

        final body = jsonEncode({
          'spreadsheetId': sheet.id,
          'sheetName': sheet.sheetName,
          'rowValues': rowValues,
        });

        final response = await http.post(
          Uri.parse(webAppUrl!),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          body: body,
        );

        // API Apps Script sometimes redirects POST to a GET, `http` package might follow it or not
        // Depending on Apps Script response, if it's 200 or 302
        if (response.statusCode == 200 || response.statusCode == 302) {
          // It could be HTML if it redirected to Google Login, but we use 'Anyone' so it should be JSON
          try {
            final json = jsonDecode(response.body);
            if (json['error'] != null) throw Exception(json['error']);
          } catch (e) {
            // IF it fails to decode JSON, it might be a redirect page or error page
            if (response.body.contains("success")) {
               // Ignore
            } else {
               throw Exception('Response format tidak dikenali. Pastikan Apps Script Web App diset ke "Anyone".');
            }
          }
        } else {
           throw Exception('HTTP Error: ${response.statusCode}');
        }

      } catch (e) {
        errors.add('Gagal di "${sheet.title}": $e');
      }
    }));

    if (errors.isNotEmpty) {
      throw Exception(errors.join('\n'));
    }
  }
}
