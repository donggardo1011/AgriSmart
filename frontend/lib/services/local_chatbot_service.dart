import 'package:flutter/foundation.dart';
import 'local_disease_kb.dart';

/// Local Chatbot Service - Handles all chatbot logic offline
class LocalChatbotService {
  /// Translations for Cebuano language
  static const Map<String, String> cebuanoTranslations = {
    "Disease:": "Sakit:",
    "Severity:": "Kagrabehon:",
    "Urgency:": "Pagkadinalian:",
    "Disease": "Sakit",
    "Severity": "Kagrabehon",
    "Urgency": "Pagkadinalian",
    "Unknown": "Wala Mailhi",
    "Symptoms": "Mga Timailhan",
    "Causes": "Mga Hinungdan",
    "Prevention": "Paglikay",
    "Disease Management Strategy": "Estratehiya sa Pagdumala sa Sakit",
    "Disease Management Steps": "Mga Lakang sa Pagdumala sa Sakit",
    "Disease Management": "Pagdumala sa Sakit",
    "Recommended Actions": "Girekomendar nga mga Aksyon",
    "Fertilizer guidance": "Giya sa Abono",
    "Immediate Actions": "Dinalian nga mga Aksyon",
    "Key Symptoms": "Panguna nga mga Timailhan",
    "Prevention Measures": "Mga Paagi sa Paglikay",
    "Management": "Pagdumala",
    "This disease is typically identified by:": "Kini nga sakit kasagarang mailhan pinaagi sa:",
    "For more help, ask me about symptoms, causes, prevention, or treatment options.":
        "Alang sa dugang tabang, pangutana bahin sa mga timailhan, hinungdan, paglikay, o mga kapilian sa pagtambal.",
    "For more specific help, try asking about symptoms, causes, prevention, treatment, or fertilizer guidance.":
        "Alang sa dugang piho nga tabang, sulayi ang pagpangutana bahin sa mga timailhan, hinungdan, paglikay, pagtambal, o giya sa abono.",
    "For management of this disease, monitor your fields regularly and consult local agricultural experts for guidance.":
        "Alang sa pagdumala niini nga sakit, susiha kanunay ang imong basakan ug pakigkonsulta sa mga lokal nga eksperto sa agrikultura.",
    "N/A": "Walay datos",
    "You can ask me about:": "Mahimo kang mangutana kanako bahin sa:",
    "symptoms": "mga timailhan",
    "causes": "mga hinungdan",
    "prevention": "paglikay",
    "treatment": "pagtambal",
    "fertilizer": "abono",
    'Example: "symptoms" or "treatment and fertilizer"':
        'Pananglitan: "mga timailhan" o "pagtambal ug abono"',
    "Step ": "Lakang ",
    "Note:": "Pahimangno:",
    "This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Kini kinatibuk-ang giya lamang—sunda ang mga rekomendasyon sa lokal nga opisina sa agrikultura alang sa mga kemikal ug giaprobahang produkto.",
    "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Pahimangno: Kini kinatibuk-ang giya lamang—sunda ang mga rekomendasyon sa lokal nga opisina sa agrikultura alang sa mga kemikal ug giaprobahang produkto.",
  };

