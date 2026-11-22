# Bảng tự chủ (phần 5.2): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `make autonomy` in ra bảng «bạn được gọi khi nào», tính từ trạng thái thật của kho, ở cả
hai bậc; mỗi lần máy gọi người (`tools/autonomy.py`, danh sách «Yours» của `tools/outside.py`) đều
nêu đúng dòng của bảng gây ra và công tắc của nó.

**Architecture:**
- Mỗi dòng của bảng có **một nơi viết**, là công cụ đã biết sự việc đó:
  - `tools/autonomy.py` có `card_row(policy, tier, reason)`: dòng ứng với một hạng và lý do của nó.
    Hàm nằm trong chính `autonomy.py` vì job `tier` của `pr-pipeline.yml` chỉ chép
    `autonomy.py`, `repo_ontology.py` và `autonomy.yaml` từ nhánh gốc vào một thư mục riêng: không
    được thêm một lệnh import nào.
  - `tools/outside.py` có `card(lists)`: các dòng của việc ngoài kho, đưa vào `status --json` dưới
    khoá `card`, và in cạnh danh sách «Yours».
  - `tools/autonomy_card.py` (mới, bậc `starter` của `_core`, nên có ở mọi kho) chỉ **gom**: gọi
    `card_row` cho các cặp hạng và lý do mà chính sách có thể sinh ra, chạy
    `python3 tools/outside.py status --json` rồi lấy khoá `card`, đếm action của `ontology/`.
- Không tệp nào được ghi. `make autonomy` không nằm trong `make check` (nó hỏi GitHub qua
  `tools/outside.py`).
- Bậc `starter`, và kho `claude-plugin` (không có `ontology/`, không có `tools/repo_ontology.py` ở
  bậc này): `autonomy_card.py` chỉ import `autonomy` và `ontology_actions` bên trong hàm, khi tệp có.

**Tech Stack:** Python 3.11+ thư viện chuẩn; bash (`tests/run.sh` nạp `tests/autonomy_card.sh`, mục 54).

**Spec:** [docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md](../specs/2026-11-22-outside-work-and-autonomy-card-design.md),
mục 1 («Xong là», gạch thứ ba), 2, 5.2, 6 (gạch «Bảng tự chủ»), 7.

## Global Constraints

- Mã, mẫu, tên tệp, đầu ra của công cụ bằng tiếng Anh; tài liệu trong `docs/` bằng tiếng Việt.
- Công cụ sinh ra chỉ dùng thư viện chuẩn của Python 3.11 trở lên; qua ruff của kho python sinh ra
  (48zi).
- Không thêm câu hỏi lúc dựng, không thêm lần nào người xuất hiện, không luật `ask`, không chặn theo
  mẫu lệnh Bash (mục 43).
- «Không biết thì ghi không biết»: một dòng không kiểm được mang `"known": false` và lý do, không bao
  giờ là đã đủ.
- Mỗi mục danh sách trong một mảnh `+AGENTS.md/` có đúng một nhãn `<!-- kept: ... -->` (50m).
- `CHANGELOG.md`: thêm dòng mới ngay dưới `## Unreleased`, không sửa mục của PR khác.
- Một dòng của bảng, ở mọi công cụ, là một dict đúng sáu khoá:
  `{"when": str, "you_do": str, "why": str, "switch": str, "keys": str, "known": bool}`.
  `switch` là `"-"` khi dòng đó luôn là của người. Một việc máy làm là `{"what": str, "keys": str}`.

## Các phán quyết của người dựng (mục 9 của thiết kế để người dựng quyết)

1. **Hình của bảng (`--json`):** `{"level": "starter" | "team", "called": [row], "machine": [item],
   "not_allowed": [item], "next_level": [item]}`. `not_allowed` là các action của `ontology/` agent
   không được chạy; `next_level` chỉ có ở bậc `starter`. Văn bản in bốn phần đó theo thứ tự, phần rỗng
   thì bỏ.
2. **Bậc của kho:** `level` của `.repo-setup.json`; thiếu hay không đọc được thì `team` khi có
   `governance/autonomy.yaml`, không thì `starter`, và bảng ghi một mục `machine` nói nó đoán từ tệp.
