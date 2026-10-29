import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

void main() => runApp(const AbsensiApp());

class AbsensiApp extends StatelessWidget {
  const AbsensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Sekolah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F6B5C),
        useMaterial3: true,
      ),
      home: const AbsensiPage(),
    );
  }
}

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  static const _kunci = 'absensi_riwayat';

  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _jurusan = TextEditingController();
  final _absen = TextEditingController();

  String? _kelas;
  Position? _posisi;
  String? _errLokasi;
  bool _loadingLokasi = false;
  bool _mengirim = false;
  List<Map<String, dynamic>> _riwayat = [];

  @override
  void initState() {
    super.initState();
    _muatRiwayat();
  }

  @override
  void dispose() {
    _nama.dispose();
    _jurusan.dispose();
    _absen.dispose();
    super.dispose();
  }

  // ===== Riwayat di HP =====
  Future<void> _muatRiwayat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kunci);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _riwayat = list.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _simpanRiwayat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunci, jsonEncode(_riwayat));
  }

  // ===== Bagikan lokasi =====
  Future<void> _ambilLokasi() async {
    setState(() {
      _loadingLokasi = true;
      _errLokasi = null;
    });
    try {
      final aktif = await Geolocator.isLocationServiceEnabled();
      if (!aktif) throw 'GPS belum menyala. Nyalakan GPS lalu coba lagi.';

      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied) {
        throw 'Izin lokasi ditolak. Izinkan lokasi lalu coba lagi.';
      }
      if (izin == LocationPermission.deniedForever) {
        throw 'Izin lokasi diblokir. Aktifkan di Pengaturan aplikasi.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _posisi = pos);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posisi = null;
        _errLokasi = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingLokasi = false);
    }
  }

  String _dua(int n) => n.toString().padLeft(2, '0');

  // ===== Kirim ke server =====
  Future<({bool ok, String pesan})> _kirimKeServer(Map<String, dynamic> d) async {
    try {
      final res = await http
          .post(
            Uri.parse(urlAbsen),
            headers: headerJson,
            body: jsonEncode({
              'nama': d['nama'],
              'kelas': d['kelas'],
              'jurusan': d['jurusan'],
              'absen': d['absen'],
              'lat': d['lat'],
              'lng': d['lng'],
              'akurasi': _posisi?.accuracy.round(),
            }),
          )
          .timeout(batasWaktu);

      Map<String, dynamic> j = {};
      try {
        j = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      if (res.statusCode == 200) {
        return (ok: true, pesan: j['pesan']?.toString() ?? 'Absensi terkirim.');
      }

      final cuplikan =
          res.body.length > 100 ? res.body.substring(0, 100) : res.body;
      return (
        ok: false,
        pesan: j['error']?.toString() ??
            'Server menolak (${res.statusCode}): $cuplikan'
      );
    } catch (_) {
      return (
        ok: false,
        pesan: 'Tidak bisa terhubung ke server. Pastikan internet aktif dan '
            'server sedang berjalan.'
      );
    }
  }

  Future<void> _kirim() async {
    if (_mengirim) return;
    final valid = _formKey.currentState!.validate();
    if (_posisi == null) {
      setState(() => _errLokasi = 'Bagikan lokasi dulu sebelum mengirim.');
    }
    if (!valid || _posisi == null) return;

    final now = DateTime.now();
    final data = <String, dynamic>{
      'nama': _nama.text.trim(),
      'kelas': _kelas,
      'jurusan': _jurusan.text.trim(),
      'absen': int.parse(_absen.text.trim()),
      'tanggal': '${_dua(now.day)}/${_dua(now.month)}/${now.year}',
      'jam': '${_dua(now.hour)}:${_dua(now.minute)}:${_dua(now.second)}',
      'lat': _posisi!.latitude,
      'lng': _posisi!.longitude,
    };

    setState(() => _mengirim = true);
    final hasil = await _kirimKeServer(data);
    if (!mounted) return;
    setState(() => _mengirim = false);

    if (!hasil.ok) {
      _snack(hasil.pesan);
      return;
    }

    _riwayat.insert(0, data);
    await _simpanRiwayat();
    if (!mounted) return;
    setState(() {
      _nama.clear();
      _absen.clear();
    });
    _snack(hasil.pesan);
  }

  Future<void> _hapusRiwayat() async {
    if (_riwayat.isEmpty) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text(
            'Riwayat di HP ini akan dihapus. Data di server tidak terhapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ya == true) {
      setState(() => _riwayat = []);
      await _simpanRiwayat();
    }
  }

  void _snack(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Absensi Sekolah')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nama,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Isi nama lengkap (minimal 3 huruf).'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _kelas,
                          decoration: const InputDecoration(
                            labelText: 'Kelas',
                            border: OutlineInputBorder(),
                          ),
                          items: daftarKelas
                              .map((k) =>
                                  DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (v) => setState(() => _kelas = v),
                          validator: (v) => v == null ? 'Pilih kelas.' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _jurusan,
                          decoration: const InputDecoration(
                            labelText: 'Jurusan',
                            hintText: 'RPL / IPA 1',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Isi jurusan.'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _absen,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor absen',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1 || n > 99) {
                        return 'Isi nomor absen 1–99.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_posisi == null
                              ? 'Lokasi belum dibagikan.'
                              : 'Lokasi berhasil dibagikan.'),
                          if (_posisi != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_posisi!.latitude.toStringAsFixed(6)}, '
                              '${_posisi!.longitude.toStringAsFixed(6)} '
                              '(akurasi ±${_posisi!.accuracy.round()} m)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (_errLokasi != null) ...[
                            const SizedBox(height: 4),
                            Text(_errLokasi!,
                                style:
                                    TextStyle(color: tema.colorScheme.error)),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loadingLokasi ? null : _ambilLokasi,
                            icon: _loadingLokasi
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_posisi == null
                                ? 'Bagikan lokasi'
                                : 'Perbarui lokasi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _mengirim ? null : _kirim,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                    child: Text(_mengirim ? 'Mengirim…' : 'Kirim absensi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text('Riwayat absensi saya',
                      style: tema.textTheme.titleMedium),
                ),
                TextButton(
                    onPressed: _hapusRiwayat,
                    child: const Text('Hapus riwayat')),
              ],
            ),
            if (_riwayat.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada absensi tercatat.'),
              )
            else
              ..._riwayat.map(
                (r) => Card(
                  child: ListTile(
                    title: Text('${r['nama']}'),
                    subtitle: Text(
                      'Kelas ${r['kelas']} ${r['jurusan']} • No. ${r['absen']}\n'
                      '${r['tanggal']} ${r['jam']}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}