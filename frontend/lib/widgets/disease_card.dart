// lib/widgets/disease_card.dart
import 'package:flutter/material.dart';
import '../screens/disease_detail_screen.dart';

class DiseaseCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String description;
  final String diseaseKey;

  const DiseaseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.diseaseKey,
  });

  @override
  State<DiseaseCard> createState() => _DiseaseCardState();
}

class _DiseaseCardState extends State<DiseaseCard> {
  bool _isHovered = false;

  void _navigateToDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiseaseDetailScreen(
          title: widget.title,
          causalAgent: widget.subtitle,
          description: widget.description,
          diseaseKey: widget.diseaseKey,
        ),
      ),
    );
  }

  String _getImageAssetPath(String diseaseKey) {
    const Map<String, String> diseaseImages = {
      'bacterial_blight': 'assets/disease_images/bacterial_blight.jpg',
      'leaf_blast': 'assets/disease_images/leaf_blast.jpg',
      'brown_spot': 'assets/disease_images/brown_spot.jpg',
      'sheath_blight': 'assets/disease_images/sheath_blight.jpg',
      'tungro': 'assets/disease_images/tungro.jpg',
    };
    return diseaseImages[diseaseKey] ?? 'assets/disease_images/bacterial_blight.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imagePath = _getImageAssetPath(widget.diseaseKey);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22A45D).withOpacity(_isHovered ? 0.2 : 0.08),
              blurRadius: _isHovered ? 16 : 8,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF22A45D).withAlpha((0.1 * 255).round()),
                    ),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF22A45D).withAlpha((0.1 * 255).round()),
                          child: Icon(
                            Icons.eco,
                            color: const Color(0xFF22A45D),
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF22A45D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _navigateToDetail(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22A45D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Learn More',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
