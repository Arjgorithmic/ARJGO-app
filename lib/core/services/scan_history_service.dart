import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanResult {
  final String date;
  final String result;
  final String imageUrl; // In actual app, this might be a local path

  ScanResult({required this.date, required this.result, required this.imageUrl});

  Map<String, dynamic> toJson() => {
        'date': date,
        'result': result,
        'imageUrl': imageUrl,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        date: json['date'],
        result: json['result'],
        imageUrl: json['imageUrl'],
      );
}

class ScanHistoryService {
  static const String _key = 'scan_history';

  Future<void> saveResult(ScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    history.insert(0, jsonEncode(result.toJson()));
    if (history.length > 50) history.removeLast(); // Keep limit
    await prefs.setStringList(_key, history);
  }

  Future<List<ScanResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    return history.map((e) => ScanResult.fromJson(jsonDecode(e))).toList();
  }
}
