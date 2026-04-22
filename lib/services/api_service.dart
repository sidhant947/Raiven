abstract class ApiService {
  Future<List<Map<String, dynamic>>> getModels();
  
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String modelId,
  });
}
