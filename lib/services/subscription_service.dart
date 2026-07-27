import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appspro_config.dart';
import '../models/subscriber.dart';

/// Raised when an AppsPro SDK call returns a non-OK response or a
/// "success" payload whose `status_code` indicates failure.
class SubscriptionException implements Exception {
  const SubscriptionException(this.message, {this.statusCode});

  final String message;
  final String? statusCode;

  @override
  String toString() => 'SubscriptionException($statusCode): $message';
}

/// Talks to the AppsPro SDK over HTTPS and persists the resulting
/// [Subscriber] in `SharedPreferences`.
///
/// Stateless aside from the `SharedPreferences` instance — safe to
/// construct at app start and reuse for the lifetime of the process.
class SubscriptionService {
  SubscriptionService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // ---- SharedPreferences keys ------------------------------------------------
  static const _prefsKey = 'clean_notes.subscriber.v1';

  // ---- OTP flow --------------------------------------------------------------

  /// Sends an SMS OTP to [phone].
  ///
  /// Phone formats accepted by AppsPro: `01XXXXXXXXX`,
  /// `8801XXXXXXXXX`, or `+8801XXXXXXXXX`.
  ///
  /// Returns the `reference_no` to pass back to [verifyOtp].
  /// Throws [SubscriptionException] on transport / API failure.
  Future<String> requestOtp(String phone) async {
    final response = await _postJson(
      AppsProConfig.otpRequestUrl,
      body: {'phone': phone},
    );

    // AppsPro returns the reference_no at the top level on success.
    final referenceNo = response['reference_no'] as String?;
    if (referenceNo == null || referenceNo.isEmpty) {
      throw SubscriptionException(
        response['status_detail']?.toString() ??
            'OTP request failed: missing reference_no.',
        statusCode: response['status_code']?.toString(),
      );
    }
    return referenceNo;
  }

  /// Verifies [otp] against [referenceNo]. On success, registers the
  /// subscriber locally (appsPro-side) and returns the resulting
  /// [Subscriber] (also persisted via [saveStored]).
  Future<Subscriber> verifyOtp({
    required String referenceNo,
    required String otp,
    required String phone,
  }) async {
    final response = await _postJson(
      AppsProConfig.otpVerifyUrl,
      body: {'reference_no': referenceNo, 'otp': otp},
    );

    final subscriptionStatus =
        response['subscription_status']?.toString().toUpperCase();
    final subscriberId = response['subscriber_id']?.toString();

    final isSuccess = subscriptionStatus == 'REGISTERED' ||
        subscriptionStatus == 'ACTIVE' ||
        (subscriberId != null && subscriberId.isNotEmpty);

    if (!isSuccess) {
      throw SubscriptionException(
        response['status_detail']?.toString() ??
            'OTP verification failed.',
        statusCode: response['status_code']?.toString(),
      );
    }

    final subscriber = Subscriber(
      subscriberId: subscriberId ?? '',
      phone: phone,
      verifiedAt: DateTime.now(),
    );

    await saveStored(subscriber);
    return subscriber;
  }

  // ---- Re-validation ---------------------------------------------------------

  /// Confirms that a stored subscriber is still active. Used on cold start
  /// before swapping the gate for the notes list.
  Future<bool> verifySubscriber(String subscriberId) async {
    if (subscriberId.isEmpty) return false;
    try {
      final response = await _getJson(
        AppsProConfig.verifyUrl(subscriberId),
      );
      final valid = response['valid'];
      return valid == true;
    } on SubscriptionException {
      return false;
    } catch (_) {
      // Network failure on cold start — fall back to the cached record so
      // the user isn't kicked out just because they have no signal.
      return true;
    }
  }

  // ---- Cancellation ----------------------------------------------------------

  /// Cancels the subscription via AppsPro.
  ///
  /// AppsPro's `/sdk/unsubscribe` requires `phone` in international form
  /// without the leading `+` (`880XXXXXXXXXX`). Sending the local `01...`
  /// form silently returns `E1951 Format of the address is invalid`. We
  /// normalise before posting.
  ///
  /// Throws [SubscriptionException] if AppsPro returns a non-success
  /// status_code. The caller is responsible for deciding what to do (in the
  /// app we still complete the local logout so the user isn't stranded).
  Future<void> unsubscribe(Subscriber subscriber) async {
    final phone = _toInternationalPhoneNoPlus(subscriber.phone);
    if (phone.isEmpty) {
      throw const SubscriptionException(
        'Stored subscriber has no phone number.',
      );
    }

    final body = <String, dynamic>{
      'phone': phone,
      if (subscriber.subscriberId.isNotEmpty)
        'subscriber_id': subscriber.subscriberId,
    };

    final response = await _postJson(
      AppsProConfig.unsubscribeUrl,
      body: body,
    );

    final statusCode = response['status_code']?.toString();
    // AppsPro returns 200 with status_code "0000" on success.
    // Anything else (e.g. E1951, E...) is a real failure we want to surface.
    if (statusCode != null && statusCode != '0000') {
      throw SubscriptionException(
        response['status_detail']?.toString() ??
            'Unsubscribe failed (status $statusCode).',
        statusCode: statusCode,
      );
    }
  }

  /// Normalises a phone entered as `01XXXXXXXXX`, `8801XXXXXXXXX`, or
  /// `+8801XXXXXXXXX` to the international form `880XXXXXXXXXX` (no `+`).
  /// Returns an empty string if the input doesn't look like a BD number.
  static String _toInternationalPhoneNoPlus(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 11) return '';
    // Strip leading 880 or leading 0 so we can rebuild consistently.
    String tail;
    if (digits.startsWith('880') && digits.length == 13) {
      tail = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length == 11) {
      tail = digits.substring(1);
    } else if (digits.length == 10) {
      tail = digits;
    } else {
      return '';
    }
    if (tail.length != 10) return '';
    return '880$tail';
  }

  // ---- Persistence -----------------------------------------------------------

  /// Reads the stored subscriber (if any). Returns `null` if nothing was
  /// persisted or the stored JSON is malformed.
  Future<Subscriber?> loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return Subscriber.fromJson(decoded);
    } catch (_) {
      // Corrupt entry — drop it so the next save starts clean.
      await prefs.remove(_prefsKey);
      return null;
    }
  }

  Future<void> saveStored(Subscriber subscriber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(subscriber.toJson()));
  }

  Future<void> clearStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ---- HTTP helpers ----------------------------------------------------------

  Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    final body = response.body;
    Map<String, dynamic> parsed;
    try {
      parsed = json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      parsed = <String, dynamic>{};
    }

    if (status < 200 || status >= 300) {
      throw SubscriptionException(
        parsed['status_detail']?.toString() ??
            parsed['message']?.toString() ??
            'HTTP $status',
        statusCode: status.toString(),
      );
    }
    return parsed;
  }

  Future<Map<String, dynamic>> _postJson(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: const {
        'Authorization': 'Bearer ${AppsProConfig.secretKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: const {
        'Authorization': 'Bearer ${AppsProConfig.secretKey}',
        'Accept': 'application/json',
      },
    );
    return _decode(response);
  }

  void dispose() {
    _client.close();
  }
}