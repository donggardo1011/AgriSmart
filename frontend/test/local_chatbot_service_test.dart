import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/local_chatbot_service.dart';

void main() {
  group('LocalChatbotService Tests', () {
    test('Language Normalization and Fallback', () {
      expect(LocalChatbotService.normalizeLanguage(null), 'english');
      expect(LocalChatbotService.normalizeLanguage(''), 'english');
      expect(LocalChatbotService.normalizeLanguage('unsupported'), 'english');
      expect(LocalChatbotService.normalizeLanguage('cebuano'), 'cebuano');
      expect(LocalChatbotService.normalizeLanguage('bisaya'), 'cebuano');
      expect(LocalChatbotService.normalizeLanguage('filipino'), 'filipino');
      expect(LocalChatbotService.normalizeLanguage('tagalog'), 'filipino');
    });

    test('Network Restriction Checks', () {
      final weatherEn = LocalChatbotService.handleNetworkRestriction(
          'What is the live weather today?', 'english');
      expect(weatherEn, isNotNull);
      expect(weatherEn!.toLowerCase(), contains('offline'));
      expect(weatherEn.toLowerCase(), contains('unavailable'));

      final weatherFil = LocalChatbotService.handleNetworkRestriction(
          'Ano ang lagay ng panahon ngayon?', 'filipino');
      expect(weatherFil, isNotNull);
      expect(weatherFil!.toLowerCase(), contains('offline'));
      expect(weatherFil.toLowerCase(), contains('hindi available'));

      final weatherCeb = LocalChatbotService.handleNetworkRestriction(
          'Unsa ang panahon karon?', 'cebuano');
      expect(weatherCeb, isNotNull);
      expect(weatherCeb!.toLowerCase(), contains('offline'));
      expect(weatherCeb.toLowerCase(), contains('dili magamit'));
    });

    test('Multi-lingual Intent Detection', () {
      expect(LocalChatbotService.detectIntents('symptoms').contains('symptoms'), isTrue);
      expect(LocalChatbotService.detectIntents('mga sintomas').contains('symptoms'), isTrue);
      expect(LocalChatbotService.detectIntents('mga timailhan').contains('symptoms'), isTrue);

      expect(LocalChatbotService.detectIntents('causes').contains('causes'), isTrue);
      expect(LocalChatbotService.detectIntents('sanhi').contains('causes'), isTrue);
      expect(LocalChatbotService.detectIntents('hinungdan').contains('causes'), isTrue);

      expect(LocalChatbotService.detectIntents('prevention').contains('prevention'), isTrue);
      expect(LocalChatbotService.detectIntents('pag-iwas').contains('prevention'), isTrue);
      expect(LocalChatbotService.detectIntents('paglikay').contains('prevention'), isTrue);
    });

    test('Strict Language Formatting in buildReply', () {
      // English
      final replyEn = LocalChatbotService.buildReply('bacterial_blight', 'symptoms', 'english');
      expect(replyEn, contains('Symptoms:'));

      // Filipino
      final replyFil = LocalChatbotService.buildReply('bacterial_blight', 'symptoms', 'filipino');
      expect(replyFil, contains('Mga Sintomas:'));

      // Cebuano
      final replyCeb = LocalChatbotService.buildReply('bacterial_blight', 'treatment', 'cebuano');
      expect(replyCeb, contains('Estratehiya sa Pagdumala sa Sakit:'));
      expect(replyCeb, contains('Lakang 1:'));
    });
  });
}