3. **Dòng của chính sách** do `card_row` viết, khoá theo `reason` mà `classify` đã dùng:

   | `reason` | `when` | `why` | `switch` |
   | --- | --- | --- | --- |
   | `protected path` | `The rules change` | `always yours` (+ `; one owner: kept by word, the machine opens pull requests as you` khi `sole_decider`) | `-` |
   | `default` | `Product code merges` | `no machine proof yet` khi không có `proof_check`; không thì `default: <tier>` | `name a proof check (proof.check), then default: low`; hay `default: low` khi đã có proof |
   | `removes, rewrites or disables test code` | `A change removes, rewrites or disables test code` | `a guard was loosened` | `-` |
   | `loosens what agents may do` | `A change lets agents do more in the product` | `a guard was loosened` | `-` |
   | `dependency update (<level>)` | `A dependency update (<level>)` | `rules.dependency_updates: <level> is <tier>` | `rules.dependency_updates.<level>: low` |

   `you_do`: hạng `high` → `merge the pull request` khi `sole_decider`, không thì
   `approve the pull request (code owner)`; hạng `medium` → `merge`. Hạng `low` → `card_row` trả
   `None`. Lý do khác (dự phòng): `when` = `A change merges`, `why` = lý do, `switch` = `-`.
   `keys` nêu `governance/autonomy.yaml:` và khoá đứng sau dòng.
4. **Các cặp bảng hỏi `card_row`** ở bậc `team`: `("high", "protected path")`;
   `(default_tier, "default")`; `(rules.test_deletions_raise_to, "removes, ...")`;
   `(rules.agent_guard_removals_raise_to, "loosens ...")`; và mỗi mức của `rules.dependency_updates`
   khi có `.github/dependabot.yml`. Cặp nào cho `None` (hạng `low`) thành một mục `machine`.
5. **Dòng của việc ngoài kho** (`outside.card`): mỗi `decision` một dòng (`when` = khoá `when` của
   dòng sổ, mà `classify` đã đặt vào `Row.why`; `you_do` = `decide`, `why` = `always yours`); «Yours» gom theo loại: khoá thiếu (`enter
   once`, `a machine cannot create them`, switch `python3 tools/outside.py secrets`), khoá chỉ có ở một
   nơi (`decide`), `action` (`do once`, `no machine can do it`), `setting` chỉ kiểm, tức các bức tường
   (`say go after the dry run`, `the walls change only with your go-ahead`, switch `-`); «Unknown» gom
   thành một dòng `known: false`, `why` là `unknown: ` + mọi lý do khác nhau, mỗi lý do một lần, nối bằng `; `, switch `python3 tools/outside.py status`;
   «Refused» một dòng. `apply`, `ok`, `unmerged` thành mục `machine`, có đếm; riêng `ok` tách đôi: dòng
   đã kiểm thì «N rows in place», dòng người ghi tay (`done`, `why` mở bằng `recorded by hand`) thì «N rows a person
   recorded as done; no machine checks them», không bao giờ tính vào «in place».
6. **Khi `tools/outside.py` không trả JSON** (thoát 2, không có tệp, quá `OUTSIDE_CARD_TIMEOUT = 120`
   giây): một dòng `known: false`, `when` = `Work outside the repository`, `why` = `unknown: ` + dòng
   cuối của stderr hay lý do. Bảng vẫn thoát 0.
7. **Bậc `starter`:** dòng `Any change merges` (`merge`, `no policy at the starter level: every merge is
   yours`, switch `the team level: re-run repo-setup with --level team`); khi `.claude/settings.json`
   có dòng `Edit(...)` trong `deny`, thêm dòng `A change to <các đường dẫn đó>` (`you edit it`,
   `the session may not edit it (.claude/settings.json)`, cùng switch). `machine`: `ci.yml` khi tệp có.
   `next_level`: ba mục (tài liệu và bài kiểm tự gộp; sổ việc ngoài kho; máy soạn thay đổi luật, người
   duyệt).