  /// Translations for Filipino language
  static const Map<String, String> filipinoTranslations = {
    "Disease:": "Sakit:",
    "Severity:": "Lala ng Sakit:",
    "Urgency:": "Pagka-apurahan:",
    "Disease": "Sakit",
    "Severity": "Lala ng Sakit",
    "Urgency": "Pagka-apurahan",
    "Unknown": "Hindi Kilala",
    "Symptoms": "Mga Sintomas",
    "Causes": "Mga Sanhi",
    "Prevention": "Pag-iwas",
    "Disease Management Strategy": "Estratehiya sa Pamamahala ng Sakit",
    "Disease Management Steps": "Mga Hakbang sa Pamamahala ng Sakit",
    "Disease Management": "Pamamahala ng Sakit",
    "Recommended Actions": "Mga Inirerekomendang Aksyon",
    "Fertilizer guidance": "Gabay sa Pataba",
    "Immediate Actions": "Mga Agarang Aksyon",
    "Key Symptoms": "Pangunahing mga Sintomas",
    "Prevention Measures": "Mga Paraan ng Pag-iwas",
    "Management": "Pamamahala",
    "This disease is typically identified by:": "Ang sakit na ito ay karaniwang nakikilala sa pamamagitan ng:",
    "For more help, ask me about symptoms, causes, prevention, or treatment options.":
        "Para sa karagdagang tulong, magtanong tungkol sa mga sintomas, sanhi, pag-iwas, o mga opsyon sa paggamot.",
    "For more specific help, try asking about symptoms, causes, prevention, treatment, or fertilizer guidance.":
        "Para sa mas partikular na tulong, subukang magtanong tungkol sa mga sintomas, sanhi, pag-iwas, paggamot, o gabay sa pataba.",
    "For management of this disease, monitor your fields regularly and consult local agricultural experts for guidance.":
        "Para sa pamamahala ng sakit na ito, regular na bantayan ang iyong palayan at kumonsulta sa mga lokal na eksperto sa agrikultura.",
    "N/A": "Walang datos",
    "You can ask me about:": "Maaari mo akong tanungin tungkol sa:",
    "symptoms": "mga sintomas",
    "causes": "mga sanhi",
    "prevention": "pag-iwas",
    "treatment": "paggamot",
    "fertilizer": "pataba",
    'Example: "symptoms" or "treatment and fertilizer"':
        'Halimbawa: "mga sintomas" o "paggamot at pataba"',
    "Step ": "Hakbang ",
    "Note:": "Paalala:",
    "This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Ito ay pangkalahatang gabay lamang—sundin ang mga rekomendasyon ng lokal na tanggapan ng agrikultura para sa mga kemikal at aprubadong produkto.",
    "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.":
        "Paalala: Ito ay pangkalahatang gabay lamang—sundin ang mga rekomendasyon ng lokal na tanggapan ng agrikultura para sa mga kemikal at aprubadong produkto.",
  };

  /// Normalize language with fallback
  static String normalizeLanguage(String? language) {
    if (language == null || language.trim().isEmpty) return "english";
    final v = language.trim().toLowerCase();
    if (v == 'cebuano' || v == 'ceb' || v == 'bisaya' || v == 'binisaya') {
      return 'cebuano';
    }
    if (v == 'filipino' || v == 'fil' || v == 'tagalog' || v == 'tl' || v == 'philippine') {
      return 'filipino';
    }
    return 'english';
  }

  /// Translate text to specified language
  static String translateText(String text, String language) {
    final lang = normalizeLanguage(language);
    if (lang == "cebuano") {
      return cebuanoTranslations[text] ?? text;
    } else if (lang == "filipino") {
      return filipinoTranslations[text] ?? text;
    }
    return text;
  }

  /// Check network restriction queries and return localized limitation message
  static String? handleNetworkRestriction(String message, String language) {
    final m = message.toLowerCase();
    final triggers = [
      'internet', 'web search', 'search the web', 'search online', 'google',
      'browse the web', 'online access', 'live data', 'real-time', 'real time',
      'weather', 'forecast', 'temperature today', 'panahon ngayon', 'panahon karon',
      'market price', 'palay price', 'rice price today', 'presyo ng palay', 'presyo sa humay',
      'presyo ngayon', 'presyo karon', 'latest news', 'breaking news', 'balita ngayon',
      'balita karon', 'connect to internet', 'are you connected', 'online ba', 'konektado ba',
      'browse internet', 'search internet', 'live weather', 'live prices'
    ];

    if (triggers.any((trigger) => m.contains(trigger))) {
      final lang = normalizeLanguage(language);
      if (lang == 'cebuano') {
        return "Dili magamit ang koneksyon sa internet ug tinuod-nga-oras (real-time) nga pagpangita sa web. "
            "Ang AgriBot eksklusibong nagalihok isip usa ka lokal ug offline nga katabang sa pag-ila ug pagdumala "
            "sa mga sakit sa humay gamit ang lokal nga datos, ug walay abilidad sa pagsusi sa live nga datos sa panahon, "
            "kasamtangang presyo sa merkado, o mga serbisyo sa gawas.";
      } else if (lang == 'filipino') {
        return "Hindi available ang internet access at real-time na paghahanap sa web. "
            "Ang AgriBot ay eksklusibong gumagana bilang isang lokal at offline na katulong sa pagsusuri at pamamahala "
            "ng sakit ng palay gamit ang lokal na datos, at walang kakayahang mag-access ng live na lagay ng panahon, "
            "kasalukuyang presyo sa merkado, o mga panlabas na serbisyo.";
      } else {
        return "Internet access and real-time web search capabilities are unavailable. "
            "AgriBot operates strictly as a local and offline rice disease specialist assistant using local knowledge base data, "
            "and does not have access to live web searches, real-time weather forecasts, current market prices, or external online services.";
      }
    }
    return null;
  }

