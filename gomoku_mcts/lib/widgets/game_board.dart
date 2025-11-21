import 'package:flutter/material.dart';
import '../models/game_state.dart';

/// 오목판 위젯
class GameBoard extends StatelessWidget {
  final GameState gameState;
  final Position? hintPosition;
  final Position? lastMove;
  final void Function(Position)? onTap;
  final bool showCoordinates;

  const GameBoard({
    super.key,
    required this.gameState,
    this.hintPosition,
    this.lastMove,
    this.onTap,
    this.showCoordinates = true,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth;
          final cellSize = boardSize / (GameState.boardSize + 1);
          final padding = cellSize;

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFDEB887), // 나무색 배경
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 격자선
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: BoardGridPainter(
                    cellSize: cellSize,
                    padding: padding,
                    boardSize: GameState.boardSize,
                    showCoordinates: showCoordinates,
                  ),
                ),
                // 돌과 힌트
                ...List.generate(GameState.boardSize, (row) {
                  return List.generate(GameState.boardSize, (col) {
                    final position = Position(row, col);
                    final player = gameState.board[row][col];
                    final isHint = hintPosition == position;
                    final isLast = lastMove == position;

                    return Positioned(
                      left: padding + col * cellSize - cellSize / 2,
                      top: padding + row * cellSize - cellSize / 2,
                      child: GestureDetector(
                        onTap: player == Player.none && !gameState.isGameOver
                            ? () => onTap?.call(position)
                            : null,
                        child: SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: _buildCell(
                            player,
                            cellSize,
                            isHint: isHint,
                            isLast: isLast,
                          ),
                        ),
                      ),
                    );
                  });
                }).expand((e) => e),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCell(
    Player player,
    double cellSize, {
    bool isHint = false,
    bool isLast = false,
  }) {
    final stoneSize = cellSize * 0.85;

    if (player == Player.none) {
      if (isHint) {
        // 힌트 표시 (반투명 돌 + 깜빡임 효과)
        return Center(
          child: _HintIndicator(
            size: stoneSize,
            color: gameState.currentPlayer == Player.black
                ? Colors.black
                : Colors.white,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // 돌 표시
    return Center(
      child: Container(
        width: stoneSize,
        height: stoneSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: player == Player.black
              ? const RadialGradient(
                  colors: [Color(0xFF4A4A4A), Colors.black],
                  center: Alignment(-0.3, -0.3),
                )
              : const RadialGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                  center: Alignment(-0.3, -0.3),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: isLast
            ? Center(
                child: Container(
                  width: stoneSize * 0.3,
                  height: stoneSize * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: player == Player.black
                        ? Colors.red
                        : Colors.red.shade700,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 힌트 표시 위젯 (깜빡이는 효과)
class _HintIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const _HintIndicator({
    required this.size,
    required this.color,
  });

  @override
  State<_HintIndicator> createState() => _HintIndicatorState();
}

class _HintIndicatorState extends State<_HintIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_animation.value),
            border: Border.all(
              color: Colors.green,
              width: 3,
            ),
          ),
        );
      },
    );
  }
}

/// 격자선 그리기
class BoardGridPainter extends CustomPainter {
  final double cellSize;
  final double padding;
  final int boardSize;
  final bool showCoordinates;

  BoardGridPainter({
    required this.cellSize,
    required this.padding,
    required this.boardSize,
    this.showCoordinates = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 격자선 그리기
    for (int i = 0; i < boardSize; i++) {
      // 가로선
      canvas.drawLine(
        Offset(padding, padding + i * cellSize),
        Offset(padding + (boardSize - 1) * cellSize, padding + i * cellSize),
        paint,
      );
      // 세로선
      canvas.drawLine(
        Offset(padding + i * cellSize, padding),
        Offset(padding + i * cellSize, padding + (boardSize - 1) * cellSize),
        paint,
      );
    }

    // 화점 (star points) 그리기
    final starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final starPoints = <List<int>>[
      [3, 3], [3, 7], [3, 11],
      [7, 3], [7, 7], [7, 11],
      [11, 3], [11, 7], [11, 11],
    ];

    for (final point in starPoints) {
      if (point[0] < boardSize && point[1] < boardSize) {
        canvas.drawCircle(
          Offset(padding + point[1] * cellSize, padding + point[0] * cellSize),
          4,
          starPaint,
        );
      }
    }

    // 좌표 표시
    if (showCoordinates) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      for (int i = 0; i < boardSize; i++) {
        // 열 좌표 (A-O)
        textPainter.text = TextSpan(
          text: String.fromCharCode(65 + i), // A, B, C, ...
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            padding + i * cellSize - textPainter.width / 2,
            size.height - padding / 2 - textPainter.height / 2,
          ),
        );

        // 행 좌표 (1-15)
        textPainter.text = TextSpan(
          text: '${boardSize - i}',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            padding / 2 - textPainter.width / 2,
            padding + i * cellSize - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
