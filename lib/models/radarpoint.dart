// Ajoutez cette classe dans votre fichier GameScreen.dart
import 'package:flutter/material.dart';

class RadarPointPainter extends CustomPainter {
  final double x;
  final double y;
  final Color color;
  final double animationValue;

  RadarPointPainter({
    required this.x,
    required this.y,
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(x, y);
    
    // Effet radar principal
    final radarPaint = Paint()
      ..color = color.withOpacity(0.6 * (1 - animationValue))
      ..style = PaintingStyle.fill;
    
    // Cercle d'onde radar
    final radius = 30.0 * animationValue;
    canvas.drawCircle(center, radius, radarPaint);
    
    // Anneau externe
    final ringPaint = Paint()
      ..color = color.withOpacity(0.9 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, ringPaint);
    
    // Point central plus visible
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 8, centerPaint);
    
    // Anneau central
    final centerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawCircle(center, 8, centerRingPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPointPainter oldDelegate) {
    return x != oldDelegate.x ||
        y != oldDelegate.y ||
        color != oldDelegate.color ||
        animationValue != oldDelegate.animationValue;
  }
}