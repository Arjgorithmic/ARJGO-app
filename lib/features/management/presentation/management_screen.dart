import 'package:arjgo/core/services/activity_log_service.dart';
import 'package:arjgo/core/services/notification_service.dart';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:arjgo/shared/widgets/arjgo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final loggingIntervalProvider = StateProvider<int>((ref) => 60); // Minutes
final loggingEnabledProvider = StateProvider<bool>((ref) => true);
final logFilterProvider = StateProvider<String>((ref) => 'Today');
final loggingDaysProvider = StateProvider<List<int>>((ref) => [1, 2, 3, 4, 5, 6, 7]); // 1=Mon, 7=Sun
final loggingStartTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 9, minute: 0));
final loggingEndTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 21, minute: 0));

class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  final _logController = TextEditingController();
  final _logService = ActivityLogService();
  bool _isSaving = false;
  List<ActivityLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshLogs();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(loggingIntervalProvider.notifier).state = prefs.getInt('logging_interval') ?? 1;
    ref.read(loggingEnabledProvider.notifier).state = prefs.getBool('logging_enabled') ?? true;
    
    final days = prefs.getStringList('logging_days')?.map(int.parse).toList() ?? [1, 2, 3, 4, 5, 6, 7];
    ref.read(loggingDaysProvider.notifier).state = days;

    final startHour = prefs.getInt('logging_start_hour') ?? 9;
    final startMin = prefs.getInt('logging_start_min') ?? 0;
    ref.read(loggingStartTimeProvider.notifier).state = TimeOfDay(hour: startHour, minute: startMin);

    final endHour = prefs.getInt('logging_end_hour') ?? 21;
    final endMin = prefs.getInt('logging_end_min') ?? 0;
    ref.read(loggingEndTimeProvider.notifier).state = TimeOfDay(hour: endHour, minute: endMin);
  }

  Future<void> _refreshLogs() async {
    final logs = await _logService.getLogs();
    setState(() => _logs = logs);
  }

  Future<void> _toggleLogging(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService().requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission is required for reminders.')),
          );
        }
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logging_enabled', enabled);
    ref.read(loggingEnabledProvider.notifier).state = enabled;

    if (!enabled) {
      // Cancel all logging notifications
      for (int i = 0; i < 100; i++) {
        await NotificationService().cancelNotification(2000 + i);
      }
    } else {
      _rescheduleNotifications();
    }
  }

  Future<void> _updateInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('logging_interval', minutes);
    ref.read(loggingIntervalProvider.notifier).state = minutes;
    _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    final isEnabled = ref.read(loggingEnabledProvider);
    final hours = ref.read(loggingIntervalProvider);
    final start = ref.read(loggingStartTimeProvider);
    final end = ref.read(loggingEndTimeProvider);
    final days = ref.read(loggingDaysProvider);

    // Cancel all existing logging notifications (IDs 2000-2100)
    for (int i = 0; i < 100; i++) {
      await NotificationService().cancelNotification(2000 + i);
    }

    if (isEnabled) {
      final List<TimeOfDay> scheduleTimes = [];
      int intervalMinutes = ref.read(loggingIntervalProvider);
      
      int startMinutes = start.hour * 60 + start.minute;
      int endMinutes = end.hour * 60 + end.minute;
      
      if (endMinutes <= startMinutes) endMinutes += 24 * 60;

      for (int m = startMinutes; m <= endMinutes; m += intervalMinutes) {
        int actualM = m % (24 * 60);
        scheduleTimes.add(TimeOfDay(hour: actualM ~/ 60, minute: actualM % 60));
        if (scheduleTimes.length >= 60) break; // System limit safety
      }

      // Note: Current NotificationService doesn't support "specific days" in scheduleMultipleDailyReminders
      // but we will update it or assume it handles daily.
      // For now, we schedule them as daily reminders.
      await NotificationService().scheduleMultipleDailyReminders(
        baseId: 2000,
        times: scheduleTimes,
        title: 'Activity Check-in',
        body: 'What are you working on right now?',
        days: days,
      );
    }
  }

  Future<void> _toggleDay(int day) async {
    final current = List<int>.from(ref.read(loggingDaysProvider));
    if (current.contains(day)) {
      if (current.length > 1) current.remove(day);
    } else {
      current.add(day);
    }
    current.sort();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('logging_days', current.map((e) => e.toString()).toList());
    ref.read(loggingDaysProvider.notifier).state = current;
    _rescheduleNotifications();
  }

  Future<void> _selectTime(bool isStart) async {
    final current = isStart ? ref.read(loggingStartTimeProvider) : ref.read(loggingEndTimeProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: AppColors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      if (isStart) {
        await prefs.setInt('logging_start_hour', picked.hour);
        await prefs.setInt('logging_start_min', picked.minute);
        ref.read(loggingStartTimeProvider.notifier).state = picked;
      } else {
        await prefs.setInt('logging_end_hour', picked.hour);
        await prefs.setInt('logging_end_min', picked.minute);
        ref.read(loggingEndTimeProvider.notifier).state = picked;
      }
      _rescheduleNotifications();
    }
  }

  Future<void> _saveQuickLog() async {
    if (_logController.text.isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      await _logService.saveLog(_logController.text);
      _logController.clear();
      await _refreshLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity logged successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLog(String id) async {
    await _logService.deleteLog(id);
    await _refreshLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log entry deleted.')),
      );
    }
  }

  List<ActivityLog> get _filteredLogs {
    final now = DateTime.now();
    final filter = ref.watch(logFilterProvider);
    
    return _logs.where((log) {
      if (filter == 'Today') {
        return log.loggedAt.year == now.year &&
               log.loggedAt.month == now.month &&
               log.loggedAt.day == now.day;
      } else if (filter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return log.loggedAt.isAfter(startOfWeek);
      } else if (filter == 'This Month') {
        return log.loggedAt.year == now.year && log.loggedAt.month == now.month;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final interval = ref.watch(loggingIntervalProvider);
    final isEnabled = ref.watch(loggingEnabledProvider);
    final currentFilter = ref.watch(logFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Personal Management',
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ACTIVITY ENGINE',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('ACTIVITY LOGGING'),
                  Switch(
                    value: isEnabled,
                    activeColor: AppColors.accent,
                    onChanged: _toggleLogging,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
                if (isEnabled) ...[
                _buildSectionHeader('FREQUENCY'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: interval,
                      isExpanded: true,
                      style: GoogleFonts.dmSans(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                      items: [5, 30, 60, 120, 240, 480, 720, 1440].map((m) {
                        String label;
                        if (m < 60) {
                          label = 'Every $m minutes';
                        } else {
                          int h = m ~/ 60;
                          label = 'Every $h hour${h > 1 ? 's' : ''}';
                        }
                        return DropdownMenuItem(
                          value: m,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (val) => val != null ? _updateInterval(val) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('ACTIVE DAYS'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                    final isSelected = ref.watch(loggingDaysProvider).contains(day);
                    final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1];
                    return GestureDetector(
                      onTap: () => _toggleDay(day),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
                          border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.white : AppColors.grey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('TIME WINDOW'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeTile('START', ref.watch(loggingStartTimeProvider), () => _selectTime(true)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeTile('END', ref.watch(loggingEndTimeProvider), () => _selectTime(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              _buildSectionHeader('QUICK LOG'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _logController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Current activity...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.grey),
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.dmSans(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveQuickLog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.white,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _isSaving 
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('SAVE LOG'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('LOG HISTORY'),
                  _buildFilterChip(currentFilter),
                ],
              ),
              const SizedBox(height: 16),
              _buildLogTable(),
              const SizedBox(height: 48),
              const VibeFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String current) {
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected: (val) => ref.read(logFilterProvider.notifier).state = val,
      itemBuilder: (context) => ['Today', 'This Week', 'This Month'].map((f) {
        return PopupMenuItem(value: f, child: Text(f, style: GoogleFonts.dmSans(fontSize: 12)));
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent)),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTable() {
    final filteredLogs = _filteredLogs;
    if (filteredLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('No logs for this period', style: GoogleFonts.dmSans(color: AppColors.grey, fontSize: 13)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
      ),
      child: DataTable(
        columnSpacing: 8,
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 72,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(AppColors.divider.withOpacity(0.3)),
        columns: [
          DataColumn(label: SizedBox(width: 40, child: Text('TIME', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold)))),
          DataColumn(label: Text('ACTIVITY', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold))),
          DataColumn(label: Container(width: 32, alignment: Alignment.centerRight, child: Text('X', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.transparent)))),
        ],
        rows: filteredLogs.map((log) {
          return DataRow(cells: [
            DataCell(Text(
              DateFormat('HH:mm').format(log.loggedAt),
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w300),
            )),
            DataCell(SizedBox(
              width: MediaQuery.of(context).size.width * 0.45,
              child: Text(
                log.content,
                style: GoogleFonts.dmSans(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            DataCell(
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  onPressed: () => _deleteLog(log.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.5,
        color: AppColors.accent.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.grey, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
    );
  }
}
