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
  ///
  /// [state]: 현재 게임 상태
  /// [timeLimitMs]: 탐색 시간 제한 (밀리초), 기본 3초
  /// [maxIterations]: 최대 반복 횟수 (시간과 함께 사용, 둘 중 하나가 먼저 도달하면 종료)
  Position? findBestMove(
    GameState state, {
    int timeLimitMs = 3000,
    int maxIterations = 100000,
  }) {
    if (state.isGameOver) return null;

    final validMoves = state.getSmartMoves();
    if (validMoves.isEmpty) return null;
    if (validMoves.length == 1) return validMoves.first;

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

    // 디버그 정보 출력 (개발 시 유용)
    // print('MCTS completed: $iterations iterations in ${stopwatch.elapsedMilliseconds}ms');
    // print(root.getTopChildrenInfo());

    // 가장 많이 방문된 수 반환
    return root.getBestMove();
  }

  /// Selection 단계: UCB를 사용하여 유망한 노드 선택
  MCTSNode _select(MCTSNode node) {
    while (!node.isTerminal) {
      if (!node.isFullyExpanded) {
        return node; // 확장되지 않은 노드 반환
      }
      // 완전히 확장된 경우, UCB가 가장 높은 자식 선택
      node = node.selectBestChild(explorationConstant: explorationConstant);
    }
    return node;
  }

  /// Simulation 단계: 무작위 플레이아웃
  Player _simulate(GameState state) {
    GameState current = state;
    int moveCount = 0;
    const maxMoves = 200; // 무한 루프 방지

    while (!current.isGameOver && moveCount < maxMoves) {
      final moves = current.getSmartMoves();
      if (moves.isEmpty) break;

      // 향상된 시뮬레이션: 즉각적인 승리/방어 수 확인
      final bestMove = _findCriticalMove(current, moves);
      current = current.makeMove(bestMove);
      moveCount++;
    }

    return current.winner;
  }

  /// 즉각적인 승리 또는 상대방의 승리를 막는 수 찾기
  Position _findCriticalMove(GameState state, List<Position> moves) {
    final currentPlayer = state.currentPlayer;
    final opponent = currentPlayer == Player.black
        ? Player.white
        : Player.black;

    // 1. 즉각적인 승리 수 찾기
    for (final move in moves) {
      final newState = state.makeMove(move);
      if (newState.winner == currentPlayer) {
        return move;
      }
    }

    // 2. 상대방의 즉각적인 승리 차단
    // 임시로 상대방 턴으로 바꿔서 테스트
    for (final move in moves) {
      final tempBoard = state.board
          .map((row) => List<Player>.from(row))
          .toList();
      tempBoard[move.row][move.col] = opponent;
      final tempState = GameState(
        board: tempBoard,
        currentPlayer: currentPlayer,
      );
      // 상대방이 여기에 두면 이기는지 확인
      if (_wouldWin(tempBoard, move, opponent)) {
        return move; // 방어
      }
    }

    // 3. 4목 만들기 시도
    for (final move in moves) {
      if (_countsInLine(state.board, move, currentPlayer) >= 3) {
        return move;
      }
    }

    // 4. 상대방의 4목 차단
    for (final move in moves) {
      if (_countsInLine(state.board, move, opponent) >= 3) {
        return move;
      }
    }

    // 5. 랜덤 선택 (가중치 적용)
    return _weightedRandomMove(state, moves);
  }

  /// 특정 위치에 두면 승리하는지 확인
  bool _wouldWin(List<List<Player>> board, Position pos, Player player) {
    const directions = [
      [0, 1],  // 가로
      [1, 0],  // 세로
      [1, 1],  // 대각선 ↘
      [1, -1], // 대각선 ↙
    ];

    for (final dir in directions) {
      int count = 1;

      // 정방향
      for (int i = 1; i < 5; i++) {
        final nr = pos.row + dir[0] * i;
        final nc = pos.col + dir[1] * i;
        if (nr < 0 || nr >= GameState.boardSize ||
            nc < 0 || nc >= GameState.boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      // 역방향
      for (int i = 1; i < 5; i++) {
        final nr = pos.row - dir[0] * i;
        final nc = pos.col - dir[1] * i;
        if (nr < 0 || nr >= GameState.boardSize ||
            nc < 0 || nc >= GameState.boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      if (count >= 5) return true;
    }
    return false;
  }

  /// 특정 위치 주변의 연속된 돌 개수 계산
  int _countsInLine(List<List<Player>> board, Position pos, Player player) {
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
      for (int i = 1; i < 5; i++) {
        final nr = pos.row + dir[0] * i;
        final nc = pos.col + dir[1] * i;
        if (nr < 0 || nr >= GameState.boardSize ||
            nc < 0 || nc >= GameState.boardSize) break;
        if (board[nr][nc] != player) break;
        count++;
      }

      // 역방향
      for (int i = 1; i < 5; i++) {
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
      // 중앙에 가까울수록 높은 가중치
      final distance = sqrt(
        pow(move.row - center, 2) + pow(move.col - center, 2),
      );
      final weight = 1.0 / (distance + 1);
      weights.add(weight);
      totalWeight += weight;
    }

    // 가중치 기반 랜덤 선택
    double random = _random.nextDouble() * totalWeight;
    for (int i = 0; i < moves.length; i++) {
      random -= weights[i];
      if (random <= 0) {
        return moves[i];
      }
    }

    return moves.last;
  }

  /// MCTS 결과 상세 정보 반환 (디버깅/UI 표시용)
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

    // 상위 수들의 정보 수집
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
