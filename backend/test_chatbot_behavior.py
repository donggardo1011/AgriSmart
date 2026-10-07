import sys
import os

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# Add backend directory to sys.path
sys.path.insert(0, os.path.dirname(__file__))

from routes.prediction_routes import (
    _normalize_language,
    _handle_network_restriction,
    _detect_intents,
    _translate_text,
    _format_list,
    _build_reply,
    DISEASE_KB,
)
from services.slm_service import _create_prompt

def test_language_normalization():
    print("\n--- Test 1: Language Normalization & Fallback ---")
    assert _normalize_language(None) == "english", "None should fallback to english"
    assert _normalize_language("") == "english", "Empty string should fallback to english"
    assert _normalize_language("   ") == "english", "Whitespace should fallback to english"
    assert _normalize_language("unsupported_lang") == "english", "Unsupported should fallback to english"
    assert _normalize_language("french") == "english", "French should fallback to english"
    
    # Aliases
    assert _normalize_language("english") == "english"
    assert _normalize_language("cebuano") == "cebuano"
    assert _normalize_language("ceb") == "cebuano"
    assert _normalize_language("bisaya") == "cebuano"
    assert _normalize_language("binisaya") == "cebuano"
    assert _normalize_language("filipino") == "filipino"
    assert _normalize_language("fil") == "filipino"
    assert _normalize_language("tagalog") == "filipino"
    assert _normalize_language("tl") == "filipino"
    assert _normalize_language("philippine") == "filipino"
    print("[PASS] Language normalization & fallback passed!")

def test_network_restriction():
    print("\n--- Test 2: Network & Offline Restriction Interceptor ---")
    queries = [
        "What is the live weather forecast today?",
        "Can you search the web for rice market prices?",
        "Ano ang presyo ng palay ngayon?",
        "Unsa ang panahon karon?",
        "Are you connected to the internet?",
        "Search online for latest news about rice blast",
    ]
    
    for q in queries:
        # Test in English
        reply_en = _handle_network_restriction(q, "english")
        assert reply_en is not None, f"Expected network restriction trigger for '{q}' in english"
        assert "unavailable" in reply_en.lower() and "offline" in reply_en.lower(), f"Unexpected EN reply: {reply_en}"
        
        # Test in Filipino
        reply_fil = _handle_network_restriction(q, "filipino")
        assert reply_fil is not None, f"Expected network restriction trigger for '{q}' in filipino"
        assert "hindi available" in reply_fil.lower() and "offline" in reply_fil.lower(), f"Unexpected FIL reply: {reply_fil}"
        
        # Test in Cebuano
        reply_ceb = _handle_network_restriction(q, "cebuano")
        assert reply_ceb is not None, f"Expected network restriction trigger for '{q}' in cebuano"
        assert "dili magamit" in reply_ceb.lower() and "offline" in reply_ceb.lower(), f"Unexpected CEB reply: {reply_ceb}"
        
    print("[PASS] Network restriction interceptor passed for English, Filipino, and Cebuano!")

def test_cross_language_intent_detection():
    print("\n--- Test 3: Multi-lingual Intent Detection ---")
    # Symptoms in EN, FIL, CEB
    assert "symptoms" in _detect_intents("What symptoms should I look for?")
    assert "symptoms" in _detect_intents("Anong mga sintomas ang dapat kong bantayan?")
    assert "symptoms" in _detect_intents("Unsa ang mga timailhan ani?")
    
    # Causes in EN, FIL, CEB
    assert "causes" in _detect_intents("What causes this disease?")
    assert "causes" in _detect_intents("Ano ang sanhi o dahilan nito?")
    assert "causes" in _detect_intents("Unsay hinungdan ani?")
    
    # Prevention in EN, FIL, CEB
    assert "prevention" in _detect_intents("How to prevent it?")
    assert "prevention" in _detect_intents("Paano ang pag-iwas dito?")
    assert "prevention" in _detect_intents("Unsaon paglikay ani?")
    
    # Treatment in EN, FIL, CEB
    assert "treatment_plan" in _detect_intents("How do I treat this disease?")
    assert "treatment_plan" in _detect_intents("Anong gamot o paggamot ang pwede?")
    assert "treatment_plan" in _detect_intents("Unsang tambal o pagtambal akong buhaton?")
    
    # Fertilizer in EN, FIL, CEB
    assert "fertilizer_guidance" in _detect_intents("What fertilizer should I apply?")
    assert "fertilizer_guidance" in _detect_intents("Anong pataba ang dapat gamitin?")
    assert "fertilizer_guidance" in _detect_intents("Unsang abono ang angay ibutang?")
    
    print("[PASS] Multi-lingual intent detection passed across English, Filipino, and Cebuano queries!")

