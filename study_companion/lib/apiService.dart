import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ApiService {
  static const _baseUrl = kBaseUrl;

  // ─── Get stored JWT token ─────────────────────────────────────────────
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ─── Save token after login ───────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // ─── Save subscription status ─────────────────────────────────────────
  static Future<void> saveSubscriptionStatus(bool isSubscribed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', isSubscribed);
  }

  static Future<bool> isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_subscribed') ?? false;
  }

  // ─── Save / get user profile ──────────────────────────────────────────
  static Future<void> saveUserProfile({required String name, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('is_subscribed');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }

  // ─── PROCESS TEXT ─────────────────────────────────────────────────────
  /// Send text to a model and get summary + flashcards + quiz + metrics
  static Future<Map<String, dynamic>> processText({
    required String text,
    required String model,
    String localModelName = 'llama3',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'model': model,
          'local_model_name': localModelName,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── UPLOAD AND PROCESS FILE ──────────────────────────────────────────
  /// Upload a PDF/DOCX/TXT file and get AI results
  static Future<Map<String, dynamic>> uploadAndProcess({
    required File file,
    required String model,
    String localModelName = 'llama3',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST', 
        Uri.parse('$_baseUrl/upload-and-process'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['model'] = model;
      request.fields['local_model_name'] = localModelName;

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Upload failed: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Upload failed: $e'};
    }
  }

  // ─── COMPARE MODELS ───────────────────────────────────────────────────
  /// Send same text to multiple models and compare
  static Future<Map<String, dynamic>> compareModels({
    required String text,
    required List<String> models,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/compare'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'models': models,
        }),
      ).timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Compare failed: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Compare failed: $e'};
    }
  }

  // ─── LOGIN ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        await saveSubscriptionStatus(data['is_subscribed'] ?? false);
        await saveUserProfile(
          name: data['name'] ?? '',
          email: email,
        );
        return data;
      } else {
        final body = jsonDecode(response.body);
        return {'error': body['detail'] ?? body['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── REGISTER ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        return {'error': body['detail'] ?? body['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── FORGOT PASSWORD ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Request failed'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── RESET PASSWORD ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'new_password': newPassword}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['detail'] ?? 'Reset failed'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── SEND CHAT MESSAGE (multi-turn) ──────────────────────────────────────
  /// Send the full conversation history to the backend and get the next reply.
  static Future<Map<String, dynamic>> sendChatMessage({
    required List<Map<String, String>> messages,
    required String model,
    String localModelName = 'llama3',
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages,
          'model': model,
          'local_model_name': localModelName,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── GET ME (live from backend) ───────────────────────────────────────
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final token = await _getToken();
      if (token == null) return {'error': 'Not authenticated'};
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Failed to load profile'};
      }
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  // ─── SESSIONS ─────────────────────────────────────────────────────────
  static const _sessionsKey = 'saved_sessions';

  static Future<List<Map<String, dynamic>>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.insert(0, session);
    if (sessions.length > 50) sessions.removeLast();
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  static Future<void> clearSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  // Upsert a chat session by id (insert if new, replace if existing).
  static Future<void> saveChatSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    final idx = sessions.indexWhere((s) => s['id'] == session['id']);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
      if (sessions.length > 50) sessions.removeLast();
    }
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.removeWhere((s) => s['id'] == id);
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  // ─── QUIZ RESULTS ─────────────────────────────────────────────────────
  static const _quizResultsKey = 'quiz_results';

  static Future<void> saveQuizResult({
    required String modelName,
    required int score,
    required int total,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quizResultsKey);
    final results = raw != null
        ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    results.insert(0, {
      'model': modelName,
      'score': score,
      'total': total,
      'percent': total > 0 ? (score / total * 100).round() : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (results.length > 100) results.removeLast();
    await prefs.setString(_quizResultsKey, jsonEncode(results));
  }

  static Future<List<Map<String, dynamic>>> getQuizResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quizResultsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ─── SUBMIT EVALUATION ────────────────────────────────────────────────
  static Future<void> submitEvaluation({
    required String model,
    required int clarity,
    required int accuracy,
    required int usefulness,
    String? comments,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'clarity': clarity,
          'accuracy': accuracy,
          'usefulness': usefulness,
          'comments': comments,
        }),
      );
    } catch (_) {}
  }
}