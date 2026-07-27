/// Centralised AppsPro / BDApps configuration.
///
/// All dashboard credentials live here so the rest of the app references
/// a single typed source of truth. Endpoints are derived from [baseUrl]
/// so a future move to staging only changes one line.
///
/// SECURITY: [secretKey] is a *server* secret by design. Embedding it in
/// the Flutter client is only acceptable for demos / assignments — anyone
/// can decompile the APK and read it. For production, route the SDK calls
/// through a backend that holds the secret and exposes only the minimum
/// surface area to the mobile client.
class AppsProConfig {
  const AppsProConfig._();

  /// REST base URL shown in the AppsPro dashboard for this app.
  static const String baseUrl = 'https://api.appspro.dev/api/v1';

  /// `Authorization: Bearer sk_...` header value.
  /// Used for `/sdk/verify`, `/sdk/otp/*`, `/sdk/unsubscribe`.
  static const String secretKey =
      'sk_dec251b804d78ea8d48267e28c5e1d779924827d33125cdf';

  /// Safe-to-ship publishable key. Useful if we later embed the WebSDK.
  static const String publishableKey = 'pk_c3b9a7f378a963fed4092617';

  /// Short handle that appears in hosted-checkout URLs
  /// (`https://appspro.dev/s/<urlSlug>`).
  static const String urlSlug = 'CkFUYUsruI';

  /// Hosted-checkout URL — used for the "Subscribe via web" fallback.
  static const String checkoutUrl = 'https://appspro.dev/s/$urlSlug';

  /// Maps to `POST /sdk/otp/request`. Sends an SMS OTP. Rate limit: 10/h.
  static String get otpRequestUrl => '$baseUrl/sdk/otp/request';

  /// Maps to `POST /sdk/otp/verify`. Verifies OTP, registers subscriber
  /// on success and returns the BDApps subscriber id.
  static String get otpVerifyUrl => '$baseUrl/sdk/otp/verify';

  /// Maps to `GET /sdk/verify/{subscriber_id}`. Re-validates a stored
  /// subscriber id at cold start.
  static String verifyUrl(String subscriberId) =>
      '$baseUrl/sdk/verify/$subscriberId';

  /// Maps to `POST /sdk/unsubscribe`. Cancels the subscription by phone.
  static String get unsubscribeUrl => '$baseUrl/sdk/unsubscribe';

  /// Maps to `GET /sdk/app-info?publishable_key=...` (public, no auth).
  /// Used for displaying the app's metadata on the login screen header.
  static String get appInfoUrl =>
      '$baseUrl/sdk/app-info?publishable_key=$publishableKey';
}