8. **`ontology/`:** `ontology_actions.load_actions(root)`; `agent` thiếu là `forbidden`, như
   `ontology_actions` đã coi. Có action `confirm` → một dòng `called` (`An agent runs one of <n>
   product actions marked confirm`, `confirm it when it asks`, switch `agent: allowed on that action`);
   có action `forbidden` → một mục `not_allowed`. Không có `ontology/actions.yaml` hay không import được
   → bỏ phần này.
9. **Mã thoát của `autonomy_card.py`:** 0 khi in được bảng (kể cả có dòng không biết); 2 khi không ở
   trong một kho git hay gọi sai.
10. **Các lớp đang bật** (`capabilities`, `deploy` của `.repo-setup.json`), bậc `team`:
    `github-agents` → mục `machine` `an agent on GitHub works on issues and pull requests; its merges
    follow the same tiers`. Có `.github/workflows/deploy.yml`, câu về deploy staging đọc `id` ở MỌI danh
    sách của `outside.py status --json` (cả `value` mà sổ đã đọc, không đọc TOML lần hai):
    `deploys to staging after each merge` chỉ khi một dòng ở `ok` có `id` đúng `github-variable:DEPLOY_ENABLED`
    (có thể kèm `@env`), phép kiểm đã chạy (không phải «not checked») và `value` là `"true"` (deploy.yml chỉ
    chạy khi `vars.DEPLOY_ENABLED == 'true'`); `value` khác (như `"false"`) → `staging deploys are paused`; dòng ở
    `refused`, `unknown` hay ở `ok` mà không phải biến đã kiểm → `not known`; ở `apply`, `yours`, `decisions`,
    `unmerged` → `wait`; `staging deploys are off: add a DEPLOY_ENABLED row ...` chỉ khi không danh sách nào có
    dòng đó (thiết kế 5.1: kit không gieo dòng đó).
11. **Câu «gộp khi check xanh»** chỉ nói máy gộp khi kho có `github-agents` (chỉ khi đó có auto-merge). Không có
    thì mục nói `may merge with no approval once the checks are green; nothing merges it for you`; không đọc
    được `.repo-setup.json` thì dùng câu đó và thêm một dòng `known: false`, không bao giờ khẳng định việc gộp.

## Review Focus

- Kho bậc `team` không có `gh` hay chưa đăng nhập: bảng vẫn in các dòng của chính sách, các dòng cần
  GitHub là `known: false` kèm lý do, thoát 0. → Task 4 (54d).
- Chính sách bị từ chối (`default: low` không có `proof.check`): bảng không được nói máy tự gộp mã sản
  phẩm; dòng `Product code merges` còn, `why` là `no machine proof yet`. → Task 4 (54c).
- Job `tier` của CI chép riêng `autonomy.py` vào một thư mục khác: nó vẫn chạy, và có `card`. → Task 1 (54e).
- Kho `claude-plugin` bậc `starter` (không `ontology/`, không `repo_ontology.py`): bảng chạy, không
  có phần `ontology`. → Task 3 (54a).
- Chạy bảng không để lại gì: `git status --porcelain` trước và sau như nhau, kể cả khi
  `.repo-setup.json` bị xoá. → Task 3 (54a).

---

### Task 1: Dòng của chính sách trong `autonomy.py`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/autonomy.py` (`card_row`, `classify`, `write_github`)
- Create: `tests/autonomy_card.sh` (mục 54), nạp ở cuối `tests/run.sh` sau `tests/autonomy_change.sh`

**Interfaces:**
- Produces: `autonomy.card_row(policy: dict[str, Any], tier: str, reason: str, own: tuple[str, ...] = OWN_CHECKS) -> dict[str, Any] | None`;
  kết quả `classify(...)` có thêm khoá `"card"`: `card_row` của hạng chung với `reason` của tệp đầu
  tiên mang hạng đó (`None` khi không có tệp).

