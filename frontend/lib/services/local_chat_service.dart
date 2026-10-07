import 'package:flutter/foundation.dart';
import 'gguf_inference_service.dart';

/// Service for local chatbot - handles user questions using local model
class LocalChatService {
  late final GGUFInferenceService _inferenceService;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _initializationFailed = false;
  late Future<bool> _initializationFuture;

  // Constructor - create new instance (not singleton in this design)
  LocalChatService() {
    _inferenceService = GGUFInferenceService.getInstance();
    print('🔧 [LocalChatService] Initialized new instance');
  }

  /// Initialize the GGUF model
  Future<bool> initialize({
    int contextSize = 512,
    int threads = 4,
  }) async {
    print('📋 [LocalChatService.initialize] Called with contextSize=$contextSize, threads=$threads');
    print('   Current state: _isInitialized=$_isInitialized, _isInitializing=$_isInitializing');
    
    if (_isInitialized) {
      print('   ✅ Already initialized, returning true');
      return true;
    }
    
    if (_isInitializing) {
      print('   ⏳ Already initializing, waiting for completion...');
      return await _initializationFuture;
    }

    print('   🚀 Starting new initialization');
    _isInitializing = true;
    _initializationFuture = _performInitialization();
    final result = await _initializationFuture;
    print('   📊 Initialization result: $result');
    return result;
  }

  /// Perform the actual initialization
  Future<bool> _performInitialization() async {
    try {
      print('   🔌 Calling GGUFInferenceService.initialize()...');
      final success = await _inferenceService.initialize();
      print('   ✅ GGUF initialization returned: $success');
      print('   📊 GGUFInferenceService state: isInitialized=${_inferenceService.isInitialized}');
      
      _isInitialized = success;
      _isInitializing = false;
      _initializationFailed = !success;
      
      if (success) {
        print('✅ [LocalChatService] ✅✅✅ MODEL READY FOR INFERENCE ✅✅✅');
      } else {
        print('❌ [LocalChatService] ❌❌❌ MODEL INITIALIZATION FAILED ❌❌❌');
      }
      
      return success;
    } catch (e) {
      print('❌ [LocalChatService] Exception during initialization: $e');
      print('   Stack trace: ${StackTrace.current}');
      _isInitialized = false;
      _isInitializing = false;
      _initializationFailed = true;
      return false;
    }
  }

  /// Check if model is initialized
  bool get isInitialized => _isInitialized;

  /// Check if model is currently initializing
  bool get isInitializing => _isInitializing;
  
  /// Check if initialization failed
  bool get initializationFailed => _initializationFailed;

  /// Get a future that completes when initialization is done
  Future<bool> get initializationComplete async {
    if (_isInitialized) return true;
    if (!_isInitializing) {
      throw Exception('Initialization not started. Call initialize() first.');
    }
    return await _initializationFuture;
  }

  /// Generate response from a prompt using the local model
  Future<String> generateResponse(
    String prompt, {
    int maxTokens = 300,
    double temperature = 0.7,
  }) async {
    print('📝 [LocalChatService.generateResponse] Called with prompt length=${prompt.length}');
    print('   State: _isInitialized=$_isInitialized, _isInitializing=$_isInitializing');
    
    if (!_isInitialized && !_isInitializing) {
      print('❌ Model not initialized and not initializing!');
      throw Exception('Model not initialized. Call initialize() first.');
    }
    
    // Wait for initialization if still in progress
    if (_isInitializing && !_isInitialized) {
      print('⏳ Waiting for initialization to complete...');
      final initSuccess = await _initializationFuture;
      if (!initSuccess) {
        print('❌ Initialization completed but failed!');
        throw Exception('Model initialization failed.');
      }
    }

    try {
      print('🎯 Calling model.generate() directly with prompt...');
      // Use the GGUF inference service to generate response directly with our prompt
      final response = await _inferenceService.generateResponseDirect(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
      print('✅ Response generated: ${response.length} chars');
      return response;
    } catch (e) {
      print('❌ Error in generateResponse: $e');
      if (kDebugMode) {
        print('Stack trace: ${StackTrace.current}');
      }
      rethrow;
    }
  }

  /// Create a disease-specific prompt for the model
  static String createDiseasePrompt({
    required String diseaseName,
    required String userQuestion,
    required String diseaseContext,
    required String language,
  }) {
    final normLang = language.trim().toLowerCase();
    String targetLang;
    String langInstruction;

    if (normLang == 'cebuano' || normLang == 'ceb' || normLang == 'bisaya' || normLang == 'binisaya') {
      targetLang = 'Cebuano/Bisaya';
      langInstruction = '''CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in natural Cebuano/Bisaya.
- Ignore the language of the farmer's question; even if the farmer writes in English or Tagalog/Filipino, your reply MUST be purely in Cebuano/Bisaya.
- Avoid unnecessary English or Tagalog code-switching.
- Keep proper nouns, scientific names (e.g., Xanthomonas oryzae), and essential technical terms in their standard form.''';
    } else if (normLang == 'filipino' || normLang == 'fil' || normLang == 'tagalog' || normLang == 'tl' || normLang == 'philippine') {
      targetLang = 'Filipino/Tagalog';
      langInstruction = '''CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in natural Filipino/Tagalog.
- Ignore the language of the farmer's question; even if the farmer writes in English or Bisaya/Cebuano, your reply MUST be purely in Filipino/Tagalog.
- Minimize unnecessary English borrowings.
- Keep proper nouns, scientific names (e.g., Xanthomonas oryzae), and essential technical terms in their standard form.''';
    } else {
      targetLang = 'Standard English';
      langInstruction = '''CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in clear, standard English.
- Ignore the language of the farmer's question; even if the farmer writes in Filipino or Bisaya, your reply MUST be purely in Standard English.''';
    }

    return '''### SYSTEM INSTRUCTIONS
You are AgriBot, an offline, locally running AI rice disease specialist assistant.

ENVIRONMENT & CAPABILITIES:
1. LOCAL EXECUTION: You operate purely within a local offline application environment using only the provided local disease knowledge.
2. NETWORK RESTRICTION: You do NOT have internet access, real-time web access, online search, or external connectivity.
   - You must NOT claim to have internet access, live search, or external API access.
   - If the user asks for real-time or external info (e.g., live weather, current market/palay prices, latest web news, web search), clearly state in the target language that this capability is unavailable in this offline system.
3. LANGUAGE ENFORCEMENT:
   - Target Response Language: $targetLang
   - $langInstruction
   - Do NOT switch languages or mix languages in your response.

DETECTED DISEASE: $diseaseName

LOCAL DISEASE DETAILS:
$diseaseContext

FARMER'S QUESTION: $userQuestion

RULES:
1. Answer ONLY about $diseaseName based on the local disease details provided.
2. Keep response to 1-2 concise, practical sentences with actionable advice.
3. Do NOT include disease name, severity, urgency, or general explanation in your answer unless directly asked.
4. Do NOT answer questions unrelated to rice disease or agriculture; politely decline in the target language.
5. Answer directly in $targetLang.

ANSWER:''';
  }

  /// Cleanup resources
  void dispose() {
    // Cleanup if needed
  }
}
