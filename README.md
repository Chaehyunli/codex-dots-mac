# Dots · 우사기 0.3.1 — Swift macOS 독립 펫

마우스와 로컬 작업 이벤트에 반응하는 Swift/AppKit 데스크톱 펫입니다. 현재 소스는 **개인용 0.3.1**이며, 캐릭터 위에 커서를 올리면 랩 댄스를 추는 기능이 포함됩니다. 이전 공유용 ZIP은 0.3.0으로 유지되어 있으므로 최신 개발을 이어가려면 ZIP이 아닌 이 저장소를 사용하세요.

## GitHub Private 저장소로 관리하기

**이 README가 있는 `Dots-source` 폴더 자체가 저장소 루트입니다.** 상위 `outputs` 전체나 이 대화의 작업 폴더 전체를 올리지 마세요. `outputs`라는 이름 자체가 Git 업로드를 금지하는 것은 아닙니다. 이 프로젝트는 소스가 그 아래에 저장되어 있을 뿐입니다.

장기 작업에는 이 폴더를 별도 개발 경로(예: `~/Developer/Dots`)로 복사하고 그곳에서 Git을 초기화하는 것을 권장합니다. 아직 자동 이동·Git 초기화·GitHub 업로드는 하지 않았습니다. 기존 앱과 훅 경로를 유지하려면 원래 앱은 그대로 두고 개발 폴더만 복사하세요.

```text
Dots/                       ← 저장소 루트
├── Sources/                # Swift 앱 코드 — 포함
├── Resources/              # 스프라이트·아이콘·애니메이션 정보 — 포함
├── Tools/                  # 에셋 패킹·훅 등록 도구의 소스 — 포함
├── Info.plist
├── Package.swift
├── build.sh
├── .gitignore
├── README.md 및 기타 문서
├── .build/                 # 컴파일 캐시 — 제외
└── dist/                   # 각 컴퓨터에서 빌드한 앱 — 제외
```

`Resources/spritesheet.webp`, `animations.json`, `keyposes.png`, `Dots.icns`는 빌드/개발에 필요한 **프로젝트 에셋**이므로 Git에 포함해야 합니다. PNG/WebP 전체를 ignore하면 다른 컴퓨터에서 캐릭터를 표시하거나 재패킹할 수 없습니다. `.app`, ZIP, 캐시, 개인 훅 설정, 인증서와 비밀 값은 포함하지 않습니다. `rap-keyposes-v3.png`와 과거 문서는 이력 참고 자료이며 현재 앱에는 사용하지 않습니다.

### 첫 업로드

1. GitHub에서 빈 저장소를 만들고 Visibility를 **Private**으로 선택합니다. 로컬 README/.gitignore가 있으므로 원격 저장소에서 초기 파일은 만들지 않습니다.
2. 아래 명령은 복사한 `Dots` 폴더 안에서 실행합니다. `YOUR_ACCOUNT`와 `YOUR_REPOSITORY`는 실제 값으로 바꿉니다.

```sh
git init -b main
git add .
git status --short
git diff --cached --stat
# 목록에 앱, 캐시, 개인 설정, 비밀 값이 없는지 확인한 뒤 진행
git commit -m "Initial Dots 0.3.1 source"
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin main
```

GitHub 인증은 사용자의 Git 자격 증명 도구/SSH 등을 사용하세요. 토큰을 코드·README·원격 URL에 직접 넣지 마세요. Private 저장소라도 캐릭터의 권리나 재배포 허가가 자동으로 생기지는 않습니다.

## 다른 Mac에서 이어서 개발

Apple Silicon Mac, macOS 13 이상 대상입니다. 빌드에는 Xcode Command Line Tools와 Swift 컴파일러가 필요합니다. 이 버전의 검증 환경은 macOS 26.5.1 / Swift 6.3.3입니다. Intel/Windows용 빌드가 아닙니다.

```sh
# 개발 도구가 없는 Mac에서 한 번 실행하고 설치를 완료
xcode-select --install

git clone https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git Dots
cd Dots
zsh build.sh ./dist/Dots.app
open ./dist/Dots.app
```

`build.sh`는 컴파일, 리소스 복사, 로컬 ad-hoc 서명, 자동 테스트를 수행합니다. 저장소에 이미지가 포함되어 있으므로 일반 빌드에는 이미지 생성 API·Python·cwebp가 필요하지 않습니다. `Package.swift`만으로 실행하면 리소스 앱 번들이 구성되지 않으므로 **앱 제작은 build.sh를 사용**하세요. 다시 빌드할 때는 실행 중인 Dots를 먼저 종료합니다.

추가 확인:

```sh
./dist/Dots.app/Contents/MacOS/Dots --self-test
codesign --verify --deep --strict ./dist/Dots.app
```

