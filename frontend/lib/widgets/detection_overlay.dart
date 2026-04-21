import 'dart:io';

import 'package:flutter/material.dart';

class DetectionOverlayImage extends StatelessWidget {
  final String? localImagePath;
  final String? networkImageUrl;
  final List<Map<String, dynamic>> detections;
  final double height;
  final BorderRadius borderRadius;

  const DetectionOverlayImage({
    super.key,
    this.localImagePath,
    this.networkImageUrl,
    required this.detections,
    this.height = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = localImagePath != null && localImagePath!.isNotEmpty;
    final hasNetworkImage =
        networkImageUrl != null && networkImageUrl!.isNotEmpty;

    if (!hasLocalImage && !hasNetworkImage) {
      return const SizedBox.shrink();
    }

    final imageWidget = hasLocalImage
        ? Image.file(
            File(localImagePath!),
            fit: BoxFit.fill,
          )
        : Image.network(
            networkImageUrl!,
            fit: BoxFit.fill,
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 640,
            height: 640,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                IgnorePointer(
                  child: CustomPaint(
                    painter: DetectionOverlayPainter(detections: detections),
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

class DetectionOverlayPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  const DetectionOverlayPainter({
    required this.detections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF22A45D);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xCC22A45D);

    for (final detection in detections) {
      var left = ((detection['left'] as num?)?.toDouble() ?? 0);
      var top = ((detection['top'] as num?)?.toDouble() ?? 0);
      var right = ((detection['right'] as num?)?.toDouble() ?? 0);
      var bottom = ((detection['bottom'] as num?)?.toDouble() ?? 0);
      final confidence = ((detection['confidence'] as num?)?.toDouble() ?? 0) * 100;
      final label = detection['label']?.toString() ?? 'disease';

      final normalized = left <= 1.0 && top <= 1.0 && right <= 1.0 && bottom <= 1.0;
      if (normalized) {
        left *= size.width;
        top *= size.height;
        right *= size.width;
        bottom *= size.height;
      } else {
        const modelWidth = 640.0;
        const modelHeight = 640.0;
        left *= size.width / modelWidth;
        top *= size.height / modelHeight;
        right *= size.width / modelWidth;
        bottom *= size.height / modelHeight;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom).intersect(Rect.fromLTWH(0, 0, size.width, size.height));
      if (rect.width <= 0 || rect.height <= 0) continue;
      canvas.drawRect(rect, boxPaint);

      final textSpan = TextSpan(
        text: '${label.replaceAll('_', ' ')} ${confidence.toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width - 12);

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          top > 24 ? top - 24 : top,
          textPainter.width + 10,
          textPainter.height + 6,
        ),
        const Radius.circular(6),
      );

      canvas.drawRRect(labelRect, fillPaint);
      textPainter.paint(
        canvas,
        Offset(labelRect.left + 5, labelRect.top + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