def test_strict_language_enforcement_in_replies():
    print("\n--- Test 4: Strict Target Language Enforcement in _build_reply ---")
    kb = DISEASE_KB["bacterial_blight"]
    
    # Scenario A: User asks in Tagalog, but Target Language is English -> Output MUST be in English
    reply_en, _, _ = _build_reply("bacterial_blight", kb, "Anong mga sintomas ang dapat kong bantayan?", "english")
    assert "Symptoms:" in reply_en, f"Expected English 'Symptoms:' but got: {reply_en}"
    assert "Disease:" in reply_en
    assert "Severity:" in reply_en
    
    # Scenario B: User asks in English, but Target Language is Filipino -> Output MUST be in Filipino
    reply_fil, _, _ = _build_reply("bacterial_blight", kb, "What symptoms should I watch for?", "filipino")
    assert "Mga Sintomas:" in reply_fil, f"Expected Filipino 'Mga Sintomas:' but got: {reply_fil}"
    assert "Sakit:" in reply_fil
    assert "Lala ng Sakit:" in reply_fil
    
    # Scenario C: User asks in English, but Target Language is Cebuano -> Output MUST be in Cebuano
    reply_ceb, _, _ = _build_reply("bacterial_blight", kb, "How do I treat this disease?", "cebuano")
    assert "Estratehiya sa Pagdumala sa Sakit:" in reply_ceb, f"Expected Cebuano strategy title but got: {reply_ceb}"
    assert "Lakang 1:" in reply_ceb, f"Expected Cebuano 'Lakang 1:' step label but got: {reply_ceb}"
    assert "Sakit:" in reply_ceb
    
    # Scenario D: User asks in Cebuano, but Target Language is Filipino -> Output MUST be in Filipino
    reply_fil2, _, _ = _build_reply("bacterial_blight", kb, "Unsaon pagtambal ani nga sakit?", "filipino")
    assert "Estratehiya sa Pamamahala ng Sakit:" in reply_fil2, f"Expected Filipino strategy title but got: {reply_fil2}"
    assert "Hakbang 1:" in reply_fil2, f"Expected Filipino 'Hakbang 1:' step label but got: {reply_fil2}"

    # Scenario E: Empty message overview in all 3 languages
    ov_en, _, _ = _build_reply("bacterial_blight", kb, "", "english")
    assert "You can ask me about:" in ov_en
    
    ov_fil, _, _ = _build_reply("bacterial_blight", kb, "", "filipino")
    assert "Maaari mo akong tanungin tungkol sa:" in ov_fil
    
    ov_ceb, _, _ = _build_reply("bacterial_blight", kb, "", "cebuano")
    assert "Mahimo kang mangutana kanako bahin sa:" in ov_ceb

    print("[PASS] Strict target language enforcement passed across all cross-language test cases!")

def test_slm_prompt_system_instructions():
    print("\n--- Test 5: SLM System Instructions and Prompt Construction ---")
    prompt_en = _create_prompt("Bacterial Blight", "What causes this?", "Context data here", "english")
    assert "LOCAL EXECUTION" in prompt_en
    assert "NETWORK RESTRICTION" in prompt_en
    assert "Standard English" in prompt_en
    
    prompt_fil = _create_prompt("Bacterial Blight", "What causes this?", "Context data here", "filipino")
    assert "Filipino/Tagalog" in prompt_fil
    assert "CRITICAL LANGUAGE RULE" in prompt_fil
    assert "Minimize unnecessary English borrowings" in prompt_fil
    
    prompt_ceb = _create_prompt("Bacterial Blight", "Anong gamot dito?", "Context data here", "cebuano")
    assert "Cebuano/Bisaya" in prompt_ceb
    assert "CRITICAL LANGUAGE RULE" in prompt_ceb
    assert "Avoid unnecessary English or Tagalog code-switching" in prompt_ceb
    
    # Fallback when invalid language passed to prompt builder
    prompt_fallback = _create_prompt("Bacterial Blight", "Help", "Context data here", "unknown_lang")
    assert "Standard English" in prompt_fallback
    print("[PASS] SLM system instructions and prompt construction passed!")

if __name__ == "__main__":
    import traceback
    try:
        test_language_normalization()
        test_network_restriction()
        test_cross_language_intent_detection()
        test_strict_language_enforcement_in_replies()
        test_slm_prompt_system_instructions()
        print("\n*** ALL TESTS PASSED SUCCESSFULLY! ***\n")
    except Exception as e:
        print(f"\n[FAIL] TEST FAILED: {e}")
        traceback.print_exc()
        sys.exit(1)
