part of '../main.dart';

// ---------------- EMPLOYEE PAYROLL (Payroll Profiles) ----------------
class EmployeePayrollScreen extends StatefulWidget {
  final AppUser currentUser;
  const EmployeePayrollScreen({super.key, required this.currentUser});

  @override
  State<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends State<EmployeePayrollScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final list = await AuthService.listEmployees();
    if (mounted) {
      setState(() {
        _employees =
            list
                .where(
                  (e) =>
                      e['active'] == true &&
                      roleFromString(e['role']) != UserRole.vendor,
                )
                .toList()
              ..sort(
                (a, b) => (a['username'] as String).compareTo(
                  b['username'] as String,
                ),
              );
        _loading = false;
      });
    }
  }

  Future<void> _showProfileDialog(Map<String, dynamic> employee) async {
    final username = employee['username'] as String;
    final existing = payrollProfileFor(username);
    EmployeeType employeeType =
        existing?.employeeType ?? EmployeeType.fieldStaff;
    final departmentController = TextEditingController(
      text: existing?.department ?? '',
    );
    DateTime joiningDate =
        existing != null && existing.joiningDateIso.isNotEmpty
        ? (DateTime.tryParse(existing.joiningDateIso) ?? DateTime.now())
        : DateTime.now();
    final salaryController = TextEditingController(
      text: existing != null
          ? existing.basicMonthlySalary.toStringAsFixed(0)
          : '',
    );
    bool overtimeEligible = existing?.overtimeEligible ?? true;
    final overtimeRateController = TextEditingController(
      text: existing?.overtimeMultiplier?.toString() ?? '',
    );
    String paymentMethod = existing?.paymentMethod ?? 'Bank Transfer';
    final bankNameController = TextEditingController(
      text: existing?.bankName ?? '',
    );
    final bankAccountController = TextEditingController(
      text: existing?.bankAccountNumber ?? '',
    );
    PayrollProfileStatus status =
        existing?.status ?? PayrollProfileStatus.active;
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final salaryChanged =
                existing != null &&
                double.tryParse(salaryController.text.trim()) != null &&
                double.parse(salaryController.text.trim()) !=
                    existing.basicMonthlySalary;
            return AlertDialog(
              title: Text('Payroll Profile - $username'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<EmployeeType>(
                        initialValue: employeeType,
                        decoration: const InputDecoration(
                          labelText: 'Employee Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: EmployeeType.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(
                          () => employeeType = v ?? employeeType,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: joiningDate,
                            firstDate: DateTime(2015),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null)
                            setDialogState(() => joiningDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Joining Date',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            '${joiningDate.year}-${joiningDate.month.toString().padLeft(2, '0')}-${joiningDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: salaryController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Basic Monthly Salary (Rs)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          errorText: error,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (salaryChanged) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Salary change: Rs ${existing.basicMonthlySalary.toStringAsFixed(0)} → Rs ${salaryController.text.trim()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: reasonController,
                                decoration: const InputDecoration(
                                  labelText: 'Reason for change',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Overtime Eligible'),
                        value: overtimeEligible,
                        onChanged: (v) =>
                            setDialogState(() => overtimeEligible = v),
                      ),
                      if (overtimeEligible) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: overtimeRateController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Overtime Multiplier (optional)',
                            hintText:
                                'Default: ${samplePayrollSettings.defaultOvertimeMultiplier}x',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const ['Bank Transfer', 'Cash', 'Cheque']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(
                          () => paymentMethod = v ?? paymentMethod,
                        ),
                      ),
                      if (paymentMethod == 'Bank Transfer') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: bankNameController,
                          decoration: const InputDecoration(
                            labelText: 'Bank Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: bankAccountController,
                          decoration: const InputDecoration(
                            labelText: 'Account Number / IBAN',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<PayrollProfileStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Payroll Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: PayrollProfileStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => status = v ?? status),
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
                          final salary = double.tryParse(
                            salaryController.text.trim(),
                          );
                          if (salary == null || salary < 0) {
                            setDialogState(
                              () => error = 'Enter a valid salary',
                            );
                            return;
                          }
                          setDialogState(() {
                            error = null;
                            isSubmitting = true;
                          });
                          final profile = PayrollProfile(
                            username: username,
                            employeeType: employeeType,
                            department: departmentController.text.trim(),
                            joiningDateIso: joiningDate.toIso8601String(),
                            basicMonthlySalary: salary,
                            overtimeEligible: overtimeEligible,
                            overtimeMultiplier: overtimeEligible
                                ? double.tryParse(
                                    overtimeRateController.text.trim(),
                                  )
                                : null,
                            paymentMethod: paymentMethod,
                            bankName:
                                paymentMethod == 'Bank Transfer' &&
                                    bankNameController.text.trim().isNotEmpty
                                ? bankNameController.text.trim()
                                : null,
                            bankAccountNumber:
                                paymentMethod == 'Bank Transfer' &&
                                    bankAccountController.text.trim().isNotEmpty
                                ? bankAccountController.text.trim()
                                : null,
                            status: status,
                            createdAt: existing?.createdAt,
                            updatedAt: DateTime.now().toIso8601String(),
                          );
                          try {
                            await DataService.savePayrollProfile(profile);
                            await logPayrollAudit(
                              action: existing == null
                                  ? 'Payroll Profile Created'
                                  : 'Payroll Profile Updated',
                              performedByUsername: widget.currentUser.username,
                              targetUsername: username,
                              details:
                                  '${profile.employeeType.label}, Rs ${profile.basicMonthlySalary.toStringAsFixed(0)}, ${profile.status.label}',
                            );
                            // Salary history is append-only and logged automatically here, not
                            // as a separate manual step - any time the saved salary differs
                            // from what was there before, per section 20.
                            if (existing != null &&
                                existing.basicMonthlySalary != salary) {
                              final histEntry = SalaryHistoryEntry(
                                username: username,
                                oldSalary: existing.basicMonthlySalary,
                                newSalary: salary,
                                effectiveDateIso: DateTime.now()
                                    .toIso8601String(),
                                changedByUsername: widget.currentUser.username,
                                reason: reasonController.text.trim(),
                              );
                              await DataService.saveSalaryHistoryEntry(
                                histEntry,
                              );
                              sampleSalaryHistory.add(histEntry);
                              await logPayrollAudit(
                                action: 'Salary Changed',
                                performedByUsername:
                                    widget.currentUser.username,
                                targetUsername: username,
                                details:
                                    'Rs ${existing.basicMonthlySalary.toStringAsFixed(0)} -> Rs ${salary.toStringAsFixed(0)}${reasonController.text.trim().isNotEmpty ? ' (${reasonController.text.trim()})' : ''}',
                              );
                            }
                            setState(() {
                              final idx = samplePayrollProfiles.indexWhere(
                                (p) => p.username == username,
                              );
                              if (idx != -1) {
                                samplePayrollProfiles[idx] = profile;
                              } else {
                                samplePayrollProfiles.add(profile);
                              }
                            });
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
                      : Text(
                          existing == null ? 'Create Profile' : 'Save Changes',
                        ),
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
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: AESColors.primaryGreen),
      );
    final q = _searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _employees
        : _employees
              .where((e) => (e['username'] as String).toLowerCase().contains(q))
              .toList();

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Payroll',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_employees.length} employees · ${samplePayrollProfiles.length} with a payroll profile',
              style: const TextStyle(color: AESColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListSearchField(
              controller: _searchController,
              hintText: 'Search employees...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 20),
            ...filtered.map((e) {
              final username = e['username'] as String;
              final profile = payrollProfileFor(username);
              return PressableScale(
                onTap: () => _showProfileDialog(e),
                child: Container(
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
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AESColors.darkGreen,
                              ),
                            ),
                            Text(
                              '${e['role'] != null ? roleFromString(e['role']).label : ''} · ${e['region']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AESColors.grey,
                              ),
                            ),
                            if (profile != null)
                              Text(
                                '${profile.employeeType.label} · ${profile.department.isEmpty ? 'No department' : profile.department}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AESColors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (profile == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'No Profile',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'Rs ${profile.basicMonthlySalary.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AESColors.darkGrey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (profile.status == PayrollProfileStatus.active
                                        ? AESColors.primaryGreen
                                        : AESColors.grey)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.status.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  profile.status == PayrollProfileStatus.active
                                  ? AESColors.primaryGreen
                                  : AESColors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
