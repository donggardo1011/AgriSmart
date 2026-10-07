"""
SLM (Small Language Model) Service using Qwen2 GGUF Model via llama-cpp-python.
Provides intelligent, disease-specific responses for the AgriBot chatbot.
Supports local GGUF model inference.
"""

import os
import json
import logging
import time
from typing import Optional
from datetime import datetime
import threading

logger = logging.getLogger(__name__)

# Configuration
SLM_MODEL_URL = os.getenv("SLM_MODEL_URL", "https://huggingface.co/itlwas/Qwen2-1.5B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2-1.5b-instruct-q4_k_m.gguf?download=true")
SLM_MODEL_SIZE = int(os.getenv("SLM_MODEL_SIZE", "940"))  # Size in MB
ENABLE_SLM = os.getenv("ENABLE_SLM", "false").lower() == "true"
SLM_TIMEOUT = int(os.getenv("SLM_TIMEOUT", "30"))  # 30 second timeout
SLOW_RESPONSE_THRESHOLD = int(os.getenv("SLOW_RESPONSE_THRESHOLD", "5"))  # 5 seconds
MAX_RESPONSE_TOKENS = int(os.getenv("MAX_RESPONSE_TOKENS", "150"))  # Limit response to 150 tokens max

# Model cache directory
MODEL_CACHE_DIR = os.path.join(os.path.expanduser("~"), ".agribot_models")
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)

# Track response times for auto-detection
response_times = []
model_instance = None
model_loaded = False
model_download_in_progress = False

# Check if llama-cpp-python is available
LLAMA_CPP_AVAILABLE = False
try:
    import llama_cpp
    LLAMA_CPP_AVAILABLE = True
    logger.info("llama-cpp-python is available")
except ImportError:
    logger.warning("llama-cpp-python not installed. SLM will be disabled. Install with: pip install llama-cpp-python")
    ENABLE_SLM = False  # Force disable SLM if library not available

def _get_model_path() -> str:
    """Get the local path where the model should be stored."""
    return os.path.join(MODEL_CACHE_DIR, "qwen2-1.5b-instruct-q4_k_m.gguf")