- [ ] **Step 1: Bài đỏ 54e.** Dựng kho `python` bậc `team` (`owner=acme`), như `ac_install` của 53.
  - `--files src/a/x.py`: `card.when == "Product code merges"`, `card.you_do == "merge"`,
    `"proof.check" in card.switch`, đủ sáu khoá, `card.known is True`.
  - `--files governance/autonomy.yaml`: `card.when == "The rules change"`,
    `card.you_do == "merge the pull request"`, `"one owner" in card.why`, `card.switch == "-"`.
    Với `owners.high: ["@acme", "@lan"]` (sửa bằng `--policy` trên một bản sao):
    `card.you_do == "approve the pull request (code owner)"`, không có `one owner`.
  - `--files docs/x.md`: `card is None`.
  - `--files tests/test_x.py` với một tệp xoá dòng (dựng qua `--base` trên hai commit):
    `card.why == "a guard was loosened"`.
  - `--github` với `GITHUB_STEP_SUMMARY` trỏ vào một tệp: tệp có `To be called less`.
  - Chép riêng `tools/autonomy.py`, `tools/repo_ontology.py`, `governance/autonomy.yaml` vào một thư
    mục tạm, chạy `--policy` từ đó như `pr-pipeline.yml`: thoát 0, có `card`.
- [ ] **Step 2:** `bash tests/run.sh > $SCRATCH/run.log 2>&1`; thấy FAIL ở 54e.
- [ ] **Step 3:** viết `card_row` theo phán quyết 3; `classify` gắn `card`; `write_github` thêm một
  dòng `You are called: <when>. You do: <you_do>. Why: <why>. To be called less: <switch>.` khi `card`
  không phải `None`.
- [ ] **Step 4:** chạy lại; 54e xanh, 43, 44, 53 vẫn xanh; ruff (48zi) xanh.
- [ ] **Step 5:** commit `feat: the autonomy gate names the row of the card that calls a person`.

### Task 2: Dòng của việc ngoài kho trong `outside.py`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/outside.py` (`card`, `_status_command`, `print_text`)
- Test: `tests/autonomy_card.sh` 54f

**Interfaces:**
- Produces: `outside.card(lists: dict[str, list[Row]]) -> dict[str, list[dict[str, Any]]]`, khoá
  `"called"` (dòng sáu khoá) và `"machine"` (mục `what`, `keys`); `status --json` có thêm khoá
  `"card"` là giá trị đó.

- [ ] **Step 1: Bài đỏ 54f.** Kho `team` có `github-agents`, không có máy chủ (đọc cây làm việc), thêm
  vào `ops/outside.toml` một dòng `decision = "approve-production"`, `when = "each deploy to
  production"`. `gh` thay thế trên `PATH`: một script in rỗng và thoát 0. `status --json`:
  - `card.called` có dòng `when == "2 keys are missing"` (`RELEASE_PLEASE_TOKEN`,
    `CLAUDE_CODE_OAUTH_TOKEN`), `switch == "python3 tools/outside.py secrets"`;
  - có dòng `when == "each deploy to production"`, `why == "always yours"`, `switch == "-"`;
  - có dòng `you_do == "do once"` nêu `install-claude-github-app` trong `keys`;
  - mọi dòng đủ sáu khoá; các khoá cũ của JSON (`base`, `ok`, `apply`, `yours`, ...) còn nguyên.
  - Văn bản (`status`): ngay dưới tiêu đề `Yours` có một dòng bắt đầu bằng `  card: ` nêu
    `2 keys are missing`.
- [ ] **Step 2:** chạy, thấy FAIL.
- [ ] **Step 3:** viết `card` theo phán quyết 5; in dòng `card:` dưới tiêu đề của `yours`,
  `decisions`, `unknown`.
- [ ] **Step 4:** chạy; 54f xanh, mục 52 vẫn xanh.
- [ ] **Step 5:** commit `feat: the outside ledger names the row of the card behind each person's step`.

### Task 3: Bảng ở bậc `starter` và `make autonomy`

**Files:**
- Create: `plugins/repo-setup/presets/_core/starter/tools/autonomy_card.py`
- Create: `plugins/repo-setup/presets/_core/starter/mk/autonomy.mk`
- Test: `tests/autonomy_card.sh` 54a, 54g

**Interfaces:**
- Produces: `autonomy_card.build(root: Path) -> dict[str, Any]` (hình ở phán quyết 1);
  `autonomy_card.render(card: dict[str, Any], keys: bool = False) -> str`;
  `autonomy_card.main(argv: list[str] | None = None) -> int` với `--root`, `--json`, `--keys`;
  đích `make autonomy` chạy `python3 tools/autonomy_card.py`.

