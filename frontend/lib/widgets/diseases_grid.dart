// lib/widgets/diseases_grid.dart
import 'package:flutter/material.dart';
import 'disease_card.dart';

class DiseasesGrid extends StatelessWidget {
  const DiseasesGrid({super.key});

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

    return Column(
      children: [
        for (final d in diseases)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: DiseaseCard(
              title: d.$2,
              subtitle: d.$3,
              description: d.$4,
              diseaseKey: d.$1,
            ),
          ),
      ],
    );
  }
}
