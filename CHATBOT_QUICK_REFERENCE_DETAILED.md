# Chatbot Implementation - Quick Reference

## 🎯 Quick Summary

**Language Selection:** Dropdown in ChatbotScreen  
**Languages Supported:** English, Cebuano (aliases: ceb, bisaya)  
**Response Format:** Single multi-language response object  
**Translation:** Static dictionary (150+ terms) + SLM dynamic (Qwen2)  
**Main Endpoint:** `POST /api/chatbot`  

---

## 📱 Frontend

### Language Selection Location
- **File:** [frontend/lib/screens/chatbot_screen.dart](frontend/lib/screens/chatbot_screen.dart#L40)
- **Variable:** `String _selectedLanguage = 'english'`
- **UI:** Dropdown menu allowing user to select language

### Quick Questions (Localized)
- **English:** "What symptoms should I watch for?" | "How do I treat this disease?" | etc.
- **Cebuano:** "Unsa nga mga sintomas akong bantayan?" | "Unsaon pagtambal ani nga sakit?" | etc.

### API Call with Language
```dart
// Payload sent to backend includes language
{
  'disease': 'leaf_blast',
  'message': 'Unsaon pagtambal?',
  'language': 'cebuano',  // ← User's selected language
  'use_slm': true
}
```

---

## 🔧 Backend

### Main Endpoint
```
POST /api/chatbot
Authorization: Bearer {token}

Request:
{
  "disease": "leaf_blast",
  "message": "How to treat this?",
  "language": "cebuano"
}

Response: ChatbotOut (all fields translated)
```

**File:** [backend/routes/prediction_routes.py](backend/routes/prediction_routes.py#L1950)

### Response Schema (ChatbotOut)
```python
{
  "disease": "leaf_blast",
  "severity": "Mataas",  # Translated
  "urgency": "Agarang aksyon",  # Translated
  "explanation": "...",  # Translated
  "symptoms": ["...", "..."],  # Translated list
  "causes": ["...", "..."],  # Translated list
  "prevention": ["...", "..."],  # Translated list
  "treatment_plan": ["Hakbang 1: ...", "Hakbang 2: ..."],  # Translated steps
  "fertilizer_guidance": ["• ...", "• ..."],  # Translated list
  "reply": "[FULL CHATBOT RESPONSE IN CEBUANO]",
  "slm_used": true,  # SLM model was used
  "slm_available": true,  # SLM is available
  "response_time_ms": 2340
}
```

---

## 🧠 Language Processing

### 1. Request Language Normalization
```python
def _normalize_language(language: str | None) -> str:
    v = (language or "english").strip().lower()
    if v in {"cebuano", "ceb", "bisaya"}:
        return "cebuano"
    return "english"
```

### 2. Response Translation (Static Dictionary)
```python
def _translate_text(text: str, language: str) -> str:
    if language != "cebuano":
        return text  # Return unchanged for English
    
    translations = {
        "Disease": "Sakit",
        "Severity": "Tubo sa kalason",
        "Symptoms": "Mga timailhan",
        "Causes": "Mga sanhi",
        "Prevention": "Pagbiwas",
        "Treatment": "Pagluyeng",
        # ... 150+ more translations
    }
    return translations.get(text, text)
```

### 3. SLM Dynamic Translation (Qwen2 Model)
For questions not matching standard intents, SLM generates contextual response:

```python
# Prompt includes language instruction
lang_instruction = "Respond in English" if language == "english" \
                  else f"Respond in {language}"

# Model generates response in target language
output = model_instance(
    prompt=f"[disease context] {lang_instruction} ... {user_question}",
    max_tokens=150,
)
```

---

## 📊 Response Generation Flow

### For Standard Questions (e.g., "What are symptoms?")
```
User Message + Language
    ↓
Detect Intent (symptoms, causes, treatment, etc.)
    ↓
Fetch KB sections matching intent
    ↓
Translate each section via _translate_text()
    ↓
Format and return
```

### For Non-Standard Questions
```
User Message + Language
    ↓
Detect Intent → No match found
    ↓
Call _generate_contextual_response()
    ↓
┌─ Try SLM Model
│  (Pass language parameter in prompt)
│  ↓
│  Generate response in target language
│  
└─ SLM unavailable? 
   Fallback to keyword-based smart response
    ↓
Translate and format
    ↓
Return response
```

---

## 🤖 SLM Model Details

**Model:** Qwen2 1.5B Instruct GGUF  
**Framework:** llama-cpp-python  
**Size:** ~940 MB  
**Context Window:** 2048 tokens  
**Max Response:** 150 tokens  
**Temperature:** 0.7  
**Language Support:** Accepts language parameter in prompt

### SLM Related Endpoints
```
GET /api/chatbot/slm-status
    → Returns: model availability, current model, response times

POST /api/chatbot/slm-download-model
    → Payload: {"model": "qwen2:0.5b"}
    → Starts async download

POST /api/chatbot/slm-switch-model
    → Payload: {"model": "qwen2:0.5b"}
    → Switches active model
```

**File:** [backend/services/slm_service.py](backend/services/slm_service.py)

---

## 📋 Supported Diseases

All diseases support multi-language responses:
- Bacterial Blight
- Brown Spot
- Leaf Blast
- Sheath Blight
- Tungro

**Knowledge Base File:** [backend/routes/prediction_routes.py](backend/routes/prediction_routes.py#L574) (lines 574+)

---

## 🔍 Current Translation Dictionary Coverage

**Translated Terms** (~150+):
- Disease-related: Disease, Severity, Urgency, Symptoms, Causes, Prevention, Treatment, Fertilizer, etc.
- Diseases: Bacterial Blight → "Bacterial Blight", Brown Spot → "Brown Spot", etc.
- Cebuano keywords: "sintomas", "hinungdan", "paglikay", "tambal", "abono", etc.

**File:** [backend/routes/prediction_routes.py](backend/routes/prediction_routes.py#L1040)

---

## 🐛 Debugging Tips

### Check if SLM is Being Used
```python
# Check slm_used flag in response
response['slm_used']  # True if SLM generated response, False if KB-based
```

### Measure Response Time
```python
response['response_time_ms']  # Time in milliseconds
# > 5000ms suggests slow response; can trigger model switch suggestion
```

### Verify Language Processing
```python
# Check request language
payload.language  # Should be normalized to "english" or "cebuano"

# Check response translation
response['severity']  # Should be translated to target language
response['reply']  # Should be full response in target language
```

### Check Model Availability
```
GET /api/chatbot/slm-status
Returns:
{
  "enabled": true,
  "available": true,
  "current_model": "qwen2:0.5b",
  "model_exists": true,
  "model_downloading": false,
  "average_response_time": 2.34
}
```

---

## 📂 Key Files Summary

| Layer | File | Key Component |
|-------|------|----------------|
| **Frontend** | [chatbot_screen.dart](frontend/lib/screens/chatbot_screen.dart) | UI, language selection, message sending |
| **Frontend** | [chatbot_service.dart](frontend/lib/services/chatbot_service.dart) | API client wrapper |
| **Backend** | [prediction_routes.py](backend/routes/prediction_routes.py) | `/api/chatbot` endpoint, reply generation |
| **Backend** | [slm_service.py](backend/services/slm_service.py) | Qwen2 model integration, dynamic translation |
| **Backend** | [schemas.py](backend/schemas.py) | `ChatbotIn`, `ChatbotOut` request/response models |

---

## ⚡ Implementation Highlights

✅ **Multi-language support:** English + Cebuano  
✅ **Smart translation:** Static dictionary + SLM dynamic  
✅ **Fallback handling:** Keywords + SLM both available  
✅ **Model flexibility:** Can download/switch SLM models  
✅ **Performance tracking:** Response times monitored  
✅ **Activity logging:** All chatbot interactions logged  
✅ **Disease ranking:** Popular diseases tracked  

