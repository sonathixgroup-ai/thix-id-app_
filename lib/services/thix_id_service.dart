import 'dart:math';
import 'dart:ui';

/// THIX ID generation + validation utilities.
///
/// We support multiple formats for backward compatibility.
///
/// Recommended (current):
///   THIX-[CC]-[MMYY]-[RANDOM5]-[CODE3]-[CHECK]
///   - MMYY: month + year (e.g. 0426)
///   - RANDOM5: 5 digits
///   - CODE3: 3 letters
///   - CHECK: verification key (1 digit)
///   Example: THIX-CD-0426-48392-NJK-7
///
/// Legacy V2 (still accepted by validation):
///   THIX-[CC]-[INIT]-[YY]-[TOKEN4]-[CHECK]
///   Example: THIX-CD-NLU-26-K8P4-7
///
/// Notes:
/// - The ID remains non-sensitive (no full name, no DOB).
/// - A checksum digit helps detect typos.
class ThixIdService {
  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _tokenAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rnd = Random.secure();

  /// Example of the recommended/current format.
  static const String exampleV2 = 'THIX-CD-0426-48392-NJK-7';

  /// Example of the legacy format.
  static const String exampleV1 = 'THIX-CD-NLU-26-K8P4-7';

  static String inferCountryCode({String? selectedOrUserProvided}) {
    final s = (selectedOrUserProvided ?? '').trim();
    final mapped = _mapToIso2(s);
    if (mapped != null) return mapped;
    if (s.length == 2) return s.toUpperCase();

    final localeCC = PlatformDispatcher.instance.locale.countryCode;
    if (localeCC != null && localeCC.trim().length == 2) return localeCC.trim().toUpperCase();
    return 'XX';
  }

  /// Normalizes user input into a canonical THIX ID string.
  ///
  /// Accepts minor variations seen in real usage:
  /// - extra spaces
  /// - missing "THIX-" prefix (e.g. "CD-..."), or partially typed "X-..."
  static String normalize(String input) {
    var v = input.trim().toUpperCase();
    // Remove all whitespace (including newlines) and keep only safe chars.
    v = v.replaceAll(RegExp(r'\s+'), '');
    v = v.replaceAll(RegExp(r'[^A-Z0-9-]'), '');

    // Fix partial prefixes.
    if (v.startsWith('X-')) v = 'THI$v'; // X-... -> THIX-...
    if (v.startsWith('HIX-')) v = 'T$v';
    if (v.startsWith('IX-')) v = 'TH$v';

    // Allow missing prefix.
    if (!v.startsWith('THIX-')) {
      final looksLikeThixBody = RegExp(r'^[A-Z]{2}-').hasMatch(v);
      if (looksLikeThixBody) v = 'THIX-$v';
    }

    // Collapse repeated dashes.
    v = v.replaceAll(RegExp(r'-{2,}'), '-');

    // Common real-world paste mistakes:
    // - trailing dash: "THIX-..-AUX-" or "THIX-..-AUX-6-"
    // - leading dash
    v = v.replaceAll(RegExp(r'^-+'), '');
    v = v.replaceAll(RegExp(r'-+$'), '');
    return v;
  }

  /// Best-effort mapping for common user-entered values into ISO-3166 alpha-2.
  ///
  /// Key requirement: RDC must map to CD (not RD).
  static String? _mapToIso2(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final up = v.toUpperCase();
    if (up == 'RDC' || up == 'DRC' || up == 'RD CONGO' || up == 'R.D.C' || up == 'R.D.C.' || up == 'CONGO DRC') return 'CD';
    if (up == 'CONGO' || up == 'REPUBLIQUE DU CONGO' || up == 'R.C' || up == 'R.C.' || up == 'ROC') return 'CG';
    if (up == 'USA' || up == 'US' || up == 'UNITED STATES') return 'US';
    if (up == 'FRANCE' || up == 'FR') return 'FR';
    if (up == 'BELGIQUE' || up == 'BELGIUM' || up == 'BE') return 'BE';

    // If user entered something like "CD - RDC" or "RDC (CD)", try to pick ISO2.
    final isoMatch = RegExp(r'\b([A-Z]{2})\b').firstMatch(up);
    if (isoMatch != null) {
      final iso = isoMatch.group(1);
      if (iso != null && iso.length == 2) return iso;
    }
    return null;
  }

  /// Generates the recommended/current THIX ID.
  static String generate({required String countryCode, DateTime? now}) {
    final ts = now ?? DateTime.now();
    final mm = ts.month.toString().padLeft(2, '0');
    final yy = (ts.year % 100).toString().padLeft(2, '0');
    final mmyy = '$mm$yy';

    final random5 = List.generate(5, (_) => _rnd.nextInt(10)).join();
    final code3 = String.fromCharCodes(List.generate(3, (_) => _letters.codeUnitAt(_rnd.nextInt(_letters.length))));
    final body = 'THIX-${countryCode.toUpperCase()}-$mmyy-$random5-$code3';
    final c = checksumDigit(body);
    return '$body-$c';
  }

