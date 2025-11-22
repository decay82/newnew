import 'stone.dart';

/// 착수 결과
enum PlaceResult {
  success, // 성공
  occupied, // 이미 돌이 있음
  suicide, // 자충수
  ko, // 패
  gameEnded, // 게임 종료
}

/// 바둑 게임 로직 - 모든 룰 구현
class GoGame {
  final int boardSize;
  late List<List<StoneColor?>> _board;
  final List<Move> _moves = [];
  StoneColor _currentPlayer = StoneColor.black;
  String? _previousBoardHash; // 패 체크용
  bool _gameEnded = false;
  int _consecutivePasses = 0;

  // 잡은 돌 수
  int _blackCaptures = 0;
  int _whiteCaptures = 0;

  GoGame({this.boardSize = 19}) {
    _board = List.generate(
      boardSize,
      (_) => List.filled(boardSize, null),
    );
  }

  // Getters
  List<List<StoneColor?>> get board => _board;
  List<Move> get moves => List.unmodifiable(_moves);
  StoneColor get currentPlayer => _currentPlayer;
  bool get gameEnded => _gameEnded;
  int get blackCaptures => _blackCaptures;
  int get whiteCaptures => _whiteCaptures;
  int get moveCount => _moves.length;

  /// 특정 위치의 돌 색상 반환
  StoneColor? getStone(int row, int col) {
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
      return null;
    }
    return _board[row][col];
  }

  /// 착수 시도
  PlaceResult placeStone(int row, int col) {
    if (_gameEnded) return PlaceResult.gameEnded;

    final position = Position(row, col);

    // 1. 범위 체크
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
      return PlaceResult.occupied;
    }

    // 2. 빈 점인지 체크
    if (_board[row][col] != null) {
      return PlaceResult.occupied;
    }

    // 3. 임시로 돌 놓기
    _board[row][col] = _currentPlayer;

    // 4. 상대 돌 따냄 체크
    final capturedStones = <Position>[];
    for (final neighbor in position.getNeighbors(boardSize)) {
      final neighborColor = _board[neighbor.row][neighbor.col];
      if (neighborColor == _currentPlayer.opponent) {
        final group = _getGroup(neighbor);
        if (_getLiberties(group).isEmpty) {
          capturedStones.addAll(group);
        }
      }
    }

    // 5. 자충수 체크 (상대를 잡지 못하면서 내 활로가 0인 경우)
    if (capturedStones.isEmpty) {
      final myGroup = _getGroup(position);
      if (_getLiberties(myGroup).isEmpty) {
        // 자충수 - 돌 되돌리기
        _board[row][col] = null;
        return PlaceResult.suicide;
      }
    }

    // 6. 패 체크
    final newBoardHash = _getBoardHash();
    if (capturedStones.length == 1 && newBoardHash == _previousBoardHash) {
      // 패 - 돌 되돌리기
      _board[row][col] = null;
      return PlaceResult.ko;
    }

    // 7. 따냄 실행
    for (final pos in capturedStones) {
      _board[pos.row][pos.col] = null;
    }

    // 잡은 돌 수 업데이트
    if (_currentPlayer == StoneColor.black) {
      _blackCaptures += capturedStones.length;
    } else {
      _whiteCaptures += capturedStones.length;
    }

    // 8. 상태 업데이트
    _previousBoardHash = _getBoardHashBeforeMove(position, capturedStones);
    _moves.add(Move(
      color: _currentPlayer,
      position: position,
      capturedStones: capturedStones,
    ));
    _currentPlayer = _currentPlayer.opponent;
    _consecutivePasses = 0;

    return PlaceResult.success;
  }

  /// 패스
  void pass() {
    if (_gameEnded) return;

    _moves.add(Move(color: _currentPlayer, position: null));
    _currentPlayer = _currentPlayer.opponent;
    _consecutivePasses++;

    // 연속 2번 패스하면 게임 종료
    if (_consecutivePasses >= 2) {
      _gameEnded = true;
    }
  }

  /// 무르기 (한 수 되돌리기)
  bool undo() {
    if (_moves.isEmpty) return false;

    final lastMove = _moves.removeLast();

    if (lastMove.isPass) {
      _consecutivePasses = 0;
      _gameEnded = false;
    } else {
      final pos = lastMove.position!;
      // 놓은 돌 제거
      _board[pos.row][pos.col] = null;

      // 잡혔던 돌 복구
      for (final captured in lastMove.capturedStones) {
        _board[captured.row][captured.col] = lastMove.color.opponent;
      }

      // 잡은 돌 수 복구
      if (lastMove.color == StoneColor.black) {
        _blackCaptures -= lastMove.capturedStones.length;
      } else {
        _whiteCaptures -= lastMove.capturedStones.length;
      }
    }

    _currentPlayer = lastMove.color;

    // 이전 패 상태 복구 (간략화)
    _previousBoardHash = null;

    return true;
  }

  /// 게임 리셋
  void reset() {
    _board = List.generate(
      boardSize,
      (_) => List.filled(boardSize, null),
    );
    _moves.clear();
    _currentPlayer = StoneColor.black;
    _previousBoardHash = null;
    _gameEnded = false;
    _consecutivePasses = 0;
    _blackCaptures = 0;
    _whiteCaptures = 0;
  }

  /// 돌 그룹 찾기 (연결된 같은 색 돌들)
  Set<Position> _getGroup(Position start) {
    final color = _board[start.row][start.col];
    if (color == null) return {};

    final group = <Position>{};
    final toCheck = <Position>[start];

    while (toCheck.isNotEmpty) {
      final pos = toCheck.removeLast();
      if (group.contains(pos)) continue;

      final posColor = _board[pos.row][pos.col];
      if (posColor != color) continue;

      group.add(pos);
      toCheck.addAll(pos.getNeighbors(boardSize));
    }

    return group;
  }

  /// 그룹의 활로(빈 점) 찾기
  Set<Position> _getLiberties(Set<Position> group) {
    final liberties = <Position>{};

    for (final pos in group) {
      for (final neighbor in pos.getNeighbors(boardSize)) {
        if (_board[neighbor.row][neighbor.col] == null) {
          liberties.add(neighbor);
        }
      }
    }

    return liberties;
  }

  /// 보드 상태 해시 (패 체크용)
  String _getBoardHash() {
    final buffer = StringBuffer();
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        final stone = _board[row][col];
        buffer.write(stone == null ? '.' : (stone == StoneColor.black ? 'B' : 'W'));
      }
    }
    return buffer.toString();
  }

  /// 착수 전 보드 해시 (패 체크용)
  String _getBoardHashBeforeMove(Position placed, List<Position> captured) {
    final buffer = StringBuffer();
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        StoneColor? stone = _board[row][col];
        // 방금 놓은 돌 제외
        if (row == placed.row && col == placed.col) {
          stone = null;
        }
        // 잡힌 돌 복구
        for (final cap in captured) {
          if (row == cap.row && col == cap.col) {
            stone = _currentPlayer; // 이미 턴이 바뀐 상태이므로 현재 플레이어가 상대
          }
        }
        buffer.write(stone == null ? '.' : (stone == StoneColor.black ? 'B' : 'W'));
      }
    }
    return buffer.toString();
  }

  /// 현재 보드 상태를 JSON으로 변환 (API 호출용)
  Map<String, dynamic> toBoardStateJson() {
    return {
      'size': boardSize,
      'moves': _moves.map((m) => m.toJson()).toList(),
    };
  }

  /// SGF 형식으로 내보내기
  String toSgf() {
    final buffer = StringBuffer();
    buffer.write('(;GM[1]FF[4]SZ[$boardSize]');
    buffer.write('KM[6.5]'); // 덤 6.5

    for (final move in _moves) {
      if (move.isPass) {
        buffer.write(';${move.color.symbol}[]');
      } else {
        final col = String.fromCharCode('a'.codeUnitAt(0) + move.position!.col);
        final row = String.fromCharCode('a'.codeUnitAt(0) + move.position!.row);
        buffer.write(';${move.color.symbol}[$col$row]');
      }
    }

    buffer.write(')');
    return buffer.toString();
  }

  /// SGF에서 불러오기
  static GoGame fromSgf(String sgf, {int defaultSize = 19}) {
    // 보드 사이즈 파싱
    int boardSize = defaultSize;
    final sizeMatch = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
    if (sizeMatch != null) {
      boardSize = int.parse(sizeMatch.group(1)!);
    }

    final game = GoGame(boardSize: boardSize);

    // 수순 파싱
    final movePattern = RegExp(r';([BW])\[([a-z]*)([a-z]*)\]');
    for (final match in movePattern.allMatches(sgf)) {
      final colorStr = match.group(1)!;
      final colStr = match.group(2) ?? '';
      final rowStr = match.group(3) ?? '';

      // 현재 턴 맞추기
      final expectedColor = colorStr == 'B' ? StoneColor.black : StoneColor.white;
      if (game.currentPlayer != expectedColor) {
        game.pass(); // 턴 맞추기 위해 패스
      }

      if (colStr.isEmpty || rowStr.isEmpty) {
        game.pass();
      } else {
        final col = colStr.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final row = rowStr.codeUnitAt(0) - 'a'.codeUnitAt(0);
        game.placeStone(row, col);
      }
    }

    return game;
  }
}
