import 'package:arjgo/core/services/finance_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

final financeRecordsProvider = FutureProvider<List<FinanceRecord>>((ref) {
  return FinanceService().getRecords();
});

final financeSummaryProvider = FutureProvider<Map<String, double>>((ref) {
  return FinanceService().getSummary();
});

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Food';
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Health',
    'Bills',
    'Other'
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Dividend',
    'Gift',
    'Business',
    'Other Income'
  ];

  final _totalAmountController = TextEditingController();
  final _durationController = TextEditingController();
  bool _isEmiMode = false;

  Future<void> _addRecord() async {
    if (_isEmiMode) {
      final monthly = double.tryParse(_amountController.text);
      final total = double.tryParse(_totalAmountController.text);
      final months = int.tryParse(_durationController.text);

      if (monthly == null || total == null || months == null) return;

      final liability = Liability(
        id: const Uuid().v4(),
        name: _descController.text.isEmpty ? 'EMI' : _descController.text,
        monthlyAmount: monthly,
        totalAmount: total,
        remainingAmount: total,
        startDate: _selectedDate,
        endDate: _selectedDate.add(Duration(days: months * 30)),
        createdAt: DateTime.now(),
      );

      await FinanceService().saveLiability(liability);
    } else {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) return;

      final record = FinanceRecord(
        id: const Uuid().v4(),
        type: _selectedType,
        category: _selectedCategory,
        amount: amount,
        description: _descController.text,
        date: _selectedDate,
        createdAt: DateTime.now(),
      );

      await FinanceService().saveRecord(record);
    }

    _amountController.clear();
    _descController.clear();
    _totalAmountController.clear();
    _durationController.clear();
    
    ref.invalidate(financeRecordsProvider);
    ref.invalidate(financeSummaryProvider);
    
    if (mounted) Navigator.pop(context);
  }

  void _showAddSheet() {
    // Reset categories when opening
    if (_selectedType == TransactionType.income) {
      _selectedCategory = _incomeCategories.first;
    } else {
      _selectedCategory = _expenseCategories.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 32,
            right: 32,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEmiMode ? 'NEW EMI / LIABILITY' : 'NEW TRANSACTION',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.grey,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildTypeTab(TransactionType.expense, 'EXPENSE', setSheetState),
                  const SizedBox(width: 12),
                  _buildTypeTab(TransactionType.income, 'INCOME', setSheetState),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setSheetState(() => _isEmiMode = !_isEmiMode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isEmiMode ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: _isEmiMode ? Colors.orange : AppColors.divider),
                      ),
                      child: Text(
                        'EMI MODE',
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _isEmiMode ? Colors.orange : AppColors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (_isEmiMode) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildField('MONTHLY', _amountController, '0.00'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField('TOTAL', _totalAmountController, '0.00'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField('DURATION (MONTHS)', _durationController, '12'),
              ] else ...[
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w200),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                    hintStyle: GoogleFonts.dmSans(color: AppColors.grey.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: _isEmiMode ? 'What is this EMI for?' : (_selectedType == TransactionType.expense ? 'What was this for?' : 'Salary or other income?'),
                  hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.grey),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
              
              if (!_isEmiMode) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (_selectedType == TransactionType.expense ? _expenseCategories : _incomeCategories)
                      .map((c) => _buildCategoryChip(c, setSheetState)).toList(),
                ),
              ],
              
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.accent,
                          onPrimary: AppColors.white,
                          onSurface: AppColors.text,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.grey),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate).toUpperCase(),
                        style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _addRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text('ADD RECORD'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.grey),
        ),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.dmSans(fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: '₹ ',
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTab(TransactionType type, String label, StateSetter setSheetState) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          _selectedType = type;
          _isEmiMode = false; // Disable EMI when switching main types
          if (type == TransactionType.income) {
            _selectedCategory = _incomeCategories.first;
          } else {
            _selectedCategory = _expenseCategories.first;
          }
        });
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.white : AppColors.grey,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, StateSetter setSheetState) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _selectedCategory = category);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.accent : AppColors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(financeRecordsProvider);
    final summaryAsync = ref.watch(financeSummaryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Finance',
                    style: GoogleFonts.dmSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w200,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                    ),
                  ),
                  IconButton(
                    onPressed: _showAddSheet,
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'MANAGEMENT ENGINE',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 32),

              // Summary Card
              summaryAsync.when(
                data: (summary) => _buildSummaryCard(summary),
                loading: () => const SizedBox(height: 100),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),
              Text(
                'RECENT TRANSACTIONS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.grey.withOpacity(0.5),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: recordsAsync.when(
                  data: (records) => records.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 32),
                          itemBuilder: (context, i) => _buildTransactionItem(records[i]),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, double> summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('INCOME', summary['income']!, AppColors.accent),
              _buildSummaryItem('EXPENSES', summary['expenses']!, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('ASSETS', summary['assets']!, Colors.blueAccent),
              _buildSummaryItem('LIABILITIES', summary['liabilities']!, Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT BALANCE',
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.grey),
              ),
              Text(
                '₹${summary['balance']!.toStringAsFixed(2)}',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: summary['balance']! >= 0 ? AppColors.accent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: color),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(FinanceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'DELETE TRANSACTION?',
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        content: Text(
          'This will permanently remove this ${record.type.name} record.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: GoogleFonts.dmSans(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FinanceService().deleteRecord(record.id);
      ref.invalidate(financeRecordsProvider);
      ref.invalidate(financeSummaryProvider);
    }
  }

  Widget _buildTransactionItem(FinanceRecord record) {
    final isExpense = record.type == TransactionType.expense;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isExpense ? Colors.redAccent : AppColors.accent).withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isExpense ? Icons.arrow_outward : Icons.south_west,
            size: 16,
            color: isExpense ? Colors.redAccent : AppColors.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.category,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (record.description.isNotEmpty)
                Text(
                  record.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.grey),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${'₹'}${record.amount.toStringAsFixed(2)}',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isExpense ? Colors.redAccent : AppColors.accent,
              ),
            ),
            Text(
              DateFormat('d MMM').format(record.date),
              style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.grey),
            ),
          ],
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => _confirmDelete(record),
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'NO TRANSACTIONS YET',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}
