// Probe script: feeds the REAL stored subscriber from the app into the
// AppsPro unsubscribe + verify endpoints to diagnose the E1951 error.
//
// Usage:
//   1. Run the app, log in, then dump the stored prefs:
//      adb shell run-as com.example.notes_management_app cat shared_prefs/FlutterSharedPreferences.xml
//   2. Copy the JSON value under <string name="clean_notes.subscriber.v1">
//      into SUB_JSON below.
//   3. dart run tool/probe_unsubscribe.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

const _base = 'https://api.appspro.dev/api/v1';
const _key = 'sk_dec251b804d78ea8d48267e28c5e1d779924827d33125cdf';

// Paste your stored subscriber JSON here.
const SUB_JSON = '''
{
  "subscriberId": "PASTE_SUBSCRIBER_ID_HERE",
  "phone": "PASTE_PHONE_HERE",
  "verifiedAt": "2026-07-27T10:00:00.000Z"
}
''';

// ignore: avoid_print
void log(String s) => print(s);

String toInternationalNoPlus(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 11) return '';
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

Future<void> probe(
  String label,
  String url,
  String method,
  Map<String, dynamic>? body,
) async {
  final headers = {
    'Authorization': 'Bearer $_key',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  log('--- $label ---');
  log('$method $url');
  if (body != null) log('body: ${json.encode(body)}');
  try {
    final req = http.Request(method, Uri.parse(url));
    req.headers.addAll(headers);
    if (body != null) req.body = json.encode(body);
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    log('status: ${r.statusCode}');
    log('body: ${r.body}');
  } catch (e) {
    log('EXCEPTION: $e');
  }
  log('');
}

Future<void> main() async {
  Map<String, dynamic> sub;
  try {
    sub = json.decode(SUB_JSON) as Map<String, dynamic>;
  } catch (e) {
    log('Could not parse SUB_JSON: $e');
    return;
  }

  final phoneRaw = (sub['phone'] as String?) ?? '';
  final subId = (sub['subscriberId'] as String?) ?? '';
  final phone880 = toInternationalNoPlus(phoneRaw);
  log('phoneRaw   = "$phoneRaw"');
  log('phone880   = "$phone880"');
  log('subscriberId = "$subId"');
  log('');

  if (subId.isEmpty) {
    log('!! Stored subscriberId is EMPTY — unsubscribe will fail regardless.');
    log('!! Re-run OTP signup; the response should contain a subscriber_id.');
    log('');
  }

  // 1. Verify the stored subscriber_id (does BDApps know about it at all?).
  if (subId.isNotEmpty) {
    await probe(
      'verify subscriber',
      '$_base/sdk/verify/$subId',
      'GET',
      null,
    );
  }

  // 2. Try all three phone formats — only one will match BDApps.
  await probe(
    'unsubscribe phone=880...',
    '$_base/sdk/unsubscribe',
    'POST',
    {'phone': phone880, if (subId.isNotEmpty) 'subscriber_id': subId},
  );
  await probe(
    'unsubscribe phone=+880...',
    '$_base/sdk/unsubscribe',
    'POST',
    {'phone': '+$phone880', if (subId.isNotEmpty) 'subscriber_id': subId},
  );
  await probe(
    'unsubscribe phone=0...',
    '$_base/sdk/unsubscribe',
    'POST',
    {'phone': '0${phone880.substring(3)}', if (subId.isNotEmpty) 'subscriber_id': subId},
  );

  // 3. If subscriber_id is set, try treating it as the phone (some BDApps
  //    setups accept the tel: URI as the cancellation target).
  if (subId.isNotEmpty) {
    await probe(
      'unsubscribe phone=subscriber_id',
      '$_base/sdk/unsubscribe',
      'POST',
      {'phone': subId, 'subscriber_id': subId},
    );
  }
}
