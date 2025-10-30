# Metabase MCP 연결 완벽 가이드

## 1단계: Metabase API 키 생성

1. Metabase에 관리자로 로그인
2. 우측 상단 톱니바퀴 아이콘 > Admin Settings 클릭
3. Settings > Authentication > API Keys 이동
4. "Create API Key" 버튼 클릭
5. 키 이름 입력 (예: "Claude MCP")
6. 생성된 API 키 복사 (한 번만 표시됩니다!)

## 2단계: Claude Desktop 설정 파일 수정

### Linux 사용자:

```bash
# 설정 디렉토리 생성 (없는 경우)
mkdir -p ~/.config/Claude

# 설정 파일 편집
nano ~/.config/Claude/claude_desktop_config.json
```

### Mac 사용자:

```bash
# 설정 파일 편집
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Windows 사용자:

```
메모장으로 다음 경로 파일 열기:
%APPDATA%\Claude\claude_desktop_config.json
```

## 3단계: 설정 파일에 다음 내용 추가

```json
{
  "mcpServers": {
    "metabase": {
      "command": "npx",
      "args": [
        "-y",
        "@postergully/metabase-mcp"
      ],
      "env": {
        "METABASE_URL": "https://your-metabase-instance.com",
        "METABASE_API_KEY": "여기에_실제_API_키_입력"
      }
    }
  }
}
```

**중요**: `YOUR_METABASE_URL`과 `YOUR_API_KEY`를 실제 값으로 변경하세요!

## 4단계: Claude Desktop 재시작

1. Claude Desktop 완전히 종료
2. 다시 실행
3. 새 대화 시작

## 5단계: 연결 확인

Claude Desktop에서 다음과 같이 테스트:

```
"Metabase에 연결됐어?"
"Metabase 데이터베이스 목록 보여줘"
```

## 문제 해결

### MCP 서버가 나타나지 않는 경우:

1. **Node.js 설치 확인**:
   ```bash
   node --version
   npm --version
   ```

2. **수동으로 MCP 패키지 설치**:
   ```bash
   npm install -g @postergully/metabase-mcp
   ```

3. **설정 파일 JSON 형식 확인**:
   - JSON 형식이 올바른지 확인 (쉼표, 중괄호 등)
   - [JSONLint](https://jsonlint.com/)에서 검증

4. **Claude Desktop 로그 확인**:
   - Help > Show Logs 메뉴에서 에러 확인

### 연결은 되지만 작동하지 않는 경우:

1. **Metabase URL 확인**:
   - `http://` 또는 `https://` 포함
   - 마지막 슬래시(/) 제거
   - 예: `https://metabase.example.com`

2. **API 키 권한 확인**:
   - API 키가 만료되지 않았는지 확인
   - 필요한 권한이 있는지 확인

3. **네트워크 접근 확인**:
   ```bash
   curl -I YOUR_METABASE_URL
   ```

## 사용 예시

MCP가 연결되면 Claude Desktop에서:

```
"Metabase에서 사용 가능한 데이터베이스 보여줘"
"고객 통계 대시보드 데이터 가져와줘"
"이번 주 매출 쿼리 실행해줘"
"질문 ID 123번 실행해줘"
```

## 추가 옵션

### 여러 Metabase 인스턴스 연결:

```json
{
  "mcpServers": {
    "metabase-prod": {
      "command": "npx",
      "args": ["-y", "@postergully/metabase-mcp"],
      "env": {
        "METABASE_URL": "https://prod.metabase.com",
        "METABASE_API_KEY": "prod_api_key"
      }
    },
    "metabase-dev": {
      "command": "npx",
      "args": ["-y", "@postergully/metabase-mcp"],
      "env": {
        "METABASE_URL": "https://dev.metabase.com",
        "METABASE_API_KEY": "dev_api_key"
      }
    }
  }
}
```

## 보안 주의사항

- API 키를 절대 공개 저장소에 커밋하지 마세요
- 정기적으로 API 키를 교체하세요
- 필요한 최소 권한만 부여하세요

## 참고 자료

- [Metabase MCP GitHub](https://github.com/postergully/metabase-mcp)
- [Metabase API 문서](https://www.metabase.com/docs/latest/api-documentation)
- [Claude Desktop MCP 설정](https://docs.anthropic.com/claude/docs/mcp)
