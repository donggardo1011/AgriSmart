import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_client.dart';
import '../core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiseaseDetailScreen extends StatefulWidget {
  final String title;
  final String causalAgent;
  final String description;
  final String diseaseKey;

  const DiseaseDetailScreen({
    super.key,
    required this.title,
    required this.causalAgent,
    required this.description,
    required this.diseaseKey,
  });

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  late Future<Map<String, dynamic>> _diseaseDataFuture;

  @override
  void initState() {
    super.initState();
    _diseaseDataFuture = _fetchDiseaseData();
  }

  Future<Map<String, dynamic>> _fetchDiseaseData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        debugPrint('❌ No token found');
        return {};
      }

      final client = ApiClient(
        baseUrl: AppConstants.apiBaseUrl,
        token: token,
      );

      final response = await client.get('/api/diseases');
      debugPrint('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> diseases = json.decode(response.body);
        debugPrint('📊 Total diseases from API: ${diseases.length}');
        
        final disease = diseases.firstWhere(
          (d) => d['key'] == widget.diseaseKey,
          orElse: () => null,
        );
        
        if (disease != null) {
          debugPrint('✅ Found disease: ${disease['display_name']}');
          debugPrint('   Symptoms: ${disease['symptoms_summary_en']?.toString().substring(0, 50)}...');
          debugPrint('   Prevention: ${disease['prevention_summary_en']?.toString().substring(0, 50)}...');
          debugPrint('   Treatment: ${disease['treatment_summary_en']?.toString().substring(0, 50)}...');
          return disease as Map<String, dynamic>;
        } else {
          debugPrint('❌ Disease not found: ${widget.diseaseKey}');
        }
        return {};
      } else {
        debugPrint('❌ API Error: ${response.statusCode} - ${response.body}');
      }
      return {};
    } catch (e) {
      debugPrint('❌ Error fetching disease data: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: const Color(0xFF22A45D),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _diseaseDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final disease = snapshot.data ?? {};
          final symptomsSummary = disease['symptoms_summary_en'] as String?;
          final preventionSummary = disease['prevention_summary_en'] as String?;
          final treatmentSummary = disease['treatment_summary_en'] as String?;
          final overview = disease['explanation_en'] as String? ?? widget.description;
          final causalAgent = disease['causal_agent'] as String? ?? widget.causalAgent;
          
          debugPrint('🔍 Built with extracted data:');
          debugPrint('   Disease object keys: ${disease.keys.toList()}');
          debugPrint('   symptomsSummary: ${symptomsSummary?.substring(0, 30) ?? 'NULL'}...');
          debugPrint('   preventionSummary: ${preventionSummary?.substring(0, 30) ?? 'NULL'}...');
          debugPrint('   treatmentSummary: ${treatmentSummary?.substring(0, 30) ?? 'NULL'}...');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(textTheme),
                const SizedBox(height: 24),
                _buildCausalAgentSection(textTheme, causalAgent),
                const SizedBox(height: 24),
                _buildOverviewSection(textTheme, overview),
                const SizedBox(height: 24),
                _buildSymptomsSection(textTheme, symptomsSummary),
                const SizedBox(height: 24),
                _buildPreventionSection(textTheme, preventionSummary),
                const SizedBox(height: 24),
                _buildTreatmentSection(textTheme, treatmentSummary),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _getImageAssetPath(String diseaseKey) {
    const Map<String, String> diseaseImages = {
      'bacterial_blight': 'assets/disease_images/bacterial_blight.jpg',
      'leaf_blast': 'assets/disease_images/leaf_blast.jpg',
      'brown_spot': 'assets/disease_images/brown_spot.jpg',
      'sheath_blight': 'assets/disease_images/sheath_blight.jpg',
      'tungro': 'assets/disease_images/tungro.jpg',
    };
    return diseaseImages[diseaseKey];
  }

  Widget _buildImageSection(TextTheme textTheme) {
    final imageAsset = _getImageAssetPath(widget.diseaseKey);
    debugPrint('🖼️ [DiseaseDetail] Loading image for ${widget.diseaseKey}: $imageAsset');

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageAsset != null
            ? Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ [DiseaseDetail] Failed to load image: $error\n$stackTrace');
                  return _buildImagePlaceholder(textTheme);
                },
              )
            : _buildImagePlaceholder(textTheme),
      ),
    );
  }

  Widget _buildImagePlaceholder(TextTheme textTheme) {
    return Container(
      color: const Color(0xFF22A45D).withAlpha((0.1 * 255).round()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: const Color(0xFF22A45D).withAlpha((0.5 * 255).round()),
          ),
          const SizedBox(height: 12),
          Text(
            'Disease Image',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF22A45D).withAlpha((0.6 * 255).round()),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '(Image file not found)',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCausalAgentSection(TextTheme textTheme, String causalAgent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Causal Agent',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF22A45D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF22A45D).withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF22A45D).withAlpha((0.1 * 255).round()),
            ),
          ),
          child: Text(
            causalAgent,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF22A45D),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection(TextTheme textTheme, String overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF22A45D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          overview,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomsSection(TextTheme textTheme, String? symptomsSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Symptoms',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF22A45D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            symptomsSummary ?? 'Loading symptoms...',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreventionSection(TextTheme textTheme, String? preventionSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prevention',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF22A45D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            preventionSummary ?? 'Loading prevention strategies...',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentSection(TextTheme textTheme, String? treatmentSummary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Treatment',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF22A45D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            treatmentSummary ?? 'Loading treatment options...',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