손쉬운 사용 권한, GPT 훅 등록/신뢰, 로그인 시 실행 여부는 **컴퓨터별 설정**이므로 Git clone으로 이전되지 않습니다. 새 Mac에서는 [GPT-CONNECTION.md](GPT-CONNECTION.md)와 [SHARING.md](SHARING.md)를 따라 새 앱 경로로 설정하세요. 사용자 hooks.json이나 신뢰 저장소를 저장소에 복사하지 마세요. 앱을 `dist`에서 응용 프로그램 폴더로 옮길 계획이라면 최종 위치를 정한 뒤 훅을 등록합니다.

### 두 컴퓨터 사이에서 동기화

작업 시작 전 `git pull --ff-only`, 작업을 마친 뒤 변경 내용을 검토하고 커밋·푸시합니다. 다른 Mac에서는 pull 후 다시 빌드합니다. GitHub는 **소스와 에셋을 동기화**하며, 실행 중인 앱을 자동 업데이트하지 않습니다. 로컬 변경이나 충돌이 있으면 먼저 보존·해결하고 강제 덮어쓰기를 하지 마세요.

```sh
git pull --ff-only
# 코드 수정 및 테스트
git add Sources Resources Tools Info.plist README.md
git diff --cached
git commit -m "Describe the change"
git push
```

---

## 기능 및 기존 사용 안내

공유·설치·재부팅 후 실행 방법은 [SHARING.md](SHARING.md)를 보세요. 0.3은 승인된 원본 키포즈만 사용하며, Pets에서 새로 생성한 그림이나 rap-v3 재생성 그림은 실행 리소스에 사용하지 않습니다. 랩은 정면 좌우 반복으로 정리했습니다. 휴식·기상은 원본 그림을 40도 회전하고 되돌리는 Swift 렌더링 전환입니다(새 팔다리 포즈 생성 아님).

이 앱은 **ChatGPT 내장 dots/Pets가 아닌 독립 macOS 앱**입니다. 텍스트·음성 입력, LLM 호출, 로그인은 없습니다. v0.2는 로컬 Codex 앱 및 VS Code의 OpenAI Codex 확장에서 보내는 작업 이벤트를 수신합니다. **훅 등록과 사용자 신뢰 검토가 필요**하며, 다른 VS Code AI 확장이나 원격/클라우드 실행은 포함하지 않습니다. 자세한 연결 절차는 `GPT-CONNECTION.md`를 보세요.

## 실행

상위 폴더의 `Dots.app`을 열면 캐릭터와 메뉴 막대 토끼 아이콘이 나타납니다. Apple Silicon용이며 macOS 13 이상을 대상으로 빌드했습니다. 실제 실행 검증은 macOS 26.5.1에서 했습니다. 개발용 ad-hoc 서명이고 Apple 공증/배포용 서명은 아닙니다.

| 입력 / 상황 | 현재 동작 |
| --- | --- |
| 캐릭터 클릭 | 빙글빙글 회전. 연속 입력은 재시작 없이 한 번만 추가 회전 |
| 우클릭 → 인어섬 랩 | 약 5초 댄스 미리보기. 선글라스·체인, 바닥 이퀄라이저 |
| GPT 응답 생성 시작 | 도입부 후 랩 핵심 구간을 계속 반복 |
| GPT 완료·중단·세션 종료 | 진행 중인 다른 작업이 없으면 자동 댄스 종료 |
| 응답 생성 중 캐릭터 클릭 | 잠시 회전 → 작업이 계속 중이면 댄스로 복귀 |
| 빈 바탕화면 클릭 | 손쉬운 사용 권한이 있을 때 클릭 지점으로 달려오기 |
| 캐릭터 드래그 | 진행 동작 취소 → 이동 → 착지 |
| 머리 위 커서 좌우 왕복 | 쓰다듬기. 1.2초 안에 방향 전환 3회 |
| 30초 / 90초 무입력 | 대각선으로 눕기 / 같은 자세로 깜빡이며 쉬기 |
| 누운 캐릭터 클릭 | 부드럽게 일어나기 → 회전 |
| 휠 스크롤 | 동작 없음. 기존 회전 입력을 클릭으로 이전 |

바탕화면 이동은 캐릭터가 있는 모니터에서만 시작합니다. 다른 모니터에는 드래그로 옮길 수 있습니다. 이동 목표는 화면 경계 안으로 제한됩니다. 수동 랩/회전 중 바탕화면을 연속 클릭하면 마지막 목적지만 보관합니다. GPT 자동 댄스 중에는 이동을 먼저 수행한 뒤 춤으로 복귀합니다. 드래그가 항상 우선입니다.

## 권한과 개인정보

클릭·회전·드래그·메뉴는 별도 권한 없이 동작합니다. 바탕화면 따라오기는 메뉴 → 사용 방법 / 권한 → 바탕화면 따라오기 설정에서 **사용자가 직접** 손쉬운 사용 권한을 허용해야 합니다. 권한을 강제로 설정하거나 보안 정책을 우회하지 않습니다.