  /// Get disease information from local knowledge base
  static Map<String, dynamic> getDiseaseInfo(String diseaseKey) {
    final disease = LocalDiseaseKB.getDisease(diseaseKey);
    return disease ?? {};
  }

  /// Detect user intents from their message
  static Set<String> detectIntents(String message) {
    final msg = message.toLowerCase();
    final intents = <String>{};

    final symptomKw = [
      'symptom', 'symptoms', 'sign', 'signs', 'look like', 'appearance', 'spot', 'streak', 'lesion',
      'sintomas', 'sintoma', 'palatandaan', 'itsura', 'mukha', 'ano ang hitsura', 'makikita', 'paano malalaman', 'bakas',
      'timailhan', 'panagway', 'hitsura', 'makita', 'unsa ang hitsura', 'unsaon pag-ila'
    ];
    final causeKw = [
      'cause', 'causes', 'why', 'reason', 'source', 'what caused', 'where does it come from', 'how does it start', 'origin',
      'sanhi', 'dahilan', 'bakit', 'pinagmulan', 'paano nagkaroon', 'paano nagsimula', 'rason',
      'hinungdan', 'ngano', 'gikanan', 'diin gikan', 'unsaon pagsugod'
    ];
    final preventKw = [
      'prevent', 'prevention', 'avoid', 'stop', 'reduce', 'protect', 'how do i stop', 'how do i protect', 'keep away',
      'paglikay', 'likayi', 'pugngan', 'pugngi', 'pagpugong', 'proteksyon', 'unsaon paglikay', 'ayaw itugot',
      'iwasan', 'pag-iwas', 'pigilan', 'mapigilan', 'protektahan', 'pagpigil', 'paano maiiwasan', 'depensa'
    ];
    final treatKw = [
      'treat', 'treatment', 'cure', 'spray', 'fungicide', 'bactericide', 'chemical', 'medicine', 'control', 'manage',
      'how do i cure', 'what can i use', 'what should i do', 'solution', 'fix', 'remedy',
      'tambal', 'pagtambal', 'bulong', 'tambalan', 'tambalanan', 'kontrolahon', 'unsaon pagtambal', 'unsa akong buhaton', 'unsang tambal',
      'gamot', 'paggamot', 'lunas', 'gamutin', 'itutrato', 'kontrolin', 'pamahalaan', 'anong dapat gawin', 'anong gamot', 'solusyon'
    ];
    final fertKw = [
      'fertil', 'fertilizer', 'npk', 'urea', 'nitrogen', 'potassium', 'phosphorus', 'k ', 'n ', 'p ', 'nutrition', 'feed',
      'abono', 'pataba', 'nitroheno', 'what fertilizer', 'unsang abono', 'anong pataba'
    ];

    if (symptomKw.any((k) => msg.contains(k))) intents.add("symptoms");
    if (causeKw.any((k) => msg.contains(k))) intents.add("causes");
    if (preventKw.any((k) => msg.contains(k))) intents.add("prevention");
    if (treatKw.any((k) => msg.contains(k))) intents.add("treatment_plan");
    if (fertKw.any((k) => msg.contains(k))) intents.add("fertilizer_guidance");

    final quickMapping = {
      "symptoms": "symptoms",
      "causes": "causes",
      "prevention": "prevention",
      "treatment": "treatment_plan",
      "fertilizer": "fertilizer_guidance",
      "sintomas": "symptoms",
      "hinungdan": "causes",
      "sanhi": "causes",
      "dahilan": "causes",
      "paglikay": "prevention",
      "pag-iwas": "prevention",
      "tambal": "treatment_plan",
      "gamot": "treatment_plan",
      "paggamot": "treatment_plan",
      "abono": "fertilizer_guidance",
      "pataba": "fertilizer_guidance",
    };
    final cleaned = msg.trim();
    if (quickMapping.containsKey(cleaned)) {
      intents.add(quickMapping[cleaned]!);
    }

    return intents;
  }

