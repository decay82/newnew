import 'dart:math';
import '../models/game_state.dart';
import 'mcts_node.dart';

/// MCTS 알고리즘 구현 클래스
class MCTSAlgorithm {
  /// 탐험 계수 (exploration constant)
  final double explorationConstant;

  /// 난수 생성기
  final Random _random;

  /// 시뮬레이션 통계
  int totalSimulations = 0;

  MCTSAlgorithm({
    this.explorationConstant = 1.414,
    int? seed,
  }) : _random = Random(seed);

  /// 주어진 게임 상태에서 최적의 수를 찾음
  Position? findBestMove(
    GameState state, {
    int timeLimitMs = 3000,
    int maxIterations = 100000,
  }) {
    if (state.isGameOver) return null;

    final validMoves = state.getSmartMoves();
    if (validMoves.isEmpty) return null;
    if (validMoves.length == 1) return validMoves.first;

    // 긴급한 수 먼저 확인 (즉각 승리/방어)
    final urgentMove = _findUrgentMove(state, validMoves);
    if (urgentMove != null) return urgentMove;

    // 루트 노드 생성
    final root = MCTSNode(state: state);

    // 시간 기반 탐색
    final stopwatch = Stopwatch()..start();
    int iterations = 0;

    while (stopwatch.elapsedMilliseconds < timeLimitMs &&
        iterations < maxIterations) {
      // 1. Selection (선택)
      MCTSNode node = _select(root);

      // 2. Expansion (확장)
      if (!node.isTerminal && !node.isFullyExpanded) {
        node = node.expand(_random);
      }

      // 3. Simulation (시뮬레이션)
      final result = _simulate(node.state);

      // 4. Backpropagation (역전파)
      node.backpropagate(result);

      iterations++;
    }

    stopwatch.stop();
    totalSimulations = iterations;

    return root.getBestMove();
  }

