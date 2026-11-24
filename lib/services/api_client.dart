import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Base URL of the ShopLon API. Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
const String apiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

/// An error the API (or the network) reported, with a message safe to show.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.details]);

  /// HTTP status, or 0 when the server couldn't be reached.
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Random, URL-safe key for the `Idempotency-Key` header. Generate one per
/// user intent (a checkout tap) and reuse it for retries of that intent.
String newIdempotencyKey() {
  final rnd = Random.secure();
  return List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
}

/// HTTP client for the ShopLon API.
///
/// * Attaches the Firebase ID token. The SDK refreshes it automatically before
///   it expires, and on a 401 the client force-refreshes once and retries.
/// * Retries network errors and 502/503/504 with exponential backoff and
///   jitter, but only for requests that are safe to repeat: GET/PUT/DELETE,
///   or a POST carrying an idempotency key.
/// * Honours 409 REQUEST_IN_PROGRESS (a duplicate still being processed)
///   by waiting for Retry-After and asking again.
/// * If the session was revoked server-side, it signs out locally too.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  static final ApiClient instance = ApiClient();

  final http.Client _http;
  static const _timeout = Duration(seconds: 20);
  static const _maxAttempts = 4;

  Future<dynamic> get(String path,
          {Map<String, String>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path,
          {Object? body, String? idempotencyKey, bool auth = true}) =>
      _send('POST', path,
          body: body, idempotencyKey: idempotencyKey, auth: auth);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<String?> _token({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(force);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final retryable = method != 'POST' || idempotencyKey != null;
    var refreshedToken = false;
    String? token;
    if (auth) {
      token = await _token();
      if (token == null) {
        throw ApiException(401, 'UNAUTHENTICATED', 'Please log in to continue.');
      }
    }

    for (var attempt = 1;; attempt++) {
      final http.Response res;
      try {
        final req = http.Request(method, uri)
          ..headers.addAll({
            'accept': 'application/json',
            if (body != null) 'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
            if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
          });
        if (body != null) req.body = jsonEncode(body);
        res = await http.Response.fromStream(
            await _http.send(req).timeout(_timeout));
      } on Exception catch (e) {
        // TimeoutException, ClientException (incl. browser network errors)...
        debugPrint('API $method $path failed: $e');
        if (retryable && attempt < _maxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw ApiException(0, 'NETWORK',
            "Couldn't reach the server. Check your connection and try again.");
      }

      if (res.statusCode == 401 && auth && !refreshedToken) {
        refreshedToken = true;
        token = await _token(force: true);
        if (token != null) continue;
      }

      final decoded = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

      final error = decoded is Map ? decoded['error'] : null;
      final code = error is Map ? (error['code'] as String? ?? 'ERROR') : 'ERROR';
      final transient = res.statusCode >= 502 && res.statusCode <= 504;
      final inProgress = res.statusCode == 409 && code == 'REQUEST_IN_PROGRESS';
      if (retryable && (transient || inProgress) && attempt < _maxAttempts) {
        final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
        await (retryAfter != null
            ? Future.delayed(Duration(seconds: retryAfter))
            : _backoff(attempt));
        continue;
      }

      if (res.statusCode == 401 && auth) {
        // Revoked or expired session that a refresh couldn't fix.
        unawaited(FirebaseAuth.instance.signOut());
      }
      throw ApiException(
        res.statusCode,
        code,
        error is Map
            ? (error['message'] as String? ?? 'Something went wrong.')
            : 'Something went wrong (${res.statusCode}).',
        error is Map && error['details'] is Map
            ? Map<String, dynamic>.from(error['details'] as Map)
            : null,
      );
    }
  }

  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  /// 300 ms, 600 ms, 1.2 s ... plus jitter, so clients don't retry in lockstep.
  static Future<void> _backoff(int attempt) => Future.delayed(Duration(
      milliseconds:
          300 * pow(2, attempt - 1).toInt() + Random().nextInt(200)));
}
