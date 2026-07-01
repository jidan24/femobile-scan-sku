import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spreadsheet_config.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _keyContinuousMode = 'continuous_mode';
  static const String _appsScriptUrlKey = 'apps_script_url';
  static const _keySpreadsheetsList = 'spreadsheets_list';

  Future<String?> getAppsScriptUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appsScriptUrlKey);
  }

  Future<void> setAppsScriptUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appsScriptUrlKey, url);
  }

  Future<bool> getContinuousMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyContinuousMode) ?? false;
  }

  Future<void> setContinuousMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyContinuousMode, value);
  }

  Future<List<SpreadsheetConfig>> getSpreadsheets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySpreadsheetsList);
    if (jsonStr == null) return [];
    
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => SpreadsheetConfig.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSpreadsheets(List<SpreadsheetConfig> sheets) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sheets.map((e) => e.toJson()).toList();
    await prefs.setString(_keySpreadsheetsList, jsonEncode(list));
  }

  Future<void> addOrUpdateSpreadsheet(SpreadsheetConfig config) async {
    final sheets = await getSpreadsheets();
    final index = sheets.indexWhere((s) => s.id == config.id);
    if (index >= 0) {
      sheets[index] = config;
    } else {
      sheets.add(config);
    }
    await saveSpreadsheets(sheets);
  }

  Future<void> removeSpreadsheet(String id) async {
    final sheets = await getSpreadsheets();
    sheets.removeWhere((s) => s.id == id);
    await saveSpreadsheets(sheets);
  }
}
