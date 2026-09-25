import 'package:flutter/material.dart';

class WorkOrderListScreen extends StatefulWidget {
  const WorkOrderListScreen({super.key});

  @override
  State<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends State<WorkOrderListScreen> {
  final List<Map<String, dynamic>> _workOrders = [
    {
      'id': 'WO-2026-001',
      'siteName': 'HBL Bank Regional HQ',
      'region': 'Lahore',
      'status': 'Pending Employee',
      'priority': 'High',
      'date': '2026-07-11',
    },
    {
      'id': 'WO-2026-002',
      'siteName': 'Nishat Mills Unit 3',
      'region': 'Faisalabad',
      'status': 'Back Office Review',
      'priority': 'Medium',
      'date': '2026-07-10',
    },
    {
      'id': 'WO-2026-003',
      'siteName': 'Metro Cash & Carry',
      'region': 'Multan',
      'status': 'Manager Approval',
      'priority': 'Low',
      'date': '2026-07-09',
    },
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending Employee': return Colors.orange;
      case 'Back Office Review': return Colors.blue;
      case 'Manager Approval': return Colors.purple;
      case 'Completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders / ورک آرڈرز', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: _workOrders.length,
          itemBuilder: (context, index) {
            final order = _workOrders[index];
            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  order['siteName'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('ID: ${order['id']}'),
                    const SizedBox(height: 4),
                    Text('Region / علاقہ: ${order['region']}'),
                    const SizedBox(height: 4),
                    Text('Date: ${order['date']}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order['priority'] == 'High' ? Colors.red[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Priority: ${order['priority']}',
                        style: TextStyle(
                          color: order['priority'] == 'High' ? Colors.red[900] : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order['status'],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening ${order['id']}')),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}