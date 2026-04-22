import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'openrouter_service.dart';
import 'openai_compatible_service.dart';
import 'anthropic_service.dart';
import 'gemini_service.dart';

enum ApiProvider { openrouter, openai, google, anthropic, mistral, nvidia, custom }

class ServiceFactory {
  static Future<ApiService> getService() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString('api_provider') ?? 'openrouter';
    
    final provider = ApiProvider.values.firstWhere(
      (e) => e.toString().split('.').last == providerName,
      orElse: () => ApiProvider.openrouter,
    );

    switch (provider) {
      case ApiProvider.openrouter:
        return OpenRouterService();
      case ApiProvider.openai:
        return OpenAiCompatibleService(
          baseUrl: 'https://api.openai.com/v1',
          apiKeyKey: 'openai_key',
          defaultModel: 'gpt-4o',
        );
      case ApiProvider.google:
        return GeminiService();
      case ApiProvider.anthropic:
        return AnthropicService();
      case ApiProvider.mistral:
        return OpenAiCompatibleService(
          baseUrl: 'https://api.mistral.ai/v1',
          apiKeyKey: 'mistral_key',
          defaultModel: 'mistral-large-latest',
        );
      case ApiProvider.nvidia:
        return OpenAiCompatibleService(
          baseUrl: 'https://integrate.api.nvidia.com/v1',
          apiKeyKey: 'nvidia_key',
          defaultModel: 'nvidia/llama-3.1-405b-instruct',
        );
      case ApiProvider.custom:
        final customUrl = prefs.getString('custom_url') ?? '';
        return OpenAiCompatibleService(
          baseUrl: customUrl,
          apiKeyKey: 'custom_key',
        );
    }
  }

  static String getProviderLabel(ApiProvider provider) {
    switch (provider) {
      case ApiProvider.openrouter: return 'OpenRouter';
      case ApiProvider.openai: return 'OpenAI';
      case ApiProvider.google: return 'Google Gemini';
      case ApiProvider.anthropic: return 'Claude (Anthropic)';
      case ApiProvider.mistral: return 'Mistral AI';
      case ApiProvider.nvidia: return 'NVIDIA NIM';
      case ApiProvider.custom: return 'Custom (OpenAI Compatible)';
    }
  }
}
