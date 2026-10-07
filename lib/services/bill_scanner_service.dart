import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR extraction result for a scanned/uploaded bill photo.
class BillScanResult {
  final String merchant;
  final double amount;
  final DateTime? date;

  const BillScanResult({
    this.merchant = '',
    this.amount = 0,
    this.date,
  });

  bool get isEmpty => merchant.isEmpty && amount == 0 && date == null;
}

/// Runs on-device text recognition on a bill photo and extracts
/// merchant, total amount, and date. Never throws: returns an empty
/// [BillScanResult] on any failure so the UI can fall back to manual entry.
class BillScannerService {
  Future<BillScanResult> extractFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      return _parse(recognized.text);
    } catch (_) {
      return const BillScanResult();
    } finally {
      recognizer.close();
    }
  }

  BillScanResult _parse(String text) {
    if (text.trim().isEmpty) return const BillScanResult();
    return BillScanResult(
      merchant: _parseMerchant(text),
      amount: _parseAmount(text),
      date: _parseDate(text),
    );
  }

  /// Amount: prefer the amount on a line containing "total", else the
  /// largest money-like value found; default 0.
  double _parseAmount(String text) {
    final moneyRe = RegExp(r'\$?\s?(\d{1,3}(?:,\d{3})*\.\d{2})');
    double best = 0;
    double? totalLineAmount;

    for (final line in text.split('\n')) {
      final lineLower = line.toLowerCase();
      for (final m in moneyRe.allMatches(line)) {
        final raw = m.group(1)!.replaceAll(',', '');
        final value = double.tryParse(raw);
        if (value == null) continue;
        if (value > best) best = value;
        // Prefer lines mentioning total/amount due/balance.
        if (totalLineAmount == null &&
            (lineLower.contains('total') ||
                lineLower.contains('amount due') ||
                lineLower.contains('balance due'))) {
          totalLineAmount = value;
        }
      }
    }
    return totalLineAmount ?? best;
  }

  /// Date: MM/DD/YYYY, MM-DD-YYYY, or Mon DD, YYYY; default null.
  DateTime? _parseDate(String text) {
    final numericRe = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
    final m = numericRe.firstMatch(text);
    if (m != null) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final namedRe =
        RegExp(r'\b([A-Za-z]{3,9})\s+(\d{1,2}),\s*(\d{4})\b');
    final n = namedRe.firstMatch(text);
    if (n != null) {
      final monthKey = n.group(1)!.toLowerCase().substring(0, 3);
      final month = months[monthKey];
      final day = int.tryParse(n.group(2)!) ?? 0;
      final year = int.tryParse(n.group(3)!) ?? 0;
      if (month != null && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  /// Merchant: first non-empty line with at least 3 letters, stripped of
  /// non-alphanumeric leading/trailing characters; default ''.
  String _parseMerchant(String text) {
    final letterRe = RegExp(r'[A-Za-z]');
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.length < 3) continue;
      if (letterRe.allMatches(line).length < 3) continue;
      var cleaned = line.replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '');
      cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9]+$'), '');
      if (cleaned.length >= 3) return cleaned;
    }
    return '';
  }
}