- [ ] **Step 1: Bài đỏ 54a.** Kho `python` bậc `starter`, và kho `claude-plugin` bậc `starter`.
  - `make autonomy` thoát 0, in `Autonomy card` và `You are called when`.
  - `--json`: `level == "starter"`; dòng `when == "Any change merges"` có `--level team` trong
    `switch`; dòng nêu `.github/workflows/` (đọc từ `deny` thật của `.claude/settings.json`);
    `machine` có mục nêu `ci.yml`; `next_level` có ba mục; mọi dòng đủ sáu khoá.
  - `--keys`: mỗi dòng có một dòng `keys: ` ngay dưới.
  - `git status --porcelain` như nhau trước và sau; xoá `.repo-setup.json` (đã commit) rồi chạy lại:
    vẫn `level == "starter"`, có mục nói bậc được đoán từ tệp.
  - Kho `claude-plugin`: thoát 0, không có phần `not_allowed`, không traceback trên stderr.
  - Gọi ngoài một kho git: thoát 2.
- [ ] **Step 2: Bài đỏ 54g.** Kho `python` bậc `starter`, ghi `ontology/actions.yaml` có ba action:
  một `agent: confirm`, một `agent: forbidden`, một không có `agent`. `--json`: dòng
  `when == "An agent runs one of 1 product actions marked confirm"`; `not_allowed` có một mục nêu
  `2`. Không có `ontology/actions.yaml`: không có hai phần đó.
- [ ] **Step 3:** chạy, thấy FAIL ở 54a, 54g.
- [ ] **Step 4:** viết `autonomy_card.py` (phán quyết 1, 2, 7, 8, 9) và `mk/autonomy.mk` (một đích
  `.PHONY`, có dòng `##` cho `make help`, không thêm vào `CHECK_TARGETS`). Văn bản: cột cố định,
  ô dài xuống dòng trong cột (`textwrap`), dòng `known: false` có `unknown: ` ở đầu `why`.
- [ ] **Step 5:** chạy; 54a, 54g xanh, 50s (bản dựng lại khớp) và ruff (48zi) xanh.
- [ ] **Step 6:** commit `feat: make autonomy draws when a person is called, at the starter level`.

### Task 4: Bảng ở bậc `team`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/tools/autonomy_card.py`
- Test: `tests/autonomy_card.sh` 54b, 54c, 54d

**Interfaces:**
- Consumes: `autonomy.card_row`, `autonomy.load_policy`, `autonomy.default_tier`,
  `autonomy.proof_check`, `autonomy.own_checks` (Task 1); các khoá `card` và `ok` của
  `outside.py status --json` (Task 2).

- [ ] **Step 1: Bài đỏ 54b.** Kho `python` bậc `team` có `github-agents`, cùng dòng `decision` và `gh`
  thay thế như 54f. `--json`:
  - `level == "team"`; dòng `The rules change` **bằng đúng** `card` của
    `tools/autonomy.py --files governance/autonomy.yaml` (một nguồn);
  - dòng `Product code merges`; dòng `2 keys are missing`; dòng `each deploy to production`;
  - `.github/dependabot.yml` có, chính sách mặc định: dòng `A dependency update (minor)` và
    `(major)`, mục `machine` nêu `patch`;
  - `machine` có mục nêu `docs/**`, mục nêu `an agent on GitHub`; không có `next_level`.
  - Kho `fastapi` bậc `team` có `--deploy container`: mục `machine` nêu `staging deploys are off`;
    thêm vào `ops/outside.toml` một dòng `github-variable` `DEPLOY_ENABLED` = `true` và cho `gh` thay
    thế in `DEPLOY_ENABLED=true`: mục đổi thành `deploys to staging after each merge`.
- [ ] **Step 2: Bài đỏ 54c**, mỗi biến thể một bản sao của `governance/autonomy.yaml` trong kho trên:
  - `proof.check: "evidence"`, `default: low`: không có dòng `Product code merges`; `machine` có mục
    nêu `evidence`;
  - `default: low`, `proof.check: ""` (bị từ chối): dòng `Product code merges` còn, `why == "no
    machine proof yet"`; không mục `machine` nào nói máy gộp mã sản phẩm;
  - `owners.high: ["@acme", "@lan"]`: dòng `The rules change` có `you_do == "approve the pull request (code owner)"`;
  - `rules.dependency_updates.minor: low`: không còn dòng `(minor)`, `machine` nêu `minor`.
