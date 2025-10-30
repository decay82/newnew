# Metabase MCP 연결 가이드

이 프로젝트에 Metabase MCP 서버를 연결하여 Metabase 데이터베이스와 상호작용할 수 있습니다.

## 사전 요구사항

- Node.js 설치 (npm 포함)
- Metabase 인스턴스 접근 권한
- Metabase API 키 또는 사용자 인증 정보

## 설치 및 설정

### 1. 환경 변수 설정

`.env.example` 파일을 `.env`로 복사하고 실제 값을 입력하세요:

```bash
cp .env.example .env
```

`.env` 파일에 다음 정보를 입력:
- `METABASE_URL`: Metabase 인스턴스 URL
- `METABASE_API_KEY`: Metabase API 키

### 2. Metabase API 키 생성

1. Metabase 관리자 계정으로 로그인
2. Settings > Admin Settings > API Keys로 이동
3. "Create API Key" 클릭
4. 생성된 키를 `.env` 파일에 추가

### 3. MCP 서버 설정

`mcp-config.json` 파일이 이미 생성되어 있습니다. Claude Code에서 이 설정을 사용하려면:

Claude Code 설정에 다음 내용을 추가하세요:

```json
{
  "mcpServers": {
    "metabase": {
      "command": "npx",
      "args": ["-y", "@postergully/metabase-mcp"],
      "env": {
        "METABASE_URL": "YOUR_METABASE_URL",
        "METABASE_API_KEY": "YOUR_API_KEY"
      }
    }
  }
}
```

### 4. 사용 가능한 기능

Metabase MCP를 통해 다음과 같은 작업을 수행할 수 있습니다:

- **쿼리 실행**: Metabase에 저장된 쿼리 실행
- **대시보드 조회**: 대시보드 정보 가져오기
- **카드/질문 조회**: 저장된 질문(카드) 정보 조회
- **데이터 추출**: 쿼리 결과를 다양한 형식으로 추출

### 5. 사용 예시

MCP 서버가 연결되면 Claude Code에서 다음과 같이 요청할 수 있습니다:

```
"Metabase에서 사용자 통계 대시보드를 조회해줘"
"이번 달 매출 데이터를 쿼리해줘"
"저장된 질문 목록을 보여줘"
```

## 문제 해결

### 연결 오류
- Metabase URL이 정확한지 확인
- API 키가 유효한지 확인
- 네트워크 연결 확인

### 인증 오류
- API 키 권한 확인
- API 키가 만료되지 않았는지 확인

## 참고 자료

- [Metabase MCP GitHub](https://github.com/postergully/metabase-mcp)
- [Metabase API 문서](https://www.metabase.com/docs/latest/api-documentation)
- [MCP 프로토콜](https://modelcontextprotocol.io)

## 보안 주의사항

- `.env` 파일을 절대 git에 커밋하지 마세요
- API 키를 안전하게 보관하세요
- 프로덕션 환경에서는 환경 변수를 안전하게 관리하세요
