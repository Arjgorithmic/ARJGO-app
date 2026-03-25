import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanResult {
  final String date;
  final String result;
  final String? imagePath;

  ScanResult({required this.date, required this.result, this.imagePath});

  Map<String, dynamic> toJson() => {
        'date': date,
        'result': result,
        'imagePath': imagePath,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        date: json['date'],
        result: json['result'],
        imagePath: json['imagePath'],
      );
}

class ScanHistoryService {
  static const String _key = 'scan_history';

  Future<void> saveResult(ScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    history.insert(0, jsonEncode(result.toJson()));
    if (history.length > 50) history.removeLast();
    await prefs.setStringList(_key, history);
  }

  Future<List<ScanResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    return history.map((e) => ScanResult.fromJson(jsonDecode(e))).toList();
  }

  Future<void> deleteResult(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyRaw = prefs.getStringList(_key) ?? [];
    final List<String> updated = historyRaw.where((e) {
      final item = ScanResult.fromJson(jsonDecode(e));
      return item.date != date;
    }).toList();
    await prefs.setStringList(_key, updated);
  }
}
