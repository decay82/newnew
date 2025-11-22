# 바둑 AI 코치

Flutter + Python 백엔드 기반 바둑 AI 코칭 앱

## 아키텍처

```
[Flutter 앱]  <──HTTP(JSON)──>  [Python 백엔드(FastAPI)]
                                    │
                                    ├─ KataGo (기보 분석)
                                    ├─ Feature 추출 (pandas/numpy)
                                    ├─ 스타일 분류 (scikit-learn)
                                    └─ 코칭 문장 생성 (규칙 기반)
```

## 프로젝트 구조

```
baduk_coach/
├── flutter_app/           # Flutter UI
│   ├── lib/
│   │   ├── models/        # 바둑 룰, 데이터 모델
│   │   │   ├── stone.dart
│   │   │   ├── go_game.dart    # ⭐ 바둑 룰 구현
│   │   │   └── api_models.dart
│   │   ├── services/      # API 호출
│   │   │   └── api_service.dart
│   │   ├── screens/       # 화면
│   │   │   ├── game_screen.dart    # AI 대국
│   │   │   └── analyze_screen.dart # 기보 분석
│   │   ├── widgets/       # UI 컴포넌트
│   │   │   └── go_board.dart       # 바둑판 렌더링
│   │   └── main.dart
│   └── pubspec.yaml
│
└── backend/               # Python 백엔드
    ├── main.py            # FastAPI 엔드포인트
    ├── katago_engine.py   # KataGo 연동
    ├── feature_extractor.py   # Feature 추출
    ├── style_classifier.py    # 스타일 분류
    └── requirements.txt
```

## 빠른 시작

### 1. 백엔드 실행

```bash
cd baduk_coach/backend

# 의존성 설치
pip install -r requirements.txt

# KataGo 설치 (별도 필요)
# https://github.com/lightvector/KataGo/releases

# 서버 실행
python main.py
# 또는
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Flutter 앱 실행

```bash
cd baduk_coach/flutter_app

# 의존성 설치
flutter pub get

# 웹으로 실행 (개발 중 추천)
flutter run -d chrome

# 또는 데스크톱
flutter run -d macos  # 또는 windows, linux
```

## API 엔드포인트

### POST /analyze_sgf
SGF 기보 스타일 분석

요청:
```json
{
  "user_id": "user123",
  "sgf_content": "(;GM[1]FF[4]SZ[19]...)"
}
```

응답:
```json
{
  "style_label": "aggressive_fighter",
  "style_name_ko": "공격형 전투 스타일",
  "features": {
    "big_loss_ratio": 0.32,
    "center_ratio": 0.45
  },
  "coaching_text": "당신은 전투를 좋아하는 공격형 스타일입니다..."
}
```

### POST /next_move
다음 수 추천

요청:
```json
{
  "user_id": "user123",
  "board_state": {
    "size": 19,
    "moves": [
      {"color": "B", "row": 3, "col": 3},
      {"color": "W", "row": 15, "col": 15}
    ]
  }
}
```

응답:
```json
{
  "best_move": {
    "row": 10,
    "col": 16,
    "winrate": 0.54,
    "scoreLead": 1.2
  },
  "style_move": {
    "row": 12,
    "col": 15,
    "winrate": 0.533,
    "scoreLead": 1.0,
    "style_reason": "공격형 스타일에 맞는 중앙 압박 수"
  }
}
```

## Flutter 바둑 룰 구현

`go_game.dart`에서 구현된 룰:
- ✅ 빈 점 확인
- ✅ 따냄 (Capture)
- ✅ 자충수 금지
- ✅ 패 (Ko) 규칙
- ✅ 턴 관리
- ✅ 무르기 (Undo)
- ✅ SGF 내보내기/불러오기

## KataGo 설정

KataGo 없이도 더미 데이터로 테스트 가능합니다.
실제 분석을 위해서는:

1. [KataGo 다운로드](https://github.com/lightvector/KataGo/releases)
2. [모델 파일 다운로드](https://katagotraining.org/) (b40 이상 추천)
3. 환경 변수 또는 코드에서 경로 설정

## 비용

**완전 무료 (로컬 개발)**
- Flutter: 무료
- FastAPI: 무료
- KataGo: 오픈소스
- scikit-learn: 무료

## 향후 계획

- [ ] 계가 (점수 계산) 기능
- [ ] 로컬 LLM 연동 (자연스러운 코칭)
- [ ] 기보 저장/불러오기
- [ ] 사용자 히스토리 분석
