import os

file_path = os.path.join(os.path.dirname(__file__), "..", "services", "slm_service.py")

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace rules
old_rules = """RULES:
1. Answer ONLY about {disease_name} based on the local disease details provided.
2. Keep response to 1-2 concise, practical sentences with actionable advice.
3. Do NOT include disease name, severity, urgency, or general explanation in your answer unless directly asked.
4. Do NOT answer questions unrelated to rice disease or agriculture; politely decline in the target language.
5. Answer directly in {target_lang}."""

new_rules = """RULES:
1. Answer ONLY about {disease_name} based on the local disease details provided.
2. Keep response to 1-2 concise, practical sentences with actionable advice.
3. Do NOT include disease name, severity, urgency, or general explanation in your answer unless directly asked.
4. Do NOT answer questions unrelated to rice disease or agriculture; politely decline in the target language.
5. Answer directly in {target_lang}.
6. PRIORITIZE NON-CHEMICAL: Always recommend cultural and non-chemical management first (e.g. resistant varieties, water/fertilizer management).
7. PESTICIDE RULE: If asked about chemicals, NEVER recommend a specific brand as a cure. State that pesticides only manage vectors/fungi, require local DA/MAO/PhilRice technician verification, and must follow Philippine FPA regulations and product labels.
8. SAFETY DISCLAIMER: When discussing image-based detection, state that it is an initial assessment only, not a 100% accurate laboratory diagnosis, and severe/uncertain cases require technician verification."""

content = content.replace(old_rules, new_rules)

# Add JSON import if missing
if "import json" not in content:
    content = content.replace("import os", "import os\nimport json")

# Update _build_disease_context
old_context_func = """def _build_disease_context(disease_name: str, disease_info: dict, language: str) -> str:
    \"\"\"Build context string from disease information.\"\"\"
    
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
    
    return "\\n".join(context_parts)"""

new_context_func = """def _build_disease_context(disease_name: str, disease_info: dict, language: str) -> str:
    \"\"\"Build context string from disease information.\"\"\"
    
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
                context_parts.append("\\nRelevant FAQs (Use these principles but adapt to the user's specific question):")
                for qa in relevant_qas[:5]:
                    context_parts.append(f"Q: {qa['question']}\\nA: {qa['answer']}")
    except Exception as e:
        import logging
        logging.error(f"Error loading Q&A data: {e}")
    
    return "\\n".join(context_parts)"""

content = content.replace(old_context_func, new_context_func)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("slm_service.py updated successfully.")
