part of '../main.dart';

// ---------------- PAYROLL SETTINGS (Working Schedules + Calculation Rules) ----------------
// Everything the calculation engine reads instead of hard-coding - per Employee Type working
// hours, and the company-wide hourly/daily rate + deduction methods. Two tabs, one screen,
// matching the "Payroll Settings" single nav entry.
class PayrollSettingsScreen extends StatefulWidget {
  final AppUser currentUser;
  const PayrollSettingsScreen({super.key, required this.currentUser});

  @override
  State<PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends State<PayrollSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AESColors.background,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: AESColors.primaryGreen,
              unselectedLabelColor: AESColors.grey,
              indicatorColor: AESColors.primaryGreen,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Working Schedules'),
                Tab(text: 'Calculation Rules'),
                Tab(text: 'Holidays'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _WorkingSchedulesTab(currentUser: widget.currentUser),
                _CalculationRulesTab(currentUser: widget.currentUser),
                _HolidaysTab(currentUser: widget.currentUser),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkingSchedulesTab extends StatefulWidget {
  final AppUser currentUser;
  const _WorkingSchedulesTab({required this.currentUser});
  @override
  State<_WorkingSchedulesTab> createState() => _WorkingSchedulesTabState();
}

class _WorkingSchedulesTabState extends State<_WorkingSchedulesTab> {
  bool _seeding = false;

  Future<void> _seedDefaults() async {
    if (_seeding) return;
    setState(() => _seeding = true);
    try {
      final defaults = buildDefaultWorkingSchedules();
      for (final s in defaults) {
        await DataService.saveWorkingSchedule(s);
      }
      await logPayrollAudit(
        action: 'Default Working Schedules Seeded',
        performedByUsername: widget.currentUser.username,
      );
      setState(() => sampleWorkingSchedules.addAll(defaults));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to seed schedules: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _editSchedule(WorkingSchedule schedule) async {
    int startMinute = schedule.startMinuteOfDay;
    int endMinute = schedule.endMinuteOfDay;
    final graceController = TextEditingController(
      text: schedule.gracePeriodMinutes.toString(),
    );
    final breakController = TextEditingController(
      text: schedule.breakDurationMinutes.toString(),
    );
    final otThresholdController = TextEditingController(
      text: schedule.overtimeStartThresholdMinutes.toString(),
    );
    bool overtimeEligible = schedule.overtimeEligible;
    final workingDays = Set<int>.from(schedule.workingDays);
    bool isSubmitting = false;

    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickTime(bool isStart) async {
              final initial = TimeOfDay(
                hour: (isStart ? startMinute : endMinute) ~/ 60,
                minute: (isStart ? startMinute : endMinute) % 60,
              );
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    startMinute = picked.hour * 60 + picked.minute;
                  } else {
                    endMinute = picked.hour * 60 + picked.minute;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text('${schedule.employeeType.label} Schedule'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => pickTime(true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Time',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(_minutesToClock(startMinute)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => pickTime(false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Time',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(_minutesToClock(endMinute)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: graceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Grace Period (min)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: breakController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Break Duration (min)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: otThresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'Overtime Start Threshold (min past end time)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Overtime Eligible'),
                        value: overtimeEligible,
                        onChanged: (v) =>
                            setDialogState(() => overtimeEligible = v),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('Working Days'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AESColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: dayNames.entries
                            .map(
                              (e) => FilterChip(
                                label: Text(e.value),
                                selected: workingDays.contains(e.key),
                                onSelected: (v) => setDialogState(() {
                                  if (v) {
                                    workingDays.add(e.key);
                                  } else {
                                    workingDays.remove(e.key);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (workingDays.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select at least one working day',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          schedule
                            ..startMinuteOfDay = startMinute
                            ..endMinuteOfDay = endMinute
                            ..gracePeriodMinutes =
                                int.tryParse(graceController.text.trim()) ??
                                schedule.gracePeriodMinutes
                            ..breakDurationMinutes =
                                int.tryParse(breakController.text.trim()) ??
                                schedule.breakDurationMinutes
                            ..overtimeStartThresholdMinutes =
                                int.tryParse(
                                  otThresholdController.text.trim(),
                                ) ??
                                schedule.overtimeStartThresholdMinutes
                            ..overtimeEligible = overtimeEligible
                            ..workingDays = (workingDays.toList()..sort());
                          try {
                            await DataService.saveWorkingSchedule(schedule);
                            await logPayrollAudit(
                              action: 'Working Schedule Updated',
                              performedByUsername: widget.currentUser.username,
                              details:
                                  '${schedule.employeeType.label}: ${schedule.startTimeLabel}-${schedule.endTimeLabel}',
                            );
                            if (context.mounted) {
                              setState(() {});
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (sampleWorkingSchedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 56,
                color: AESColors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No working schedules configured yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AESColors.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seeds the 3 default schedules from the spec (Field 9-6, Office 9:30-6, Executive) - fully editable after.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AESColors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _seeding ? null : _seedDefaults,
                icon: _seeding
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.playlist_add),
                label: Text(_seeding ? 'Seeding...' : 'Seed Default Schedules'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final schedules = List.of(sampleWorkingSchedules)
      ..sort((a, b) => a.employeeType.index.compareTo(b.employeeType.index));
    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: schedules
          .map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.employeeType.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AESColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.startTimeLabel} - ${s.endTimeLabel} · Grace ${s.gracePeriodMinutes}min · Break ${s.breakDurationMinutes}min',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AESColors.darkGrey,
                          ),
                        ),
                        Text(
                          'Working days: ${s.workingDays.map((d) => dayNames[d]).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AESColors.grey,
                          ),
                        ),
                        Text(
                          s.overtimeEligible
                              ? 'Overtime eligible (starts ${s.overtimeStartThresholdMinutes}min past end time)'
                              : 'Overtime not eligible',
                          style: TextStyle(
                            fontSize: 12,
                            color: s.overtimeEligible
                                ? AESColors.primaryGreen
                                : AESColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AESColors.primaryGreen,
                    ),
                    onPressed: () => _editSchedule(s),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalculationRulesTab extends StatefulWidget {
  final AppUser currentUser;
  const _CalculationRulesTab({required this.currentUser});
  @override
  State<_CalculationRulesTab> createState() => _CalculationRulesTabState();
}

class _CalculationRulesTabState extends State<_CalculationRulesTab> {
  late HourlyRateMethod _hourlyRateMethod;
  late final TextEditingController _monthlyHoursController;
  late final TextEditingController _daysPerMonthController;
  late final TextEditingController _hoursPerDayController;
  late final TextEditingController _payrollWorkingDaysController;
  late final TextEditingController _otMultiplierController;
  late DeductionMethod _lateMethod;
  late final TextEditingController _latePerMinuteController;
  late final TextEditingController _lateFixedController;
  late final TextEditingController _lateFreeOccurrencesController;
  late bool _earlyCheckoutEnabled;
  late DeductionMethod _earlyCheckoutMethod;
  late final TextEditingController _earlyPerMinuteController;
  late final TextEditingController _earlyFixedController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = samplePayrollSettings;
    _hourlyRateMethod = s.hourlyRateMethod;
    _monthlyHoursController = TextEditingController(
      text: s.monthlyWorkingHours.toStringAsFixed(0),
    );
    _daysPerMonthController = TextEditingController(
      text: s.workingDaysPerMonthForHourlyRate.toStringAsFixed(0),
    );
    _hoursPerDayController = TextEditingController(
      text: s.hoursPerWorkingDay.toStringAsFixed(0),
    );
    _payrollWorkingDaysController = TextEditingController(
      text: s.payrollWorkingDaysPerMonth.toStringAsFixed(0),
    );
    _otMultiplierController = TextEditingController(
      text: s.defaultOvertimeMultiplier.toString(),
    );
    _lateMethod = s.lateDeductionMethod;
    _latePerMinuteController = TextEditingController(
      text: s.lateDeductionPerMinuteRate.toString(),
    );
    _lateFixedController = TextEditingController(
      text: s.lateDeductionFixedAmount.toString(),
    );
    _lateFreeOccurrencesController = TextEditingController(
      text: s.lateProgressiveFreeOccurrences.toString(),
    );
    _earlyCheckoutEnabled = s.earlyCheckoutDeductionEnabled;
    _earlyCheckoutMethod = s.earlyCheckoutDeductionMethod;
    _earlyPerMinuteController = TextEditingController(
      text: s.earlyCheckoutDeductionPerMinuteRate.toString(),
    );
    _earlyFixedController = TextEditingController(
      text: s.earlyCheckoutDeductionFixedAmount.toString(),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final updated = PayrollSettings(
      hourlyRateMethod: _hourlyRateMethod,
      monthlyWorkingHours:
          double.tryParse(_monthlyHoursController.text.trim()) ?? 240,
      workingDaysPerMonthForHourlyRate:
          double.tryParse(_daysPerMonthController.text.trim()) ?? 26,
      hoursPerWorkingDay:
          double.tryParse(_hoursPerDayController.text.trim()) ?? 8,
      payrollWorkingDaysPerMonth:
          double.tryParse(_payrollWorkingDaysController.text.trim()) ?? 26,
      defaultOvertimeMultiplier:
          double.tryParse(_otMultiplierController.text.trim()) ?? 1.5,
      lateDeductionMethod: _lateMethod,
      lateDeductionPerMinuteRate:
          double.tryParse(_latePerMinuteController.text.trim()) ?? 0,
      lateDeductionFixedAmount:
          double.tryParse(_lateFixedController.text.trim()) ?? 0,
      lateProgressiveFreeOccurrences:
          int.tryParse(_lateFreeOccurrencesController.text.trim()) ?? 3,
      earlyCheckoutDeductionEnabled: _earlyCheckoutEnabled,
      earlyCheckoutDeductionMethod: _earlyCheckoutMethod,
      earlyCheckoutDeductionPerMinuteRate:
          double.tryParse(_earlyPerMinuteController.text.trim()) ?? 0,
      earlyCheckoutDeductionFixedAmount:
          double.tryParse(_earlyFixedController.text.trim()) ?? 0,
    );
    try {
      await DataService.savePayrollSettings(updated);
      await logPayrollAudit(
        action: 'Payroll Calculation Rules Updated',
        performedByUsername: widget.currentUser.username,
      );
      setState(() => samplePayrollSettings = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll settings saved'),
            backgroundColor: AESColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('Hourly Rate Calculation'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<HourlyRateMethod>(
          initialValue: _hourlyRateMethod,
          decoration: const InputDecoration(
            labelText: 'Method',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: HourlyRateMethod.monthlyHoursDirect,
              child: Text('Fixed monthly hours'),
            ),
            DropdownMenuItem(
              value: HourlyRateMethod.daysPerMonthTimesHoursPerDay,
              child: Text('Working days/month × hours/day'),
            ),
          ],
          onChanged: (v) =>
              setState(() => _hourlyRateMethod = v ?? _hourlyRateMethod),
        ),
        const SizedBox(height: 14),
        if (_hourlyRateMethod == HourlyRateMethod.monthlyHoursDirect)
          TextField(
            controller: _monthlyHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly Working Hours',
              helperText: 'Hourly Rate = Basic Salary / this number',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _daysPerMonthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Working Days / Month',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hoursPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hours / Working Day',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          tr('Daily Rate Calculation'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _payrollWorkingDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Payroll Working Days / Month',
            helperText: 'Daily Rate = Basic Salary / this number',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr('Overtime'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _otMultiplierController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Default Overtime Multiplier (e.g. 1.5)',
            helperText:
                'Used unless an employee has their own rate set on their profile',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr('Late Arrival Deduction'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AESColors.darkGreen,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<DeductionMethod>(
          initialValue: _lateMethod,
          decoration: const InputDecoration(
            labelText: 'Method',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: DeductionMethod.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: (v) => setState(() => _lateMethod = v ?? _lateMethod),
        ),
        if (_lateMethod == DeductionMethod.perMinute) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _latePerMinuteController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Deduction per Late Minute (Rs)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        if (_lateMethod == DeductionMethod.fixed ||
            _lateMethod == DeductionMethod.progressive) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _lateFixedController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fixed Deduction per Late Occurrence (Rs)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        if (_lateMethod == DeductionMethod.progressive) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _lateFreeOccurrencesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Free Occurrences Before Deduction Starts',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Early Checkout Deduction'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AESColors.darkGreen,
                ),
              ),
            ),
            Switch(
              value: _earlyCheckoutEnabled,
              onChanged: (v) => setState(() => _earlyCheckoutEnabled = v),
              activeThumbColor: AESColors.primaryGreen,
            ),
          ],
        ),
        if (_earlyCheckoutEnabled) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<DeductionMethod>(
            initialValue: _earlyCheckoutMethod,
            decoration: const InputDecoration(
              labelText: 'Method',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: DeductionMethod.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) => setState(
              () => _earlyCheckoutMethod = v ?? _earlyCheckoutMethod,
            ),
          ),
          if (_earlyCheckoutMethod == DeductionMethod.perMinute) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _earlyPerMinuteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Deduction per Early-Checkout Minute (Rs)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          if (_earlyCheckoutMethod == DeductionMethod.fixed) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _earlyFixedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fixed Deduction per Occurrence (Rs)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AESColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(tr('Save Settings')),
          ),
        ),
      ],
    );
  }
}

// ---------------- HOLIDAY CALENDAR TAB ----------------
class _HolidaysTab extends StatefulWidget {
  final AppUser currentUser;
  const _HolidaysTab({required this.currentUser});

  @override
  State<_HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends State<_HolidaysTab> {
  static const _regionOptions = ['All', 'Multan', 'Lahore', 'Faisalabad'];

  Future<void> _showHolidayDialog({Holiday? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    DateTime date = existing != null && existing.dateIso.isNotEmpty
        ? (DateTime.tryParse(existing.dateIso) ?? DateTime.now())
        : DateTime.now();
    String region = existing?.region ?? 'All';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Holiday' : 'Edit Holiday'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Holiday Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: region,
                      decoration: const InputDecoration(
                        labelText: 'Applies To',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _regionOptions
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r == 'All' ? 'All Regions' : r),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => region = v ?? region),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          final holiday = Holiday(
                            id: existing?.id ?? nextHolidayId(),
                            name: nameController.text.trim(),
                            dateIso:
                                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                            region: region,
                          );
                          try {
                            await DataService.saveHoliday(holiday);
                            await logPayrollAudit(
                              action: existing == null
                                  ? 'Holiday Added'
                                  : 'Holiday Updated',
                              performedByUsername: widget.currentUser.username,
                              details:
                                  '${holiday.name} on ${holiday.dateIso} (${holiday.region})',
                            );
                            if (mounted) {
                              setState(() {
                                final idx = sampleHolidays.indexWhere(
                                  (h) => h.id == holiday.id,
                                );
                                if (idx != -1) {
                                  sampleHolidays[idx] = holiday;
                                } else {
                                  sampleHolidays.add(holiday);
                                }
                              });
                            }
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHoliday(Holiday holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday?'),
        content: Text('Remove "${holiday.name}" (${holiday.dateIso})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteHoliday(holiday.id);
      await logPayrollAudit(
        action: 'Holiday Deleted',
        performedByUsername: widget.currentUser.username,
        details: '${holiday.name} on ${holiday.dateIso}',
      );
      if (mounted)
        setState(() => sampleHolidays.removeWhere((h) => h.id == holiday.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidays = List<Holiday>.from(sampleHolidays)
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Public/company holidays - paid, non-working days PayrollEngine excludes from Absent.',
                  style: TextStyle(color: AESColors.grey, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showHolidayDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Holiday'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (holidays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: AESColors.grey.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No holidays configured yet.',
                      style: TextStyle(color: AESColors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...holidays.map((h) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AESColors.darkGreen,
                            ),
                          ),
                          Text(
                            '${h.dateIso} · ${h.region == 'All' ? 'All Regions' : h.region}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AESColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showHolidayDialog(existing: h),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteHoliday(h),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
