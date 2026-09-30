import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// HTTP client for the GitAlong Python backend.
///
/// Only ranking, GitHub sync and account deletion go through the backend;
/// core loops (profile, swipe, match, chat, safety) talk to Supabase
/// directly so they keep working when the backend is cold or down.
///
/// Every authenticated request reads the access token from the live
/// Supabase session right before sending it (tokens expire hourly).
@lazySingleton
class BackendApiClient {
  final SupabaseClient _supabase;

  BackendApiClient(this._supabase);

  /// Shared in-flight GitHub refresh so concurrent callers (app start,
  /// profile setup, "Refresh from GitHub") trigger a single request.
  Future<Map<String, dynamic>>? _githubRefreshInFlight;

  String get _baseUrl =>
      dotenv.env['BACKEND_URL'] ?? 'https://gitalong-backend.onrender.com';

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  String _requireAccessToken() {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('No active Supabase session');
    return session.accessToken;
  }

  // ── Recommendations ────────────────────────────────────────────────────────

  /// `GET /api/v1/recommendations?limit=N`
  ///
  /// Each user carries `match_score` (0–100), `match_reasons` and
  /// `score_breakdown`, parsed by [UserModel.fromJson].
  Future<List<UserEntity>> getRecommendations({int limit = 20}) async {
    final token = _requireAccessToken();
    final uri = Uri.parse('$_baseUrl/api/v1/recommendations?limit=$limit');

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception(
          'Backend /recommendations returned ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map) {
      throw Exception('Backend /recommendations returned an unexpected body');
    }
    final list = data['recommendations'];
    if (list is! List) return const [];

    AppLogger.i(
      'Backend: ${list.length} recommendations (algorithm: ${data['algorithm']})',
    );

    return list
        .whereType<Map>()
        .map((j) => UserModel.fromJson(
              j.map((key, value) => MapEntry(key.toString(), value)),
            ).toEntity())
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  // ── GitHub sync ────────────────────────────────────────────────────────────

  /// `POST /api/v1/users/me/refresh-github` → `{status, profile}`.
  ///
  /// Throws on failure (`503` when GitHub is unavailable; nothing is
  /// overwritten in that case).
  Future<Map<String, dynamic>> refreshGitHubStats() {
    return _githubRefreshInFlight ??= _refreshGitHubStats().whenComplete(() {
      _githubRefreshInFlight = null;
    });
  }

  Future<Map<String, dynamic>> _refreshGitHubStats() async {
    final token = _requireAccessToken();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/users/me/refresh-github'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception(
          'Backend /refresh-github returned ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map) return <String, dynamic>{};
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  // ── Account ─────────────────────────────────────────────────────────────────

  /// `DELETE /api/v1/users/me` — full server-side account deletion.
  /// Returns false (never throws) so the caller can fall back to the
  /// `delete_my_account` RPC.
  Future<bool> deleteAccount() async {
    try {
      final token = _requireAccessToken();
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/api/v1/users/me'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 204) return true;
      AppLogger.w(
          'Backend DELETE /users/me returned ${res.statusCode}: ${res.body}');
      return false;
    } catch (e, st) {
      AppLogger.e('Backend deleteAccount failed', e, st);
      return false;
    }
  }
}
