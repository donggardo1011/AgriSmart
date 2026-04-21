# Chatbot Testing & Implementation Guide
## AgriSmartAI Rice Disease Chatbot

---

## ✅ What Has Been Implemented

### 1. **Enhanced Disease Knowledge Base**
- ✅ Updated `DISEASE_KB` in `prediction_routes.py`
- ✅ Expanded each of 5 diseases with detailed information:
  - 8-15 comprehensive symptoms per disease
  - 6-10 detailed causes explaining disease ecology
  - 5-8 proven prevention strategies
  - 4-7 treatment approaches specific to disease type
  - 3-5 fertilizer guidance points for each disease
  - 3-5 actionable next steps
  - 3-5 clear guidance on when to contact experts

### 2. **Full Cebuano Language Support**
- ✅ 200+ new Cebuano translations added
- ✅ All disease information available in Cebuano
- ✅ Scientific terms appropriately transliterated
- ✅ Agricultural context maintained in translations
- ✅ Language toggle functional: English ↔ Cebuano

### 3. **Consistent Disease Structure**
- ✅ Each disease follows same information architecture
- ✅ Predictable user experience across all 5 diseases
- ✅ Comparable severity and urgency guidance
- ✅ Scalable for future disease additions

### 4. **Reference Documentation**
- ✅ `RICE_DISEASE_CHATBOT_GUIDE.md` - Implementation & structure details
- ✅ `RICE_DISEASE_QUICK_REFERENCE.md` - Farmer-friendly quick reference
- ✅ `diseases_data.json` - Complete disease data in JSON format

---

## 🧪 Testing Procedures

### **Test Environment Setup**

Before testing, ensure:
```bash
# Backend
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt

# Frontend (if testing UI)
cd frontend
flutter pub get

# Admin Web (for testing API directly)
cd admin-web
npm install
```

### **Test 1: Basic Disease Selection**

**Objective:** Verify all 5 diseases load correctly

**Steps:**
1. Open chatbot screen in app
2. Click disease dropdown
3. Verify you see:
   - Bacterial Blight(Rice Leaf Blight Disease)
   - Leaf Blast (Rice Leaf Blast Disease)
   - Brown Spot (Rice Leaf Brown-Spot Disease)
   - Tungro (Rice Tungro Disease)
   - Leaf Smut (Rice Leaf Smut Disease)
4. Select each disease
5. Verify correct disease loads each time

**Expected Result:** All 5 diseases appear and load correctly with their specific information

---

### **Test 2: Information Completeness**

**Objective:** Verify each disease has complete information

**Steps for Each Disease:**
1. Select disease
2. Ask: "symptoms"
   - Should return 8+ specific symptoms
   - Each symptom should be unique to that disease
3. Ask: "causes"
   - Should return 6+ distinct causes
   - Causes should explain WHY disease develops, not just WHAT spreads it
4. Ask: "prevention"
   - Should return 5+ prevention strategies
   - Should be prioritized (most effective first)
5. Ask: "treatment"
   - Should return 4+ treatment options
   - Should include timing information
6. Ask: "fertilizer"
   - Should return 3+ fertilizer recommendations
   - Should address disease-specific fertilizer needs

**Expected Result:** Each disease returns comprehensive information for each category

---

### **Test 3: Language Switching**

**Objective:** Verify Cebuano translations work correctly

**Steps:**
1. Select: Bacterial Blight + English
2. Ask: "symptoms"
3. Note the English symptoms
4. Switch to Cebuano
5. Ask: "symptoms" again
6. Verify:
   - Symptoms appear in Cebuano
   - Same information, translated accurately
   - Scientific terms appropriately transliterated
7. Repeat for:
   - "causes"
   - "prevention"
   - "treatment"
   - "fertilizer"

**Expected Result:** All information translates correctly to Cebuano while maintaining accuracy

---

### **Test 4: Disease Differentiation**

**Objective:** Verify each disease provides distinct information

**Steps:**
1. Ask all 5 diseases: "What are symptoms?"
2. Verify:
   - Symptoms are DIFFERENT for each disease
   - No overlap between diseases
   - Each clearly identifiable

**Quick Check (Key Differentiators):**
- Bacterial Blight → yellow from TIP, water-soaked streaks
- Leaf Blast → SPINDLE-shaped, gray center, brown border
- Brown Spot → brown CIRCLE/oval like sesame, yellow halo
- Tungro → orange/yellow STUNTING, leafhopper vector
- Leaf Smut → tiny BLACK POWDER, not merging

