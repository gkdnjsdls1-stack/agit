# 아지트 광산

초등 2학년 딸을 위한 보석 깨기 게임. 모바일 세로, 웹.
게임 설계와 그동안의 결정은 [아지트-기획서.md](아지트-기획서.md)에 있다.

---

## 폴더에 뭐가 있나

**게임에 필요한 것** (올릴 때 이것만 있으면 된다, 약 5.7MB)

```
index.html          게임 전부. 라이브러리 없음, 빌드 없음
manifest.json       홈 화면 추가용
icon-180/192/512.png
art/
  bg-mine.png       광산 배경
  bg-pasture.png    목장 배경
  bg-agit.png       아지트 배경
  sprites/          투명 PNG 12장 (캐릭터 6, 동물 3, 아지트 3단계)
```

**나중에 다시 만들 때 필요한 것**

```
art/anchor-a.png    1번 캐릭터 원본 (스타일 기준)
art/sheet-b.png     캐릭터 6인 시트 원본
art/animals2-b.png  동물 3종 시트 원본
art/agit-a.png      아지트 3단계 시트 원본
art/rejected/       탈락한 생성본들
tools/              아래 참고
```

---

## 로컬에서 보기

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools/serve.ps1
```

그다음 브라우저에서 `http://localhost:8765/` 를 연다.
**파일을 더블클릭해 여는 건 안 된다** — `file://` 에서는 배경과 스프라이트가 막힌다.

---

## 폰에 올리기

정적 파일만 있으면 되므로 아무 호스팅이나 된다. GitHub Pages 기준:

1. 저장소를 만들고 이 폴더를 그대로 올린다
2. Settings → Pages → Branch를 `main` / `/ (root)` 로
3. 폰 브라우저로 주소를 열고 **공유 → 홈 화면에 추가**

`art/rejected/` 와 원본 시트들은 안 올려도 게임은 돈다. (올려도 11MB쯤이라 상관은 없다.)

### 홈 화면 추가에 대해

- iOS는 매니페스트 없이도 추가되고 `icon-180.png`를 쓴다
- Android는 `manifest.json`을 읽는다. **`.webmanifest` 확장자로 바꾸지 말 것** — 호스트가 엉뚱한 MIME 타입으로 내보내면 Chrome이 거부한다
- **오프라인 실행은 안 된다.** 서비스 워커를 일부러 안 넣었다. 캐시가 묵으면 고칠 때마다 아이 폰에 옛 버전이 남는다. 다 만든 뒤에 넣는 게 맞다

---

## 숫자 바꾸기

`index.html` 안의 `--- tuning ---` 블록 하나에 모여 있다.

| 상수 | 지금 | 뜻 |
|---|---|---|
| `DAILY_GEMS` | 30 | 하루에 깰 수 있는 보석. 다 깨면 광산이 잠든다 |
| `BASE_CRACKS` | 4 | 보석 하나에 필요한 타격 수 |
| `SHARDS_PER_GEM` | 12 | 보석 하나에서 나오는 조각 |
| `JAR_BASE` / `JAR_STEP` | 30 / 18 | 친구 한 명에 필요한 조각 (뒤로 갈수록 +18) |
| `GROW` | 4 | 풀이 다 자라는 데 필요한 보석 수 |
| `STAGE_AT` | [3, 6] | 아지트가 2단계·3단계가 되는 친구 수 |

**아이를 보기 전에 미리 조이지 말 것.** 전부 D6에 정하기로 한 값들이다.

---

## 그림 다시 뽑기

```bash
# 시트에서 투명 PNG 잘라내기
powershell -File tools/cut-sprites.ps1 -In art/sheet-b.png -OutDir art/sprites -Prefix char -MinCol 110 -MinGap 4 -MinWidth 60 -Inset 14

# 홈 화면 아이콘
powershell -File tools/make-icons.ps1
```

캐릭터 시트는 머리카락이 서로 닿아 있어 `-Inset 14`가 필요하다. 동물·아지트 시트는 떨어져 있어 없어도 된다.

새 그림을 AI로 뽑을 때의 규칙(스타일 고정 문장, 시트로 한 번에 뽑기, 동물에는 캐릭터 레퍼런스 물리지 말 것)은 기획서 §10에 있다.

---

## 아이에게 주기 전에

진행 상황은 브라우저의 `localStorage`(`agit.save.v1`)에 저장된다. **브라우저 데이터를 지우면 날아간다.** 모은 친구와 지어준 이름이 다 사라지니, 폰 정리할 때 주의.

도감 안의 `처음부터`는 두 번 눌러야 지워진다. 그래도 그게 거기 있다는 건 알고 계실 것.