  /// Format a list of items for display
  static String formatList(
      String title, List<String> items, String language, String sectionType) {
    final lang = normalizeLanguage(language);
    final translatedTitle = translateText(title.trim(), lang);
    
    final stepLabel = lang == 'cebuano'
        ? 'Lakang '
        : (lang == 'filipino' ? 'Hakbang ' : 'Step ');

    if (items.isEmpty) {
      if (sectionType == "bullets") {
        return "$translatedTitle:\n• ${translateText('N/A', lang)}";
      } else {
        return "$translatedTitle:\n${stepLabel}1: ${translateText('N/A', lang)}";
      }
    }

    final formattedItems = <String>[];

    if (sectionType == "bullets") {
      for (var item in items) {
        final txItem = translateText(item, lang);
        final shortened =
            txItem.length > 100 ? txItem.substring(0, 100) + "..." : txItem;
        formattedItems.add("• $shortened");
      }
    } else {
      for (int idx = 0; idx < items.length; idx++) {
        final txItem = translateText(items[idx], lang);
        final shortened =
            txItem.length > 100 ? txItem.substring(0, 100) + "..." : txItem;
        formattedItems.add("${stepLabel}${idx + 1}: $shortened");
      }
    }

    return "$translatedTitle:\n" + formattedItems.join("\n");
  }

  /// Generate contextual response without SLM (local only)
  static String generateContextualResponse(
      String diseaseName, Map<String, dynamic> kb, String question, String language) {
    final lang = normalizeLanguage(language);

    // Check network / external restriction request first
    final networkNotice = handleNetworkRestriction(question, lang);
    if (networkNotice != null) {
      return networkNotice;
    }

    final qLower = question.toLowerCase();

    // Identity question detection
    final isIdentityQuestion = [
      "who", "what are you", "yourself", "bot", "assistant", "help",
      "sino ka", "kinsa ka", "unsa ka", "your name", "about you", "ano ka"
    ].any((kw) => qLower.contains(kw));

    if (isIdentityQuestion) {
      if (lang == 'cebuano') {
        return "Ako si AgriBot, ang imong lokal ug offline nga katabang sa sakit sa humay. Makatabang ko nimo sa pagsabot sa mga timailhan, hinungdan, paglikay, pagtambal, ug abono para sa $diseaseName.";
      } else if (lang == 'filipino') {
        return "Ako si AgriBot, ang iyong lokal at offline na katulong sa sakit ng palay. Makatutulong ako sa iyo sa pag-unawa ng mga sintomas, sanhi, pag-iwas, paggamot, at pataba para sa $diseaseName.";
      } else {
        return "I am AgriBot, your local and offline rice disease assistant. I can help you understand symptoms, causes, prevention, treatment, and fertilizer guidance for $diseaseName.";
      }
    }

    final isControlQuestion = [
      "control", "manage", "what should i do", "how do i", "what can i do",
      "fix", "solve", "buhaton", "gawin", "gamot", "tambal"
    ].any((kw) => qLower.contains(kw));

    final isSeverityQuestion = [
      "serious", "severe", "danger", "risk", "bad", "harmful",
      "maingat", "peligro", "delikado", "kagrabe", "lala"
    ].any((kw) => qLower.contains(kw));

    String response = "";

    if (isControlQuestion || isSeverityQuestion) {
      final treatment = (kb['treatment_plan'] ?? []) as List;
      if (treatment.isNotEmpty) {
        response = formatList(
            "Recommended Actions", treatment.cast<String>(), lang, "steps");
      } else {
        response = translateText(
            "For management of this disease, monitor your fields regularly and consult local agricultural experts for guidance.",
            lang);
      }
    } else {
      final treatment = (kb['treatment_plan'] ?? []) as List;
      if (treatment.isNotEmpty) {
        response = formatList(
            "Disease Management",
            treatment.take(3).cast<String>().toList(),
            lang,
            "steps");
      } else {
        response = translateText(
            "For more specific help, try asking about symptoms, causes, prevention, treatment, or fertilizer guidance.",
            lang);
      }
    }

    final note = translateText(
        "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.",
        lang);
    response += "\n\n$note";

    return response;
  }

