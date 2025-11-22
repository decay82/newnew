import 'package:flutter/material.dart';
import '../models/go_game.dart';
import '../models/stone.dart';
import '../models/api_models.dart';
import '../widgets/go_board.dart';
import '../services/api_service.dart';

/// AI 대국 화면
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GoGame _game;
  final _apiService = ApiService();

  bool _isLoading = false;
  RecommendedMove? _bestMove;
  RecommendedMove? _styleMove;
  String? _error;
  bool _showRecommendations = true;

  @override
  void initState() {
    super.initState();
    _game = GoGame(boardSize: 19);
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  void _onBoardTap(int row, int col) {
    if (_game.gameEnded) return;

    final result = _game.placeStone(row, col);

    setState(() {
      _bestMove = null;
      _styleMove = null;
      _error = null;
    });

    switch (result) {
      case PlaceResult.success:
        // 착수 성공 - 추천 수 요청
        if (_showRecommendations) {
          _getRecommendations();
        }
        break;
      case PlaceResult.occupied:
        _showMessage('이미 돌이 있는 곳입니다');
        break;
      case PlaceResult.suicide:
        _showMessage('자충수입니다 (착수 금지)');
        break;
      case PlaceResult.ko:
        _showMessage('패입니다 (착수 금지)');
        break;
      case PlaceResult.gameEnded:
        _showMessage('게임이 종료되었습니다');
        break;
    }
  }

  Future<void> _getRecommendations() async {
    if (_game.moveCount == 0) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.getNextMove('user123', _game);
      setState(() {
        _bestMove = result.bestMove;
        _styleMove = result.styleMove;
      });
    } catch (e) {
      setState(() => _error = '추천 수 요청 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _pass() {
    _game.pass();
    setState(() {
      _bestMove = null;
      _styleMove = null;
    });
    if (_game.gameEnded) {
      _showGameEndDialog();
    }
  }

  void _undo() {
    if (_game.undo()) {
      setState(() {
        _bestMove = null;
        _styleMove = null;
      });
    }
  }

  void _reset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 게임'),
        content: const Text('현재 게임을 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _game.reset();
                _bestMove = null;
                _styleMove = null;
                _error = null;
              });
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showGameEndDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게임 종료'),
        content: Text(
          '흑 잡은 돌: ${_game.blackCaptures}\n백 잡은 돌: ${_game.whiteCaptures}\n\n'
          '(계가 기능은 추후 추가 예정)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Position? get _lastMovePosition {
    if (_game.moves.isEmpty) return null;
    final lastMove = _game.moves.last;
    return lastMove.position;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 대국'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _showRecommendations ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() => _showRecommendations = !_showRecommendations);
            },
            tooltip: '추천 수 표시',
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPlayerInfo('흑', StoneColor.black, _game.blackCaptures),
                Column(
                  children: [
                    Text(
                      '${_game.moveCount}수',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _game.gameEnded ? '종료' : '${_game.currentPlayer} 차례',
                      style: TextStyle(
                        color: _game.gameEnded ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                _buildPlayerInfo('백', StoneColor.white, _game.whiteCaptures),
              ],
            ),
          ),

          // 바둑판
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GoBoard(
                game: _game,
                onTap: _onBoardTap,
                bestMove: _showRecommendations ? _bestMove : null,
                styleMove: _showRecommendations ? _styleMove : null,
                lastMove: _lastMovePosition,
              ),
            ),
          ),

          // 로딩/에러 표시
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // 추천 수 정보
          if (_bestMove != null || _styleMove != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  if (_bestMove != null)
                    Expanded(
                      child: _buildMoveInfo(
                        '최적 수',
                        _bestMove!,
                        Colors.blue,
                      ),
                    ),
                  if (_styleMove != null && _styleMove != _bestMove)
                    Expanded(
                      child: _buildMoveInfo(
                        '스타일 수',
                        _styleMove!,
                        Colors.green,
                      ),
                    ),
                ],
              ),
            ),

          // 버튼들
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('무르기'),
                ),
                ElevatedButton.icon(
                  onPressed: _game.gameEnded ? null : _pass,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('패스'),
                ),
                ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새 게임'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String label, StoneColor color, int captures) {
    final isCurrentPlayer = _game.currentPlayer == color && !_game.gameEnded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? Colors.amber.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentPlayer ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color == StoneColor.black ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('잡음: $captures', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoveInfo(String label, RecommendedMove move, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(
          '승률: ${(move.winrate * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12),
        ),
        if (move.styleReason != null)
          Text(
            move.styleReason!,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }
}
