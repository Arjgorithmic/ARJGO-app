import 'dart:typed_data';

import 'package:arjgo/core/services/database_service.dart';
import 'package:arjgo/core/services/vector_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum TransactionType { income, expense }

class FinanceRecord {
  final String id;
  final TransactionType type;
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;

  FinanceRecord({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  factory FinanceRecord.fromMap(Map<String, dynamic> map) {
    return FinanceRecord(
      id: map['id'],
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: map['category'],
      amount: map['amount'],
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Liability {
  final String id;
  final String name;
  final double monthlyAmount;
  final double totalAmount;
  final double remainingAmount;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  Liability({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    required this.totalAmount,
    required this.remainingAmount,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory Liability.fromMap(Map<String, dynamic> map) {
    return Liability(
      id: map['id'],
      name: map['name'],
      monthlyAmount: map['monthly_amount'],
      totalAmount: map['total_amount'],
      remainingAmount: map['remaining_amount'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthly_amount': monthlyAmount,
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class FinanceService {
  final _dbService = DatabaseService();
  final _vectorService = VectorService();

  Future<void> saveRecord(FinanceRecord record) async {
    final db = await _dbService.db;
    db.execute(
      'INSERT INTO finance_records (id, type, category, amount, description, date, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [record.id, record.type.name, record.category, record.amount, record.description, record.date.toIso8601String(), record.createdAt.toIso8601String()],
    );

    // Vectorize (Graceful failure)
    if (!DatabaseService.isVectorEnabled) return;

    try {
      final text = '${record.type.name} ${record.category} ${record.description}';
      final embedding = _vectorService.embed(text);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();
      db.execute(
        'INSERT INTO vec_finance (id, embedding) VALUES (?, ?)',
        [record.id, blob],
      );
    } catch (e) {
      debugPrint('FINANCE STORAGE ERROR: Could not save vector embedding: $e');
    }
  }

  Future<List<FinanceRecord>> getRecords() async {
    final db = await _dbService.db;
    final results = db.select('SELECT * FROM finance_records ORDER BY date DESC');
    return results.map((row) => FinanceRecord.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> deleteRecord(String id) async {
    final db = await _dbService.db;
    db.execute('DELETE FROM finance_records WHERE id = ?', [id]);
    try {
      db.execute('DELETE FROM vec_finance WHERE id = ?', [id]);
    } catch (_) {}
  }

  Future<void> saveLiability(Liability liability) async {
    final db = await _dbService.db;
    db.execute(
      'INSERT INTO liabilities (id, name, monthly_amount, total_amount, remaining_amount, start_date, end_date, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [liability.id, liability.name, liability.monthlyAmount, liability.totalAmount, liability.remainingAmount, liability.startDate.toIso8601String(), liability.endDate.toIso8601String(), liability.createdAt.toIso8601String()],
    );
  }

  Future<List<Liability>> getLiabilities() async {
    final db = await _dbService.db;
    final results = db.select('SELECT * FROM liabilities ORDER BY created_at DESC');
    return results.map((row) => Liability.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> deleteLiability(String id) async {
    final db = await _dbService.db;
    db.execute('DELETE FROM liabilities WHERE id = ?', [id]);
  }

  Future<Map<String, double>> getSummary() async {
    final records = await getRecords();
    final liabilities = await getLiabilities();
    
    double income = 0;
    double expenses = 0;

    for (final r in records) {
      if (r.type == TransactionType.income) {
        income += r.amount;
      } else {
        expenses += r.amount;
      }
    }

    double totalLiabilities = 0;
    for (final l in liabilities) {
      totalLiabilities += l.remainingAmount;
    }

    final balance = income - expenses;

    return {
      'income': income,
      'expenses': expenses,
      'balance': balance,
      'assets': balance > 0 ? balance : 0, // Simplified: Assets = positive balance
      'liabilities': totalLiabilities,
    };
  }

  Future<List<FinanceRecord>> searchFinancesSemantic(String query) async {
    if (!DatabaseService.isVectorEnabled || !_vectorService.isReady) {
      return _fallbackSearch(query);
    }

    try {
      final db = await _dbService.db;
      final embedding = _vectorService.embed(query);
      final blob = Float32List.fromList(embedding).buffer.asUint8List();

      final results = db.select('''
        SELECT 
          f.*,
          vec_distance_cosine(v.embedding, ?) as distance
        FROM finance_records f
        JOIN vec_finance v ON f.id = v.id
        WHERE distance < 0.35
        ORDER BY distance ASC
        LIMIT 10
      ''', [blob]);
      
      return results.map((row) => FinanceRecord.fromMap(Map<String, dynamic>.from(row))).toList();
    } catch (e) {
      debugPrint('FINANCE SEARCH ERROR: Vector search failed: $e');
      return _fallbackSearch(query);
    }
  }

  Future<List<FinanceRecord>> _fallbackSearch(String query) async {
    final db = await _dbService.db;
    final results = db.select(
      'SELECT * FROM finance_records WHERE category LIKE ? OR description LIKE ? ORDER BY date DESC LIMIT 10',
      ['%$query%', '%$query%']
    );
    return results.map((row) => FinanceRecord.fromMap(Map<String, dynamic>.from(row))).toList();
  }
}