**Expected Result:** Each disease is clearly distinct and identifiable

---

### **Test 5: Combined Queries**

**Objective:** Verify chatbot handles multiple topic requests

**Steps:**
1. Select disease
2. Ask: "symptoms and causes"
   - Should return both sections
   - Both should be complete
3. Ask: "prevention and treatment"
   - Should return both sections
   - Both should be complete
4. Ask: "causes, prevention, and fertilizer"
   - Should return all three sections

**Expected Result:** Chatbot handles combined queries correctly and returns all requested sections

---

### **Test 6: Context-Aware Responses**

**Objective:** Verify responses are specific to selected disease

**Setup:**
1. Select: Bacterial Blight
2. Ask: "How do I prevent this?"
3. Note: Recommendations include resistant varieties, clean seeds, drainage, balanced NPK
4. Change to: Tungro
5. Ask: "How do I prevent this?"
6. Note: Recommendations now include leafhopper control, synchronized planting, resistant varieties
7. Each response should be specific to the selected disease

**Expected Result:** Responses vary appropriately by disease selection

---

### **Test 7: Cebuano Keyword Recognition**

**Objective:** Verify Cebuano language queries are recognized

**Using Tungro disease:**
1. Ask in Cebuano: "sintomas" (symptoms)
   - Should return symptoms in Cebuano
2. Ask: "pagtambal" (treatment)
   - Should return treatment in Cebuano
3. Ask: "paglikay" (prevention)
   - Should return prevention in Cebuano
4. Ask: "abono" (fertilizer)
   - Should return fertilizer guidance in Cebuano

**Expected Result:** Cebuano keywords are recognized and trigger appropriate responses

---

### **Test 8: Image Prediction Integration**

**Objective:** Verify chatbot loads correctly when disease is pre-identified from image

**Steps:**
1. Upload rice disease image
2. Model predicts: "brown_spot" (for example)
3. Verify:
   - Chatbot opens with Brown Spot selected
   - Prediction image displays with detection overlay
   - User can immediately ask questions about Brown Spot
4. Ask: "What could be causing this?"
   - Response specific to Brown Spot causes
5. Ask: "What fertilizer should I use?"
   - Response specific to Brown Spot fertilizer needs

**Expected Result:** Image-detected disease loads correctly in chatbot

---

### **Test 9: API Response Validation**

**Objective:** Verify backend API returns correctly structured responses

**Using curl or API testing tool:**

```bash
# Test Bacterial Blight in English
curl -X POST http://localhost:8000/api/chatbot \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "disease": "bacterial_blight",
    "message": "symptoms",
    "language": "english"
  }'

# Expected response should include:
# - disease: "bacterial_blight"
# - severity: "High"
# - urgency: "Act quickly to prevent spread and yield loss"
# - explanation: [full explanation]
# - symptoms: [8+ items]
# - causes: [6+ items]
# - prevention: [5+ items]
# - treatment_plan: [4+ items]
# - fertilizer_guidance: [3+ items]
# - reply: [formatted response]
```

**For Cebuano:**
```bash
curl -X POST http://localhost:8000/api/chatbot \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "disease": "brown_spot",
    "message": "causes",
    "language": "cebuano"
  }'
```

**Expected Result:** API returns complete, correctly structured JSON with all fields populated

---

### **Test 10: Performance & Load**

**Objective:** Verify chatbot response time is acceptable

**Steps:**
1. Ask question about each disease
2. Measure response time
3. Should complete in:
   - <200ms for simple queries
   - <500ms for complex/first load
4. Language switching should be instant
5. Disease switching should be instant

**Expected Result:** All responses complete within acceptable time frame

---

## 📋 Test Execution Checklist

### **Pre-Testing Checklist**

- [ ] Backend server running
- [ ] Frontend/Flutter app running
- [ ] Login successful with test account
- [ ] Internet connectivity working
- [ ] No browser cache issues (clear if needed)

### **Smoke Test (Quick 5-minute check)**

- [ ] Select Bacterial Blight, ask "symptoms" → Returns 8+ symptoms
- [ ] Select Tungro, ask "treatment" → Returns 4+ treatments
- [ ] Switch to Cebuano → Text changes language
- [ ] Select Brown Spot → Information updates correctly
- [ ] Ask combined question → Both sections return

### **Full Test (Comprehensive 30-minute check)**

