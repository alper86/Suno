import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import '../models/song_info.dart';

class SunoService {
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  static const Map<String, String> rightsHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Origin': 'https://usesuno.com',
    'Referer': 'https://usesuno.com/tools/downloader'
  };

  static const String rightsEndpoint = 'https://yellow-salad.aibiei.com/rights';
  static const String audioBaseUrl =
      'https://d2lwuy8qc234o3.cloudfront.net/1/clip/';

  final RegExp _uuidRegex = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );

  String? extractSongId(String input) {
    final match = _uuidRegex.firstMatch(input);
    return match?.group(0)?.toLowerCase();
  }

  Future<String> resolveUrl(String url) async {
    if (url.contains('suno.com/s/')) {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url))
          ..followRedirects = true
          ..headers.addAll(defaultHeaders);
        final response = await client.send(request);
        return response.headers['location'] ?? url;
      } finally {
        client.close();
      }
    }
    return url;
  }

  String _extractField(String html, String field) {
    // 1. Escaped format: \"field\":\"...\"
    final escapedRegex = RegExp(
      '\\\\"$field\\\\":\\s*\\\\"(.*?)(?<!\\\\)\\\\"',
      dotAll: true,
    );
    var match = escapedRegex.firstMatch(html);
    if (match != null) {
      var val = match.group(1)?.replaceAll('\\"', '"') ?? '';
      try {
        val = json.decode('"$val"') as String;
      } catch (_) {}
      return val.trim();
    }

    // 2. Unescaped format: "field":"..."
    final unescapedRegex = RegExp(
      '"$field":\\s*"(.*?)(?<!\\\\)"',
      dotAll: true,
    );
    match = unescapedRegex.firstMatch(html);
    if (match != null) {
      var val = match.group(1) ?? '';
      try {
        val = json.decode('"$val"') as String;
      } catch (_) {}
      return val.trim();
    }

    return '';
  }

  Future<SongInfo> fetchSongInfo(String inputUrl) async {
    var cleanUrl = inputUrl.trim();
    cleanUrl = await resolveUrl(cleanUrl);

    var songId = extractSongId(cleanUrl);
    if (songId == null) {
      throw Exception("Geçersiz Suno URL veya ID: '$inputUrl'");
    }

    final targetUri = cleanUrl.startsWith('http')
        ? Uri.parse(cleanUrl)
        : Uri.parse('https://suno.com/song/$songId');

    final resp = await http.get(targetUri, headers: defaultHeaders);
    if (resp.statusCode != 200) {
      throw Exception('Şarkı sayfası yüklenemedi (HTTP ${resp.statusCode})');
    }

    final html = resp.body;

    // Extract title from og:title
    String title = '';
    final ogTitleRegex = RegExp(
      r'<meta\s+property=["\']og:title["\']\s+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final titleMatch = ogTitleRegex.firstMatch(html);
    if (titleMatch != null) {
      var raw = titleMatch.group(1) ?? '';
      title = raw.replaceAll(RegExp(r'\s*\|\s*Suno.*$', caseSensitive: false), '');
      title = title.replaceAll(RegExp(r'\s*by\s+@[^\s|]+', caseSensitive: false), '').trim();
    }
    if (title.isEmpty) {
      title = _extractField(html, 'title');
      if (title.isEmpty) title = 'Suno Track';
    }

    // Extract handle / artist
    String handle = '';
    final handleMatch = RegExp(r'\\\"handle\\\":\s*\\\"([a-zA-Z0-9_\-]+)\\\"').firstMatch(html) ??
        RegExp(r'"handle":\s*"([a-zA-Z0-9_\-]+)"').firstMatch(html) ??
        RegExp(r'by\s+@([a-zA-Z0-9_\-]+)').firstMatch(html);
    if (handleMatch != null) {
      handle = handleMatch.group(1)?.trim() ?? '';
    }

    // Extract tags
    final tags = _extractField(html, 'tags');

    // Extract duration
    double? duration;
    final durMatch = RegExp(r'\\\"duration\\\":\s*([0-9.]+)').firstMatch(html) ??
        RegExp(r'"duration":\s*([0-9.]+)').firstMatch(html);
    if (durMatch != null) {
      duration = double.tryParse(durMatch.group(1) ?? '');
    }

    // Extract image URL
    String imageUrl = 'https://cdn2.suno.ai/image_large_$songId.jpeg';
    final ogImgMatch = RegExp(
      r'<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogImgMatch != null && ogImgMatch.group(1)?.startsWith('http') == true) {
      imageUrl = ogImgMatch.group(1)!;
    }

    // Extract video URL
    String videoUrl = 'https://cdn1.suno.ai/$songId.mp4';
    final videoMatch = RegExp(r'\\\"video_url\\\":\s*\\\"(https://[^\s\"\\]+)\\\"').firstMatch(html) ??
        RegExp(r'"video_url":\s*"(https://[^\s"]+)"').firstMatch(html);
    if (videoMatch != null) {
      videoUrl = videoMatch.group(1)!;
    }

    // Extract audio stream URL
    String audioStreamUrl = '$audioBaseUrl$songId.m4a';
    final audioMatch = RegExp(
      r'https://[a-zA-Z0-9.\-]+\.cloudfront\.net/1/clip/[0-9a-f\-]+(?:\.m4a|\.mp3|\.mp4)',
    ).firstMatch(html);
    if (audioMatch != null) {
      audioStreamUrl = audioMatch.group(0)!;
    }

    return SongInfo(
      id: songId,
      title: title,
      handle: handle,
      duration: duration,
      tags: tags,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      audioStreamUrl: audioStreamUrl,
    );
  }

  Future<Map<String, dynamic>> fetchRights(String songId) async {
    final body = json.encode({
      'content_params': {
        'content_id': songId,
        'content_type': 'clip',
      }
    });

    final resp = await http.post(
      Uri.parse(rightsEndpoint),
      headers: rightsHeaders,
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Ses yetkilendirmesi başarısız (HTTP ${resp.statusCode})');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['key'] == null || data['iv'] == null || data['glt'] == null) {
      throw Exception('Yetkilendirme verisi eksik');
    }
    return data;
  }

  Future<Uint8List> decryptAudio({
    required Uint8List encryptedBytes,
    required Map<String, dynamic> rights,
    required String songId,
  }) async {
    final glt = rights['glt'] as String;
    final sha256Algo = Sha256();
    final userKeyHash = await sha256Algo.hash(utf8.encode(glt));
    final userKeyBytes = userKeyHash.bytes;

    Future<Uint8List> unwrap(String wrappedB64) async {
      final raw = base64.decode(wrappedB64);
      final nonce = raw.sublist(0, 12);
      final ciphertextAndTag = raw.sublist(12);
      final ciphertext =
          ciphertextAndTag.sublist(0, ciphertextAndTag.length - 16);
      final mac = Mac(ciphertextAndTag.sublist(ciphertextAndTag.length - 16));

      final aesGcm = AesGcm.with256Bits();
      final secretKey = SecretKey(userKeyBytes);
      final box = SecretBox(ciphertext, nonce: nonce, mac: mac);

      final decrypted = await aesGcm.decrypt(
        box,
        secretKey: secretKey,
        aad: utf8.encode(songId),
      );
      return Uint8List.fromList(decrypted);
    }

    final contentKey = await unwrap(rights['key'] as String);
    final contentIv = await unwrap(rights['iv'] as String);

    final aesCtr = AesCtr.with128Bits(macAlgorithm: MacAlgorithm.empty);
    final secretKey = SecretKey(contentKey);
    final secretBox = SecretBox(
      encryptedBytes,
      nonce: contentIv,
      mac: Mac.empty,
    );

    final decryptedAudio = await aesCtr.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(decryptedAudio);
  }
}
