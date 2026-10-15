# Deskling

macOS와 Windows에서 쓰는 Claude Code용 데스크톱 펫입니다.

Deskling은 화면 아래를 걸어 다니다가 Claude Code의 작업 상태에 따라 동작을 바꿉니다. Claude Code가 권한을 요청하거나 작업을 마치면 말풍선으로 알려 주기 때문에, 터미널을 계속 보고 있지 않아도 됩니다.

- 말풍선에 프로젝트 폴더 이름과 그 세션에서 보낸 프롬프트가 함께 나오므로, 세션이 여러 개여도 어느 작업의 알림인지 알 수 있습니다.
- 펫을 더블클릭하거나 오른쪽 클릭하면 모든 Claude Code 세션과 각 세션의 상태를 볼 수 있습니다.
- 펫을 마우스로 잡고 있으면 달리고, 공중에서 놓으면 천천히 떨어집니다.
- GIF나 PNG 그림을 담은 폴더 하나로 펫을 원하는 캐릭터로 바꿀 수 있습니다.

Deskling에는 별도의 창이 없습니다. 펫과, macOS 메뉴 막대 또는 Windows 알림 영역의 발바닥 아이콘만 있습니다.

![말풍선을 보여 주는 Deskling](docs/images/demo.png)

[English](README.md)

> Deskling은 비공식 프로젝트이며 Anthropic과 관계가 없습니다.

## 설치하기