- [ ] Test 1: All 5 diseases load ✓
- [ ] Test 2: Each disease has complete info ✓
- [ ] Test 3: Language switching works ✓
- [ ] Test 4: Diseases are differentiated ✓
- [ ] Test 5: Combined queries work ✓
- [ ] Test 6: Responses are context-specific ✓
- [ ] Test 7: Cebuano keywords recognized ✓
- [ ] Test 8: Image integration works ✓
- [ ] Test 9: API responses correct ✓
- [ ] Test 10: Performance acceptable ✓

---

## 🐛 Troubleshooting

### **Issue: Disease dropdown empty**
**Solution:**
1. Refresh page
2. Check backend is running: `python main.py`
3. Verify database connection
4. Check chatbot_screen.dart disease list matches backend

### **Issue: Cebuano translations not appearing**
**Solution:**
1. Verify language parameter is "cebuano" (lowercase)
2. Check translations dictionary includes the text
3. Verify no caching issues (hard refresh)
4. Check browser console for errors

### **Issue: Incomplete responses**
**Solution:**
1. Verify DISEASE_KB has all fields
2. Check _detect_intents() recognizes keywords
3. Verify knowledge base wasn't truncated
4. Check error logs in terminal

### **Issue: API timeout**
**Solution:**
1. Reduce message complexity
2. Check backend server CPU usage
3. Verify database connection not hanging
4. Restart backend: `python main.py`

### **Issue: Image disease not loading in chatbot**
**Solution:**
1. Verify prediction includes disease key
2. Check disease key matches DISEASE_KB keys
3. Verify initialDisease parameter passed correctly
4. Check frontend passes disease to chatbot component

---

## 📊 Sample Test Data

### **Test Query 1: Symptom Identification**
```
Input: User selects "Brown Spot" + English
Query: "symptoms"

Expected Output (excerpt):
- Small brown oval or circular spots on leaves (like sesame seeds)
- Gray or whitish centers with yellow halos around lesions
- Early lesions appear as small dark brown spots on seedlings
- Mature lesions show reddish-brown borders and gray centers
[... 6 more symptoms]
```

### **Test Query 2: Cause Understanding**
```
Input: User selects "Tungro" + English
Query: "causes"

Expected Output (excerpt):
- Rice tungro virus complex (RTBV + RTSV)
- Transmission by green leafhopper (Nephotettix virescens) insects
- Nearby infected rice plants serving as inoculum source
[... 6+ more causes]
```

### **Test Query 3: Language Switching**
```
Input: User selects "Leaf Blast" + English
Query: "prevention"
Output: [5 prevention strategies in English]

Switch to Cebuano
Same Query: "prevention" OR "paglikay"
Output: [5 prevention strategies in Cebuano, same information]
```

---

## ✅ Success Criteria

The implementation is successful when:

1. **All 5 diseases** are accessible and selectable
2. **Each disease** provides 30+ unique data points
3. **Language switching** works without errors
4. **Responses are specific** to selected disease
5. **Cebuano translations** are accurate
6. **API returns** complete, structured JSON
7. **Performance** is acceptable (<500ms)
8. **No duplicate** or contradicting information
9. **Farmer-friendly** language is maintained
10. **Technical accuracy** is preserved

---

## 📝 Sign-Off Sheet

**After completing all tests, fill in:**

```
Test Date: ___________
Tested By: ___________

Total Tests Executed: ___
Tests Passed: ___
Tests Failed: ___

Critical Issues: None / [describe]
Minor Issues: None / [describe]

Overall Status: 
[ ] PASS - Ready for production
[ ] PASS with minor issues - Ready with notes
[ ] NEEDS REWORK - Not ready

Notes:
_____________________________________
_____________________________________
_____________________________________

Signature: ____________________
```

---

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] All tests passed
- [ ] Documentation complete
- [ ] Backend tested with production database
- [ ] Frontend builds without errors
- [ ] No console warnings or errors
- [ ] API timeout values appropriate
- [ ] Database backups in place
- [ ] Error logging configured
- [ ] Translation coverage at 100%
- [ ] Performance benchmarks met

---

## 📚 Related Documentation

- [RICE_DISEASE_CHATBOT_GUIDE.md](./RICE_DISEASE_CHATBOT_GUIDE.md) - Implementation details
- [RICE_DISEASE_QUICK_REFERENCE.md](./RICE_DISEASE_QUICK_REFERENCE.md) - Farmer reference guide
- [diseases_data.json](./backend/diseases_data.json) - Disease data in JSON

---

## 🆘 Support

For issues or questions:

1. Check disease names are correctly spelled
2. Verify backend routes are running
3. Check browser developer console for errors
4. Review error logs in terminal
5. Verify database connection status
6. Check translation keys exist in _translate_text()

