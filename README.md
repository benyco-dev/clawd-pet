# 데스크톱 펫 (macOS · Windows)

Clawd, 흰 고양이, 검은 고양이가 창 위를 걸어다녀요. macOS와 Windows 버전의 기능이 같아요.
Windows는 [아래](#windows)를 보세요.

## 설치 (3분)

1. 이 폴더를 맥북으로 옮기기 (AirDrop, USB 등)
2. 터미널에서 이 폴더로 이동한 뒤 실행:
   ```bash
   bash install.sh
   ```
   - 특정 펫만: `bash install.sh white black`
   - Xcode Command Line Tools 설치 창이 뜨면 설치 후 다시 실행

설치하면 바로 펫이 나오고, 로그인할 때마다 자동으로 나와요. Claude Code 작업이 끝나면 랜덤 펫이 "작업 완료!"라고 알려줘요.

## 사용법

- 드래그: 옮기기 (창 위 어디든 놓으면 그 높이에 서요)
- 우클릭: 그 펫 끄기

## 펫 대사 바꾸기

펫들은 시간대별로 인사하고(아침/점심/오후/저녁/밤), 가끔 자기들끼리 대화해요.
대사는 `~/.clawd-pet/lines.txt`에 있어요. 고친 뒤 **펫 모두 켜기**를 누르면 적용돼요.

```bash
open -e ~/.clawd-pet/lines.txt
```

### 오늘의 트렌드로 AI 대화

펫끼리 대화의 절반은 [요즘 뭐 떠?](https://storage.googleapis.com/benyco-trends-kr/index.html) 인기 검색어를 주제로 Claude(Haiku)가 만든 대화예요.
맥북에 Claude Code(`claude` 명령)가 설치·로그인돼 있어야 해요. 없으면 기존 대사만 써요.
최대 10분에 한 번 Claude를 불러 대화 6개씩 만들어 둬요. 말투·규칙은 `~/.clawd-pet/ai-prompt.txt`에서 고칠 수 있어요.

## 모두 켜기/끄기 버튼

설치하면 바탕화면에 **펫 모두 켜기**, **펫 모두 끄기**가 생겨요. 더블클릭하면 돼요.
터미널에서 하려면 아래 명령을 쓰세요.

## 모두 한번에 끄기

```bash
pkill -x clawd-pet
```

## 모두 한번에 켜기

```bash
launchctl kickstart -k gui/$(id -u)/com.clawd.pet
```

## 완전히 지우기

```bash
launchctl unload ~/Library/LaunchAgents/com.clawd.pet.plist; rm ~/Library/LaunchAgents/com.clawd.pet.plist; rm -rf ~/.clawd-pet
```

그다음 `~/.claude/settings.json`의 `hooks.Stop`에서 `touch ~/.clawd-pet/done` 항목을 지우세요.

## Windows

`windows/` 폴더를 원하는 곳(예: `문서`)에 두고, 그 폴더에서 PowerShell로 실행하세요. 펫은 그 폴더에서 실행되니 설치 후 폴더를 옮기지 마세요.

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

- 특정 펫만: `install.ps1 white black`
- 로그인할 때 자동 실행(시작프로그램), 바탕화면에 **펫 모두 켜기/끄기** 바로가기가 생겨요
- Claude Code 완료 훅을 `~/.claude/settings.json`에 추가해요 (원본은 `settings.json.bak`으로 백업)
- 대사: `clawd-pet-lines.txt`, AI 대화 지시문: `clawd-pet-ai-prompt.txt` (고친 뒤 펫 모두 켜기)
- 완전히 지우기: 시작프로그램 폴더(`shell:startup`)의 `clawd-pet-*.lnk`, 바탕화면 바로가기 2개, `%LOCALAPPDATA%\clawd-pet`를 지우고 `settings.json`의 `hooks.Stop`에서 `clawd-pet-notify.ps1` 항목을 지우세요