[Releases](https://github.com/fghjjkl32/deskling/releases/latest)에서 최신 파일을 내려받습니다.

### macOS

macOS 13 이상이 필요합니다.

1. `Deskling-x.y.z.dmg`를 내려받습니다.
2. DMG를 열고 **Deskling**을 **Applications** 폴더로 끌어다 놓습니다.
3. Deskling을 엽니다. Apple의 공증을 받지 않은 앱이라서 처음에는 macOS가 실행을 막습니다.
4. **시스템 설정 > 개인정보 보호 및 보안**을 열고 아래로 내려가서, Deskling 안내 옆에 있는 **그래도 열기**를 누릅니다.

터미널이 편하다면 3번과 4번 대신 다음 명령을 실행해도 됩니다.

```bash
xattr -dr com.apple.quarantine /Applications/Deskling.app
```

### Windows

64비트 Windows 10 또는 11이 필요합니다. Windows판은 0.2.0에서 처음 나왔으므로, 문제가 생기면 [이슈](https://github.com/fghjjkl32/deskling/issues)로 알려 주세요.

1. `Deskling-windows-x.y.z.zip`을 내려받아 원하는 곳에 압축을 풉니다.
2. `Deskling` 폴더 안의 `Deskling.exe`를 실행합니다.
3. 서명하지 않은 앱이라서 처음에는 "Windows의 PC 보호" 창이 뜹니다. **추가 정보**를 누른 뒤 **실행**을 누릅니다.

펫은 작업 표시줄 바로 위를 걸어 다닙니다. 발바닥 아이콘이 보이지 않으면 알림 영역의 **^**를 누릅니다.

## Claude Code와 연결하기

발바닥 아이콘을 누르고 **Claude Code 연결하기**를 고릅니다.

Deskling은 Claude Code의 `settings.json`에 훅을 추가하며, 다른 설정과 기존 훅은 건드리지 않습니다. 원본 파일은 `settings.json.deskling-backup`으로 보관합니다. **연결 해제하기**를 고르면 Deskling이 추가한 훅만 지웁니다. 이미 실행 중이던 세션에는 다시 시작한 뒤부터 적용됩니다.

| | 설정 파일 | 참고 |
|---|---|---|
| macOS | `~/.claude/settings.json` | 연결하면 키를 정렬하고 들여쓰기를 표준 형식으로 다시 씁니다. 서식은 바뀌지만 값은 모두 그대로 유지됩니다. `CLAUDE_CONFIG_DIR`은 앱을 실행할 때 환경 변수로 전달된 경우에만 인식하며, Dock이나 Finder에서 열면 전달되지 않습니다. |
| Windows | `%USERPROFILE%\.claude\settings.json` | 키 순서를 그대로 유지합니다. 사용자 환경 변수에 `CLAUDE_CONFIG_DIR`이 있으면 그 위치를 씁니다. |
| WSL | 각 배포판의 `~/.claude/settings.json` | **WSL** 하위 메뉴에서 Claude Code를 실행하는 배포판마다 연결합니다. 이 훅은 `/mnt/c/...` 경로로 Windows의 `deskling-hook.exe`를 실행합니다. |

펫은 다음과 같이 동작합니다.

| Claude Code | 펫 |
|---|---|
| 프롬프트를 처리하는 중 | 작업하는 동작을 보여 줍니다. |
| 권한이나 답을 요청하는 중 | 멈춰 서서 말풍선으로 알려 주며, Claude Code가 다시 진행할 때까지 말풍선이 남아 있습니다. |
| 작업 완료 | 기뻐하며 말풍선을 5초 동안 보여 줍니다. |
| 아무 일도 없음 | 걷다가 쉬기를 반복합니다. |

말풍선을 누르면 말풍선이 사라집니다. Deskling은 이 컴퓨터 안에서만 이벤트를 받습니다. macOS에서는 `~/Library/Application Support/Deskling/` 안의 유닉스 소켓을 쓰고, Windows에서는 임의 토큰을 확인하는 `127.0.0.1` 연결을 씁니다. 어디로도 데이터를 보내지 않습니다.

## 스킨 직접 만들기

메뉴에서 **스킨 > 스킨 폴더 열기**를 고른 뒤, 폴더를 하나 만들고 그림을 넣습니다. 스킨 폴더는 macOS에서는 `~/Library/Application Support/Deskling/skins/`이고 Windows에서는 `%APPDATA%\Deskling\skins\`입니다. 같은 스킨 폴더를 두 운영체제에서 그대로 쓸 수 있습니다.

```
skins/내펫/
  idle.gif      쉬는 중 (필수)
  walk.gif      걷기
  working.gif   Claude Code가 작업하는 중
  waiting.gif   Claude Code가 사용자를 기다리는 중
  done.gif      Claude Code가 작업을 마침
  drag.gif      마우스로 잡고 있을 때 (달리기)
  fall.gif      놓은 뒤 떨어지는 동안
  skin.json     선택 사항
```

- 각 파일은 GIF, 움직이는 PNG, 정지 PNG 가운데 하나이며 확장자는 `.gif` 또는 `.png`입니다.
- `idle`만 반드시 있어야 합니다. 없는 동작에는 `idle` 그림을 대신 씁니다.
- `drag`가 없으면 `walk` 그림을 2배 빠르게 재생해서 달리게 합니다. `fall`이 없으면 `drag` 그림을 씁니다.
- 펫이 오른쪽을 바라보게 그립니다. 왼쪽으로 걸을 때에는 Deskling이 그림을 뒤집습니다.
- `skin.json`에는 표시할 이름과 높이(포인트)를 적을 수 있습니다: `{ "name": "내 펫", "height": 120 }`

그다음 **스킨** 메뉴에서 만든 스킨을 고릅니다. 공유할 권리가 있는 그림만 다른 사람과 공유해 주세요.

## 삭제하기

먼저 연결을 해제해야 합니다. 연결된 상태로 Deskling을 지우면 훅이 `settings.json`에 남아서 Claude Code의 모든 이벤트에서 실패합니다.

**macOS**

1. 메뉴에서 **연결 해제하기**를 고른 뒤 **종료하기**를 고릅니다.
2. `Deskling.app`과 `~/Library/Application Support/Deskling` 폴더를 삭제합니다.

**Windows**

1. **연결 해제하기**를 고르고, 연결했던 WSL 배포판도 모두 연결을 해제합니다. 그다음 **종료하기**를 고릅니다.
2. **로그인할 때 실행하기**를 켜 두었다면 끕니다.
3. 압축을 푼 `Deskling` 폴더와 `%APPDATA%\Deskling` 폴더를 삭제합니다.

이미 앱을 지웠다면 Deskling을 다시 설치하고 **연결 해제하기**를 고르거나, `settings.json`을 열어 명령에 `deskling-hook`이 들어 있는 훅 항목을 모두 지워야 합니다.

## 소스에서 빌드하기

**macOS**: Swift 5.9 이상이 들어 있는 Xcode(또는 최소한 명령줄 도구)가 필요합니다.

```bash
swift test
scripts/bundle.sh 0.2.0   # dist/Deskling.app을 만듭니다.
```

**Windows**: Flutter 3.44와, "C++를 사용한 데스크톱 개발" 워크로드를 설치한 Visual Studio가 필요합니다. 앱 코드는 `deskling-windows/`에 있습니다.

```bash
cd deskling-windows
flutter test
flutter build windows --release
dart compile exe bin/deskling_hook.dart -o build/windows/x64/runner/Release/deskling-hook.exe
```

## 라이선스

코드는 [MIT 라이선스](LICENSE)로 공개합니다. 기본 펫은 shuaa(megupets.com)가 CC0로 공개한 고양이 그림이며, 자세한 내용은 [CREDITS.md](CREDITS.md)에 있습니다.
