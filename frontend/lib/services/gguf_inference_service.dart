import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dart_llama/dart_llama.dart';

/// Service for running GGUF model inference locally
class GGUFInferenceService {
  static GGUFInferenceService? _instance;
  LlamaModel? _model;
  bool _isInitialized = false;
  bool _isLoading = false;

  GGUFInferenceService._();

  /// Get singleton instance
  static GGUFInferenceService getInstance() {
    _instance ??= GGUFInferenceService._();
    return _instance!;
  }

  /// Check if model is initialized
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Initialize the GGUF model from downloaded file
  Future<bool> initialize() async {
    if (_isInitialized || _isLoading) return _isInitialized;

    _isLoading = true;
    try {
      final appDir = await getApplicationSupportDirectory();
      final modelPath =
          '${appDir.path}${Platform.pathSeparator}slm_models${Platform.pathSeparator}model.bin';
      final modelFile = File(modelPath);

      print('DEBUG GGUF: App support dir: ${appDir.path}');
      print('DEBUG GGUF: Checking model at path: $modelPath');
      
      if (!modelFile.existsSync()) {
        print('DEBUG GGUF: ❌ Model file NOT found at $modelPath');
        
        // Check if slm_models directory exists
        final slmDir = Directory('${appDir.path}${Platform.pathSeparator}slm_models');
        if (slmDir.existsSync()) {
          print('DEBUG GGUF: ℹ slm_models directory exists');
          try {
            final files = slmDir.listSync();
            print('DEBUG GGUF: Files in slm_models: ${files.map((f) => f.path).toList()}');
          } catch (e) {
            print('DEBUG GGUF: Error listing directory: $e');
          }
        } else {
          print('DEBUG GGUF: ℹ slm_models directory does NOT exist');
        }
        
        print('DEBUG GGUF: Please download the model from the SLM Management page');
        return false;
      }

      final fileSize = modelFile.lengthSync();
      print('DEBUG GGUF: ✓ Model file found! Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB');

      // Initialize with correct API
      final config = LlamaConfig(
        modelPath: modelPath,
        contextSize: 512,
        batchSize: 256,
        threads: 4,
        useMmap: true,
      );

      print('DEBUG GGUF: Creating LlamaModel instance...');
      _model = LlamaModel(config);
      
      print('DEBUG GGUF: ✓ Model initialization complete!');
      _isInitialized = true;
      return true;
    } catch (e) {
      print('DEBUG GGUF: ❌ Error initializing GGUF model: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Generate a response using the local GGUF model with a pre-built prompt
  /// This bypasses the internal prompt template and uses the prompt directly
  Future<String> generateResponseDirect({
    required String prompt,
    int maxTokens = 200,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized || _model == null) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    try {
      print('DEBUG GGUF: Generating response with direct prompt (${prompt.length} chars)...');
      print('DEBUG GGUF: maxTokens=$maxTokens, temperature=$temperature');

      // Generate response using the model with correct API
      print('DEBUG GGUF: Creating GenerationRequest...');
      final request = GenerationRequest(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
        repeatLastN: 64,
      );
      
      print('DEBUG GGUF: Calling model.generate()...');
      dynamic response = await _model!.generate(request);
      print('DEBUG GGUF: ✓ Response received');
      
      // Extract text from response
      String result;
      try {
        if (response is String) {
          result = response;
        } else if (response.hasProperty('text') || response is Map) {
          result = (response as dynamic).text ?? response.toString();
        } else {
          result = response.toString();
        }
      } catch (parseError) {
        result = response.toString();
      }
      
      print('DEBUG GGUF: ✓ Generated response (${result.length} chars)');
      return result.trim();
    } catch (e) {
      print('Error generating response with GGUF model: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Generate a response using the local GGUF model
  Future<String> generateResponse({
    required String diseaseName,
    required String userQuestion,
    required Map<String, dynamic> diseaseInfo,
    String language = 'english',
    int maxTokens = 200,
    double temperature = 0.7,
  }) async {
    if (!_isInitialized || _model == null) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    try {
      // Build context from disease information
      final context = _buildDiseaseContext(diseaseName, diseaseInfo, language);

      // Create prompt
      final prompt = _createPrompt(
        diseaseName: diseaseName,
        userQuestion: userQuestion,
        context: context,
        language: language,
      );

      print('DEBUG GGUF: Generating response with prompt (${prompt.length} chars)...');
      print('DEBUG GGUF: maxTokens=$maxTokens, temperature=$temperature');

      // Generate response using the model with correct API
      print('DEBUG GGUF: Creating GenerationRequest...');
      final request = GenerationRequest(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
        repeatLastN: 64,
      );
      
      print('DEBUG GGUF: Calling model.generate()...');
      dynamic response = await _model!.generate(request);
      print('DEBUG GGUF: ✓ Response received');
      
      // Extract text from response
      String result;
      try {
        if (response is String) {
          result = response;
        } else if (response.hasProperty('text') || response is Map) {
          result = (response as dynamic).text ?? response.toString();
        } else {
          result = response.toString();
        }
      } catch (parseError) {
        result = response.toString();
      }
      
      print('DEBUG GGUF: ✓ Generated response (${result.length} chars)');
      return result.trim();
    } catch (e) {
      print('Error generating response with GGUF model: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Build disease context from disease information
  String _buildDiseaseContext(
    String diseaseName,
    Map<String, dynamic> diseaseInfo,
    String language,
  ) {
    final contextParts = <String>[];

    // Add severity
    if (diseaseInfo.containsKey('severity')) {
      contextParts.add('Severity: ${diseaseInfo['severity']}');
    }

    // Add urgency
    if (diseaseInfo.containsKey('urgency')) {
      contextParts.add('Urgency: ${diseaseInfo['urgency']}');
    }

    // Add explanation
    if (diseaseInfo.containsKey('explanation')) {
      contextParts.add('Overview: ${diseaseInfo['explanation']}');
    }

    // Add symptoms
    final symptoms = diseaseInfo['symptoms'] as List?;
    if (symptoms != null && symptoms.isNotEmpty) {
      final symptomList = symptoms.take(3).join(', ');
      contextParts.add('Key Symptoms: $symptomList');
    }

    // Add prevention
    final prevention = diseaseInfo['prevention'] as List?;
    if (prevention != null && prevention.isNotEmpty) {
      final preventionList = prevention.take(2).join(', ');
      contextParts.add('Prevention: $preventionList');
    }

    // Add treatment
    final treatment = diseaseInfo['treatment_plan'] as List?;
    if (treatment != null && treatment.isNotEmpty) {
      final treatmentList = treatment.take(2).join(', ');
      contextParts.add('Treatment: $treatmentList');
    }

    return contextParts.join('\n');
  }

  /// Create a structured prompt for the model
  String _createPrompt({
    required String diseaseName,
    required String userQuestion,
    required String context,
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
$context

FARMER'S QUESTION: $userQuestion

RULES:
1. Answer ONLY about $diseaseName based on the local disease details provided.
2. Keep response to 1-2 concise, practical sentences with actionable advice.
3. Do NOT include disease name, severity, urgency, or general explanation in your answer unless directly asked.
4. Do NOT answer questions unrelated to rice disease or agriculture; politely decline in the target language.
5. Answer directly in $targetLang.

ANSWER:''';
  }

  /// Dispose of resources
  void dispose() {
    _model?.dispose();
    _model = null;
    _isInitialized = false;
  }
}
