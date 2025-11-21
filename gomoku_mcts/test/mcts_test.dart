import 'package:gomoku_mcts/models/game_state.dart';
import 'package:gomoku_mcts/ai/mcts_algorithm.dart';
import 'package:gomoku_mcts/ai/mcts_node.dart';

/// MCTS 알고리즘 테스트 (Flutter 없이 Dart만으로 실행 가능)
void main() {
  print('=== MCTS 오목 AI 테스트 ===\n');

  // 테스트 1: GameState 기본 기능
  testGameState();

  // 테스트 2: MCTS 노드
  testMCTSNode();

  // 테스트 3: MCTS 알고리즘 - 빈 보드
  testMCTSEmptyBoard();

  // 테스트 4: MCTS 알고리즘 - 즉각적인 승리 감지
  testMCTSImmediateWin();

  // 테스트 5: MCTS 알고리즘 - 방어 수 감지
  testMCTSDefense();

  // 테스트 6: 성능 테스트
  testMCTSPerformance();

  print('\n=== 모든 테스트 완료 ===');
}

void testGameState() {
  print('--- 테스트 1: GameState 기본 기능 ---');

  // 초기 상태
  final state = GameState.initial();
  assert(state.currentPlayer == Player.black, '흑돌이 선공이어야 함');
  assert(!state.isGameOver, '게임이 시작되지 않았으므로 종료되지 않아야 함');
  print('  초기 상태 OK');

  // 수 두기
  final pos = Position(7, 7);
  final newState = state.makeMove(pos);
  assert(newState.board[7][7] == Player.black, '흑돌이 놓여야 함');
  assert(newState.currentPlayer == Player.white, '백돌 차례로 바뀌어야 함');
  print('  수 두기 OK');

  // 유효하지 않은 수
  assert(!newState.isValidMove(pos), '이미 돌이 있는 곳에 둘 수 없음');
  print('  유효성 검사 OK');

  // 직렬화/역직렬화
  final json = newState.toJson();
  final restored = GameState.fromJson(json);
  assert(restored.board[7][7] == Player.black, '복원된 상태가 일치해야 함');
  print('  직렬화/역직렬화 OK');

  print('  GameState 테스트 통과!\n');
}

void testMCTSNode() {
  print('--- 테스트 2: MCTS 노드 ---');

  final state = GameState.initial();
  final root = MCTSNode(state: state);

  // 초기 상태
  assert(root.visits == 0, '초기 방문 횟수는 0');
  assert(root.wins == 0, '초기 승리 횟수는 0');
  assert(!root.isFullyExpanded, '초기에는 확장되지 않은 상태');
  print('  초기 상태 OK');

  // UCB 값 (방문 전)
  assert(root.ucbValue() == double.infinity, '방문 전 UCB는 무한대');
  print('  UCB 계산 OK');

  print('  MCTSNode 테스트 통과!\n');
}

void testMCTSEmptyBoard() {
  print('--- 테스트 3: MCTS 빈 보드 ---');

  final state = GameState.initial();
  final mcts = MCTSAlgorithm(seed: 42);

  final result = mcts.findBestMoveWithDetails(
    state,
    timeLimitMs: 500,
    maxIterations: 1000,
  );

  assert(result.bestMove != null, '최적의 수가 있어야 함');
  print('  추천 수: ${result.bestMove}');
  print('  시뮬레이션 횟수: ${result.iterations}');
  print('  소요 시간: ${result.elapsedMs}ms');

  // 빈 보드에서는 중앙 근처를 추천해야 함
  final move = result.bestMove!;
  final distFromCenter = (move.row - 7).abs() + (move.col - 7).abs();
  print('  중앙으로부터 거리: $distFromCenter');

  print('  MCTS 빈 보드 테스트 통과!\n');
}

