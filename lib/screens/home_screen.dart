import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song_info.dart';
import '../services/suno_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final SunoService _sunoService = SunoService();

  SongInfo? _songInfo;
  bool _isLoadingInfo = false;
  bool _isDownloading = false;
  String _statusMessage = 'Suno şarkı bağlantısını yapıştırıp indirin.';
  double _downloadProgress = 0.0;

  String _selectedFormat = 'MP3';
  final List<String> _formats = ['MP3', 'M4A', 'WAV', 'MP4'];

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _urlController.text = data.text!.trim();
      _fetchSongInfo();
    }
  }

  Future<void> _fetchSongInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Lütfen bir Suno linki girin', isError: true);
      return;
    }

    setState(() {
      _isLoadingInfo = true;
      _statusMessage = 'Şarkı bilgileri çekiliyor...';
    });

    try {
      final info = await _sunoService.fetchSongInfo(url);
      setState(() {
        _songInfo = info;
        _isLoadingInfo = false;
        _statusMessage = 'Şarkı hazır. İndirme formatını seçin.';
      });
    } catch (e) {
      setState(() {
        _isLoadingInfo = false;
        _statusMessage = 'Hata: $e';
      });
      _showSnackBar('Bilgiler alınamadı: $e', isError: true);
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Lütfen bir link girin', isError: true);
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
      _statusMessage = 'İndirme başlatılıyor...';
    });

    try {
      final info = _songInfo ?? await _sunoService.fetchSongInfo(url);
      _songInfo = info;

      File outputFile;
      final safeName = info.safeFilename;

      Directory? baseDir;
      try {
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final testDir = Directory('${downloadDir.path}/Suno_Downloads');
            await testDir.create(recursive: true);
            baseDir = downloadDir;
          }
        }
      } catch (_) {
        baseDir = null;
      }

      if (baseDir == null) {
        try {
          baseDir = await getExternalStorageDirectory();
        } catch (_) {}
      }

      baseDir ??= await getApplicationDocumentsDirectory();
      final targetFolder = Directory('${baseDir.path}/Suno_Downloads');
      if (!await targetFolder.exists()) {
        await targetFolder.create(recursive: true);
      }

      if (_selectedFormat == 'MP4') {
        setState(() {
          _statusMessage = 'MP4 video klibi indiriliyor...';
          _downloadProgress = 0.4;
        });
        final resp = await http.get(Uri.parse(info.videoUrl));
        outputFile = File('${targetFolder.path}/$safeName.mp4');
        await outputFile.writeAsBytes(resp.bodyBytes);
      } else {
        setState(() {
          _statusMessage = 'Ses yetkilendirmesi alınıyor...';
          _downloadProgress = 0.3;
        });
        final rights = await _sunoService.fetchRights(info.id);

        setState(() {
          _statusMessage = 'Şifreli ses indiriliyor...';
          _downloadProgress = 0.5;
        });
        final audioResp = await http.get(Uri.parse(info.audioStreamUrl));

        setState(() {
          _statusMessage = 'Ses şifresi çözülüyor (AES-CTR)...';
          _downloadProgress = 0.8;
        });
        final decryptedBytes = await _sunoService.decryptAudio(
          encryptedBytes: audioResp.bodyBytes,
          rights: rights,
          songId: info.id,
        );

        final ext = _selectedFormat.toLowerCase();
        outputFile = File('${targetFolder.path}/$safeName.$ext');
        await outputFile.writeAsBytes(decryptedBytes);
      }

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _statusMessage = '✅ İndirme tamamlandı: ${outputFile.path}';
      });

      _showSuccessDialog(outputFile);
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'İndirme hatası: $e';
      });
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  void _showSuccessDialog(File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 İndirme Tamamlandı'),
        content: Text(
          'Dosyanız kaydedildi:\n${file.path}\n\n'
          'Dosyayı müzik çalarınızda açmak veya paylaşmak ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles(
                [XFile(file.path)],
                text: _songInfo?.title ?? 'Suno Şarkısı',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Aç / Paylaş'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Bağlantı açılamadı: $url', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🎵 Suno AI Şarkı İndirici',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // URL Input Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suno Şarkı Bağlantısı:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: 'https://suno.com/song/... veya /s/...',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _pasteClipboard,
                            icon: const Icon(Icons.paste),
                            tooltip: 'Yapıştır',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingInfo ? null : _fetchSongInfo,
                          icon: _isLoadingInfo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Bilgileri Getir'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Song Preview Card
              if (_songInfo != null) ...[
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _songInfo!.imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note, size: 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _songInfo!.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _songInfo!.handle.isNotEmpty
                                    ? '@${_songInfo!.handle}'
                                    : 'Suno AI',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              if (_songInfo!.duration != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Süre: ${_songInfo!.duration!.toStringAsFixed(1)} sn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                              if (_songInfo!.tags.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _songInfo!.tags,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Format Selection Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İndirme Formatı:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _formats.map((fmt) {
                          final isSelected = _selectedFormat == fmt;
                          return ChoiceChip(
                            label: Text(fmt),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedFormat = fmt);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Download Button & Progress
              if (_isDownloading) ...[
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
              ],
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 10),

              FilledButton.icon(
                onPressed: _isDownloading ? null : _startDownload,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.download),
                label: Text(
                  _isDownloading ? 'İndiriliyor...' : 'Şarkıyı İndir ($_selectedFormat)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // Channels Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎧 Kanallarımız',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),

                      // Aykırı Mısra
                      const Text(
                        'Aykırı Mısra',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                'https://www.youtube.com/channel/UCZH31WrVekNeldKMAD2fB7A',
                              ),
                              icon: const Icon(Icons.play_arrow, color: Colors.red),
                              label: const Text('YouTube'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                'https://open.spotify.com/intl-tr/artist/3GSbp9n7nO5OSAgyFJ7yfJ?si=R0NmYqubS1eCSPLubqFVpw',
                              ),
                              icon: const Icon(Icons.music_note, color: Colors.green),
                              label: const Text('Spotify'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Kürşat Alper ALKAÇIR
                      const Text(
                        'Kürşat Alper ALKAÇIR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                'https://www.youtube.com/channel/UCkpqBdHDBlerYE9TngEqSsQ',
                              ),
                              icon: const Icon(Icons.play_arrow, color: Colors.red),
                              label: const Text('YouTube'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                'https://open.spotify.com/intl-tr/artist/7eG4xDmU08SeMrkwrqAVJ7?si=qSMNn7kLQeG3wt4FhEgaHg',
                              ),
                              icon: const Icon(Icons.music_note, color: Colors.green),
                              label: const Text('Spotify'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Producer & Rights Footer
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yapımcı: Kürşat Alper ALKAÇIR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tüm Hakları Saklıdır',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Aykırı Mısra Production',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
