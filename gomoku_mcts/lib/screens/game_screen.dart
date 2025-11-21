import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../widgets/game_board.dart';
import '../ai/mcts_algorithm.dart';
import '../ai/mcts_isolate.dart';

/// 오목 게임 메인 화면
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  Position? _hintPosition;
  Position? _lastMove;
  bool _isCalculatingHint = false;
  int _hintTimeMs = 3000; // 힌트 계산 시간 (기본 3초)

  // MCTS 결과 정보 (디버그/표시용)
  int _lastIterations = 0;
  int _lastElapsedMs = 0;
  List<MoveInfo> _topMoves = [];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _gameState = GameState.initial();
      _hintPosition = null;
      _lastMove = null;
      _isCalculatingHint = false;
      _lastIterations = 0;
      _lastElapsedMs = 0;
      _topMoves = [];
    });
  }

  Future<void> _makeMove(Position pos) async {
    if (_gameState.isGameOver || _isCalculatingHint) return;
    if (!_gameState.isValidMove(pos)) return;

    setState(() {
      _gameState = _gameState.makeMove(pos);
      _lastMove = pos;
      _hintPosition = null;
      _topMoves = [];
    });

    // 게임 종료 체크
    if (_gameState.isGameOver) {
      _showGameOverDialog();
    }
  }

  Future<void> _requestHint() async {
    if (_gameState.isGameOver || _isCalculatingHint) return;

    setState(() {
      _isCalculatingHint = true;
      _hintPosition = null;
    });

    try {
      // Isolate를 사용하여 비동기로 MCTS 실행
      final response = await MCTSIsolateManager.findBestMoveAsync(
        _gameState,
        timeLimitMs: _hintTimeMs,
      );

      if (mounted) {
        setState(() {
          _hintPosition = response.bestMove;
          _lastIterations = response.iterations;
          _lastElapsedMs = response.elapsedMs;
          _topMoves = response.topMoves;
          _isCalculatingHint = false;
        });
      }
    } catch (e) {
      // 에러 발생 시 동기 방식으로 폴백
      debugPrint('Isolate error, falling back to sync: $e');

      final mcts = MCTSAlgorithm();
      final result = mcts.findBestMoveWithDetails(
        _gameState,
        timeLimitMs: _hintTimeMs,
      );

      if (mounted) {
        setState(() {
          _hintPosition = result.bestMove;
          _lastIterations = result.iterations;
          _lastElapsedMs = result.elapsedMs;
          _topMoves = result.topMoves;
          _isCalculatingHint = false;
        });
      }
    }
  }

  void _showGameOverDialog() {
    final winner = _gameState.winner;
    String message;

    if (winner == Player.black) {
      message = '흑돌 승리!';
    } else if (winner == Player.white) {
      message = '백돌 승리!';
    } else {
      message = '무승부!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('게임 종료'),
        content: Text(
          message,
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text('새 게임'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오목 with MCTS AI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: '새 게임',
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보 표시
          _buildGameInfo(),

          // 오목판
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: GameBoard(
                    gameState: _gameState,
                    hintPosition: _hintPosition,
                    lastMove: _lastMove,
                    onTap: _makeMove,
                  ),
                ),
              ),
            ),
          ),

          // 힌트 버튼 및 설정
          _buildControlPanel(),

          // MCTS 결과 정보
          if (_topMoves.isNotEmpty) _buildMCTSInfo(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 현재 차례 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _gameState.currentPlayer == Player.black
                  ? Colors.black
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey),
            ),
            child: Text(
              _gameState.currentPlayer == Player.black ? '흑돌 차례' : '백돌 차례',
              style: TextStyle(
                color: _gameState.currentPlayer == Player.black
                    ? Colors.white
                    : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (_gameState.isGameOver)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '게임 종료',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 힌트 시간 설정
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('힌트 계산 시간: '),
              DropdownButton<int>(
                value: _hintTimeMs,
                items: const [
                  DropdownMenuItem(value: 1000, child: Text('1초')),
                  DropdownMenuItem(value: 2000, child: Text('2초')),
                  DropdownMenuItem(value: 3000, child: Text('3초')),
                  DropdownMenuItem(value: 5000, child: Text('5초')),
                  DropdownMenuItem(value: 10000, child: Text('10초')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _hintTimeMs = value;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 힌트 버튼
          ElevatedButton.icon(
            onPressed:
                _isCalculatingHint || _gameState.isGameOver ? null : _requestHint,
            icon: _isCalculatingHint
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
            label: Text(_isCalculatingHint ? 'AI 계산 중...' : '힌트 받기'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMCTSInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MCTS 결과: $_lastIterations회 시뮬레이션 (${_lastElapsedMs}ms)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('상위 추천 수:', style: TextStyle(fontWeight: FontWeight.w500)),
          ...List.generate(
            _topMoves.length > 3 ? 3 : _topMoves.length,
            (index) {
              final move = _topMoves[index];
              final colLetter = String.fromCharCode(65 + move.move.col);
              final rowNum = GameState.boardSize - move.move.row;
              final winRate = (move.winRate * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '${index + 1}. $colLetter$rowNum - 방문: ${move.visits}회, 승률: $winRate%',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
