"""
스타일 분류 모듈
Feature 기반으로 바둑 스타일 분류 및 코칭 문장 생성
"""
import numpy as np
from typing import Optional
from sklearn.cluster import KMeans
import pickle
import os


class StyleClassifier:
    """바둑 스타일 분류기"""

    # 스타일 정의
    STYLES = {
        "aggressive_fighter": {
            "name_ko": "공격형 전투 스타일",
            "description": "전투를 좋아하고 적극적으로 상대를 공격하는 스타일",
            "center_weight": 0.3,
            "invasion_weight": 0.4,
            "aggression_weight": 0.5,
        },
        "territory_player": {
            "name_ko": "실리형 스타일",
            "description": "안정적으로 실리를 확보하며 두는 스타일",
            "territory_weight": 0.5,
            "stability_weight": 0.4,
        },
        "center_oriented": {
            "name_ko": "중앙 세력형 스타일",
            "description": "중앙에 세력을 키우며 두는 스타일",
            "center_weight": 0.6,
            "aggression_weight": 0.3,
        },
        "balanced": {
            "name_ko": "균형형 스타일",
            "description": "실리와 세력의 균형을 맞추며 두는 스타일",
        },
        "invasion_expert": {
            "name_ko": "침투형 스타일",
            "description": "상대 진영에 과감하게 침투하는 스타일",
            "invasion_weight": 0.6,
            "aggression_weight": 0.4,
        },
    }

    def __init__(self, model_path: Optional[str] = None):
        """
        스타일 분류기 초기화

        Args:
            model_path: 학습된 KMeans 모델 경로 (없으면 규칙 기반 사용)
        """
        self.kmeans: Optional[KMeans] = None

        if model_path and os.path.exists(model_path):
            with open(model_path, "rb") as f:
                self.kmeans = pickle.load(f)
        else:
            # 기본 KMeans 모델 (나중에 실제 데이터로 학습 필요)
            self._init_default_kmeans()

    def _init_default_kmeans(self):
        """기본 KMeans 모델 초기화"""
        # 각 스타일의 대표 Feature 벡터
        # [big_loss, center, invasion, fight, territory, aggression, stability]
        style_centers = np.array([
            [0.25, 0.4, 0.35, 0.5, 0.3, 0.6, 0.4],   # aggressive_fighter
            [0.15, 0.2, 0.15, 0.2, 0.6, 0.2, 0.7],   # territory_player
            [0.2, 0.55, 0.2, 0.4, 0.35, 0.5, 0.5],   # center_oriented
            [0.2, 0.35, 0.25, 0.35, 0.45, 0.4, 0.55], # balanced
            [0.3, 0.3, 0.5, 0.45, 0.35, 0.55, 0.4],  # invasion_expert
        ])

        self.kmeans = KMeans(n_clusters=5, random_state=42, n_init=10)
        self.kmeans.fit(style_centers)
        # 클러스터 중심 재설정
        self.kmeans.cluster_centers_ = style_centers

    def classify(self, features: dict[str, float]) -> tuple[str, str]:
        """
        Feature 기반 스타일 분류

        Args:
            features: Feature 딕셔너리

        Returns:
            (style_label, style_name_ko)
        """
        style_labels = list(self.STYLES.keys())

        if self.kmeans:
            # KMeans 기반 분류
            feature_vector = np.array([[
                features.get("big_loss_ratio", 0.2),
                features.get("center_ratio", 0.3),
                features.get("invasion_ratio", 0.2),
                features.get("fight_ratio", 0.3),
                features.get("territory_ratio", 0.4),
                features.get("aggression_score", 0.5),
                features.get("stability_score", 0.5),
            ]])

            cluster_id = self.kmeans.predict(feature_vector)[0]
            style_label = style_labels[cluster_id]
        else:
            # 규칙 기반 분류 (폴백)
            style_label = self._rule_based_classify(features)

        style_name_ko = self.STYLES[style_label]["name_ko"]
        return style_label, style_name_ko

    def _rule_based_classify(self, features: dict[str, float]) -> str:
        """규칙 기반 스타일 분류"""
        aggression = features.get("aggression_score", 0.5)
        center = features.get("center_ratio", 0.3)
        invasion = features.get("invasion_ratio", 0.2)
        territory = features.get("territory_ratio", 0.4)
        stability = features.get("stability_score", 0.5)

        # 공격성이 높으면
        if aggression > 0.55:
            if invasion > 0.35:
                return "invasion_expert"
            else:
                return "aggressive_fighter"

        # 중앙 비율이 높으면
        if center > 0.45:
            return "center_oriented"

        # 실리 비율이 높고 안정적이면
        if territory > 0.5 and stability > 0.55:
            return "territory_player"

        return "balanced"

    def generate_coaching(self, style_label: str, features: dict[str, float]) -> str:
        """
        스타일과 Feature 기반 코칭 문장 생성

        Args:
            style_label: 스타일 라벨
            features: Feature 딕셔너리

        Returns:
            코칭 텍스트
        """
        style_info = self.STYLES.get(style_label, self.STYLES["balanced"])
        base_description = style_info["description"]

        # Feature 기반 추가 조언
        advice_parts = [f"당신은 {base_description}입니다."]

        big_loss = features.get("big_loss_ratio", 0.2)
        stability = features.get("stability_score", 0.5)

        # 큰 손해 비율에 따른 조언
        if big_loss > 0.3:
            advice_parts.append(
                "다만 큰 손해를 보는 수의 비율이 높아 승부처에서 판단 안정성이 필요합니다."
            )
        elif big_loss < 0.15:
            advice_parts.append(
                "실수가 적고 안정적인 수읽기를 보여주고 있습니다."
            )

        # 스타일별 맞춤 조언
        if style_label == "aggressive_fighter":
            if stability < 0.4:
                advice_parts.append(
                    "공격적인 플레이는 좋지만, 때로는 한 템포 쉬어가는 수도 고려해보세요."
                )
            else:
                advice_parts.append(
                    "전투 능력이 뛰어나면서도 안정감이 있습니다. 강점을 살려보세요."
                )

        elif style_label == "territory_player":
            center = features.get("center_ratio", 0.3)
            if center < 0.25:
                advice_parts.append(
                    "때로는 중앙으로 진출하여 세력을 키우는 것도 좋은 전략입니다."
                )

        elif style_label == "center_oriented":
            advice_parts.append(
                "세력을 실리로 전환하는 타이밍을 잘 잡는 것이 중요합니다."
            )

        elif style_label == "invasion_expert":
            advice_parts.append(
                "침투 후 수습하는 능력을 키우면 더욱 강해질 수 있습니다."
            )

        return " ".join(advice_parts)

    def score_moves_for_style(
        self,
        candidates: list[dict],
        style_label: str,
        user_features: dict[str, float],
    ) -> list[dict]:
        """
        후보 수들에 스타일 점수 부여하여 정렬

        Args:
            candidates: 후보 수 리스트
            style_label: 사용자 스타일
            user_features: 사용자 Feature

        Returns:
            스타일 점수 순으로 정렬된 후보 수 리스트
        """
        if not candidates:
            return []

        style_info = self.STYLES.get(style_label, {})

        def calc_style_score(move: dict) -> float:
            score = 0.0

            # 중앙 선호 스타일
            if style_label in ["center_oriented", "aggressive_fighter"]:
                if move.get("is_center", False):
                    score += style_info.get("center_weight", 0.3)

            # 침투 선호 스타일
            if style_label in ["invasion_expert", "aggressive_fighter"]:
                if move.get("is_invasion", False):
                    score += style_info.get("invasion_weight", 0.3)

            # 공격적 스타일
            if style_label in ["aggressive_fighter", "invasion_expert"]:
                if move.get("is_aggressive", False):
                    score += style_info.get("aggression_weight", 0.3)

            # 기본 승률도 반영
            score += move.get("winrate", 0.5) * 0.3

            return score

        # 스타일 점수로 정렬
        for move in candidates:
            move["style_score"] = calc_style_score(move)

        return sorted(candidates, key=lambda m: m["style_score"], reverse=True)

    def train(self, feature_vectors: np.ndarray, save_path: Optional[str] = None):
        """
        실제 기보 데이터로 KMeans 모델 학습

        Args:
            feature_vectors: Feature 벡터 배열 (n_samples, n_features)
            save_path: 모델 저장 경로
        """
        self.kmeans = KMeans(n_clusters=5, random_state=42, n_init=10)
        self.kmeans.fit(feature_vectors)

        if save_path:
            with open(save_path, "wb") as f:
                pickle.dump(self.kmeans, f)
            print(f"모델 저장됨: {save_path}")
