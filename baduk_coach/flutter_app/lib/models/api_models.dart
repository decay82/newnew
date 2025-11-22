/// 스타일 분석 결과
class StyleResult {
  final String styleLabel;
  final String styleNameKo;
  final Map<String, double> features;
  final String coachingText;

  StyleResult({
    required this.styleLabel,
    required this.styleNameKo,
    required this.features,
    required this.coachingText,
  });

  factory StyleResult.fromJson(Map<String, dynamic> json) {
    return StyleResult(
      styleLabel: json['style_label'] ?? '',
      styleNameKo: json['style_name_ko'] ?? '',
      features: Map<String, double>.from(
        (json['features'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      coachingText: json['coaching_text'] ?? '',
    );
  }
}

/// 추천 수 정보
class RecommendedMove {
  final int row;
  final int col;
  final double winrate;
  final double scoreLead;
  final String? styleReason;

  RecommendedMove({
    required this.row,
    required this.col,
    required this.winrate,
    required this.scoreLead,
    this.styleReason,
  });

  factory RecommendedMove.fromJson(Map<String, dynamic> json) {
    return RecommendedMove(
      row: json['row'] ?? 0,
      col: json['col'] ?? 0,
      winrate: (json['winrate'] ?? 0).toDouble(),
      scoreLead: (json['scoreLead'] ?? 0).toDouble(),
      styleReason: json['style_reason'],
    );
  }
}

/// 다음 수 추천 결과
class NextMoveResult {
  final RecommendedMove bestMove;
  final RecommendedMove? styleMove;

  NextMoveResult({
    required this.bestMove,
    this.styleMove,
  });

  factory NextMoveResult.fromJson(Map<String, dynamic> json) {
    return NextMoveResult(
      bestMove: RecommendedMove.fromJson(json['best_move']),
      styleMove: json['style_move'] != null
          ? RecommendedMove.fromJson(json['style_move'])
          : null,
    );
  }
}