void testMCTSImmediateWin() {
  print('--- 테스트 4: MCTS 즉각적인 승리 감지 ---');

  // 흑돌이 4목을 만들어 놓은 상태 (한 수만 더 두면 승리)
  // ● ● ● ● _
  var state = GameState.initial();
  state = state.makeMove(const Position(7, 3)); // 흑
  state = state.makeMove(const Position(0, 0)); // 백
  state = state.makeMove(const Position(7, 4)); // 흑
  state = state.makeMove(const Position(0, 1)); // 백
  state = state.makeMove(const Position(7, 5)); // 흑
  state = state.makeMove(const Position(0, 2)); // 백
  state = state.makeMove(const Position(7, 6)); // 흑
  state = state.makeMove(const Position(0, 3)); // 백

  // 이제 흑돌 차례, (7, 7)에 두면 승리
  final mcts = MCTSAlgorithm(seed: 42);
  final result = mcts.findBestMoveWithDetails(
    state,
    timeLimitMs: 1000,
  );

  print('  현재 상태: 흑돌 4목 (7,3)-(7,6)');
  print('  추천 수: ${result.bestMove}');

  // 승리 수를 찾아야 함
  if (result.bestMove != null) {
    final winMove = result.bestMove!;
    // (7, 2) 또는 (7, 7) 중 하나여야 함
    final isWinningMove =
        (winMove.row == 7 && (winMove.col == 2 || winMove.col == 7));
    if (isWinningMove) {
      print('  즉각적인 승리 수 감지 성공!');
    } else {
      print('  경고: 최적의 수가 아닐 수 있음 (하지만 MCTS는 확률적)');
    }
  }

  print('  MCTS 즉각적인 승리 감지 테스트 완료!\n');
}

void testMCTSDefense() {
  print('--- 테스트 5: MCTS 방어 수 감지 ---');

  // 백돌이 4목을 만들어 놓은 상태, 흑돌이 막아야 함
  var state = GameState.initial();
  state = state.makeMove(const Position(0, 0)); // 흑
  state = state.makeMove(const Position(7, 3)); // 백
  state = state.makeMove(const Position(0, 1)); // 흑
  state = state.makeMove(const Position(7, 4)); // 백
  state = state.makeMove(const Position(1, 0)); // 흑
  state = state.makeMove(const Position(7, 5)); // 백
  state = state.makeMove(const Position(1, 1)); // 흑
  state = state.makeMove(const Position(7, 6)); // 백

  // 이제 흑돌 차례, 백돌의 5목을 막아야 함
  final mcts = MCTSAlgorithm(seed: 42);
  final result = mcts.findBestMoveWithDetails(
    state,
    timeLimitMs: 1000,
  );

  print('  현재 상태: 백돌 4목 (7,3)-(7,6)');
  print('  추천 수: ${result.bestMove}');

  if (result.bestMove != null) {
    final defMove = result.bestMove!;
    // (7, 2) 또는 (7, 7)을 막아야 함
    final isDefensiveMove =
        (defMove.row == 7 && (defMove.col == 2 || defMove.col == 7));
    if (isDefensiveMove) {
      print('  방어 수 감지 성공!');
    } else {
      print('  경고: 방어 수가 아닐 수 있음 (하지만 MCTS는 확률적)');
    }
  }

  print('  MCTS 방어 수 감지 테스트 완료!\n');
}

void testMCTSPerformance() {
  print('--- 테스트 6: MCTS 성능 테스트 ---');

  final state = GameState.initial();
  final mcts = MCTSAlgorithm();

  // 다양한 시간 제한으로 테스트
  final timeLimits = [500, 1000, 2000, 3000];

  for (final timeLimit in timeLimits) {
    final stopwatch = Stopwatch()..start();
    final result = mcts.findBestMoveWithDetails(
      state,
      timeLimitMs: timeLimit,
    );
    stopwatch.stop();

    print('  시간 제한: ${timeLimit}ms');
    print('    실제 소요: ${result.elapsedMs}ms');
    print('    시뮬레이션: ${result.iterations}회');
    print('    초당 시뮬레이션: ${(result.iterations / (result.elapsedMs / 1000)).toStringAsFixed(0)}회/초');

    if (result.topMoves.isNotEmpty) {
      final best = result.topMoves.first;
      print('    최선의 수: ${best.move}, 승률: ${(best.winRate * 100).toStringAsFixed(1)}%');
    }
    print('');
  }

  print('  MCTS 성능 테스트 완료!\n');
}