- [ ] **Step 3: Bài đỏ 54d.**
  - `PATH` chỉ có một thư mục với `python3`, `git`, `make` (không `gh`): thoát 0; các dòng của chính
    sách còn; có ít nhất một dòng `known: false` mà `why` nêu `gh`.
  - Xoá `governance/outside.toml` (`outside.py` thoát 2): một dòng `when == "Work outside the
    repository"`, `known: false`; thoát 0.
  - `git status --porcelain` như nhau trước và sau.
- [ ] **Step 4:** chạy, thấy FAIL.
- [ ] **Step 5:** viết phần `team` (phán quyết 4, 6, 10): import `autonomy` trong hàm; chạy
  `[sys.executable, "tools/outside.py", "status", "--json"]` ở `root`, thoát 0 hay 1 là có JSON;
  thêm phần `ontology` như bậc `starter`.
- [ ] **Step 6:** chạy; 54b, 54c, 54d xanh; cả bộ xanh.
- [ ] **Step 7:** commit `feat: the team card reads the policy, the outside ledger and the layers`.

### Task 5: Luật, tài liệu, changelog

**Files:**
- Create: `plugins/repo-setup/presets/_core/starter/+AGENTS.md/50-autonomy-card.md`
- Modify: `plugins/repo-setup/presets/_core/starter/dot.claude/skills/review-change/SKILL.md` (bước 10)
- Modify: `plugins/repo-setup/presets/claude-plugin/starter/dot.claude/skills/review-change/SKILL.md` (bước 9)
- Modify: `plugins/repo-setup/skills/new/references/tour.md`
- Modify: `plugins/repo-setup/skills/explain/SKILL.md` (bảng tệp: thêm `tools/autonomy_card.py`)
- Modify: `CHANGELOG.md` (dưới `## Unreleased`)
- Test: `tests/autonomy_card.sh` 54h

- [ ] **Step 1: Bài đỏ 54h.**
  - `AGENTS.md` của kho `starter` và kho `team` có `make autonomy` và cụm `row of the autonomy card`,
    trong một mục mang `<!-- kept: word -->`.
  - Hai kỹ năng `review-change`, ở bước bậc tự chủ, nêu khoá `card`.
  - `tour.md` nêu `make autonomy` và nói không chép bảng vào `docs/START-HERE.md`.
  - `CHANGELOG.md`, giữa `## Unreleased` và tiêu đề `## ` kế tiếp: có `make autonomy` và
    `What breaks on upgrade`.
- [ ] **Step 2:** chạy, thấy FAIL.
- [ ] **Step 3:** viết. Luật, một mục: khi trao một việc cho người, nêu dòng của bảng tự chủ
  (`make autonomy`) gây ra lần gọi đó và công tắc của nó. Mục changelog nêu: tệp mới
  `tools/autonomy_card.py`, `mk/autonomy.mk`; một luật mới trong `AGENTS.md` ở cả hai bậc; JSON của
  `tools/autonomy.py` và của `outside.py status --json` có thêm khoá `card` (thêm, không bỏ gì).
- [ ] **Step 4:** chạy; 54h, 50m, 50n, 43g xanh.
- [ ] **Step 5:** commit `docs: every call of a person names its row of the autonomy card`.

### Task 6: Soát cả nhánh, sửa, mở PR

- [ ] Một lượt soát độc lập trên model mạnh nhất, đối chiếu mục 5.2 của thiết kế; mỗi phát hiện
  nghiêm trọng hay quan trọng có một bài đỏ rồi bản sửa.
- [ ] `bash tests/run.sh` xanh; `tests/e2e.sh` cho `python` và `python:none:none:github-agents`
  (`make autonomy` chạy trong kho thật).
- [ ] Đẩy nhánh `feat/autonomy-card`; `gh pr create` lên `main`; không gộp.