def _download_model(url: str, model_path: str) -> bool:
    """Download model from Hugging Face."""
    import requests
    
    try:
        logger.info(f"Downloading model from {url}")
        response = requests.get(url, stream=True, timeout=None)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        with open(model_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        logger.info(f"Download progress: {percent:.1f}%")
        
        logger.info(f"Model downloaded successfully to {model_path}")
        return True
    except Exception as e:
        logger.error(f"Error downloading model: {str(e)}")
        return False

def _load_model():
    """Load the GGUF model into memory."""
    global model_instance, model_loaded
    
    if not LLAMA_CPP_AVAILABLE:
        logger.error("llama-cpp-python not installed. Cannot load model.")
        return False
    
    try:
        from llama_cpp import Llama
        
        model_path = _get_model_path()
        
        # Download if not exists
        if not os.path.exists(model_path):
            logger.info(f"Model not found at {model_path}, downloading...")
            if not _download_model(SLM_MODEL_URL, model_path):
                logger.error("Failed to download model")
                return False
        
        logger.info(f"Loading model from {model_path}")
        model_instance = Llama(
            model_path=model_path,
            n_ctx=2048,  # Context window
            n_gpu_layers=-1,  # Use GPU if available
            verbose=False
        )
        model_loaded = True
        logger.info("Model loaded successfully")
        return True
    except ImportError:
        logger.error("llama-cpp-python not installed. Install with: pip install llama-cpp-python")
        return False
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        return False

def get_current_model() -> str:
    """Get the currently active model."""
    return "qwen2-1.5b-instruct-q4_k_m"

def set_current_model(model_name: str) -> bool:
    """Model switching not supported with GGUF."""
    logger.warning("Model switching not supported with direct GGUF model")
    return False

def pull_model_async(model_name: str, callback=None) -> threading.Thread:
    """Model pulling not needed with direct GGUF."""
    if callback:
        callback(model_name, True, "GGUF model already available")
    return threading.Thread(target=lambda: None, daemon=True)

def is_model_downloading() -> bool:
    """Check if a model is currently being downloaded."""
    global model_download_in_progress
    return model_download_in_progress

def track_response_time(duration_seconds: float) -> None:
    """Track response time for slow detection."""
    global response_times
    response_times.append(duration_seconds)
    
    # Keep only last 10 responses
    if len(response_times) > 10:
        response_times.pop(0)

def get_average_response_time() -> float:
    """Get average response time across recent requests."""
    if not response_times:
        return 0.0
    return sum(response_times) / len(response_times)

def get_available_models() -> dict:
    """Get list of available models - only GGUF model available."""
    return {
        "qwen2-1.5b-instruct-q4_k_m": {
            "size": f"{SLM_MODEL_SIZE}MB",
            "speed": "Medium",
            "quality": "Better"
        }
    }

def check_model_available_locally(model_name: str = None) -> bool:
    """Check if the GGUF model is available locally."""
    model_path = _get_model_path()
    return os.path.exists(model_path)

def check_ollama_availability() -> bool:
    """Check if SLM is available (GGUF version)."""
    if not ENABLE_SLM:
        return False
    
    # Ensure model is loaded
    global model_loaded
    if not model_loaded:
        return _load_model()
    
    return model_loaded


def generate_disease_response(
    disease_name: str,
    user_question: str,
    disease_info: dict,
    language: str = "english"
) -> tuple[Optional[str], float]:
    """
    Generate an intelligent, disease-specific response using Qwen2 GGUF model.
    
    Args:
        disease_name: Name of the disease (e.g., "Bacterial Blight")
        user_question: The user's question
        disease_info: Dictionary containing disease information (symptoms, treatment, etc.)
        language: Target language for the response
    
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
        
        # Create the prompt
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
            
            # Track response time for monitoring
            track_response_time(elapsed_time)
            
            # Log successful generation
            logger.info(f"SLM generated response for {disease_name} in {elapsed_time:.2f}s")
            
            return generated_text, elapsed_time
        else:
            logger.error("Invalid response from model")
            return None, elapsed_time
            
    except Exception as e:
        elapsed_time = time.time() - start_time
        logger.error(f"Error generating SLM response: {str(e)}")
        return None, elapsed_time


def _build_disease_context(disease_name: str, disease_info: dict, language: str) -> str:
    """Build context string from disease information."""
    
    context_parts = []
    
    # Add basic disease info
    if "severity" in disease_info:
        context_parts.append(f"Severity: {disease_info['severity']}")
    if "urgency" in disease_info:
        context_parts.append(f"Urgency: {disease_info['urgency']}")
    if "explanation" in disease_info:
        context_parts.append(f"Overview: {disease_info['explanation']}")
    
    # Add symptoms
    symptoms = disease_info.get("symptoms", [])
    if symptoms:
        context_parts.append(f"Key Symptoms: {', '.join(symptoms[:3])}")
    
    # Add prevention measures
    prevention = disease_info.get("prevention", [])
    if prevention:
        context_parts.append(f"Prevention: {', '.join(prevention[:2])}")
    
    # Add treatment options
    treatment = disease_info.get("treatment_plan", [])
    if treatment:
        context_parts.append(f"Treatment: {', '.join(treatment[:2])}")
        
    # Append Q&A Context
    try:
        import json
        qa_file = os.path.join(os.path.dirname(__file__), "..", "dataset_clean", "agrismart_qa.json")
        if os.path.exists(qa_file):
            with open(qa_file, "r", encoding="utf-8") as f:
                qa_data = json.load(f)
            
            # Map disease name to key
            d_key = disease_name.lower().replace(" ", "_")
            if "bacterial" in d_key: d_key = "bacterial_blight"
            elif "tungro" in d_key: d_key = "tungro"
            elif "blast" in d_key: d_key = "leaf_blast"
            elif "sheath" in d_key: d_key = "sheath_blight"
            elif "brown" in d_key: d_key = "brown_spot"
            
            # Get language
            l_key = "english"
            if language:
                l = language.lower()
                if l in ["cebuano", "ceb", "bisaya", "binisaya"]:
                    l_key = "bisaya"  # Fallback to Bisaya/Cebuano Q&As
            
            relevant_qas = [qa for qa in qa_data if qa["disease"] == d_key and qa["language"] in [l_key, "cebuano", "bisaya"]]
            if not relevant_qas:
                relevant_qas = [qa for qa in qa_data if qa["disease"] == d_key and qa["language"] == "english"]
            
            if relevant_qas:
                context_parts.append("\nRelevant FAQs (Use these principles but adapt to the user's specific question):")
                for qa in relevant_qas[:5]:
                    context_parts.append(f"Q: {qa['question']}\nA: {qa['answer']}")
    except Exception as e:
        import logging
        logging.error(f"Error loading Q&A data: {e}")
    
    return "\n".join(context_parts)


def _create_prompt(
    disease_name: str,
    user_question: str,
    context: str,
    language: str
) -> str:
    """Create a structured prompt for the SLM model focused on detected disease and strict system instructions."""
    
    # Normalize language with fallback
    norm_lang = (language or "english").strip().lower()
    if norm_lang in {"cebuano", "ceb", "bisaya", "binisaya"}:
        target_lang = "Cebuano/Bisaya"
        lang_instruction = (
            "CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in natural Cebuano/Bisaya.\n"
            "- Ignore the language of the farmer's question; even if the farmer writes in English or Tagalog/Filipino, your reply MUST be purely in Cebuano/Bisaya.\n"
            "- Avoid unnecessary English or Tagalog code-switching.\n"
            "- Keep proper nouns, scientific names (e.g., Xanthomonas oryzae), and essential technical terms in their standard form."
        )
    elif norm_lang in {"filipino", "fil", "tagalog", "tl", "philippine"}:
        target_lang = "Filipino/Tagalog"
        lang_instruction = (
            "CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in natural Filipino/Tagalog.\n"
            "- Ignore the language of the farmer's question; even if the farmer writes in English or Bisaya/Cebuano, your reply MUST be purely in Filipino/Tagalog.\n"
            "- Minimize unnecessary English borrowings.\n"
            "- Keep proper nouns, scientific names (e.g., Xanthomonas oryzae), and essential technical terms in their standard form."
        )
    else:
        target_lang = "Standard English"
        lang_instruction = (
            "CRITICAL LANGUAGE RULE: You MUST respond EXCLUSIVELY in clear, standard English.\n"
            "- Ignore the language of the farmer's question; even if the farmer writes in Filipino or Bisaya, your reply MUST be purely in Standard English."
        )

    prompt = f"""### SYSTEM INSTRUCTIONS
You are AgriBot, an offline, locally running AI rice disease specialist assistant.

ENVIRONMENT & CAPABILITIES:
1. LOCAL EXECUTION: You operate purely within a local offline application environment using only the provided local disease knowledge.
2. NETWORK RESTRICTION: You do NOT have internet access, real-time web access, online search, or external connectivity.
   - You must NOT claim to have internet access, live search, or external API access.
   - If the user asks for real-time or external info (e.g., live weather, current market/palay prices, latest web news, web search), clearly state in the target language that this capability is unavailable in this offline system.
3. LANGUAGE ENFORCEMENT:
   - Target Response Language: {target_lang}
   - {lang_instruction}
   - Do NOT switch languages or mix languages in your response.

DETECTED DISEASE: {disease_name}

LOCAL DISEASE DETAILS:
{context}

FARMER'S QUESTION: {user_question}

RULES:
1. Answer ONLY about {disease_name} based on the local disease details provided.
2. Keep response to 1-2 concise, practical sentences with actionable advice.
3. Do NOT include disease name, severity, urgency, or general explanation in your answer unless directly asked.
4. Do NOT answer questions unrelated to rice disease or agriculture; politely decline in the target language.
5. Answer directly in {target_lang}.
6. IPM FIRST: Follow Integrated Pest Management strictly. Recommend confirmation, monitoring, resistant/tolerant varieties, synchronized planting where relevant, field sanitation, balanced fertilizer, water management, spacing, and removal of infected/volunteer plants before any chemical option.
7. PESTICIDE VERIFICATION: Never invent pesticide brands, dosages, registrations, or image sources. Mention a specific product only when it appears in LOCAL DISEASE DETAILS/Relevant FAQs for this exact disease and use. Otherwise say a currently verified Philippine FPA-registered product was not confirmed in the local book data and the farmer must ask the Municipal Agriculture Office, DA technician, or PhilRice/local agricultural technician to check the current FPA registered-products list.
8. PESTICIDE LIMITS BY DISEASE: Do not present pesticides as cures. Tungro sprays can only manage leafhopper vectors, not cure infected plants. Fungicides may only manage verified fungal diseases. Do not recommend ordinary fungicides for Bacterial Leaf Blight because it is bacterial. For Brown Spot and Bacterial Leaf Blight, default to non-chemical management unless a technician verifies a current registered product.
9. CHEMICAL SAFETY: When chemicals are discussed, always include a brief safety reminder to follow the Philippine-approved product label exactly, including dose, timing, PPE, re-entry interval, and pre-harvest interval, and to consult a qualified agricultural technician if unsure.
10. IMAGE/DIAGNOSIS DISCLAIMER: When discussing image-based detection or uncertain symptoms, state that AgriSmart gives an initial decision-support assessment only, not a 100% accurate laboratory diagnosis; severe, fast-spreading, or uncertain cases require MAO/DA/PhilRice/local technician verification.

ANSWER:"""
    
    return prompt


def batch_generate_responses(
    disease_name: str,
    questions: list[str],
    disease_info: dict,
    language: str = "english"
) -> dict[str, tuple[Optional[str], float]]:
    """
    Generate responses for multiple questions about the same disease.
    
    Args:
        disease_name: Name of the disease
        questions: List of user questions
        disease_info: Disease information dictionary
        language: Target language
    
    Returns:
        Dictionary mapping questions to (response, time) tuples
    """
    results = {}
    for question in questions:
        response, elapsed = generate_disease_response(
            disease_name, question, disease_info, language
        )
        results[question] = (response, elapsed)
    
    return results


def get_slm_status() -> dict:
    """Get the current status of the SLM service."""
    is_enabled = ENABLE_SLM
    is_available = check_ollama_availability() if is_enabled else False
    model_path = _get_model_path() if is_enabled else None
    
    return {
        "enabled": is_enabled,
        "available": is_available,
        "current_model": get_current_model(),
        "model_path": model_path,
        "model_exists": os.path.exists(model_path) if model_path else False,
        "model_downloading": is_model_downloading(),
        "available_models": get_available_models(),
        "model_url": SLM_MODEL_URL,
        "model_size_mb": SLM_MODEL_SIZE,
        "timeout": SLM_TIMEOUT,
        "slow_response_threshold": SLOW_RESPONSE_THRESHOLD,
        "average_response_time": get_average_response_time(),
        "estimated_response_time_ms": int(get_average_response_time() * 1000) if get_average_response_time() > 0 else 3000,
        "timestamp": datetime.utcnow().isoformat()
    }