바탕화면 감지는 창 경계와 Finder 접근성 요소의 역할/파일 URL 존재 여부를 확인합니다. 모호한 위치는 무시합니다. 다른 앱의 창, 파일 아이콘, 드래그 선택에는 반응하지 않도록 설계했습니다. 키보드 감시, 화면 녹화, 대화 내용 수집, 네트워크 요청, 자동 시작 등록은 없습니다. 실제 권한을 켠 환경에서 바탕화면/파일 구분 검증은 아직 필요합니다.

## 설정

캐릭터 우클릭 또는 메뉴 막대 토끼 아이콘: 랩, 회전, 쉬기, 멈추기, 바탕화면 따라오기, 집중 모드, GPT 자동 댄스, 연동 데모, 작업 상태 초기화, 추임새 말풍선, 효과음, 움직임 줄이기, 크기, 숨기기, 종료. 수동 멈춤/쉬기는 현재 작업의 자동 춤을 억제하고, 모든 작업이 종료된 후 새로운 작업이 시작되면 자동 춤이 다시 활성화됩니다.

말풍선·효과음 기본값은 꺼짐입니다. 효과음은 macOS Pop이며 원작 음성/음악이 아닙니다. 원작 영상의 정확한 안무·오디오 복제본이 아니라 참고 이미지와 콘셉트에 기반한 생성 스프라이트 프로토타입입니다.

## 에셋

- `Resources/spritesheet.webp`: 투명 lossless WebP, 3072×3584, 256×256 셀, 12열×14행.
- `Resources/animations.json`: 160개 재생 셀의 모션별 인덱스, FPS, 루프 여부, 선택적 프레임 유지 시간.
- 실제 생성 키포즈는 64개. 반복 유지 프레임과 좌우 달리기 미러링을 포함하여 160개 셀로 구성했습니다. 마지막 8셀은 비어 있습니다.
- `Resources/keyposes.png`: 생성 원본. `ART-PROMPTS.md`: ImageGen 프롬프트.
- `Tools/pack-sprites.swift`: 몸체 연결 성분을 분리하고 발 기준선과 회전 중심을 정렬하는 기계적 패킹 도구.

ImageGen으로 원화를 생성·수정하고 Swift/CoreGraphics로 분리·정렬했습니다. 이 캐릭터의 권리를 부여하는 패키지가 아니므로 공개 배포·상업 이용 전 권리 검토가 별도로 필요합니다.

## 개발 / 테스트

Xcode Command Line Tools 설치 후 소스 폴더에서:

```sh
zsh build.sh
../Dots.app/Contents/MacOS/Dots --self-test
```

`build.sh`는 기본적으로 상위 `Dots.app`을 다시 빌드하므로 실행 중인 앱을 먼저 종료하세요. 외부 라이브러리는 없습니다. Swift 6.3.3에서 Swift 5 언어 모드로 빌드했습니다.

- `Engine.swift`: 순수 상태 머신. `click(at:)`은 회전, `rap(at:)`은 별도 댄스 진입점.
- `Sprites.swift`: WebP 디코딩, 알파 기반 클릭 판정, 렌더링, 마우스 입력.
- `Desktop.swift`: 수동 전역 마우스 감지와 Finder 배경 구분.
- `App.swift`: 투명 비활성 패널, 메뉴, 설정, 타이머, 화면 경계.
- `Activity.swift`: 훅 입력에서 ID와 이벤트 종류만 선택, ID SHA-256 처리, 로컬 프로세스 간 알림, 동시 작업 추적.
- `Tools/HookConfig.swift`: 기존 훅을 보존하는 등록·제거 도구. 신뢰 설정에는 손대지 않습니다.

자동 테스트는 WebP 디코딩, 프레임 범위, 이동/도착, 마지막 목적지 우선, 클릭 회전, 드래그 취소/착지, 집중 모드, 휴식/수면 전환, 응답 중 루프, 완료 시 종료, 이벤트 중복/역순, 여러 작업 중첩, 대화 내용 제외를 검사합니다. `--bridge-self-test`는 테스트 전용 채널에서 별도 프로세스의 실제 로컬 이벤트 전달을 확인합니다. macOS 프로세스 간 알림을 막는 셸 샌드박스에서는 이 테스트가 실패할 수 있습니다. 보안 설정을 끄지 마세요.

## 지원 범위

같은 Mac/사용자 계정/Codex 설정을 사용하는 로컬 Codex 앱과 OpenAI Codex IDE 확장을 대상으로 합니다. 공식 [Hooks 문서](https://learn.chatgpt.com/docs/hooks)의 신뢰 검토가 필요합니다. 이는 '제출부터 작업 완료까지'의 표시이므로 도구 실행이나 승인 대기 시간도 포함합니다. 실제 토큰 생성 구간만 감지하지는 않습니다. 자세한 제한과 검증 상태는 `GPT-CONNECTION.md`에 기록합니다.
