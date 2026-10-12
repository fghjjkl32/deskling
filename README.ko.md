# Deskling

macOS에서 쓰는 Claude Code용 데스크톱 펫입니다.

Deskling은 화면 아래를 걸어 다니다가 Claude Code의 작업 상태에 따라 동작을 바꿉니다. Claude Code가 권한을 요청하거나 작업을 마치면 말풍선으로 알려 주기 때문에, 터미널을 계속 보고 있지 않아도 됩니다.

Deskling은 메뉴 막대에서 실행됩니다. Dock 아이콘과 창은 없고, 펫과 메뉴만 있습니다.

![말풍선을 보여 주는 Deskling](docs/images/demo.png)

[English](README.md)

> Deskling은 비공식 프로젝트이며 Anthropic과 관계가 없습니다.

## 설치하기

macOS 13 이상이 필요합니다.

1. [Releases](https://github.com/fghjjkl32/deskling/releases/latest)에서 `Deskling-x.y.z.dmg`를 내려받습니다.
2. DMG를 열고 **Deskling**을 **Applications** 폴더로 끌어다 놓습니다.
3. Deskling을 엽니다. Apple의 공증을 받지 않은 앱이라서 처음에는 macOS가 실행을 막습니다.
4. **시스템 설정 > 개인정보 보호 및 보안**을 열고 아래로 내려가서, Deskling 안내 옆에 있는 **그래도 열기**를 누릅니다.

터미널이 편하다면 3번과 4번 대신 다음 명령을 실행해도 됩니다.

```bash
xattr -dr com.apple.quarantine /Applications/Deskling.app
```

## Claude Code와 연결하기

메뉴 막대의 발바닥 아이콘을 누르고 **Claude Code 연결하기**를 고릅니다.

Deskling은 `~/.claude/settings.json`에 훅을 추가하며, 다른 설정과 기존 훅은 건드리지 않습니다. 원본 파일은 `settings.json.deskling-backup`으로 보관합니다. **연결 해제하기**를 고르면 추가한 훅만 지웁니다. 연결하면 `settings.json`의 키를 정렬하고 들여쓰기를 표준 형식으로 다시 쓰므로 서식은 바뀌지만 값은 모두 그대로 유지됩니다. `CLAUDE_CONFIG_DIR`은 앱을 실행할 때 환경 변수로 전달된 경우에만 인식하며, Dock이나 Finder에서 앱을 열면 전달되지 않습니다. 이미 실행 중이던 세션에는 다시 시작한 뒤부터 적용됩니다.

| Claude Code | 펫 |
|---|---|
| 프롬프트를 처리하는 중 | 작업하는 동작을 보여 줍니다. |
| 권한을 요청하는 중 | 멈춰 서서 말풍선으로 알려 주며, Claude Code가 다시 진행할 때까지 말풍선이 남아 있습니다. |
| 작업 완료 | 기뻐하며 말풍선으로 알려 줍니다. |
| 아무 일도 없음 | 걷다가 쉬기를 반복합니다. |

말풍선을 누르면 말풍선이 사라집니다. Deskling은 `~/Library/Application Support/Deskling/` 안의 유닉스 소켓으로만 이벤트를 받습니다. 네트워크 포트를 열지 않으며 어디로도 데이터를 보내지 않습니다.

## 삭제하기

1. 먼저 메뉴에서 **연결 해제하기**를 고릅니다.
2. **종료하기**를 고릅니다.
3. `Deskling.app`과 `~/Library/Application Support/Deskling` 폴더를 삭제합니다.

연결을 해제하지 않고 앱만 삭제하면 훅이 `settings.json`에 남아서 Claude Code의 모든 이벤트에서 실패합니다. 이 경우에는 Deskling을 다시 설치하고 **연결 해제하기**를 고르거나, `settings.json`을 열어 명령에 `deskling-hook`이 들어 있는 훅 항목을 모두 지워야 합니다.

## 스킨 직접 만들기

메뉴에서 **스킨 > 스킨 폴더 열기**를 고른 뒤, 폴더를 하나 만들고 그림을 넣습니다.

```
skins/내펫/
  idle.gif      쉬는 중 (필수)
  walk.gif      걷기
  working.gif   Claude Code가 작업하는 중
  waiting.gif   Claude Code가 사용자를 기다리는 중
  done.gif      Claude Code가 작업을 마침
  skin.json     선택 사항
```

- 각 파일은 GIF, 움직이는 PNG, 정지 PNG 가운데 하나이며 확장자는 `.gif` 또는 `.png`입니다.
- `idle`만 반드시 있어야 합니다. 없는 동작에는 `idle` 그림을 대신 씁니다.
- 펫이 오른쪽을 바라보게 그립니다. 왼쪽으로 걸을 때에는 Deskling이 그림을 뒤집습니다.
- `skin.json`에는 표시할 이름과 높이(포인트)를 적을 수 있습니다: `{ "name": "내 펫", "height": 120 }`

그다음 **스킨** 메뉴에서 만든 스킨을 고릅니다. 공유할 권리가 있는 그림만 다른 사람과 공유해 주세요.

## 소스에서 빌드하기

빌드하려면 Swift 5.9 이상이 들어 있는 Xcode(또는 최소한 명령줄 도구)가 필요합니다.

```bash
swift test
scripts/bundle.sh 0.1.0   # dist/Deskling.app을 만듭니다.
```

## 라이선스

코드는 [MIT 라이선스](LICENSE)로 공개합니다. 기본 펫은 shuaa(megupets.com)가 CC0로 공개한 고양이 그림이며, 자세한 내용은 [CREDITS.md](CREDITS.md)에 있습니다.