  /// 긴급한 수 찾기 (MCTS 전에 먼저 확인)
  Position? _findUrgentMove(GameState state, List<Position> moves) {
    final currentPlayer = state.currentPlayer;
    final opponent = currentPlayer == Player.black ? Player.white : Player.black;

    // 1. 즉각적인 승리 수 (5목 완성)
    for (final move in moves) {
      if (_wouldMakeFive(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 2. 상대방 5목 차단 (가장 중요한 방어!)
    for (final move in moves) {
      if (_wouldMakeFive(state.board, move, opponent)) {
        return move;
      }
    }

    // 3. 열린 4목 만들기
    for (final move in moves) {
      if (_wouldMakeOpenFour(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 4. 상대방 열린 4목 차단
    for (final move in moves) {
      if (_wouldMakeOpenFour(state.board, move, opponent)) {
        return move;
      }
    }

    // 5. 4목 만들기 (한쪽이라도 열린)
    for (final move in moves) {
      if (_wouldMakeFour(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 6. 상대방 4목 차단
    for (final move in moves) {
      if (_wouldMakeFour(state.board, move, opponent)) {
        return move;
      }
    }

    // 7. 열린 3목 만들기
    for (final move in moves) {
      if (_wouldMakeOpenThree(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 8. 상대방 열린 3목 차단
    for (final move in moves) {
      if (_wouldMakeOpenThree(state.board, move, opponent)) {
        return move;
      }
    }

    return null; // 긴급한 수 없음, MCTS로 탐색
  }

  /// Selection 단계: UCB를 사용하여 유망한 노드 선택
  MCTSNode _select(MCTSNode node) {
    while (!node.isTerminal) {
      if (!node.isFullyExpanded) {
        return node;
      }
      node = node.selectBestChild(explorationConstant: explorationConstant);
    }
    return node;
  }

  /// Simulation 단계: 향상된 플레이아웃
  Player _simulate(GameState state) {
    GameState current = state;
    int moveCount = 0;
    const maxMoves = 200;

    while (!current.isGameOver && moveCount < maxMoves) {
      final moves = current.getSmartMoves();
      if (moves.isEmpty) break;

      final bestMove = _findCriticalMove(current, moves);
      current = current.makeMove(bestMove);
      moveCount++;
    }

    return current.winner;
  }

  /// 시뮬레이션 중 중요한 수 찾기
  Position _findCriticalMove(GameState state, List<Position> moves) {
    final currentPlayer = state.currentPlayer;
    final opponent = currentPlayer == Player.black ? Player.white : Player.black;

    // 1. 즉각적인 승리 수 (5목)
    for (final move in moves) {
      if (_wouldMakeFive(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 2. 상대방 5목 차단
    for (final move in moves) {
      if (_wouldMakeFive(state.board, move, opponent)) {
        return move;
      }
    }

    // 3. 열린 4목 만들기
    for (final move in moves) {
      if (_wouldMakeOpenFour(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 4. 상대방 열린 4목 차단
    for (final move in moves) {
      if (_wouldMakeOpenFour(state.board, move, opponent)) {
        return move;
      }
    }

    // 5. 4목 만들기
    for (final move in moves) {
      if (_wouldMakeFour(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 6. 상대방 4목 차단
    for (final move in moves) {
      if (_wouldMakeFour(state.board, move, opponent)) {
        return move;
      }
    }

    // 7. 열린 3목 만들기
    for (final move in moves) {
      if (_wouldMakeOpenThree(state.board, move, currentPlayer)) {
        return move;
      }
    }

    // 8. 상대방 열린 3목 차단
    for (final move in moves) {
      if (_wouldMakeOpenThree(state.board, move, opponent)) {
        return move;
      }
    }

    // 9. 2목 연결 시도
    for (final move in moves) {
      if (_countLine(state.board, move, currentPlayer) >= 1) {
        return move;
      }
    }

    // 10. 가중치 기반 랜덤 선택
    return _weightedRandomMove(state, moves);
  }

  /// 5목을 완성하는지 확인 (연속 또는 점프 패턴 모두)
  /// 예: OOOO_, OOO_O, OO_OO, O_OOO, _OOOO
  bool _wouldMakeFive(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],  // 가로
      [1, 0],  // 세로
      [1, 1],  // 대각선 ↘
      [1, -1], // 대각선 ↙
    ];

    for (final dir in directions) {
      // pos 위치를 포함한 5칸 윈도우를 검사
      // pos가 윈도우의 0~4번째 위치에 올 수 있음
      for (int startOffset = -4; startOffset <= 0; startOffset++) {
        int count = 0;
        bool valid = true;

        for (int i = 0; i < 5; i++) {
          final nr = pos.row + dir[0] * (startOffset + i);
          final nc = pos.col + dir[1] * (startOffset + i);

          if (nr < 0 || nr >= GameState.boardSize ||
              nc < 0 || nc >= GameState.boardSize) {
            valid = false;
            break;
          }

          if (nr == pos.row && nc == pos.col) {
            count++; // 놓을 위치
          } else if (board[nr][nc] == player) {
            count++;
          } else if (board[nr][nc] != Player.none) {
            valid = false;
            break;
          }
        }

        if (valid && count >= 5) {
          return true;
        }
      }
    }
    return false;
  }

  /// 4목을 완성하는지 확인 (점프 패턴 포함)
  /// 예: OOO__, OO_O_, O_OO_, _OOO_, O__OO 등
  bool _wouldMakeFour(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final dir in directions) {
      // 5칸 윈도우에서 4개가 player이고 1개가 빈칸(pos)인 경우
      for (int startOffset = -4; startOffset <= 0; startOffset++) {
        int playerCount = 0;
        int emptyCount = 0;
        bool valid = true;
        bool includesPos = false;

        for (int i = 0; i < 5; i++) {
          final nr = pos.row + dir[0] * (startOffset + i);
          final nc = pos.col + dir[1] * (startOffset + i);

          if (nr < 0 || nr >= GameState.boardSize ||
              nc < 0 || nc >= GameState.boardSize) {
            valid = false;
            break;
          }

          if (nr == pos.row && nc == pos.col) {
            includesPos = true;
            playerCount++; // pos에 놓으면 player 돌이 됨
          } else if (board[nr][nc] == player) {
            playerCount++;
          } else if (board[nr][nc] == Player.none) {
            emptyCount++;
          } else {
            valid = false;
            break;
          }
        }

        // pos 포함, 4개 player, 윈도우 유효
        if (valid && includesPos && playerCount >= 4) {
          return true;
        }
      }
    }
    return false;
  }

  /// 열린 4목을 완성하는지 확인 (양쪽이 열린 4목)
  bool _wouldMakeOpenFour(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final dir in directions) {
      // 6칸 윈도우: _OOOO_ 형태 확인
      for (int startOffset = -5; startOffset <= 0; startOffset++) {
        int playerCount = 0;
        bool valid = true;
        bool includesPos = false;
        bool leftOpen = false;
        bool rightOpen = false;

        for (int i = 0; i < 6; i++) {
          final nr = pos.row + dir[0] * (startOffset + i);
          final nc = pos.col + dir[1] * (startOffset + i);

          if (nr < 0 || nr >= GameState.boardSize ||
              nc < 0 || nc >= GameState.boardSize) {
            valid = false;
            break;
          }

          if (i == 0) {
            // 첫 번째 칸은 빈칸이어야 함 (왼쪽 열림)
            if (board[nr][nc] == Player.none && !(nr == pos.row && nc == pos.col)) {
              leftOpen = true;
            } else if (nr == pos.row && nc == pos.col) {
              // pos가 첫 번째면 패턴 아님
              valid = false;
              break;
            } else {
              valid = false;
              break;
            }
          } else if (i == 5) {
            // 마지막 칸은 빈칸이어야 함 (오른쪽 열림)
            if (board[nr][nc] == Player.none && !(nr == pos.row && nc == pos.col)) {
              rightOpen = true;
            } else if (nr == pos.row && nc == pos.col) {
              valid = false;
              break;
            } else {
              valid = false;
              break;
            }
          } else {
            // 중간 4칸: player 또는 pos
            if (nr == pos.row && nc == pos.col) {
              includesPos = true;
              playerCount++;
            } else if (board[nr][nc] == player) {
              playerCount++;
            } else {
              valid = false;
              break;
            }
          }
        }

        if (valid && includesPos && playerCount == 4 && leftOpen && rightOpen) {
          return true;
        }
      }
    }
    return false;
  }

  /// 열린 3목을 완성하는지 확인 (양쪽이 열린 3목)
  /// _OOO_ 형태 (pos 포함 시 3개)
  bool _wouldMakeOpenThree(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final dir in directions) {
      // 5칸 윈도우: _OOO_ 형태 확인
      for (int startOffset = -4; startOffset <= 0; startOffset++) {
        int playerCount = 0;
        bool valid = true;
        bool includesPos = false;
        bool leftOpen = false;
        bool rightOpen = false;

        for (int i = 0; i < 5; i++) {
          final nr = pos.row + dir[0] * (startOffset + i);
          final nc = pos.col + dir[1] * (startOffset + i);

          if (nr < 0 || nr >= GameState.boardSize ||
              nc < 0 || nc >= GameState.boardSize) {
            valid = false;
            break;
          }

          if (i == 0) {
            // 첫 번째 칸은 빈칸이어야 함
            if (board[nr][nc] == Player.none && !(nr == pos.row && nc == pos.col)) {
              leftOpen = true;
            } else {
              valid = false;
              break;
            }
          } else if (i == 4) {
            // 마지막 칸은 빈칸이어야 함
            if (board[nr][nc] == Player.none && !(nr == pos.row && nc == pos.col)) {
              rightOpen = true;
            } else {
              valid = false;
              break;
            }
          } else {
            // 중간 3칸
            if (nr == pos.row && nc == pos.col) {
              includesPos = true;
              playerCount++;
            } else if (board[nr][nc] == player) {
              playerCount++;
            } else {
              valid = false;
              break;
            }
          }
        }

        if (valid && includesPos && playerCount == 3 && leftOpen && rightOpen) {
          return true;
        }
      }
    }
    return false;
  }

  /// 특정 위치에 돌을 놓았을 때 연결되는 돌 개수 (최대 방향, 연속만)
  int _countLine(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    int maxCount = 0;

    for (final dir in directions) {
      int count = 0;

      // 정방향
      for (int i = 1; i <= 4; i++) {
        final nr = pos.row + dir[0] * i;
        final nc = pos.col + dir[1] * i;
        if (nr < 0 || nr >= GameState.boardSize ||
            nc < 0 || nc >= GameState.boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      // 역방향
      for (int i = 1; i <= 4; i++) {
        final nr = pos.row - dir[0] * i;
        final nc = pos.col - dir[1] * i;
        if (nr < 0 || nr >= GameState.boardSize ||
            nc < 0 || nc >= GameState.boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      maxCount = max(maxCount, count);
    }

    return maxCount;
  }

  /// 가중치 기반 랜덤 선택 (중앙에 가까울수록 높은 가중치)
  Position _weightedRandomMove(GameState state, List<Position> moves) {
    if (moves.isEmpty) {
      return Position(GameState.boardSize ~/ 2, GameState.boardSize ~/ 2);
    }

    final center = GameState.boardSize ~/ 2;
    final weights = <double>[];
    double totalWeight = 0;

    for (final move in moves) {
      final distance = sqrt(
        pow(move.row - center, 2) + pow(move.col - center, 2),
      );
      final weight = 1.0 / (distance + 1);
      weights.add(weight);
      totalWeight += weight;
    }

    double random = _random.nextDouble() * totalWeight;
    for (int i = 0; i < moves.length; i++) {
      random -= weights[i];
      if (random <= 0) {
        return moves[i];
      }
    }

    return moves.last;
  }

  /// MCTS 결과 상세 정보 반환
  MCTSResult findBestMoveWithDetails(
    GameState state, {
    int timeLimitMs = 3000,
    int maxIterations = 100000,
  }) {
    if (state.isGameOver) {
      return MCTSResult(
        bestMove: null,
        iterations: 0,
        elapsedMs: 0,
        topMoves: [],
      );
    }

    final validMoves = state.getSmartMoves();
    if (validMoves.isEmpty) {
      return MCTSResult(
        bestMove: null,
        iterations: 0,
        elapsedMs: 0,
        topMoves: [],
      );
    }

    // 긴급한 수 먼저 확인
    final urgentMove = _findUrgentMove(state, validMoves);
    if (urgentMove != null) {
      return MCTSResult(
        bestMove: urgentMove,
        iterations: 1,
        elapsedMs: 0,
        topMoves: [MoveInfo(urgentMove, 1, 1.0)],
      );
    }

    if (validMoves.length == 1) {
      return MCTSResult(
        bestMove: validMoves.first,
        iterations: 1,
        elapsedMs: 0,
        topMoves: [MoveInfo(validMoves.first, 1, 1.0)],
      );
    }

    final root = MCTSNode(state: state);
    final stopwatch = Stopwatch()..start();
    int iterations = 0;

    while (stopwatch.elapsedMilliseconds < timeLimitMs &&
        iterations < maxIterations) {
      MCTSNode node = _select(root);

      if (!node.isTerminal && !node.isFullyExpanded) {
        node = node.expand(_random);
      }

      final result = _simulate(node.state);
      node.backpropagate(result);

      iterations++;
    }

    stopwatch.stop();

    final sortedChildren = List<MCTSNode>.from(root.children)
      ..sort((a, b) => b.visits.compareTo(a.visits));

    final topMoves = sortedChildren.take(5).map((child) {
      return MoveInfo(
        child.move!,
        child.visits,
        child.visits > 0 ? child.wins / child.visits : 0,
      );
    }).toList();

    return MCTSResult(
      bestMove: root.getBestMove(),
      iterations: iterations,
      elapsedMs: stopwatch.elapsedMilliseconds,
      topMoves: topMoves,
    );
  }
}

/// 라인 분석 결과
class _LineAnalysis {
  final int count;    // 연결된 돌 개수
  final int openEnds; // 열린 끝 개수 (0, 1, 2)

  _LineAnalysis(this.count, this.openEnds);
}

/// MCTS 결과를 담는 클래스
class MCTSResult {
  final Position? bestMove;
  final int iterations;
  final int elapsedMs;
  final List<MoveInfo> topMoves;

  MCTSResult({
    required this.bestMove,
    required this.iterations,
    required this.elapsedMs,
    required this.topMoves,
  });

  Map<String, dynamic> toJson() {
    return {
      'bestMove': bestMove != null
          ? {'row': bestMove!.row, 'col': bestMove!.col}
          : null,
      'iterations': iterations,
      'elapsedMs': elapsedMs,
      'topMoves': topMoves.map((m) => m.toJson()).toList(),
    };
  }

  factory MCTSResult.fromJson(Map<String, dynamic> json) {
    final moveData = json['bestMove'];
    return MCTSResult(
      bestMove: moveData != null
          ? Position(moveData['row'] as int, moveData['col'] as int)
          : null,
      iterations: json['iterations'] as int,
      elapsedMs: json['elapsedMs'] as int,
      topMoves: (json['topMoves'] as List)
          .map((m) => MoveInfo.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 개별 수의 정보
class MoveInfo {
  final Position move;
  final int visits;
  final double winRate;

  MoveInfo(this.move, this.visits, this.winRate);

  Map<String, dynamic> toJson() {
    return {
      'move': {'row': move.row, 'col': move.col},
      'visits': visits,
      'winRate': winRate,
    };
  }

  factory MoveInfo.fromJson(Map<String, dynamic> json) {
    final moveData = json['move'] as Map<String, dynamic>;
    return MoveInfo(
      Position(moveData['row'] as int, moveData['col'] as int),
      json['visits'] as int,
      (json['winRate'] as num).toDouble(),
    );
  }
}
