import 'package:flutter/material.dart';
import 'home_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyList = HomeScreen.attendanceHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
      ),
      body: historyList.isEmpty
          ? const Center(
              child: Text('Belum ada riwayat absensi.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final item = historyList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.calendar_today, color: Colors.white),
                    ),
                    title: Text(item.date, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Masuk: ${item.checkInTime}  |  Pulang: ${item.checkOutTime}'),
                    trailing: Chip(
                      label: Text(item.status),
                      backgroundColor: Colors.green[100],
                      labelStyle: const TextStyle(color: Colors.green),
                    ),
                  ),
                );
              },
            ),
    );
  }
}