  /// Backward-compatible API: previously generated a different “V2” format.
  ///
  /// As requested, we now generate the **recommended/current** format:
  /// `THIX-[CC]-[MMYY]-[RANDOM5]-[CODE3]-[CHECK]`.
  ///
  /// The [displayName] argument is kept for compatibility with existing calls.
  static String generateV2({required String countryCode, required String displayName, DateTime? now}) => generate(countryCode: countryCode, now: now);

  /// Computes an anti-fraud checksum digit (0-9) using a Luhn-like mod10.
  ///
  /// We map alphanumerics into a digit stream, then run Luhn.
  static int checksumDigit(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final digits = <int>[];
    for (final r in cleaned.runes) {
      final ch = String.fromCharCode(r);
      final v = _charValue(ch);
      // Expand value into base-10 digits to keep Luhn stable.
      if (v >= 10) {
        digits.add(v ~/ 10);
        digits.add(v % 10);
      } else {
        digits.add(v);
      }
    }
    final check = _luhnCheckDigit(digits);
    return check;
  }

  static bool isValid(String thixId) {
    final v = normalize(thixId);
    // Current/recommended.
    final isCurrent = RegExp(r'^THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3}-\d$').hasMatch(v);
    // Legacy.
    final isLegacy = RegExp(r'^THIX-[A-Z]{2}-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}-\d$').hasMatch(v);
    if (!isCurrent && !isLegacy) return false;
    final body = v.substring(0, v.length - 2); // strip -C
    final expected = checksumDigit(body);
    final got = int.tryParse(v.substring(v.length - 1)) ?? -1;
    return expected == got;
  }

  static String _initials(String displayName) {
    final cleaned = displayName.trim().toUpperCase();
    if (cleaned.isEmpty) return 'USR';
    final parts = cleaned.split(RegExp(r'[^A-Z]+')).where((p) => p.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return 'USR';
    final buf = StringBuffer();
    for (final p in parts.take(3)) {
      buf.write(p[0]);
    }
    final out = buf.toString();
    return out.isEmpty ? 'USR' : out;
  }

  static int _charValue(String ch) {
    final c = ch.codeUnitAt(0);
    if (c >= 48 && c <= 57) return c - 48;
    if (c >= 65 && c <= 90) return 10 + (c - 65);
    return 0;
  }

  static int _luhnCheckDigit(List<int> digits) {
    var sum = 0;
    var alt = true;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits[i];
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return (10 - (sum % 10)) % 10;
  }

  /// Attempts to transform a user-entered string into a **valid** THIX ID by
  /// fixing common mistakes around the checksum.
  ///
  /// This is intentionally conservative:
  /// - If the structure doesn't look like a THIX ID, returns null.
  /// - If it looks like a THIX ID but checksum is wrong/missing, we recompute it.
  ///
  /// Example:
  /// - Input:  `THIX-CD-0426-48392-NJK-9`  -> Output: `THIX-CD-0426-48392-NJK-7`
  /// - Input:  `THIX-CD-0426-48392-NJK`    -> Output: `THIX-CD-0426-48392-NJK-7`
  static String? canonicalizeOrNull(String input) {
    final v = normalize(input);

    // Current format without checksum.
    final currentNoCheck = RegExp(r'^THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3}$');
    if (currentNoCheck.hasMatch(v)) {
      final c = checksumDigit(v);
      return '$v-$c';
    }

    // Current format with checksum (possibly wrong).
    final currentMaybe = RegExp(r'^(THIX-[A-Z]{2}-\d{4}-\d{5}-[A-Z]{3})-(\d)$');
    final m1 = currentMaybe.firstMatch(v);
    if (m1 != null) {
      final body = m1.group(1)!;
      final c = checksumDigit(body);
      return '$body-$c';
    }

    // Legacy format without checksum.
    final legacyNoCheck = RegExp(r'^THIX-[A-Z]{2}-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4}$');
    if (legacyNoCheck.hasMatch(v)) {
      final c = checksumDigit(v);
      return '$v-$c';
    }

    // Legacy format with checksum (possibly wrong).
    final legacyMaybe = RegExp(r'^(THIX-[A-Z]{2}-[A-Z]{1,3}-\d{2}-[A-Z0-9]{4})-(\d)$');
    final m2 = legacyMaybe.firstMatch(v);
    if (m2 != null) {
      final body = m2.group(1)!;
      final c = checksumDigit(body);
      return '$body-$c';
    }

    return null;
  }
}
