part of '../main.dart';

// ---------------- PAYROLL DASHBOARD ----------------
// Charts/KPIs summarizing payroll data already computed by PayrollEngine and stored in
// samplePayrollRecords/samplePayrollPeriods - this screen never calculates anything itself,
// it only visualizes what Process Payroll already produced.
class PayrollDashboardScreen extends StatelessWidget {
  const PayrollDashboardScreen({super.key});

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final periods = List<PayrollPeriod>.from(samplePayrollPeriods)
      ..sort((a, b) => a.id.compareTo(b.id));
    final latestPeriod = periods.isNotEmpty ? periods.last : null;
    final latestRecords = latestPeriod != null
        ? payrollRecordsForPeriod(latestPeriod.id)
        : <PayrollRecord>[];

    final totalNet = latestRecords.fold(0.0, (s, r) => s + r.netSalary);
    final totalGross = latestRecords.fold(0.0, (s, r) => s + r.grossSalary);
    final totalOvertimePay = latestRecords.fold(
      0.0,
      (s, r) => s + r.overtimePay,
    );
    final totalOvertimeHours = latestRecords.fold(
      0.0,
      (s, r) => s + r.overtimeHours,
    );
    final avgNet = latestRecords.isEmpty
        ? 0.0
        : totalNet / latestRecords.length;

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payroll Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AESColors.darkGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              latestPeriod != null
                  ? 'Latest run: ${latestPeriod.monthLabel} (${latestPeriod.status.label})'
                  : 'No payroll has been run yet.',
              style: const TextStyle(color: AESColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        size: 48,
                        color: AESColors.grey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Run Process Payroll at least once to see charts here.',
                        style: TextStyle(color: AESColors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _kpiCard(
                    'Total Net Pay',
                    'Rs ${totalNet.toStringAsFixed(0)}',
                    AESColors.primaryGreen,
                    Icons.payments_outlined,
                  ),
                  _kpiCard(
                    'Total Gross Pay',
                    'Rs ${totalGross.toStringAsFixed(0)}',
                    const Color(0xFF2196F3),
                    Icons.account_balance_wallet_outlined,
                  ),
                  _kpiCard(
                    'Employees Paid',
                    '${latestRecords.length}',
                    const Color(0xFF9C27B0),
                    Icons.people_alt_outlined,
                  ),
                  _kpiCard(
                    'Avg Net Salary',
                    'Rs ${avgNet.toStringAsFixed(0)}',
                    const Color(0xFFFF9800),
                    Icons.trending_up,
                  ),
                  _kpiCard(
                    'Overtime Pay',
                    'Rs ${totalOvertimePay.toStringAsFixed(0)} (${totalOvertimeHours.toStringAsFixed(0)}h)',
                    Colors.redAccent,
                    Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final trendChart = _PayrollTrendChartCard(
                    periods: periods,
                    monthNames: _monthNames,
                  );
                  final typeChart = _EmployeeTypeBreakdownCard(
                    records: latestRecords,
                  );
                  final regionChart = _RegionBreakdownCard(
                    records: latestRecords,
                  );
                  final deductionsChart = _DeductionsBreakdownCard(
                    records: latestRecords,
                  );

                  if (isWide) {
                    return Column(
                      children: [
                        trendChart,
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: typeChart),
                            const SizedBox(width: 16),
                            Expanded(child: regionChart),
                          ],
                        ),
                        const SizedBox(height: 16),
                        deductionsChart,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      trendChart,
                      const SizedBox(height: 16),
                      typeChart,
                      const SizedBox(height: 16),
                      regionChart,
                      const SizedBox(height: 16),
                      deductionsChart,
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: 200,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AESColors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollTrendChartCard extends StatelessWidget {
  final List<PayrollPeriod> periods;
  final List<String> monthNames;
  const _PayrollTrendChartCard({
    required this.periods,
    required this.monthNames,
  });

  @override
  Widget build(BuildContext context) {
    final recent = periods.length > 6
        ? periods.sublist(periods.length - 6)
        : periods;
    final totals = [
      for (final p in recent)
        payrollRecordsForPeriod(p.id).fold(0.0, (s, r) => s + r.netSalary),
    ];
    final maxTotal = totals.fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payroll Cost Trend (Net Pay)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxTotal == 0 ? 1 : maxTotal * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= recent.length)
                          return const SizedBox.shrink();
                        final parts = recent[i].id.split('-');
                        final monthIdx = parts.length == 2
                            ? (int.tryParse(parts[1]) ?? 1) - 1
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            monthNames[monthIdx.clamp(0, 11)],
                            style: const TextStyle(
                              fontSize: 11,
                              color: AESColors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AESColors.nearBlack,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${recent[group.x].monthLabel}\nRs ${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < recent.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: totals[i],
                          color: AESColors.primaryGreen,
                          width: 26,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTypeBreakdownCard extends StatelessWidget {
  final List<PayrollRecord> records;
  const _EmployeeTypeBreakdownCard({required this.records});

  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
  ];

  @override
  Widget build(BuildContext context) {
    final totals = <EmployeeType, double>{
      for (final t in EmployeeType.values) t: 0,
    };
    for (final r in records) {
      totals[r.employeeType] = (totals[r.employeeType] ?? 0) + r.netSalary;
    }
    final total = totals.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Pay by Employee Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No data yet',
                  style: TextStyle(color: AESColors.grey, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(enabled: true),
                  sections: [
                    for (int i = 0; i < EmployeeType.values.length; i++)
                      if ((totals[EmployeeType.values[i]] ?? 0) > 0)
                        PieChartSectionData(
                          value: totals[EmployeeType.values[i]],
                          color: _colors[i % _colors.length],
                          radius: 50,
                          title:
                              '${(totals[EmployeeType.values[i]]! / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (int i = 0; i < EmployeeType.values.length; i++)
                _chartLegendDot(
                  _colors[i % _colors.length],
                  '${EmployeeType.values[i].label} (Rs ${(totals[EmployeeType.values[i]] ?? 0).toStringAsFixed(0)})',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionBreakdownCard extends StatelessWidget {
  final List<PayrollRecord> records;
  const _RegionBreakdownCard({required this.records});

  static const _regions = ['Multan', 'Lahore', 'Faisalabad'];
  static const _colors = [
    Color(0xFFF3B41B),
    Color(0xFF1B7A3D),
    Color(0xFF00897B),
  ];

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{for (final r in _regions) r: 0};
    for (final rec in records) {
      totals[rec.region] = (totals[rec.region] ?? 0) + rec.netSalary;
    }
    final total = totals.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Pay by Region',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No data yet',
                  style: TextStyle(color: AESColors.grey, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(enabled: true),
                  sections: [
                    for (int i = 0; i < _regions.length; i++)
                      if ((totals[_regions[i]] ?? 0) > 0)
                        PieChartSectionData(
                          value: totals[_regions[i]],
                          color: _colors[i],
                          radius: 50,
                          title:
                              '${(totals[_regions[i]]! / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _regions.length; i++)
                _chartLegendDot(
                  _colors[i],
                  '${_regions[i]} (Rs ${(totals[_regions[i]] ?? 0).toStringAsFixed(0)})',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeductionsBreakdownCard extends StatelessWidget {
  final List<PayrollRecord> records;
  const _DeductionsBreakdownCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final lateTotal = records.fold(0.0, (s, r) => s + r.lateDeduction);
    final earlyTotal = records.fold(
      0.0,
      (s, r) => s + r.earlyCheckoutDeduction,
    );
    final manualTotal = records.fold(
      0.0,
      (s, r) => s + r.manualDeductionsTotal,
    );
    final maxVal = [
      lateTotal,
      earlyTotal,
      manualTotal,
    ].fold(0.0, (m, v) => v > m ? v : m);
    final labels = ['Late Arrival', 'Early Checkout', 'Manual Deductions'];
    final values = [lateTotal, earlyTotal, manualTotal];
    const colors = [Color(0xFFFF9800), Color(0xFF9C27B0), Colors.redAccent];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deductions Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AESColors.darkGreen,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 1 : maxVal * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AESColors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AESColors.nearBlack,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${labels[group.x]}\nRs ${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: colors[i],
                          width: 30,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
