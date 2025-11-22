"""
바둑 AI 코치 백엔드 - FastAPI 서버
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn

from katago_engine import KataGoEngine
from feature_extractor import FeatureExtractor
from style_classifier import StyleClassifier

app = FastAPI(
    title="바둑 AI 코치 API",
    description="KataGo 기반 바둑 분석 및 스타일 맞춤 추천",
    version="1.0.0"
)

# CORS 설정 (Flutter 앱에서 접근 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 환경용 - 프로덕션에서는 제한 필요
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 전역 인스턴스
katago: Optional[KataGoEngine] = None
feature_extractor = FeatureExtractor()
style_classifier = StyleClassifier()

# 사용자 스타일 저장소 (실제로는 DB 사용)
user_styles: dict = {}


# ===== 요청/응답 모델 =====

class AnalyzeSgfRequest(BaseModel):
    user_id: str
    sgf_content: str


class MoveData(BaseModel):
    color: str  # "B" or "W"
    row: Optional[int] = None
    col: Optional[int] = None
    isPass: bool = False


class BoardState(BaseModel):
    size: int = 19
    moves: list[MoveData]


class NextMoveRequest(BaseModel):
    user_id: str
    board_state: BoardState


class RecommendedMove(BaseModel):
    row: int
    col: int
    winrate: float
    scoreLead: float
    style_reason: Optional[str] = None


class AnalyzeResponse(BaseModel):
    style_label: str
    style_name_ko: str
    features: dict
    coaching_text: str


class NextMoveResponse(BaseModel):
    best_move: RecommendedMove
    style_move: Optional[RecommendedMove] = None


# ===== API 엔드포인트 =====

@app.on_event("startup")
async def startup_event():
    """서버 시작 시 KataGo 초기화"""
    global katago
    try:
        katago = KataGoEngine()
        print("KataGo 엔진 초기화 완료")
    except Exception as e:
        print(f"KataGo 초기화 실패 (분석 기능 제한됨): {e}")
        katago = None


@app.on_event("shutdown")
async def shutdown_event():
    """서버 종료 시 KataGo 정리"""
    global katago
    if katago:
        katago.close()


@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {
        "status": "ok",
        "katago_available": katago is not None
    }


@app.post("/analyze_sgf", response_model=AnalyzeResponse)
async def analyze_sgf(request: AnalyzeSgfRequest):
    """
    SGF 기보를 분석하여 사용자 스타일 판정
    """
    try:
        # 1. KataGo로 기보 분석
        if katago:
            analysis = katago.analyze_sgf(request.sgf_content)
        else:
            # KataGo 없으면 더미 데이터
            analysis = _get_dummy_analysis()

        # 2. Feature 추출
        features = feature_extractor.extract(analysis)

        # 3. 스타일 분류
        style_label, style_name_ko = style_classifier.classify(features)

        # 4. 코칭 문장 생성
        coaching_text = style_classifier.generate_coaching(style_label, features)

        # 5. 사용자 스타일 저장
        user_styles[request.user_id] = {
            "style_label": style_label,
            "features": features
        }

        return AnalyzeResponse(
            style_label=style_label,
            style_name_ko=style_name_ko,
            features=features,
            coaching_text=coaching_text
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/next_move", response_model=NextMoveResponse)
async def get_next_move(request: NextMoveRequest):
    """
    현재 국면에서 최적 수와 스타일 맞춤 수 추천
    """
    try:
        # 1. 현재 국면 분석
        if katago:
            candidates = katago.analyze_position(
                request.board_state.size,
                [(m.color, m.row, m.col) for m in request.board_state.moves if not m.isPass]
            )
        else:
            # KataGo 없으면 더미 데이터
            candidates = _get_dummy_candidates()

        if not candidates:
            raise HTTPException(status_code=400, detail="분석할 수 없는 국면입니다")

        # 2. 최적 수 (승률 최대)
        best = max(candidates, key=lambda c: c["winrate"])
        best_move = RecommendedMove(
            row=best["row"],
            col=best["col"],
            winrate=best["winrate"],
            scoreLead=best["scoreLead"]
        )

        # 3. 스타일 맞춤 수
        style_move = None
        user_style = user_styles.get(request.user_id)

        if user_style:
            style_label = user_style["style_label"]
            style_features = user_style["features"]

            # 승률이 최적 수의 95% 이상인 후보들 중에서
            # 스타일에 맞는 수 선택
            viable_candidates = [
                c for c in candidates
                if c["winrate"] >= best["winrate"] * 0.95
            ]

            style_scored = style_classifier.score_moves_for_style(
                viable_candidates,
                style_label,
                style_features
            )

            if style_scored and style_scored[0] != best:
                top_style = style_scored[0]
                style_move = RecommendedMove(
                    row=top_style["row"],
                    col=top_style["col"],
                    winrate=top_style["winrate"],
                    scoreLead=top_style["scoreLead"],
                    style_reason=_get_style_reason(style_label, top_style)
                )

        return NextMoveResponse(
            best_move=best_move,
            style_move=style_move
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _get_dummy_analysis():
    """KataGo 없을 때 테스트용 더미 분석 데이터"""
    return {
        "moves": [
            {"winrate": 0.52, "scoreLead": 0.5, "row": 3, "col": 3, "is_center": False, "is_invasion": False},
            {"winrate": 0.48, "scoreLead": -0.3, "row": 10, "col": 10, "is_center": True, "is_invasion": False},
        ] * 50
    }


def _get_dummy_candidates():
    """KataGo 없을 때 테스트용 더미 후보 수"""
    import random
    candidates = []
    for _ in range(5):
        candidates.append({
            "row": random.randint(0, 18),
            "col": random.randint(0, 18),
            "winrate": 0.45 + random.random() * 0.1,
            "scoreLead": random.random() * 2 - 1,
            "is_center": random.random() > 0.5,
            "is_invasion": random.random() > 0.7,
            "is_aggressive": random.random() > 0.5,
        })
    return candidates


def _get_style_reason(style_label: str, move: dict) -> str:
    """스타일에 따른 추천 이유 생성"""
    reasons = {
        "aggressive_fighter": "공격적인 전투를 유도하는 수",
        "territory_player": "실리를 확보하는 안정적인 수",
        "center_oriented": "중앙 세력을 키우는 수",
        "balanced": "균형 잡힌 수",
        "invasion_expert": "상대 진영을 압박하는 침투수",
    }
    return reasons.get(style_label, "스타일에 맞는 수")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
