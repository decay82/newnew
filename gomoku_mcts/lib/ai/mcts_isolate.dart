import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'mcts_algorithm.dart';

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

/// Flutter의 compute 함수와 함께 사용할 수 있는 래퍼
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
MCTSResponse _computeMCTS(MCTSComputeParams params) {
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
    );
  } catch (e) {
    return MCTSResponse(error: 'Compute Error: $e');
  }
}

/// MCTS 관리 클래스 - 웹/네이티브 모두 지원
class MCTSIsolateManager {
  /// 비동기로 MCTS를 실행하고 최적의 수를 반환
  ///
  /// - 네이티브(iOS, Android, Desktop): Flutter의 compute 함수 사용 (별도 Isolate)
  /// - 웹: 메인 스레드에서 실행 (Future.delayed로 UI 블로킹 최소화)
  static Future<MCTSResponse> findBestMoveAsync(
    GameState state, {
    int timeLimitMs = 3000,
    int maxIterations = 100000,
    double explorationConstant = 1.414,
  }) async {
    final params = MCTSComputeParams(
      stateJson: state.toJson(),
      timeLimitMs: timeLimitMs,
      maxIterations: maxIterations,
      explorationConstant: explorationConstant,
    );

    try {
      if (kIsWeb) {
        // 웹에서는 compute를 사용할 수 없으므로 메인 스레드에서 실행
        // Future.delayed를 사용하여 UI가 한 프레임 업데이트될 시간을 줌
        await Future.delayed(const Duration(milliseconds: 50));
        return _computeMCTS(params);
      } else {
        // 네이티브에서는 compute 함수 사용 (별도 Isolate에서 실행)
        return await compute(_computeMCTS, params);
      }
    } catch (e) {
      // compute 실패 시 폴백
      debugPrint('Compute failed, running on main thread: $e');
      return _computeMCTS(params);
    }
  }

  /// 간편한 버전 - 최적의 수만 반환
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
