# Chatbot Implementation - Code Reference Guide

## Navigation Index

- [1. Frontend Code](#1-frontend-code)
- [2. Backend Code](#2-backend-code)
- [3. Response Schema](#3-response-schema)
- [4. Translation Code](#4-translation-code)
- [5. SLM Integration Code](#5-slm-integration-code)
- [6. API Endpoints](#6-api-endpoints)

---

## 1. Frontend Code

### Language Selection Setup
**File:** [frontend/lib/screens/chatbot_screen.dart](frontend/lib/screens/chatbot_screen.dart#L40)

```dart
class _ChatbotScreenState extends State<ChatbotScreen> {
  // ... other variables ...
  
  String _selectedLanguage = 'english';  // ← Default language
  
  // Supported languages set by user via UI dropdown
  // Options: 'english', 'cebuano'
}
```

### Quick Questions (Localized)
**Lines: 60-75**

```dart
static const _quickQuestions = [
  'What symptoms should I watch for?',
  'How do I treat this disease?',
  'How can I prevent it from spreading?',
  'What fertilizer guidance should I follow?',
];

static const _quickQuestionsCebuano = [
  'Unsa nga mga sintomas akong bantayan?',
  'Unsaon pagtambal ani nga sakit?',
  'Unsaon paglikay nga mokaylap kini?',
  'Unsa nga giya sa abono akong sundon?',
];

// Dynamic getter based on selected language
List<String> get _localizedQuickQuestions {
  return _selectedLanguage == 'cebuano' 
      ? _quickQuestionsCebuano 
      : _quickQuestions;
}
```

### Sending Message with Language
**Lines: 315-360**

```dart
Future<void> _sendMessage(String message) async {
  if (widget.accessToken == null || widget.accessToken!.isEmpty) {
    setState(() {
      _error = 'Please sign in again to use AgriBot.';
    });
    return;
  }

  setState(() {
    _loading = true;
    _error = null;
    if (message.trim().isNotEmpty) {
      _messages.add(_ChatMessage(text: message.trim(), isUser: true));
    }
  });

  try {
    final uri = Uri.parse('$apiBaseUrl/api/chatbot');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (widget.accessToken != null)
          'Authorization': 'Bearer ${widget.accessToken}',
      },
      body: jsonEncode({
        'disease': _selectedDisease,
        'message': message.trim(),
        'language': _selectedLanguage,  // ← INCLUDE LANGUAGE HERE
        'use_slm': _useSLMMode,
        'timestamp': DateTime.now().toIso8601String(),
        'save_to_history': true,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply']?.toString() ?? 'No reply available.';
      final slmUsed = data['slm_used'] as bool? ?? false;
      
      setState(() {
        _messages.add(_ChatMessage(
          text: reply,  // ← ALREADY IN TARGET LANGUAGE
          isUser: false,
          slmUsed: slmUsed,
        ));
      });
    }
  } catch (e) {
    setState(() {
      _error = 'AgriBot is unavailable right now. Please try again.';
    });
  }
}
```

### ChatbotService API Client
**File:** [frontend/lib/services/chatbot_service.dart](frontend/lib/services/chatbot_service.dart)

```dart
class ChatbotService {
  final String? token;

  ChatbotService({this.token});

  ApiClient get _client =>
      ApiClient(baseUrl: AppConstants.apiBaseUrl, token: token);

  Future<String?> ask(String disease, String message) async {
    final res = await _client.post('/api/chatbot', {
      'disease': disease,
      'message': message,
      // Note: Language parameter should be added here in request
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['reply']?.toString();
    }

    throw Exception('Chatbot failed (${res.statusCode}): ${res.body}');
  }
}
```

---

## 2. Backend Code

### Main Chatbot Endpoint
**File:** [backend/routes/prediction_routes.py](backend/routes/prediction_routes.py#L1950)

```python
@router.post("/chatbot", response_model=ChatbotOut)
def chatbot(
    payload: ChatbotIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Main chatbot endpoint that handles user questions about detected diseases.
    Supports multiple languages and SLM model integration.
    """
    # 1. Normalize inputs
    disease_key = _normalize_disease(payload.disease)
    language = _normalize_language(payload.language)
    
    # 2. Fetch knowledge base
    kb = disease_from_db(db, disease_key) or DISEASE_KB.get(disease_key)

    # 3. Check SLM availability
    slm_available = check_ollama_availability()
    slm_used = False

    # 4. Handle unknown disease
    if not kb:
        return ChatbotOut(
            disease=disease_key,
            severity=_translate_text("Unknown", language),
            urgency=_translate_text("Please verify the image / label", language),
            explanation=_translate_text("I don't recognize this disease label yet.", language),
            symptoms=[_translate_text("N/A", language)],
            causes=[_translate_text("N/A", language)],
            prevention=[...],
            treatment_plan=[...],
            fertilizer_guidance=[...],
            next_steps=[...],
            when_to_contact=[...],
            reply=_translate_text("Unknown disease label.", language),
            slm_used=slm_used,
            slm_available=slm_available
        )

    # 5. Generate reply
    reply, slm_used, response_time = _build_reply(disease_key, kb, payload.message, language)
    
    # 6. Log activity
    update_disease_ranking(db, disease_key, user_location=current_user.location)
    log_activity(
        db,
        user_id=current_user.id,
        action="chatbot.ask",
        detail={
            "disease": disease_key, 
            "message": payload.message or "", 
            "slm_used": slm_used,
            "response_time": response_time
        },
        location=current_user.location
    )

    # 7. Return translated response
    return ChatbotOut(
        disease=disease_key,
        severity=kb["severity"],  # ← Already translated
        urgency=kb["urgency"],    # ← Already translated
        explanation=kb["explanation"],
        symptoms=kb["symptoms"],
        causes=kb["causes"],
        prevention=kb["prevention"],
        treatment_plan=kb["treatment_plan"],
        fertilizer_guidance=kb["fertilizer_guidance"],
        next_steps=kb.get("next_steps", []),
        when_to_contact=kb.get("when_to_contact", []),
        reply=reply,  # ← Already translated
        slm_used=slm_used,
        slm_available=slm_available,
        response_time_ms=int(response_time * 1000)
    )
```

---

## 3. Response Schema

**File:** [backend/schemas.py](backend/schemas.py#L85-L105)

```python
class ChatbotIn(BaseModel):
    """Request schema for chatbot endpoint"""
    disease: str
    message: Optional[str] = None              # Optional user question
    language: Optional[str] = "english"        # ← LANGUAGE PARAMETER
    is_quick_question: Optional[bool] = False  # Flag for quick questions

class ChatbotOut(BaseModel):
    """Response schema - ALL FIELDS PRE-TRANSLATED"""
    disease: str                               # Disease key
    severity: str                              # ← TRANSLATED
    urgency: str                               # ← TRANSLATED
    explanation: str                           # ← TRANSLATED
    symptoms: List[str]                        # ← TRANSLATED LIST
    causes: List[str]                          # ← TRANSLATED LIST
    prevention: List[str]                      # ← TRANSLATED LIST
    treatment_plan: List[str]                  # ← TRANSLATED STEPS
    fertilizer_guidance: List[str]             # ← TRANSLATED LIST
    next_steps: List[str]                      # ← TRANSLATED
    when_to_contact: List[str]                 # ← TRANSLATED
    reply: str                                 # ← FULL RESPONSE IN TARGET LANGUAGE
    slm_used: Optional[bool] = False           # SLM model was used?
    slm_available: Optional[bool] = False      # SLM available?
    response_time_ms: Optional[int] = 0        # Response time
```

### Example Response (Cebuano)
```json
{
  "disease": "leaf_blast",
  "severity": "Mataas",
  "urgency": "Agarang aksyon",
  "explanation": "Ang Leaf Blast ay isang fungal disease na nakakaapekto...",
  "symptoms": [
    "Mga likid na may small, oblong lesions na mayroon dalawang kulay",
    "Mga veins ay nagiging dark brown o gray"
  ],
  "causes": [
    "High humidity at mainit na panahon",
    "Poor air circulation"
  ],
  "prevention": [
    "Gamitin ang disease-free na binhi",
    "Maintain proper field drainage"
  ],
  "treatment_plan": [
    "Hakbang 1: Alisin ang lubhang nakahawang tanim",
    "Hakbang 2: Mag-apply ng approved fungicide"
  ],
  "fertilizer_guidance": [
    "Gamita ang balanced NPK fertilizer",
    "Iwasan ang sobrang nitrogen"
  ],
  "next_steps": ["Monitor field regularly", "Consult agriculture technician"],
  "when_to_contact": ["If disease spreads rapidly", "If multiple plants affected"],
  "reply": "[FULL CHATBOT RESPONSE IN CEBUANO]",
  "slm_used": false,
  "slm_available": true,
  "response_time_ms": 340
}
```

---

## 4. Translation Code

### Language Normalization
**Lines: 1029-1035**

```python
def _normalize_language(language: str | None) -> str:
    """Normalize language parameter to supported language."""
    v = (language or "english").strip().lower()
    if v in {"cebuano", "ceb", "bisaya"}:
        return "cebuano"
    return "english"
```

### Static Translation Dictionary
**Lines: 1036-1200+**

```python
def _translate_text(text: str, language: str) -> str:
    """Translate text to target language using static dictionary."""
    if language != "cebuano":
        return text  # No translation for English

    translations = {
        # General terms
        "Disease": "Sakit",
        "Severity": "Tubo sa kalason",
        "Urgency": "Kinahanglan ug bili",
        "Unknown": "Wala mailhi",
        
        # Categories
        "Symptoms": "Mga timailhan",
        "Causes": "Mga sanhi",
        "Prevention": "Pagbiwas",
        "Disease Management Strategy": "Plano sa pagluyeng sakit",
        "Fertilizer guidance": "Pagtoon sa pataba",
        
        # Full sentences
        "You can ask me about:": "Pwede ka pangutana bahin sa:",
        "Note: This is general guidance...": "Pasa-ingat: Kini ay pangumum-ingon...",
        
        # Steps
        "Step ": "Hakbang ",
        
        # Disease names and symptoms
        "Leaf Blast": "Leaf Blast",
        "Bacterial Blight": "Bacterial Blight",
        "leaves with brown lesions": "mga likod na may mainit na kulay",
        "veins turn yellow": "mga ugat ay nagiging dilaw",
        
        # Treatment/prevention items (examples from KB)
        "Remove heavily infected plants if practical": 
            "Alisin ang lubhang nakahawang tanim kung praktikal",
        "Apply approved fungicides with local guidance": 
            "Magbigay ng aprubadong fungicide gamit ang gabay ng lokal",
        
        # ... 150+ more translations ...
    }
    
    return translations.get(text, text)
```

### Translation Application
**Lines: 1892-1948**

```python
def _build_reply(disease_key: str, kb: dict, user_msg: str | None, language: str) -> tuple[str, bool, float]:
    """
    Build a reply, applying translations to all KB fields.
    """
    # Translate display name
    display = _translate_text(kb.get("display", disease_key.replace("_", " ").title()), language)
    
    # Translate severity and urgency
    severity = _translate_text(kb.get("severity", "Unknown"), language)
    urgency = _translate_text(kb.get("urgency", "N/A"), language)
    
    # Process symptoms with translation
    if "symptoms" in intents:
        parts.append(_format_list(
            "\nSymptoms", 
            kb.get("symptoms", []), 
            language,  # ← Pass language parameter
            "bullets"
        ))
    
    # Process treatment with translation
    if "treatment_plan" in intents:
        parts.append(_format_list(
            "\nDisease Management Strategy", 
            kb.get("treatment_plan", []), 
            language,  # ← Pass language parameter
            "steps"
        ))
    
    # ... more sections ...
    
    return "\n".join(parts), False, 0.0


def _format_list(title: str, items: list[str], language: str, section_type: str = "steps") -> str:
    """Format list items with translation."""
    translated_title = _translate_text(title, language)
    
    if not items:
        if section_type == "bullets":
            return f"{translated_title}:\n• {_translate_text('N/A', language)}"
        else:
            step_label = _translate_text('Step ', language)
            return f"{translated_title}:\n{step_label}1: {_translate_text('N/A', language)}"
    
    formatted_items = []
    
    if section_type == "bullets":
        for item in items:
            tx_item = _translate_text(item, language)  # ← TRANSLATE EACH ITEM
            if len(tx_item) > 100:
                tx_item = tx_item[:100] + "..."
            formatted_items.append(f"• {tx_item}")
    else:
        step_label = _translate_text('Step ', language)
        for idx, item in enumerate(items, 1):
            tx_item = _translate_text(item, language)  # ← TRANSLATE EACH ITEM
            if len(tx_item) > 100:
                tx_item = tx_item[:100] + "..."
            formatted_items.append(f"{step_label}{idx}: {tx_item}")
    
    return translated_title + ":\n" + "\n".join(formatted_items)
```

---

## 5. SLM Integration Code

### SLM Service Main Function
**File:** [backend/services/slm_service.py](backend/services/slm_service.py#L175)

```python
def generate_disease_response(
    disease_name: str,
    user_question: str,
    disease_info: dict,
    language: str = "english"  # ← LANGUAGE PARAMETER
) -> tuple[Optional[str], float]:
    """
    Generate an intelligent, disease-specific response using Qwen2 GGUF model.
    
    Args:
        disease_name: Name of the disease
        user_question: The user's question
        disease_info: Dictionary containing disease information
        language: Target language for the response  ← IMPORTANT
    
    Returns:
        Tuple of (response_text, response_time_in_seconds)
    """
    
    if not ENABLE_SLM:
        logger.debug("SLM mode is disabled")
        return None, 0.0
    
    global model_instance, model_loaded
    
    start_time = time.time()
    
    try:
        # Ensure model is loaded
        if not model_loaded:
            if not _load_model():
                logger.error("Failed to load model")
                return None, 0.0
        
        # Build context from disease information
        context = _build_disease_context(disease_name, disease_info, language)
        
        # Create the prompt WITH LANGUAGE INSTRUCTION
        prompt = _create_prompt(disease_name, user_question, context, language)
        
        # Generate response using the local GGUF model
        output = model_instance(
            prompt=prompt,
            max_tokens=MAX_RESPONSE_TOKENS,
            temperature=0.7,
            top_p=0.9,
            stop=["USER:", "FARMER:", "\n\nFARMER:"],
            echo=False
        )
        
        elapsed_time = time.time() - start_time
        
        if output and "choices" in output:
            generated_text = output["choices"][0]["text"].strip()
            track_response_time(elapsed_time)
            logger.info(f"SLM generated response in {elapsed_time:.2f}s")
            return generated_text, elapsed_time
        else:
            logger.error("Invalid response from model")
            return None, elapsed_time
            
    except Exception as e:
        elapsed_time = time.time() - start_time
        logger.error(f"Error generating SLM response: {str(e)}")
        return None, elapsed_time
```

### Prompt Creation with Language
**Lines: 278-317**

```python
def _create_prompt(
    disease_name: str,
    user_question: str,
    context: str,
    language: str  # ← LANGUAGE PARAMETER
) -> str:
    """Create a structured prompt for the SLM model with language instruction."""
    
    # ← KEY: Create language-specific instruction
    lang_instruction = "Respond in English" if language == "english" \
                      else f"Respond in {language}"
    
    prompt = f"""You are AgriBot, a rice disease specialist assistant.

DETECTED DISEASE: {disease_name}

DISEASE DETAILS:
{context}

FARMER'S QUESTION: {user_question}

RULES:
1. Answer ONLY about {disease_name} - do not discuss other diseases
2. If the question is about disease, focus specifically on {disease_name}
3. Keep response to 1-2 sentences maximum (be very concise)
4. Be practical and actionable - give specific advice
5. {lang_instruction}  ← ← ← LANGUAGE CONTROL
6. Do NOT include disease name, severity, urgency, or general explanation in your answer
7. Do NOT answer questions unrelated to {disease_name}
8. Answer the question directly without repeating disease details already shown

ANSWER:"""
    
    return prompt
```

### Context Building
**Lines: 248-277**

```python
def _build_disease_context(disease_name: str, disease_info: dict, language: str) -> str:
    """Build context string from disease information for SLM prompt."""
    
    context_parts = []
    
    # Add basic disease info
    if "severity" in disease_info:
        context_parts.append(f"Severity: {disease_info['severity']}")
    if "urgency" in disease_info:
        context_parts.append(f"Urgency: {disease_info['urgency']}")
    if "explanation" in disease_info:
        context_parts.append(f"Overview: {disease_info['explanation']}")
    
    # Add symptoms (first 3)
    symptoms = disease_info.get("symptoms", [])
    if symptoms:
        context_parts.append(f"Key Symptoms: {', '.join(symptoms[:3])}")
    
    # Add prevention measures (first 2)
    prevention = disease_info.get("prevention", [])
    if prevention:
        context_parts.append(f"Prevention: {', '.join(prevention[:2])}")
    
    # Add treatment options (first 2)
    treatment = disease_info.get("treatment_plan", [])
    if treatment:
        context_parts.append(f"Treatment: {', '.join(treatment[:2])}")
    
    return "\n".join(context_parts)
```

### Contextual Response Generation (with SLM fallback)
**Lines: 1761-1890**

```python
def _generate_contextual_response(disease_name: str, kb: dict, question: str, language: str) -> tuple[str, bool, float]:
    """
    Generate an intelligent contextual response for questions that don't match standard intents.
    Uses SLM model (Qwen2) if available, otherwise falls back to smart keyword-based approach.
    
    Returns:
        Tuple of (response_text, slm_used, response_time)
    """
    q_lower = (question or "").lower()
    
    # Try SLM model first if enabled
    try:
        slm_response, response_time = generate_disease_response(
            disease_name=disease_name,
            user_question=question,
            disease_info=kb,
            language=language  # ← Pass language to SLM
        )
        if slm_response:
            # Add footer with disclaimer
            note = _translate_text(
                "Note: This is general guidance—follow local agriculture office recommendations...", 
                language  # ← Also translate disclaimer
            )
            return f"{slm_response}\n\n{note}", True, response_time
    except Exception as e:
        import logging
        logging.warning(f"SLM generation failed, falling back: {str(e)}")
    
    # Fallback to smart keyword-based response if SLM is unavailable
    asks_about_overview = any(kw in q_lower for kw in ["tell me", "explain", "what is", "about"])
    asks_about_severity = any(kw in q_lower for kw in ["serious", "severe", "danger", "risk"])
    asks_about_solution = any(kw in q_lower for kw in ["do", "solve", "fix", "help", "what can"])
    
    # ... build response based on detected intent ...
    
    # Translate all response parts
    severity = _translate_text(kb.get("severity", "Moderate"), language)
    urgency = _translate_text(kb.get("urgency", "Monitor"), language)
    
    # ... build response_parts with translations ...
    
    response = "\n\n".join(response_parts)
    note = _translate_text("Note: This is general guidance...", language)
    response += f"\n\n{note}"
    
    return response, False, 0.0
```

---

## 6. API Endpoints

### Endpoint 1: Main Chatbot
```
POST /api/chatbot
Content-Type: application/json
Authorization: Bearer {token}

Request:
{
  "disease": "leaf_blast",
  "message": "How to treat?",
  "language": "cebuano"
}

Response: ChatbotOut (above)
```

**Implementation:** [prediction_routes.py:1950](backend/routes/prediction_routes.py#L1950)

### Endpoint 2: SLM Status
```
GET /api/chatbot/slm-status
Authorization: Bearer {token}

Response:
{
  "enabled": true,
  "available": true,
  "current_model": "qwen2:0.5b",
  "model_exists": true,
  "model_downloading": false,
  "available_models": {
    "qwen2:0.5b": {"size": "312MB", "speed": "Fast", "quality": "Good"},
    "qwen2:1.0b": {"size": "621MB", "speed": "Medium", "quality": "Better"},
    "qwen2:1.5b": {"size": "940MB", "speed": "Slow", "quality": "Best"}
  },
  "average_response_time": 2.34,
  "timestamp": "2024-04-22T10:30:45.123456"
}
```

**Implementation:** [prediction_routes.py:2020](backend/routes/prediction_routes.py#L2020)

### Endpoint 3: Download SLM Model
```
POST /api/chatbot/slm-download-model
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "model": "qwen2:1.0b"
}

Response:
{
  "status": "downloading",
  "model": "qwen2:1.0b",
  "message": "Downloading qwen2:1.0b. This may take a few minutes."
}
```

**Implementation:** [prediction_routes.py:2038](backend/routes/prediction_routes.py#L2038)

### Endpoint 4: Switch SLM Model
```
POST /api/chatbot/slm-switch-model
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "model": "qwen2:0.5b"
}

Response:
{
  "status": "success",
  "model": "qwen2:0.5b",
  "message": "Model switched successfully"
}
```

**Implementation:** [prediction_routes.py:2081](backend/routes/prediction_routes.py#L2081)

---

## Quick Copy-Paste Reference

### Send Chatbot Request (Frontend)
```dart
final res = await http.post(
  Uri.parse('$apiBaseUrl/api/chatbot'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'disease': 'leaf_blast',
    'message': 'Unsaon pagtambal?',
    'language': 'cebuano',  // ← Include language
  }),
);
```

### Extract Language from Request (Backend)
```python
from routes.prediction_routes import _normalize_language

language = _normalize_language(payload.language)
# Returns "cebuano" or "english"
```

### Translate Text (Backend)
```python
from routes.prediction_routes import _translate_text

text_en = "Disease Management Strategy"
text_ceb = _translate_text(text_en, "cebuano")
# Returns: "Plano sa pagluyeng sakit"
```

### Check SLM Availability (Frontend)
```dart
await _fetchSLMModels();
if (_slmAvailable) {
  // SLM model is available and can generate contextual responses
}
```

### Generate SLM Response (Backend)
```python
from services.slm_service import generate_disease_response

response, elapsed_time = generate_disease_response(
    disease_name="leaf_blast",
    user_question="Unsaon pagtambal?",
    disease_info=kb,
    language="cebuano"  # ← Model will respond in Cebuano
)
```

