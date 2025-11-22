import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';
import '../models/go_game.dart';

/// 백엔드 API 서비스
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// SGF 기보 스타일 분석
  Future<StyleResult> analyzeSgf(String userId, String sgfContent) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/analyze_sgf'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'sgf_content': sgfContent,
      }),
    );

    if (response.statusCode == 200) {
      return StyleResult.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        'SGF 분석 실패: ${response.statusCode}',
        response.body,
      );
    }
  }

  /// 다음 수 추천 요청
  Future<NextMoveResult> getNextMove(String userId, GoGame game) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/next_move'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'board_state': game.toBoardStateJson(),
      }),
    );

    if (response.statusCode == 200) {
      return NextMoveResult.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        '추천 수 요청 실패: ${response.statusCode}',
        response.body,
      );
    }
  }

  /// 서버 상태 확인
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// API 예외
class ApiException implements Exception {
  final String message;
  final String? details;

  ApiException(this.message, [this.details]);

  @override
  String toString() => 'ApiException: $message${details != null ? '\n$details' : ''}';
}
