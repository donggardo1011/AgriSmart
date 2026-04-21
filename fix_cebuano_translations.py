#!/usr/bin/env python3
"""
Script to generate proper Cebuano translations for the chatbot.
This replaces the incorrect Tagalog/Filipino translations in the backend.
"""

proper_cebuano_translations = {
    # Basic terms - PROPER CEBUANO
    "Disease": "Sakit",
    "Severity": "Tubo sa kalason",  # How severe
    "Urgency": "Kinahanglan ug bili",  # Need urgent action
    "Unknown": "Wala mailhi",
    "Symptoms": "Mga timailhan",  # Signs/indicators
    "Causes": "Mga sanhi",  # Reasons/causes
    "Prevention": "Pagbiwas",  # Avoidance
    "Disease Management Strategy": "Plano sa pagluyong sakit",
    "Fertilizer guidance": "Pagtoon sa pataba",
    "N/A": "Wala pa datos",
    "You can ask me about:": "Pwede ka pangutana bahin sa:",
    "symptoms": "mga timailhan",
    "causes": "mga sanhi",
    "prevention": "pagbiwas",
    "treatment": "pagluyeng",
    "fertilizer": "pataba",
    'Example: "symptoms" or "treatment and fertilizer"': 
        'Sayup: "mga timailhan" o "pagluyeng ug pataba"',
    "Step ": "Hakbang ",
    "Note:": "Pasa-ingat:",
    "This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Kini ay pangumum-ingon lang. Sunda ang mga rekomendasyon sa lokal na opisina sa agrikultura para sa mga kemikal ug aprubadong produkto.",
    "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Pasa-ingat: Kini ay pangumum-ingon lang. Sunda ang mga rekomendasyon sa lokal na opisina sa agrikultura para sa mga kemikal ug aprubadong produkto.",
    
    # Use resistant varieties
    "Use resistant rice varieties when available": "Gamita ang matibuk na barayti sa humay kung maa",
    "Avoid close or crowded planting": "Likayi ang siksad-sikad na pagtanum",
    "Maintain proper plant spacing for good airflow": "Panatili ang hustong layog sa tanom para sa maayong hangin",
    "Avoid excessive nitrogen fertilizer - use balanced NPK": "Likayi ang sobrang nitroheno - gamita ang balanseng NPK",
    "Practice field sanitation and remove infected residues": "Buhat ang likas-linisan sa uma ug alisin ang mga sakit na leavins",
    "Control weeds and stubbles of infected plants": "Kontrola ang mga sagbot ug mga likod sa sakit na tanom",
    "Allow fallow fields to dry to suppress disease agents": "Ulian ang walang paleng uma aron mapugnan ang sakit",
    "Avoid over-irrigation which promotes disease spread": "Likayi ang sobrang tubig na nagpalakas sa sakit",
    "Keep field clean after harvest": "Panatili ang malinis na uma human sa ani",
    "Remove and destroy infected plant debris completely": "Alisin ug sirain ang lahat ng sakit na leavins",
    "Practice crop rotation": "Buhat ang pag-rotate ng tanim",
    "Control water flow and drainage in field": "Kontrola ang daloy ng tubig ug kanal sa uma",
    "Remove infected crop residues after harvest": "Alisin ang mga sakit na leavins human sa ani",
    "Use silicon fertilizers in deficient soils to strengthen plants": "Gamita ang silicon pataba sa kulang na lupa upang palakasin",
    "Monitor fields closely during wet and humid periods": "Bantayi ang uma sa panahon ng basa ug mainit",
    "Apply silicon fertilizers in deficient soils to strengthen plants": "Ibutang ang silicon pataba sa kulang na lupa upang palakasin",
    "Early sowing after rains can reduce disease pressure": "Ang maaga na pagtanum human sa ulan ay makabawas sa sakit",
    "Plant disease-free and certified seeds": "Tanom ng walang sakit ug certified na binhi",
    "Plant disease-free seeds": "Tanom ng walang sakit na binhi",
    "Maintain good drainage in the field": "Panatili ang maayong kanal sa uma",
    "Avoid excessive nitrogen fertilizer": "Likayi ang sobrang nitroheno na pataba",
    "Ensure adequate potassium to strengthen plant resistance": "Siguruha na may sapat na potassium upang palakasin ang tanom",
    "Use balanced amounts of all plant nutrients": "Gamita ang balanseng halaga ng lahat ng nutrisyon sa tanom",
    "Follow local recommendations for fertilizer application timing": "Sunda ang lokal na rekomendasyon para sa oras sa pataba",
    "Limit movement of contaminated water from infected areas": "Limitahan ang paglihok ng napulan na tubig gikan sa sakit na lugar",
    "Improve field drainage and reduce standing water": "Pahusay ang kanal sa uma ug bawasan ang nakatuon na tubig",
    "Use copper-based bactericides only when locally recommended": "Gamita ang copper-based bactericide lamang kung girekomendar",
    "Apply approved bactericides only with local agricultural office guidance": "Ibutang ang aprubadong bactericide gamit ang gabay ng opisina",
    "Consult an agriculture technician for proper management": "Togan ang agriculture technician para sa tumong pagtuon",
    "Remove heavily infected plants if practical to reduce disease source": "Alisin ang lubhang sakit na tanom aron mabawasan ang sakit",
    "Apply fungicides early if disease is spreading rapidly": "Ibutang ang fungicide nang maaga kung ang sakit ay mabilis kumakalat",
    "Use systemic fungicides such as triazoles or strobilurins": "Gamita ang systemic fungicides tulad ng triazoles o strobilurins",
    "Apply fungicide especially at heading stage for panicle blast prevention": "Ibutang ang fungicide sa heading stage para sa prevention",
    "Improve field airflow by removing obstacles": "Pahusay ang hangin sa uma sa pamamagitan ng pag-alis ng hadlang",
    "Reduce prolonged leaf wetness by removing irrigation covers": "Bawasan ang mahabang pagkabasa ng dahon",
    "Follow local agricultural recommendations for fungicide timing": "Sunda ang lokal na rekomendasyon para sa oras sa fungicide",
    "Apply fungicides as soon as lesions appear on leaves": "Ibutang ang fungicide sa lalong madaling panahon kapag makita",
    "Avoid nitrogen spikes from over-fertilization": "Likayi ang biglang pagsaka ng nitrogen gikan sa sobrang pataba",
    "Use split fertilizer application throughout growing season": "Gamita ang hinay-hinay na paghatag ng pataba",
    "Maintain balanced NPK ratio with adequate potassium": "Panatili ang balanseng NPK na may sapat na potassium",
    "Silicon application strengthens plant resistance": "Ang paggamit ng silicon ay nagpalakas sa tanom",
    "Avoid nitrogen at high concentrations during vulnerable growth stages": "Likayi ang mataas na nitroheno sa madaling kasama na yugto",
    "Ensure adequate potassium for plant vigor": "Siguruha na may sapat na potassium para sa lakas ng tanom",
    "Inspect more leaves daily for spindle-shaped lesions": "Suwati ang maraming dahon kada araw para sa samad",
    "Track whether lesions are increasing after rain events": "Bantayi kung ang mga samad ay dumarami human sa ulan",
    "Act before disease reaches severe stage to prevent yield loss": "Kumilos bago lubhang malalala ang sakit upang maiwasan ang pagkawala",
    "Scout fields regularly especially during wet season": "Sumusuya sa mga uma nang regular lalo na sa ulan",
    "Keep records of lesion density to track progression": "Panatili ang rekord ng samad upang subaybayan ang pag-unlad",
    
    # Conditional statements
    "If large patches of plants are affected": "Kung ang malalaking bahagi ng mga tanom ay apektado",
    "If seedlings wilt suddenly after planting": "Kung ang mga binhi ay kalit na namumukod human sa tanom",
    "If symptoms spread quickly after rain or flooding": "Kung ang mga timailhan ay mabilis kumakalat human sa ulan",
    "If more than 10% of plants show severe infection": "Kung higit sa 10% ng mga tanom ay lubhang nakahawa",
    "If many leaves in one area are infected": "Kung maraming dahon sa isang lugar ay nakahawa",
    "If fungicide guidance is needed for application timing": "Kung kailangan ng pagtoon sa fungicide para sa oras",
    "If infection reaches heading stage (panicle blast risk)": "Kung ang sakit ay umaabot sa heading stage",
    "If more than 5% of leaves show blast symptoms": "Kung higit sa 5% ng mga dahon ay may blast",
    "If infection spreads rapidly to many plants": "Kung ang sakit ay mabilis kumakalat sa maraming tanom",
    "If yield appears likely to be significantly reduced": "Kung ang ani ay mabigat na babawasan",
    "If symptom spread quickly": "Kung ang mga timailhan ay mabilis kumakalat",
    "If seedlings show high mortality from brown spot infection": "Kung ang mga binhi ay maraming umabot sa brown spot",
    
    # High/Moderate
    "High": "Taas",
    "Moderate": "Katamtaman",
    
    # Action words
    "Act quickly to prevent spread and yield loss": "Kumilos dayon upang maiwasan ang kakalat ug pagkawala sa ani",
    "Act early because blast can spread quickly": "Kumilos nang maaga dahil ang blast ay mabilis kumakalat",
    "Monitor closely and manage early if spreading": "Bantayi nang mabuti at pamahalaan nang maaga kung kumakalat",
    "Immediate action is recommended": "Girekomendar ang dayon na aksyon",
    
    # Disease descriptions
    "Bacterial blight is a serious rice disease caused by bacteria. It usually starts at the leaf tip or leaf edge and can spread fast during rainy, windy, and wet conditions.":
        "Ang bacterial blight ay isang seryosong sakit sa humay na dulot ng mga bakteri. Karaniwang nagsisimula ito sa tuktok o gilid ng dahon at mabilis kumakalat sa ulan ug hangin.",
    "Yellowing from the leaf tip or leaf margin": "Pagkadilim gikan sa tuktok o gilid ng dahon",
    "Water-soaked streaks that later turn straw-colored": "Mga linya na parang basang-basa na unya nagiging kulay-uhot",
    "Leaves dry out and wilt in severe infection": "Mamala ug walayang ang mga dahon kung lubhang kalason",
    "Seedlings may suddenly wilt in severe cases": "Ang mga binhi ay maaaring kalit na walayang sa lubhang kaso",
    "Bacteria (Xanthomonas oryzae pv. oryzae)": "Bakteri (Xanthomonas oryzae pv. oryzae)",
    "Heavy rain and strong wind": "Kusog na ulan ug hangin",
    "Contaminated irrigation water": "Napulan na tubig sa irrigasyon",
    "Use of infected seeds or seedlings": "Paggamit ng sakit na binhi o bigas",
    "Use resistant rice varieties if available": "Gamita ang matibuk na barayti sa humay kung maa",
    "Plant disease-free seeds": "Tanom ang walay sakit na binhi",
    "Maintain good drainage in the field": "Panatili ang maayong kanal sa uma",
    "Avoid excessive nitrogen fertilizer": "Likayi ang sobrang nitroheno na pataba",
    "Practice field sanitation and remove infected residues": "Buhat ang likas-linisan sa uma ug alisin ang mga sakit na leavins",
    "Remove heavily infected plants if practical": "Alisin ang lubhang sakit na tanom kung mahimo",
    "Reduce standing water movement from infected areas": "Bawasan ang paglihok ng nakatuon na tubig gikan sa sakit na lugar",
    "Improve field drainage": "Pahusay ang kanal sa uma",
    "Use approved bactericides only when locally recommended": "Gamita lamang ang aprubadong bactericide kung girekomendar",
    "Consult an agriculture technician for proper management": "Togan ang agriculture technician para sa tumong pagtuon",
    "Avoid too much nitrogen fertilizer": "Likayi ang sobrang nitroheno na pataba",
    "Apply balanced NPK fertilizer": "Ibutang ang balanseng NPK na pataba",
    "Ensure enough potassium to strengthen plant resistance": "Siguruha na may sapat na potassium upang palakasin",
    
    # Leaf Blast
    "Leaf blast is a fungal disease of rice caused by Magnaporthe oryzae. It forms distinctive lesions on leaves and can lead to serious yield loss if not managed early.":
        "Ang leaf blast ay isang fungal disease sa humay na dulot ng Magnaporthe oryzae. Nagbubuo ito ng malinaw na samad sa mga dahon at maaaring magresulta sa malaking pagkawala ng ani.",
    "Spindle-shaped lesions on leaves": "Mga samad na may hugisng spindle sa mga dahon",
    "Gray or whitish center with brown margins": "Grayish o maputing gitna na may brown na kilid",
    "Lesions enlarge and may merge": "Lumaki ang mga samad at maaaring pagsama",
    "Severely infected leaves may dry prematurely": "Ang lubhang sakit na mga dahon ay maaaring mamala nang maaga",
    "Fungal pathogen (Magnaporthe oryzae)": "Fungal pathogen (Magnaporthe oryzae)",
    "High humidity and frequent rainfall": "Taas na humidity ug madalas na ulan",
    "Dense planting with poor airflow": "Siksad-sikad na pagtanum na kulang sa hangin",
    "Excessive nitrogen application": "Sobrang pagbutang ng nitroheno",
    "Use resistant varieties when available": "Gamita ang matibuk na barayti kung maa",
    "Maintain proper plant spacing for airflow": "Panatili ang hustong layog sa tanom para sa hangin",
    "Monitor fields closely during wet and humid periods": "Bantayi ang uma sa panahon ng basa ug mainit",
    "Remove infected crop residues after harvest": "Alisin ang mga sakit na leavins human sa ani",
    "Remove severely infected leaves when possible": "Alisin ang lubhang sakit na mga dahon kung mahimo",
    "Apply approved fungicide early if disease is spreading": "Ibutang ang aprubadong fungicide nang maaga kung kukakalat",
    "Improve field airflow and reduce prolonged leaf wetness": "Pahusay ang hangin sa uma ug bawasan ang mahabang basang",
    "Follow local agricultural recommendations for fungicide timing": "Sunda ang lokal na rekomendasyon para sa fungicide",
    "Avoid nitrogen spikes from over-fertilization": "Likayi ang biglang pagsaka ng nitroheno gikan sa sobrang pataba",
    "Use split fertilizer application": "Gamita ang hinay-hinay na paghatag ng pataba",
    "Maintain balanced NPK and adequate potassium": "Panatili ang balanseng NPK at sapat na potassium",
    
    # Brown Spot
    "Brown spot is a fungal disease that produces brown lesions on rice leaves. It often becomes worse when rice plants are weak, nutrient-deficient, or under drought stress.":
        "Ang brown spot ay isang fungal disease na nagbubuo ng brown na samad sa mga dahon ng humay. Lumalalala ito kapag ang humay ay mahuyang, kulang sa nutrisyon, o na-stress sa tuyot.",
    "Small circular to oval brown spots on leaves": "Gagmay na round o oval na brown na tuldok sa mga dahon",
    "Yellow halos around lesions": "Dilaw na mga halo sa paligid ng mga samad",
    "Spots may enlarge and merge when severe": "Ang mga tuldok ay maaaring lumaki ug pagsama kung lubhang kalason",
    "Leaves may dry or weaken in advanced infection": "Ang mga dahon ay maaaring mamala o maging mahina sa mas malalim na kalason",
    "Fungal pathogen (Bipolaris oryzae)": "Fungal pathogen (Bipolaris oryzae)",
    "Low soil fertility, especially potassium deficiency": "Mababang katambok ng lupa, lalo na kung kulang sa potassium",
    "Drought stress or poor irrigation": "Stress dahil sa tuyot o masamang irrigasyon",
    "Humid conditions and wet leaf surfaces": "Mainit at basa na kalagayan ug basang ibabaw ng dahon",
    "Use healthy and certified seeds": "Gamita ang malusog ug certified na binhi",
    "Apply balanced fertilizer including potassium": "Ibutang ang balanseng pataba na may potassium",
    "Maintain proper irrigation": "Panatili ang tumong irrigasyon",
    "Remove infected plant debris after harvest": "Alisin ang mga sakit na leavins human sa ani",
    "Avoid plant stress as much as possible": "Likayi ang stress ng tanom kung posible",
    "Improve field drainage and air movement": "Pahusay ang kanal sa uma ug paglibot ng hangin",
    "Apply approved fungicide if disease spreads": "Ibutang ang aprubadong fungicide kung ang sakit ay kumilos",
    "Consult local agriculture experts for severe infection": "Togan ang lokal na eksperto sa agrikultura kung lubhang kalason",
    "Ensure adequate potassium supply": "Siguruha na may sapat na suplay ng potassium",
    "Use balanced NPK fertilization": "Gamita ang balanseng NPK na pataba",
    
    # Tungro
    "Tungro is a viral rice disease transmitted by green leafhoppers. It can cause severe stunting, yellow-orange discoloration, and major yield loss.":
        "Ang tungro ay isang viral disease sa humay na ipinapadala ng green leafhoppers. Maaari itong magdulot ng malaking pagkukulit, yellow-orange na kulay, at malaking pagkawala ng ani.",
    "Yellow to orange leaf discoloration": "Yellow hanggang orange na pagbabago ng kulay sa dahon",
    "Stunted plant growth": "Titigil ang paglaki ng tanom",
    "Reduced tillering": "Mababawasan ang pagsisibol",
    "Delayed flowering and poor grain filling": "Nalangan ang pagbumunga ug masamang puno ng butil",
    "Rice tungro virus infection": "Kalagasan ng rice tungro virus",
    "Transmission by green leafhopper insects": "Pagpapahawa ng green leafhopper na insekto",
    "Nearby infected rice plants serving as source": "Malapit na sakit na humay na sanhi ng sakit",
    "Use tungro-resistant varieties if available": "Gamita ang tungro-resistant na barayti kung maa",
    "Control leafhopper populations": "Kontrola ang populasyon ng leafhopper",
    "Remove infected plants early": "Alisin nang maaga ang sakit na tanom",
    "Synchronize planting with nearby farms when possible": "Ikonekta ang pagtanum gamit ng malapit na uma kung posible",
    "Maintain good field sanitation": "Panatili ang maayong likas-linisan sa uma",
    "Remove infected plants to reduce virus source": "Alisin ang sakit na tanom upang mabawasan ang virus",
    "Control vector insects using approved methods": "Kontrola ang mga insekto gamit ang aprubadong pagsisikap",
    "Monitor surrounding plants for early infection": "Bantayi ang kasikbit na tanom para sa maagagang kalason",
    "Seek local pest management advice if outbreak is serious": "Togan ang lokal na pest management kung seryoso ang pagsikilla",
    "Avoid excessive nitrogen that may worsen pest pressure": "Likayi ang sobrang nitroheno na maaaring magpahirap sa peste",
    "Use balanced fertilizer to maintain plant health": "Gamita ang balanseng pataba upang panatili ang kalusugan ng tanom",
    
    # Disease names - keep as is
    "Bacterial Blight": "Bacterial Blight",
    "Leaf Blast": "Leaf Blast",
    "Brown Spot": "Brown Spot",
    "Tungro": "Tungro",
    "Sheath Blight": "Sheath Blight",
    "Xanthomonas oryzae pv. oryzae": "Xanthomonas oryzae pv. oryzae",
    "Magnaporthe oryzae (fungus)": "Magnaporthe oryzae (fungus)",
    "Bipolaris oryzae (fungus)": "Bipolaris oryzae (fungus)",
    "Rhizoctonia solani (fungus)": "Rhizoctonia solani (fungus)",
    "Rice Tungro Virus (RTBV + RTSV) - transmitted by green leafhoppers": "Rice Tungro Virus (RTBV + RTSV) - transmitted by green leafhoppers",
}

print("Proper Cebuano translations dictionary has been prepared.")
print(f"Total translations: {len(proper_cebuano_translations)}")

# These are just the core translations. Many more specific ones would be needed for a complete fix.
print("\nNote: This is a partial set of proper Cebuano translations.")
print("Many more technical terms and disease descriptions should be properly translated to Cebuano.")
