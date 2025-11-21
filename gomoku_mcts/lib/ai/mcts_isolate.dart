import 'dart:isolate';
import '../models/game_state.dart';
import 'mcts_algorithm.dart';

/// Isolate에서 실행할 MCTS 요청 메시지
class MCTSRequest {
  final GameState state;
  final int timeLimitMs;
  final int maxIterations;
  final double explorationConstant;
  final SendPort responsePort;

  MCTSRequest({
    required this.state,
    required this.responsePort,
    this.timeLimitMs = 3000,
    this.maxIterations = 100000,
    this.explorationConstant = 1.414,
  });

  /// Isolate 전송을 위한 직렬화
  Map<String, dynamic> toJson() {
    return {
      'state': state.toJson(),
      'timeLimitMs': timeLimitMs,
      'maxIterations': maxIterations,
      'explorationConstant': explorationConstant,
    };
  }

  /// Isolate에서 역직렬화
  factory MCTSRequest.fromJson(
    Map<String, dynamic> json,
    SendPort responsePort,
  ) {
    return MCTSRequest(
      state: GameState.fromJson(json['state'] as Map<String, dynamic>),
      timeLimitMs: json['timeLimitMs'] as int,
      maxIterations: json['maxIterations'] as int,
      explorationConstant: (json['explorationConstant'] as num).toDouble(),
      responsePort: responsePort,
    );
  }
}

/// Isolate에서 반환할 MCTS 응답 메시지
class MCTSResponse {
  final Position? bestMove;
  final int iterations;
  final int elapsedMs;
  final List<MoveInfo> topMoves;
  final String? error;

  MCTSResponse({
    this.bestMove,
    this.iterations = 0,
    this.elapsedMs = 0,
    this.topMoves = const [],
    this.error,
  });

  bool get isSuccess => error == null;

  Map<String, dynamic> toJson() {
    return {
      'bestMove': bestMove != null
          ? {'row': bestMove!.row, 'col': bestMove!.col}
          : null,
      'iterations': iterations,
      'elapsedMs': elapsedMs,
      'topMoves': topMoves.map((m) => m.toJson()).toList(),
      'error': error,
    };
  }

  factory MCTSResponse.fromJson(Map<String, dynamic> json) {
    final moveData = json['bestMove'];
    return MCTSResponse(
      bestMove: moveData != null
          ? Position(moveData['row'] as int, moveData['col'] as int)
          : null,
      iterations: json['iterations'] as int,
      elapsedMs: json['elapsedMs'] as int,
      topMoves: (json['topMoves'] as List)
          .map((m) => MoveInfo.fromJson(m as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );
  }
}

/// Isolate 진입점 함수 (최상위 함수여야 함)
void _mctsIsolateEntryPoint(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final requestJson = args[1] as Map<String, dynamic>;
  final timeLimitMs = args[2] as int;
  final maxIterations = args[3] as int;
  final explorationConstant = args[4] as double;

  try {
    final state = GameState.fromJson(requestJson);

    final mcts = MCTSAlgorithm(explorationConstant: explorationConstant);
    final result = mcts.findBestMoveWithDetails(
      state,
      timeLimitMs: timeLimitMs,
      maxIterations: maxIterations,
    );

    final response = MCTSResponse(
      bestMove: result.bestMove,
      iterations: result.iterations,
      elapsedMs: result.elapsedMs,
      topMoves: result.topMoves,
    );

    sendPort.send(response.toJson());
  } catch (e, stackTrace) {
    final response = MCTSResponse(
      error: 'MCTS Error: $e\n$stackTrace',
    );
    sendPort.send(response.toJson());
  }
}

/// MCTS Isolate 관리 클래스
/// Flutter UI 스레드에서 사용
class MCTSIsolateManager {
  /// 비동기로 MCTS를 실행하고 최적의 수를 반환
  ///
  /// UI 스레드가 블로킹되지 않도록 별도 Isolate에서 실행
  static Future<MCTSResponse> findBestMoveAsync(
    GameState state, {
    int timeLimitMs = 3000,
    int maxIterations = 100000,
    double explorationConstant = 1.414,
  }) async {
    final receivePort = ReceivePort();

    try {
      // Isolate 생성 및 실행
      await Isolate.spawn(
        _mctsIsolateEntryPoint,
        [
          receivePort.sendPort,
          state.toJson(),
          timeLimitMs,
          maxIterations,
          explorationConstant,
        ],
      );

      // 결과 대기
      final responseJson = await receivePort.first as Map<String, dynamic>;
      return MCTSResponse.fromJson(responseJson);
    } catch (e) {
      return MCTSResponse(error: 'Isolate Error: $e');
    } finally {
      receivePort.close();
    }
  }

  /// compute 함수를 사용한 간편한 버전 (Flutter의 compute 함수와 유사)
  static Future<Position?> computeBestMove(
    GameState state, {
    int timeLimitMs = 3000,
  }) async {
    final response = await findBestMoveAsync(
      state,
      timeLimitMs: timeLimitMs,
    );
    return response.bestMove;
  }
}

/// Flutter의 compute 함수와 함께 사용할 수 있는 래퍼
/// compute 함수는 Isolate를 더 쉽게 사용할 수 있게 해줌
class MCTSComputeParams {
  final Map<String, dynamic> stateJson;
  final int timeLimitMs;
  final int maxIterations;
  final double explorationConstant;

  MCTSComputeParams({
    required this.stateJson,
    this.timeLimitMs = 3000,
    this.maxIterations = 100000,
    this.explorationConstant = 1.414,
  });
}

/// compute 함수에서 호출할 정적 함수
Map<String, dynamic> computeMCTS(MCTSComputeParams params) {
  try {
    final state = GameState.fromJson(params.stateJson);
    final mcts = MCTSAlgorithm(explorationConstant: params.explorationConstant);
    final result = mcts.findBestMoveWithDetails(
      state,
      timeLimitMs: params.timeLimitMs,
      maxIterations: params.maxIterations,
    );

    return MCTSResponse(
      bestMove: result.bestMove,
      iterations: result.iterations,
      elapsedMs: result.elapsedMs,
      topMoves: result.topMoves,
    ).toJson();
  } catch (e) {
    return MCTSResponse(error: 'Compute Error: $e').toJson();
  }
}
