import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// In-app updater: checks GitHub for a newer APK and prompts install.
/// Version source: version.json in the public lifeez-updates repo.
class UpdateService {
  static const _versionUrl =
      'https://raw.githubusercontent.com/petspaws127-code/lifeez-updates/main/version.json';
  static const _checkInterval = Duration(hours: 12);

  DateTime? _lastCheck;
  UpdateInfo? _cached;

  /// Returns update info if a newer version is available, else null.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _checkInterval &&
        _cached != null) {
      return _cached;
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = int.tryParse(pkg.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = (data['versionCode'] as num?)?.toInt() ?? 0;
      if (latest <= current) {
        _cached = null;
        _lastCheck = DateTime.now();
        return null;
      }
      _cached = UpdateInfo(
        versionName: data['versionName']?.toString() ?? '$latest',
        versionCode: latest,
        apkUrl: data['apkUrl']?.toString() ?? '',
        notes: data['notes']?.toString() ?? '',
      );
      _lastCheck = DateTime.now();
      return _cached;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK to temp storage and opens it for install.
  /// Returns true if the install intent was launched.
  /// Robust: retries up to 3 times with resume support for large files.
  Future<bool> downloadAndInstall(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    if (info.apkUrl.isEmpty) return false;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/lifeez-update.apk');

    // Try up to 3 times with resume
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final existingLength = await file.exists() ? await file.length() : 0;

        final client = http.Client();
        final req = http.Request('GET', Uri.parse(info.apkUrl));
        // Resume from where we left off
        if (existingLength > 0) {
          req.headers['Range'] = 'bytes=$existingLength-';
        }

        final res = await client.send(req).timeout(
          const Duration(seconds: 30),
        );

        if (res.statusCode != 200 && res.statusCode != 206) {
          client.close();
          continue; // Retry
        }

        // Get total size
        var total = res.contentLength ?? 0;
        if (res.statusCode == 206 && existingLength > 0) {
          // Partial content: total is remaining + already downloaded
          total += existingLength;
        }

        var received = existingLength;
        final sink = file.openWrite(mode: existingLength > 0 ? FileMode.append : FileMode.write);

        await for (final chunk in res.stream.timeout(
          const Duration(seconds: 60),
          onTimeout: (sink) {
            sink.close();
            throw TimeoutException('Download stalled');
          },
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }

        await sink.close();
        client.close();

        // Verify download completed
        final finalSize = await file.length();
        if (total > 0 && finalSize < total) {
          continue; // Incomplete, retry
        }

        onProgress(1.0);
        await OpenFilex.open(file.path);
        return true;
      } catch (_) {
        // Wait before retry
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }

    // All retries failed, clean up partial file
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    return false;
  }

  /// Shows the update dialog. Call from home/settings on startup.
  static Future<void> promptIfAvailable(
    BuildContext context,
    UpdateService service, {
    bool force = false,
  }) async {
    final info = await service.checkForUpdate(force: force);
    if (info == null || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(info: info, service: service),
    );
  }
}

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String notes;
  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.notes,
  });
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final UpdateService service;
  const _UpdateDialog({required this.info, required this.service});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = -1; // -1 = not started
  bool _failed = false;

  Future<void> _start() async {
    // Open download URL in browser (reliable, no in-app download issues)
    try {
      final uri = Uri.parse(widget.info.apkUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _progress = -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lifeez ${widget.info.versionName} is ready.'),
          if (widget.info.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.info.notes, style: const TextStyle(fontSize: 13)),
          ],
          if (_progress >= 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}% downloaded'),
          ],
          if (_failed) ...[
            const SizedBox(height: 8),
            const Text('Download failed. Check your connection and try again.',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        if (_progress < 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        if (_progress < 0)
          ElevatedButton(
            onPressed: _failed ? _start : _start,
            child: Text(_failed ? 'Retry' : 'Update now'),
          ),
        if (_progress >= 0 && _progress < 1)
          const TextButton(onPressed: null, child: Text('Downloading…')),
      ],
    );
  }
}
