import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class GeminiService implements ApiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  Future<List<Map<String, dynamic>>> getModels() async {
    // Gemini has a specific list of models. We can return the major ones.
    return [
      {'id': 'gemini-1.5-pro', 'name': 'Gemini 1.5 Pro'},
      {'id': 'gemini-1.5-flash', 'name': 'Gemini 1.5 Flash'},
      {'id': 'gemini-1.0-pro', 'name': 'Gemini 1.0 Pro'},
    ];
  }

  @override
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String? modelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('google_key') ?? '';

    if (apiKey.isEmpty) {
      throw Exception('API key not found. Please add your Google Gemini key.');
    }

    final selectedModel = modelId ?? 'gemini-1.5-flash';
    final url = '$_baseUrl/$selectedModel:generateContent?key=$apiKey';

    // Map history to Gemini format
    final contents = history.map((m) {
      return {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': m['content']}]
      };
    }).toList();

    // Add current message
    contents.add({
      'role': 'user',
      'parts': [{'text': message}]
    });

    final body = jsonEncode({'contents': contents});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null && candidate['content']['parts'] != null) {
            return candidate['content']['parts'][0]['text'];
          }
        }
        throw Exception('Empty response from Gemini');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Failed to communicate with Gemini: $errorMessage');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }
}
