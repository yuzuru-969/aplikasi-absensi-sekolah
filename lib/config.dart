// lib/config.dart
// Pengaturan server yang dipakai di semua file.

// --- ALAMAT SERVER ---
// Lewat ngrok (HP tidak perlu satu Wi-Fi dengan laptop).
// Ganti dengan alamat yang tampil di terminal ngrok.
const String baseUrl = 'https://rearview-juggle-legwork.ngrok-free.dev';

// Alternatif tanpa ngrok (HP dan laptop satu Wi-Fi), hapus // lalu ganti IP-nya:
// const String baseUrl = 'http://192.168.1.10:5000';
// Emulator Android:
// const String baseUrl = 'http://10.0.2.2:5000';

// Alamat endpoint penerima absensi
const String urlAbsen = '$baseUrl/api/absen';

// Header untuk semua permintaan ke server.
// 'ngrok-skip-browser-warning' mencegah ngrok gratis menyisipkan halaman peringatan.
const Map<String, String> headerJson = {
  'Content-Type': 'application/json',
  'ngrok-skip-browser-warning': 'true',
};

// Batas waktu menunggu jawaban server
const Duration batasWaktu = Duration(seconds: 15);

// Pilihan kelas di form
const List<String> daftarKelas = ['X', 'XI', 'XII'];