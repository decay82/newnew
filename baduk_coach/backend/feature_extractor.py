"""
Feature 추출 모듈
KataGo 분석 결과에서 스타일 특성 추출
"""
import numpy as np
from typing import Any


class FeatureExtractor:
    """바둑 기보에서 스타일 Feature 추출"""

    def __init__(self):
        # 큰 손해 기준 (승률 하락)
        self.big_loss_threshold = 0.05  # 5% 이상 하락

    def extract(self, analysis: dict) -> dict[str, float]:
        """
        KataGo 분석 결과에서 Feature 추출

        Args:
            analysis: KataGo 분석 결과 {"moves": [...]}

        Returns:
            Feature 딕셔너리 {feature_name: value}
        """
        moves = analysis.get("moves", [])

        if not moves:
            return self._get_default_features()

        return {
            "big_loss_ratio": self._calc_big_loss_ratio(moves),
            "center_ratio": self._calc_center_ratio(moves),
            "invasion_ratio": self._calc_invasion_ratio(moves),
            "fight_ratio": self._calc_fight_ratio(moves),
            "territory_ratio": self._calc_territory_ratio(moves),
            "aggression_score": self._calc_aggression_score(moves),
            "stability_score": self._calc_stability_score(moves),
        }

    def _get_default_features(self) -> dict[str, float]:
        """기본 Feature 값"""
        return {
            "big_loss_ratio": 0.2,
            "center_ratio": 0.3,
            "invasion_ratio": 0.2,
            "fight_ratio": 0.3,
            "territory_ratio": 0.4,
            "aggression_score": 0.5,
            "stability_score": 0.5,
        }

    def _calc_big_loss_ratio(self, moves: list[dict]) -> float:
        """
        큰 손해를 본 수의 비율
        - 전 수 대비 승률이 크게 하락한 수 / 전체 수
        """
        if len(moves) < 2:
            return 0.0

        big_losses = 0
        for i in range(1, len(moves)):
            prev_winrate = moves[i - 1].get("winrate", 0.5)
            curr_winrate = moves[i].get("winrate", 0.5)

            # 현재 플레이어 관점에서 손해 계산
            # (번갈아 두므로 관점이 바뀜)
            if i % 2 == 0:  # 흑 기준
                loss = prev_winrate - curr_winrate
            else:  # 백 기준
                loss = curr_winrate - prev_winrate

            if loss > self.big_loss_threshold:
                big_losses += 1

        return big_losses / len(moves)

    def _calc_center_ratio(self, moves: list[dict]) -> float:
        """
        중앙 근처에 둔 수의 비율
        """
        if not moves:
            return 0.0

        center_moves = sum(1 for m in moves if m.get("is_center", False))
        return center_moves / len(moves)

    def _calc_invasion_ratio(self, moves: list[dict]) -> float:
        """
        침투/침입 수의 비율
        """
        if not moves:
            return 0.0

        invasion_moves = sum(1 for m in moves if m.get("is_invasion", False))
        return invasion_moves / len(moves)

    def _calc_fight_ratio(self, moves: list[dict]) -> float:
        """
        전투 관련 수의 비율 (승률 변동이 큰 수)
        """
        if len(moves) < 2:
            return 0.0

        fight_threshold = 0.02  # 2% 이상 변동
        fight_moves = 0

        for i in range(1, len(moves)):
            prev_winrate = moves[i - 1].get("winrate", 0.5)
            curr_winrate = moves[i].get("winrate", 0.5)
            volatility = abs(curr_winrate - prev_winrate)

            if volatility > fight_threshold:
                fight_moves += 1

        return fight_moves / len(moves)

    def _calc_territory_ratio(self, moves: list[dict]) -> float:
        """
        실리 지향 수의 비율 (변두리/귀 수)
        """
        if not moves:
            return 0.0

        # 중앙이 아닌 수 = 실리 지향으로 간주
        territory_moves = sum(1 for m in moves if not m.get("is_center", False))
        return territory_moves / len(moves)

    def _calc_aggression_score(self, moves: list[dict]) -> float:
        """
        공격성 점수 (0~1)
        - 침투 + 중앙 + 전투 비율 종합
        """
        center = self._calc_center_ratio(moves)
        invasion = self._calc_invasion_ratio(moves)
        fight = self._calc_fight_ratio(moves)

        # 가중 평균
        return (center * 0.3 + invasion * 0.4 + fight * 0.3)

    def _calc_stability_score(self, moves: list[dict]) -> float:
        """
        안정성 점수 (0~1)
        - 큰 손해 비율이 낮을수록 안정적
        """
        big_loss = self._calc_big_loss_ratio(moves)
        return 1.0 - min(big_loss * 2, 1.0)  # 손해 많으면 불안정

    def extract_to_vector(self, analysis: dict) -> np.ndarray:
        """
        Feature를 numpy 벡터로 반환 (ML 모델 입력용)
        """
        features = self.extract(analysis)
        return np.array([
            features["big_loss_ratio"],
            features["center_ratio"],
            features["invasion_ratio"],
            features["fight_ratio"],
            features["territory_ratio"],
            features["aggression_score"],
            features["stability_score"],
        ])
