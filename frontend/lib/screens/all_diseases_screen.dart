import 'package:flutter/material.dart';

import '../widgets/disease_card.dart';

class AllDiseasesScreen extends StatelessWidget {
  const AllDiseasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const diseases = [
      (
        'bacterial_blight',
        'Bacterial Blight',
        'Xanthomonas oryzae pv. oryzae',
        'Serious bacterial disease that can spread quickly in wet and windy conditions.',
      ),
      (
        'brown_spot',
        'Brown Spot',
        'Bipolaris oryzae',
        'Common fungal disease that often worsens when rice plants are weak or nutrient-deficient.',
      ),
      (
        'leaf_blast',
        'Leaf Blast',
        'Magnaporthe oryzae',
        'Destructive fungal disease that forms lesions on leaves and can reduce yield.',
      ),
      (
        'sheath_blight',
        'Sheath Blight',
        'Rhizoctonia solani',
        'Major fungal disease that can cause yield loss up to 50% and affects leaf sheaths.',
      ),
      (
        'tungro',
        'Tungro',
        'RTSV & RTBV',
        'Viral disease transmitted by green leafhoppers that can severely stunt rice growth.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rice Diseases'),
        backgroundColor: const Color(0xFF22A45D),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: diseases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = diseases[i];
          return DiseaseCard(
            title: d.$2,
            subtitle: d.$3,
            description: d.$4,
            diseaseKey: d.$1,
          );
        },
      ),
    );
  }
}

