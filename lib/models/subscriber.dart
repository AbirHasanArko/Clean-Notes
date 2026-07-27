/// Persisted record of a successfully subscribed user.
///
/// Stored in `SharedPreferences` so the gate can skip the login screen on
/// subsequent cold starts. The [subscriberId] is the BDApps id returned by
/// `/sdk/otp/verify` (e.g. `tel:8801712345678`) — re-validation happens
/// against `/sdk/verify/{subscriberId}`.
class Subscriber {
  const Subscriber({
    required this.subscriberId,
    required this.phone,
    required this.verifiedAt,
  });

  /// BDApps subscriber id, e.g. `tel:8801712345678`.
  final String subscriberId;

  /// User's phone number in the format they entered (`01XXXXXXXXX`).
  final String phone;

  /// When the OTP verification succeeded.
  final DateTime verifiedAt;

  Map<String, dynamic> toJson() => {
        'subscriberId': subscriberId,
        'phone': phone,
        'verifiedAt': verifiedAt.toIso8601String(),
      };

  factory Subscriber.fromJson(Map<String, dynamic> json) {
    return Subscriber(
      subscriberId: (json['subscriberId'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      verifiedAt: DateTime.tryParse((json['verifiedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  String toString() =>
      'Subscriber(subscriberId: $subscriberId, phone: $phone, '
      'verifiedAt: $verifiedAt)';
}