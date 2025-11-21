/// 오목 게임의 플레이어를 나타내는 열거형
enum Player {
  black, // 흑돌 (선공)
  white, // 백돌 (후공)
  none,  // 빈 칸
}

/// 보드 위의 위치를 나타내는 클래스
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row * 100 + col;

  @override
  String toString() => '($row, $col)';
}

/// 오목 게임 상태를 나타내는 클래스
/// Isolate 간 전송을 위해 불변(immutable)으로 설계
class GameState {
  static const int boardSize = 15; // 15x15 오목판
  static const int winCount = 5;   // 5목 승리

  /// 보드 상태: 2D 리스트 (row, col)
  /// Player.none = 빈 칸, Player.black = 흑돌, Player.white = 백돌
  final List<List<Player>> board;

  /// 현재 차례인 플레이어
  final Player currentPlayer;

  /// 게임 종료 여부
  final bool isGameOver;

  /// 승자 (게임 진행 중이면 Player.none)
  final Player winner;

  const GameState({
    required this.board,
    required this.currentPlayer,
    this.isGameOver = false,
    this.winner = Player.none,
  });

  /// 빈 보드로 새 게임 시작
  factory GameState.initial() {
    final board = List.generate(
      boardSize,
      (_) => List.filled(boardSize, Player.none),
    );
    return GameState(
      board: board,
      currentPlayer: Player.black, // 흑돌 선공
    );
  }

  /// 깊은 복사를 통한 보드 복제
  List<List<Player>> _copyBoard() {
    return board.map((row) => List<Player>.from(row)).toList();
  }

  /// 특정 위치에 돌을 놓고 새로운 GameState 반환
  GameState makeMove(Position pos) {
    if (!isValidMove(pos)) {
      return this; // 유효하지 않은 수는 무시
    }

    final newBoard = _copyBoard();
    newBoard[pos.row][pos.col] = currentPlayer;

    // 승리 체크
    final hasWon = _checkWin(newBoard, pos, currentPlayer);

    // 무승부 체크 (보드가 가득 찼는지)
    final isDraw = !hasWon && _isBoardFull(newBoard);

    return GameState(
      board: newBoard,
      currentPlayer: hasWon || isDraw
          ? currentPlayer
          : (currentPlayer == Player.black ? Player.white : Player.black),
      isGameOver: hasWon || isDraw,
      winner: hasWon ? currentPlayer : Player.none,
    );
  }

  /// 해당 위치에 돌을 놓을 수 있는지 확인
  bool isValidMove(Position pos) {
    if (isGameOver) return false;
    if (pos.row < 0 || pos.row >= boardSize) return false;
    if (pos.col < 0 || pos.col >= boardSize) return false;
    return board[pos.row][pos.col] == Player.none;
  }

  /// 가능한 모든 수(빈 칸) 반환
  List<Position> getValidMoves() {
    if (isGameOver) return [];

    final moves = <Position>[];
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (board[row][col] == Player.none) {
          moves.add(Position(row, col));
        }
      }
    }
    return moves;
  }

  /// 효율적인 탐색을 위해 기존 돌 주변의 빈 칸만 반환
  /// MCTS 시뮬레이션 최적화용
  List<Position> getSmartMoves({int radius = 2}) {
    if (isGameOver) return [];

    final candidateSet = <Position>{};
    bool hasStones = false;

    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (board[row][col] != Player.none) {
          hasStones = true;
          // 돌 주변 radius 범위 내의 빈 칸 추가
          for (int dr = -radius; dr <= radius; dr++) {
            for (int dc = -radius; dc <= radius; dc++) {
              final nr = row + dr;
              final nc = col + dc;
              if (nr >= 0 && nr < boardSize &&
                  nc >= 0 && nc < boardSize &&
                  board[nr][nc] == Player.none) {
                candidateSet.add(Position(nr, nc));
              }
            }
          }
        }
      }
    }

    // 보드에 돌이 없으면 중앙에 두기
    if (!hasStones) {
      return [Position(boardSize ~/ 2, boardSize ~/ 2)];
    }

    return candidateSet.toList();
  }

  /// 승리 조건 확인 (5목 연속)
  bool _checkWin(List<List<Player>> board, Position lastMove, Player player) {
    final directions = [
      [0, 1],  // 가로
      [1, 0],  // 세로
      [1, 1],  // 대각선 ↘
      [1, -1], // 대각선 ↙
    ];

    for (final dir in directions) {
      int count = 1; // 마지막으로 둔 돌 포함

      // 정방향 탐색
      for (int i = 1; i < winCount; i++) {
        final nr = lastMove.row + dir[0] * i;
        final nc = lastMove.col + dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      // 역방향 탐색
      for (int i = 1; i < winCount; i++) {
        final nr = lastMove.row - dir[0] * i;
        final nc = lastMove.col - dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      if (count >= winCount) return true;
    }
    return false;
  }

  /// 보드가 가득 찼는지 확인
  bool _isBoardFull(List<List<Player>> board) {
    for (final row in board) {
      for (final cell in row) {
        if (cell == Player.none) return false;
      }
    }
    return true;
  }

  /// Isolate 전송을 위한 직렬화
  Map<String, dynamic> toJson() {
    return {
      'board': board.map((row) => row.map((p) => p.index).toList()).toList(),
      'currentPlayer': currentPlayer.index,
      'isGameOver': isGameOver,
      'winner': winner.index,
    };
  }

  /// Isolate에서 역직렬화
  factory GameState.fromJson(Map<String, dynamic> json) {
    final boardData = json['board'] as List;
    final board = boardData.map((row) {
      return (row as List).map((p) => Player.values[p as int]).toList();
    }).toList();

    return GameState(
      board: board,
      currentPlayer: Player.values[json['currentPlayer'] as int],
      isGameOver: json['isGameOver'] as bool,
      winner: Player.values[json['winner'] as int],
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Current: $currentPlayer, GameOver: $isGameOver, Winner: $winner');
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        switch (board[row][col]) {
          case Player.black:
            buffer.write('● ');
            break;
          case Player.white:
            buffer.write('○ ');
            break;
          case Player.none:
            buffer.write('· ');
            break;
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
