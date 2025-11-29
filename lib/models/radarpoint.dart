import 'package:flutter/material.dart';

class RadarPointPainter extends CustomPainter {
  final double x;
  final double y;
  final Color color;
  final double animationValue;
  final Offset? previousPosition; // 🔥 Nouveau: position précédente pour interpolation
  final double smoothFactor; // 🔥 Nouveau: facteur de lissage

  RadarPointPainter({
    required this.x,
    required this.y,
    required this.color,
    required this.animationValue,
    this.previousPosition, // 🔥 Optionnel: pour interpolation
    this.smoothFactor = 0.3, // 🔥 Facteur de lissage (0.1 = très lisse, 0.5 = peu lisse)
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🔥 CALCUL DE LA POSITION LISSÉE
    Offset currentCenter = Offset(x, y);
    Offset smoothedCenter = currentCenter;
    
    if (previousPosition != null) {
      // 🔥 Interpolation linéaire pour un mouvement fluide
      smoothedCenter = Offset(
        previousPosition!.dx + (x - previousPosition!.dx) * smoothFactor,
        previousPosition!.dy + (y - previousPosition!.dy) * smoothFactor,
      );
    }
    
    final center = smoothedCenter;
    
    // 🔥 EFFET RADAR PERMANENT - Plusieurs couches pour plus de contraste
    
    // 1. POINT CENTRAL TRÈS VISIBLE
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 10, centerPaint);
    
    // 2. ANEAU CENTRAL BLANC ÉPAIS
    final centerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(center, 10, centerRingPaint);
    
    // 3. PREMIÈRE ONDE RADAR (très visible)
    final radarPaint1 = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final radius1 = 15.0 + (25.0 * animationValue);
    canvas.drawCircle(center, radius1, radarPaint1);
    
    // 4. DEUXIÈME ONDE RADAR (contraste)
    final radarPaint2 = Paint()
      ..color = Colors.white.withOpacity(0.6 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    
    canvas.drawCircle(center, radius1, radarPaint2);
    
    // 5. TROISIÈME ONDE EXTERNE (très large)
    final radarPaint3 = Paint()
      ..color = color.withOpacity(0.4 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final radius2 = radius1 + 15.0;
    canvas.drawCircle(center, radius2, radarPaint3);
    
    // 6. EFFET DE LUMIÈRE PULSÉE
    if (animationValue > 0.5) {
      final pulsePaint = Paint()
        ..color = Colors.white.withOpacity(0.3 * (1 - animationValue))
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, 8, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPointPainter oldDelegate) {
    return x != oldDelegate.x ||
        y != oldDelegate.y ||
        color != oldDelegate.color ||
        animationValue != oldDelegate.animationValue ||
        previousPosition != oldDelegate.previousPosition;
  }
}