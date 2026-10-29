import 'package:flutter/material.dart';
import '../models/attendance_model.dart';

// --- KELAS UTAMA ---
class HomeScreen extends StatefulWidget {
  // TARUH DI SINI (Harus ada kata kunci 'static' dan berada di dalam kelas HomeScreen)
  static List<AttendanceModel> attendanceHistory = [];

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// --- KELAS STATE ---
class _HomeScreenState extends State<HomeScreen> {
  // Semua fungsi dan tampilan (widget) Anda berada di dalam sini...
  
  void _handleCheckIn() {
    setState(() {
      // Menambahkan data absensi ke dalam list static HomeScreen
      HomeScreen.attendanceHistory.add(
        AttendanceModel(
          date: "28 Oktober 2026",
          checkInTime: "08:00",
          checkOutTime: "-",
          status: "Hadir",
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Utama Absensi')),
      body: Center(
        child: ElevatedButton(
          onPressed: _handleCheckIn,
          child: const Text('Absen Masuk'),
        ),
      ),
    );
  }
}