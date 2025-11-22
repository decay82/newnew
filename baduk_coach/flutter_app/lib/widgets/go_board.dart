import 'package:flutter/material.dart';
import '../models/stone.dart';
import '../models/go_game.dart';
import '../models/api_models.dart';

/// 바둑판 위젯
class GoBoard extends StatelessWidget {
  final GoGame game;
  final Function(int row, int col)? onTap;
  final RecommendedMove? bestMove;
  final RecommendedMove? styleMove;
  final Position? lastMove;

  const GoBoard({
    super.key,
    required this.game,
    this.onTap,
    this.bestMove,
    this.styleMove,
    this.lastMove,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) {
              if (onTap == null) return;
              final cellSize = constraints.maxWidth / game.boardSize;
              final row = (details.localPosition.dy / cellSize).floor();
              final col = (details.localPosition.dx / cellSize).floor();
              if (row >= 0 && row < game.boardSize && col >= 0 && col < game.boardSize) {
                onTap!(row, col);
              }
            },
            child: CustomPaint(
              painter: GoBoardPainter(
                game: game,
                bestMove: bestMove,
                styleMove: styleMove,
                lastMove: lastMove,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          );
        },
      ),
    );
  }
}

/// 바둑판 그리기
class GoBoardPainter extends CustomPainter {
  final GoGame game;
  final RecommendedMove? bestMove;
  final RecommendedMove? styleMove;
  final Position? lastMove;

  GoBoardPainter({
    required this.game,
    this.bestMove,
    this.styleMove,
    this.lastMove,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / game.boardSize;
    final stoneRadius = cellSize * 0.45;
    final padding = cellSize / 2;

    // 배경 (나무색)
    final bgPaint = Paint()..color = const Color(0xFFDEB887);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 선 그리기
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    for (var i = 0; i < game.boardSize; i++) {
      final pos = padding + i * cellSize;
      // 가로선
      canvas.drawLine(
        Offset(padding, pos),
        Offset(size.width - padding, pos),
        linePaint,
      );
      // 세로선
      canvas.drawLine(
        Offset(pos, padding),
        Offset(pos, size.height - padding),
        linePaint,
      );
    }

    // 화점 그리기
    _drawStarPoints(canvas, cellSize, padding);

    // 추천 수 마커 그리기
    _drawRecommendedMoves(canvas, cellSize, padding, stoneRadius);

    // 돌 그리기
    for (var row = 0; row < game.boardSize; row++) {
      for (var col = 0; col < game.boardSize; col++) {
        final stone = game.getStone(row, col);
        if (stone != null) {
          _drawStone(
            canvas,
            Offset(padding + col * cellSize, padding + row * cellSize),
            stoneRadius,
            stone,
            isLastMove: lastMove?.row == row && lastMove?.col == col,
          );
        }
      }
    }
  }

  void _drawStarPoints(Canvas canvas, double cellSize, double padding) {
    final starPaint = Paint()..color = Colors.black;
    final starRadius = cellSize * 0.1;

    List<int> starPoints;
    if (game.boardSize == 19) {
      starPoints = [3, 9, 15];
    } else if (game.boardSize == 13) {
      starPoints = [3, 6, 9];
    } else if (game.boardSize == 9) {
      starPoints = [2, 4, 6];
    } else {
      return;
    }

    for (final row in starPoints) {
      for (final col in starPoints) {
        canvas.drawCircle(
          Offset(padding + col * cellSize, padding + row * cellSize),
          starRadius,
          starPaint,
        );
      }
    }
  }

  void _drawStone(
    Canvas canvas,
    Offset center,
    double radius,
    StoneColor color, {
    bool isLastMove = false,
  }) {
    // 돌 그림자
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);

    // 돌
    final stonePaint = Paint()
      ..color = color == StoneColor.black ? Colors.black : Colors.white;
    canvas.drawCircle(center, radius, stonePaint);

    // 돌 테두리
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);

    // 마지막 수 마커
    if (isLastMove) {
      final markerPaint = Paint()
        ..color = color == StoneColor.black ? Colors.white : Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius * 0.3, markerPaint);
    }
  }

  void _drawRecommendedMoves(
    Canvas canvas,
    double cellSize,
    double padding,
    double stoneRadius,
  ) {
    // Best Move (파란색)
    if (bestMove != null && game.getStone(bestMove!.row, bestMove!.col) == null) {
      final center = Offset(
        padding + bestMove!.col * cellSize,
        padding + bestMove!.row * cellSize,
      );
      final paint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, stoneRadius * 0.6, paint);

      // "최적" 텍스트
      _drawText(canvas, center, '최적', Colors.white, stoneRadius * 0.4);
    }

    // Style Move (녹색)
    if (styleMove != null &&
        game.getStone(styleMove!.row, styleMove!.col) == null &&
        (bestMove == null || bestMove!.row != styleMove!.row || bestMove!.col != styleMove!.col)) {
      final center = Offset(
        padding + styleMove!.col * cellSize,
        padding + styleMove!.row * cellSize,
      );
      final paint = Paint()
        ..color = Colors.green.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, stoneRadius * 0.6, paint);

      // "스타일" 텍스트
      _drawText(canvas, center, '스타일', Colors.white, stoneRadius * 0.35);
    }
  }

  void _drawText(Canvas canvas, Offset center, String text, Color color, double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GoBoardPainter oldDelegate) {
    return true;
  }
}