  /// Build reply for chatbot - main entry point
  static String buildReply(String diseaseKey, String userMessage, String language) {
    final lang = normalizeLanguage(language);
    final kb = LocalDiseaseKB.getDisease(diseaseKey);
    if (kb == null) {
      return lang == 'cebuano'
          ? "Wala mailhi ang impormasyon sa sakit. Palihog susiha ang matang sa sakit."
          : (lang == 'filipino'
              ? "Hindi available ang impormasyon ng sakit. Mangyaring suriin ang uri ng sakit."
              : "Disease information not available. Please verify the disease type.");
    }

    final msg = userMessage.trim();
    final display = translateText(kb['display'] ?? diseaseKey, lang);

    // Check network restriction query
    if (msg.isNotEmpty) {
      final networkNotice = handleNetworkRestriction(msg, lang);
      if (networkNotice != null) {
        return networkNotice;
      }
    }

    // If no message, return overview + menu
    if (msg.isEmpty) {
      final severity = translateText(kb['severity'] ?? "Unknown", lang);
      final urgency = translateText(kb['urgency'] ?? "N/A", lang);
      final explanation = kb['explanation'] ?? "";
      final sentences = explanation.split('. ');
      final shortExplanation =
          sentences.length >= 2 ? "${sentences[0]}. ${sentences[1]}." : explanation;
      final shortExplanationTx = translateText(shortExplanation, lang);

      final header =
          "${translateText('Disease:', lang)} $display\n${translateText('Severity:', lang)} $severity | ${translateText('Urgency:', lang)} $urgency\n\n$shortExplanationTx\n";

      final example = translateText(
          'Example: "symptoms" or "treatment and fertilizer"', lang);

      return header +
          "\n${translateText('You can ask me about:', lang)}\n"
          "  - ${translateText('symptoms', lang)}\n"
          "  - ${translateText('causes', lang)}\n"
          "  - ${translateText('prevention', lang)}\n"
          "  - ${translateText('treatment', lang)}\n"
          "  - ${translateText('fertilizer', lang)}\n\n"
          "$example";
    }

    final intents = detectIntents(msg);
    if (intents.isNotEmpty) {
      final parts = <String>[];
      if (intents.contains("symptoms")) {
        parts.add(formatList("Symptoms", (kb['symptoms'] ?? []).cast<String>(), lang, "bullets"));
      }
      if (intents.contains("causes")) {
        parts.add(formatList("Causes", (kb['causes'] ?? []).cast<String>(), lang, "bullets"));
      }
      if (intents.contains("prevention")) {
        parts.add(formatList("Prevention", (kb['prevention'] ?? []).cast<String>(), lang, "bullets"));
      }
      if (intents.contains("treatment_plan")) {
        parts.add(formatList("Disease Management Strategy", (kb['treatment_plan'] ?? []).cast<String>(), lang, "steps"));
      }
      if (intents.contains("fertilizer_guidance")) {
        parts.add(formatList("Fertilizer guidance", (kb['fertilizer_guidance'] ?? []).cast<String>(), lang, "bullets"));
      }
      final note = translateText(
          "Note: This is general guidance—follow local agriculture office recommendations for chemicals and approved products.",
          lang);
      parts.add("\n$note");
      return parts.join("\n");
    }

    return generateContextualResponse(display, kb, msg, lang);
  }

  /// Get initial overview for a disease
  static String getOverview(String diseaseKey, String language) {
    return buildReply(diseaseKey, "", language);
  }

  /// Validate disease key
  static bool isValidDisease(String diseaseKey) {
    return LocalDiseaseKB.getDisease(diseaseKey) != null;
  }
}

