import 'dart:math';
import '../models/game_state.dart';

/// MCTS 트리의 노드를 나타내는 클래스
class MCTSNode {
  /// 이 노드의 게임 상태
  final GameState state;

  /// 이 노드에 도달하게 한 착수 (루트 노드는 null)
  final Position? move;

  /// 부모 노드
  final MCTSNode? parent;

  /// 자식 노드들
  final List<MCTSNode> children = [];

  /// 아직 확장되지 않은 가능한 수들
  List<Position> untriedMoves;

  /// 방문 횟수 (N_i)
  int visits = 0;

  /// 승리 횟수 (W_i) - 이 노드의 플레이어 관점에서
  double wins = 0.0;

  MCTSNode({
    required this.state,
    this.move,
    this.parent,
  }) : untriedMoves = state.getSmartMoves();

  /// 이 노드가 완전히 확장되었는지 (모든 가능한 수가 자식 노드로 존재)
  bool get isFullyExpanded => untriedMoves.isEmpty;

  /// 이 노드가 종단 노드인지 (게임 종료)
  bool get isTerminal => state.isGameOver;

  /// UCB1 값 계산
  /// UCB = W_i / N_i + c * sqrt(ln(N_p) / N_i)
  ///
  /// [explorationConstant]: 탐험 계수 (c), 기본값 sqrt(2) ≈ 1.414
  double ucbValue({double explorationConstant = 1.414}) {
    if (visits == 0) {
      return double.infinity; // 방문하지 않은 노드는 최우선 탐색
    }
    if (parent == null) {
      return 0;
    }

    // 승률 (exploitation term)
    final exploitation = wins / visits;

    // 탐험 항 (exploration term)
    final exploration = explorationConstant *
        sqrt(log(parent!.visits) / visits);

    return exploitation + exploration;
  }

  /// UCB 값이 가장 높은 자식 노드 선택 (Selection 단계)
  MCTSNode selectBestChild({double explorationConstant = 1.414}) {
    MCTSNode? bestChild;
    double bestValue = double.negativeInfinity;

    for (final child in children) {
      final ucb = child.ucbValue(explorationConstant: explorationConstant);
      if (ucb > bestValue) {
        bestValue = ucb;
        bestChild = child;
      }
    }

    return bestChild!;
  }

  /// 새로운 자식 노드 확장 (Expansion 단계)
  MCTSNode expand(Random random) {
    // 확장되지 않은 수 중 하나를 랜덤하게 선택
    final index = random.nextInt(untriedMoves.length);
    final move = untriedMoves.removeAt(index);

    // 해당 수를 둔 새로운 게임 상태 생성
    final newState = state.makeMove(move);

    // 새로운 자식 노드 생성
    final childNode = MCTSNode(
      state: newState,
      move: move,
      parent: this,
    );

    children.add(childNode);
    return childNode;
  }

  /// 역전파 (Backpropagation 단계)
  /// [result]: 시뮬레이션 결과 (승리한 플레이어)
  void backpropagate(Player result) {
    MCTSNode? node = this;

    while (node != null) {
      node.visits++;

      // 승리 계산: 이 노드의 "이전 차례" 플레이어가 승리했으면 승리로 카운트
      // (노드는 해당 수를 둔 후의 상태이므로, 부모의 currentPlayer가 이 수를 둔 플레이어)
      if (node.parent != null) {
        final playerWhoMoved = node.parent!.state.currentPlayer;
        if (result == playerWhoMoved) {
          node.wins += 1.0;
        } else if (result == Player.none) {
          // 무승부인 경우 0.5점
          node.wins += 0.5;
        }
        // 패배한 경우 0점 (이미 0이므로 아무것도 추가하지 않음)
      }

      node = node.parent;
    }
  }

  /// 가장 많이 방문된 자식 노드의 수 반환 (최종 힌트 결정)
  Position? getBestMove() {
    if (children.isEmpty) return null;

    MCTSNode? bestChild;
    int maxVisits = -1;

    for (final child in children) {
      if (child.visits > maxVisits) {
        maxVisits = child.visits;
        bestChild = child;
      }
    }

    return bestChild?.move;
  }

  /// 가장 높은 승률을 가진 자식 노드의 수 반환 (대안적 힌트 결정)
  Position? getBestMoveByWinRate() {
    if (children.isEmpty) return null;

    MCTSNode? bestChild;
    double bestWinRate = -1;

    for (final child in children) {
      if (child.visits > 0) {
        final winRate = child.wins / child.visits;
        if (winRate > bestWinRate) {
          bestWinRate = winRate;
          bestChild = child;
        }
      }
    }

    return bestChild?.move;
  }

  /// 디버깅용: 상위 N개 자식 노드 정보 출력
  String getTopChildrenInfo({int topN = 5}) {
    final sortedChildren = List<MCTSNode>.from(children)
      ..sort((a, b) => b.visits.compareTo(a.visits));

    final buffer = StringBuffer();
    buffer.writeln('Top $topN moves:');

    for (int i = 0; i < min(topN, sortedChildren.length); i++) {
      final child = sortedChildren[i];
      final winRate = child.visits > 0
          ? (child.wins / child.visits * 100).toStringAsFixed(1)
          : '0.0';
      buffer.writeln(
          '  ${i + 1}. ${child.move} - Visits: ${child.visits}, '
          'Win Rate: $winRate%');
    }

    return buffer.toString();
  }
}
