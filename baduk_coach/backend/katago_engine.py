"""
KataGo 엔진 연동 모듈
GTP (Go Text Protocol) 기반으로 KataGo와 통신
"""
import subprocess
import json
import os
from typing import Optional


class KataGoEngine:
    """KataGo 분석 엔진 래퍼"""

    def __init__(
        self,
        katago_path: str = "katago",
        model_path: Optional[str] = None,
        config_path: Optional[str] = None,
        analysis_threads: int = 2,
    ):
        """
        KataGo 엔진 초기화

        Args:
            katago_path: KataGo 실행 파일 경로 (PATH에 있으면 "katago"만)
            model_path: 신경망 모델 파일 경로 (.bin.gz)
            config_path: 설정 파일 경로 (.cfg)
            analysis_threads: 분석 스레드 수
        """
        self.katago_path = katago_path
        self.model_path = model_path or self._find_default_model()
        self.config_path = config_path or self._find_default_config()
        self.analysis_threads = analysis_threads
        self.process: Optional[subprocess.Popen] = None

        # 분석 모드로 KataGo 시작
        self._start_analysis_mode()

    def _find_default_model(self) -> str:
        """기본 모델 파일 찾기"""
        possible_paths = [
            "./katago/models/kata1-b40c256-s11840935168-d2898845681.bin.gz",
            "./models/kata1-b40c256-s11840935168-d2898845681.bin.gz",
            os.path.expanduser("~/.katago/default_model.bin.gz"),
        ]
        for path in possible_paths:
            if os.path.exists(path):
                return path
        return "default_model.bin.gz"  # 사용자가 설정해야 함

    def _find_default_config(self) -> str:
        """기본 설정 파일 찾기"""
        possible_paths = [
            "./katago/configs/analysis_example.cfg",
            "./configs/analysis_example.cfg",
            os.path.expanduser("~/.katago/analysis.cfg"),
        ]
        for path in possible_paths:
            if os.path.exists(path):
                return path
        return "analysis.cfg"

    def _start_analysis_mode(self):
        """KataGo 분석 모드 시작"""
        cmd = [
            self.katago_path,
            "analysis",
            "-model", self.model_path,
            "-config", self.config_path,
            "-analysis-threads", str(self.analysis_threads),
        ]

        try:
            self.process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
            print(f"KataGo 시작됨: {' '.join(cmd)}")
        except FileNotFoundError:
            raise RuntimeError(
                f"KataGo를 찾을 수 없습니다: {self.katago_path}\n"
                "KataGo를 설치하고 PATH에 추가하거나 katago_path를 지정하세요.\n"
                "설치: https://github.com/lightvector/KataGo/releases"
            )

    def _send_query(self, query: dict) -> dict:
        """KataGo에 분석 쿼리 전송"""
        if not self.process:
            raise RuntimeError("KataGo 프로세스가 실행되지 않았습니다")

        query_json = json.dumps(query)
        self.process.stdin.write(query_json + "\n")
        self.process.stdin.flush()

        response_line = self.process.stdout.readline()
        if not response_line:
            raise RuntimeError("KataGo 응답 없음")

        return json.loads(response_line)

    def analyze_sgf(self, sgf_content: str, max_visits: int = 100) -> dict:
        """
        SGF 기보 전체 분석

        Args:
            sgf_content: SGF 문자열
            max_visits: 각 수당 분석 횟수

        Returns:
            각 수별 분석 결과 딕셔너리
        """
        # SGF 파싱
        moves = self._parse_sgf(sgf_content)
        board_size = self._get_board_size(sgf_content)

        results = {"moves": []}

        for i, (color, row, col) in enumerate(moves):
            # 해당 수까지의 국면 분석
            query = {
                "id": f"move_{i}",
                "moves": [
                    [m[0], self._coord_to_gtp(m[1], m[2], board_size)]
                    for m in moves[:i+1]
                ],
                "rules": "korean",
                "komi": 6.5,
                "boardXSize": board_size,
                "boardYSize": board_size,
                "maxVisits": max_visits,
            }

            try:
                response = self._send_query(query)
                if "moveInfos" in response:
                    best_move = response["moveInfos"][0] if response["moveInfos"] else {}
                    results["moves"].append({
                        "move_number": i + 1,
                        "color": color,
                        "row": row,
                        "col": col,
                        "winrate": response.get("rootInfo", {}).get("winrate", 0.5),
                        "scoreLead": response.get("rootInfo", {}).get("scoreLead", 0),
                        "is_center": self._is_center_move(row, col, board_size),
                        "is_invasion": False,  # 나중에 개선
                    })
            except Exception as e:
                print(f"수 {i+1} 분석 실패: {e}")

        return results

    def analyze_position(
        self,
        board_size: int,
        moves: list[tuple[str, int, int]],
        max_visits: int = 200,
        num_candidates: int = 10,
    ) -> list[dict]:
        """
        현재 국면에서 후보 수 분석

        Args:
            board_size: 바둑판 크기
            moves: 지금까지의 수 [(color, row, col), ...]
            max_visits: 분석 횟수
            num_candidates: 반환할 후보 수 개수

        Returns:
            후보 수 리스트 [{row, col, winrate, scoreLead, ...}, ...]
        """
        query = {
            "id": "position_analysis",
            "moves": [
                [m[0], self._coord_to_gtp(m[1], m[2], board_size)]
                for m in moves
            ],
            "rules": "korean",
            "komi": 6.5,
            "boardXSize": board_size,
            "boardYSize": board_size,
            "maxVisits": max_visits,
        }

        response = self._send_query(query)

        candidates = []
        for info in response.get("moveInfos", [])[:num_candidates]:
            gtp_move = info.get("move", "")
            if gtp_move and gtp_move != "pass":
                row, col = self._gtp_to_coord(gtp_move, board_size)
                candidates.append({
                    "row": row,
                    "col": col,
                    "winrate": info.get("winrate", 0.5),
                    "scoreLead": info.get("scoreLead", 0),
                    "visits": info.get("visits", 0),
                    "is_center": self._is_center_move(row, col, board_size),
                    "is_invasion": False,  # 나중에 상대 영역 계산 필요
                    "is_aggressive": info.get("scoreLead", 0) > 1,
                })

        return candidates

    def _parse_sgf(self, sgf: str) -> list[tuple[str, int, int]]:
        """SGF에서 수순 파싱"""
        import re
        moves = []
        pattern = r';([BW])\[([a-z])([a-z])\]'

        for match in re.finditer(pattern, sgf, re.IGNORECASE):
            color = match.group(1).upper()
            col = ord(match.group(2).lower()) - ord('a')
            row = ord(match.group(3).lower()) - ord('a')
            moves.append((color, row, col))

        return moves

    def _get_board_size(self, sgf: str) -> int:
        """SGF에서 바둑판 크기 파싱"""
        import re
        match = re.search(r'SZ\[(\d+)\]', sgf)
        return int(match.group(1)) if match else 19

    def _coord_to_gtp(self, row: int, col: int, board_size: int) -> str:
        """좌표를 GTP 형식으로 변환 (예: 3,3 -> D4)"""
        # GTP는 I를 건너뜀
        col_letter = chr(ord('A') + col + (1 if col >= 8 else 0))
        row_num = board_size - row
        return f"{col_letter}{row_num}"

    def _gtp_to_coord(self, gtp: str, board_size: int) -> tuple[int, int]:
        """GTP 형식을 좌표로 변환 (예: D4 -> 3,3)"""
        col_letter = gtp[0].upper()
        row_num = int(gtp[1:])

        col = ord(col_letter) - ord('A')
        if col > 7:  # I 건너뜀
            col -= 1

        row = board_size - row_num
        return row, col

    def _is_center_move(self, row: int, col: int, board_size: int) -> bool:
        """중앙 근처 수인지 판단"""
        center = board_size // 2
        distance = max(abs(row - center), abs(col - center))
        return distance <= board_size // 4

    def close(self):
        """KataGo 프로세스 종료"""
        if self.process:
            self.process.stdin.close()
            self.process.terminate()
            self.process.wait(timeout=5)
            self.process = None
