import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// In-app updater: checks GitHub for a newer APK and prompts install.
/// Version source: version.json in the repo (raw.githubusercontent).
class UpdateService {
  static const _versionUrl =
      'https://raw.githubusercontent.com/petspaws127-code/lifeez-app/main/version.json';
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
  Future<bool> downloadAndInstall(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    if (info.apkUrl.isEmpty) return false;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lifeez-update.apk');
      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final res = await http.Client().send(req);
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      onProgress(1.0);
      await OpenFilex.open(file.path);
      return true;
    } catch (_) {
      return false;
    }
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
    setState(() {
      _progress = 0;
      _failed = false;
    });
    final ok = await widget.service.downloadAndInstall(
      widget.info,
      (p) => mounted ? setState(() => _progress = p) : null,
    );
    if (!ok && mounted) {
      setState(() {
        _failed = true;
        _progress = -1;
      });
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
