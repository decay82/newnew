/// 바둑돌 색상
enum StoneColor {
  black,
  white;

  StoneColor get opponent => this == black ? white : black;

  String get symbol => this == black ? 'B' : 'W';

  @override
  String toString() => this == black ? '흑' : '백';
}

/// 바둑판 위치
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '($row, $col)';

  /// 인접한 4방향 위치 반환
  List<Position> getNeighbors(int boardSize) {
    final neighbors = <Position>[];
    if (row > 0) neighbors.add(Position(row - 1, col));
    if (row < boardSize - 1) neighbors.add(Position(row + 1, col));
    if (col > 0) neighbors.add(Position(row, col - 1));
    if (col < boardSize - 1) neighbors.add(Position(row, col + 1));
    return neighbors;
  }
}

/// 착수 기록
class Move {
  final StoneColor color;
  final Position? position; // null이면 패스
  final List<Position> capturedStones; // 이 수로 잡은 돌들
  final DateTime timestamp;

  Move({
    required this.color,
    this.position,
    this.capturedStones = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isPass => position == null;

  Map<String, dynamic> toJson() => {
        'color': color.symbol,
        'row': position?.row,
        'col': position?.col,
        'isPass': isPass,
      };
}
