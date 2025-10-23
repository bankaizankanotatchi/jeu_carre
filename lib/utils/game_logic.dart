import 'package:jeu_carre/models/game_model.dart';

class GameLogic {
  static const int squareSize = 1; // Taille fixe des carrés

  static List<Square> checkSquares(
    List<GridPoint> points,
    int gridSize,
    String playerId,
    int placedX,
    int placedY,
  ) {
    List<Square> newSquares = [];

    // Vérifier les 4 carrés possibles autour du point placé
    List<List<int>> possibleSquares = [
      [placedX - squareSize, placedY - squareSize], // Haut gauche
      [placedX, placedY - squareSize], // Haut droite
      [placedX - squareSize, placedY], // Bas gauche
      [placedX, placedY], // Bas droite
    ];

    for (var square in possibleSquares) {
      int startX = square[0];
      int startY = square[1];

      if (_isValidSquare(startX, startY, gridSize) &&
          _isSquareComplete(points, startX, startY, playerId)) {
        newSquares.add(Square(
          x: startX,
          y: startY,
          playerId: playerId,
          completedAt: DateTime.now(),
        ));
      }
    }

    return newSquares;
  }

  static bool _isValidSquare(int x, int y, int gridSize) {
    return x >= 0 && 
           y >= 0 && 
           (x + squareSize) < gridSize && 
           (y + squareSize) < gridSize;
  }

  static bool _isSquareComplete(
    List<GridPoint> points, 
    int startX, 
    int startY, 
    String playerId,
  ) {
    // Vérifier les 4 coins du carré
    final corners = [
      [startX, startY],
      [startX + squareSize, startY],
      [startX, startY + squareSize],
      [startX + squareSize, startY + squareSize],
    ];

    for (var corner in corners) {
      if (!_hasPlayerPoint(points, corner[0], corner[1], playerId)) {
        return false;
      }
    }
    return true;
  }

  static bool _hasPlayerPoint(
    List<GridPoint> points, 
    int x, 
    int y, 
    String playerId,
  ) {
    return points.any((point) =>
        point.x == x && point.y == y && point.playerId == playerId);
  }
}