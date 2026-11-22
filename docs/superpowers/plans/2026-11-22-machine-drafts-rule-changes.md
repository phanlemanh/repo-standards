# Máy soạn, người duyệt (phần 5.3): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ở bậc `team`, agent soạn được thay đổi ở `.github/workflows/` và `governance/` thành một PR
riêng, code owner quyết; ở kho một chủ, luật nhánh không đòi code owner duyệt và việc chủ kho bấm gộp
là duyệt.

**Architecture:**
- Một mẫu `settings.json.tmpl`, một chỗ trống `{{settings_edit_walls}}`: bậc `starter` nhận hai dòng
  chặn sửa, bậc `team` nhận chuỗi rỗng. Biến tính từ bậc trong `scripts/apply_plan.py`
  (`level_variables`), gọi ở cả hai đường dựng biến (lượt dựng của `apply.py` và `render_variables`
  mà lượt nâng cấp dùng để dựng lại bản gốc).
- `tools/autonomy.py` có `sole_decider(policy)`. `tools/github_setup.py` hỏi nó để bật hay tắt
  `require_code_owner_review`, và in lý do ở cả lượt chạy thử lẫn lượt áp. `tools/github_check.py`
  đã so mọi khoá của luật `pull_request`, nên `--check` thấy sự đổi mà không cần sửa.
- `scripts/doctor.py` hỏi chính `tools/autonomy.py` của kho được chấm: kho một chủ không bị chấm
  trượt vì thiếu code owner duyệt. Kho có công cụ cũ (chưa có hàm) thì vẫn đòi như nay, khớp với
  việc công cụ cũ của kho đó vẫn ghi luật đòi duyệt.
- Kỹ năng `.claude/skills/autonomy-change/SKILL.md` sinh ở bậc `team`.

**Tech Stack:** Python 3.11+ thư viện chuẩn; bash (`tests/run.sh` nạp `tests/autonomy_change.sh`).

**Spec:** [docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md](../specs/2026-11-22-outside-work-and-autonomy-card-design.md),
mục 5.3, 6, 7, 10. Phần 5.2 (bảng tự chủ) không dựng ở đây.

## Global Constraints

- Mã, mẫu, tên tệp, đầu ra bằng tiếng Anh; tài liệu trong `docs/` bằng tiếng Việt.
- Không thêm câu hỏi lúc dựng, không thêm lần nào người xuất hiện, không luật `ask`, không chặn theo
  mẫu lệnh Bash.
- Dòng chặn đọc bí mật (`Read(...)`) giữ nguyên ở cả hai bậc.
- Mỗi mục danh sách trong một mảnh `+AGENTS.md/` có đúng một nhãn `<!-- kept: ... -->` (50m).
- Công cụ sinh ra qua được cấu hình ruff của kho python sinh ra (48zi).
- `CHANGELOG.md`: thêm dòng mới ngay dưới `## Unreleased`, không sửa mục của PR khác.

## Các phán quyết của người dựng (mục 9 của thiết kế để người dựng quyết)

1. **«Một tài khoản»** là: `owners.high` nêu đúng một handle sau khi bỏ `@`, bỏ khoảng trắng, so
   không phân biệt hoa thường; và handle đó là người dùng, không phải đội (`@org/team` có thể là
   nhiều người). Danh sách rỗng hay không đọc được thì giữ code owner duyệt như nay.
2. **Chỉ xét `owners.high`**, đúng lời chủ kho. `owners.medium` không đổi phán quyết (ghi là chỗ nhỏ
   để lại: dòng `*` của CODEOWNERS cũng chịu luật code owner duyệt).
3. **Luật trong `AGENTS.md` tách hai mục**, vì mỗi mục một nhãn: «thay đổi ở đó là hạng high, code
   owner quyết» (`autonomy-gate`), và «PR riêng, không kèm thứ khác, không tự gộp; soạn theo kỹ năng
   autonomy-change» (`word`).
4. **Mảnh `github-agents`** (`60-ai-native-sdlc.md`) cũng nói «không bao giờ sửa ... (chặn trong
   settings.json)», điều không còn đúng ở bậc `team`: đổi theo cùng lời. Câu «viết spec, gắn
   `spec:needs-approval`» giữ cho trường hợp GitHub từ chối đẩy tệp workflow (token thiếu quyền
   `workflows`).
5. **README của plugin** và chú thích đầu `governance/autonomy.yaml.tmpl` đổi lời theo.

## Review Focus

- Kho `team` đã sửa `settings.json` ngay cạnh hai dòng chặn (thêm một dòng `deny` của riêng mình
  sau chúng): phải nhận dấu xung đột, không mất dòng của kho. → Task 5.
- `owners.high: ["@Acme", "@acme"]` (một người, viết hai kiểu): là một tài khoản. → Task 4.
- `owners.high: ["@acme/core"]`: một đội, giữ code owner duyệt. → Task 4.
- Kho một chủ chạy `doctor --remote`: không bị chấm trượt «mất người quyết». → Task 4.
- `github_setup.py --check` trên kho một chủ có luật nhánh cũ đòi code owner duyệt: mã thoát 1,
  nêu `pull_request`. → Task 4.

---

### Task 1: Hai dòng chặn sửa theo bậc

**Files:**
- Modify: `plugins/repo-setup/scripts/apply_plan.py` (thêm `level_variables`, gọi trong `render_variables`)
- Modify: `plugins/repo-setup/scripts/apply.py` (gọi `level_variables` sau khi nạp `meta["vars"]`)
- Modify: `plugins/repo-setup/presets/_core/starter/dot.claude/settings.json.tmpl`
- Modify: `tests/run.sh` mục 43g; Create: `tests/autonomy_change.sh` (mục 53), nạp ở cuối `tests/run.sh`

**Interfaces:**
- Produces: `apply_plan.level_variables(level: str) -> dict[str, str]`, khoá `settings_edit_walls`.

- [ ] **Step 1: Bài đỏ 53a.** Dựng một kho `python` bậc `starter` và một kho bậc `team`. Đọc
  `.claude/settings.json` bằng `json`: `team` không có `Edit(./.github/workflows/**)` và
  `Edit(./governance/**)`; `starter` có cả hai; cả hai có đủ bảy dòng `Read(...)`, không có `ask`,
  không có `Bash(`. Đổi 43g: tường `Read(./.env)` giữ, hai dòng `Edit` thì phải vắng ở kho `team` của 43.
- [ ] **Step 2:** `bash tests/run.sh > $SCRATCH/run.log 2>&1`; thấy FAIL ở 53a và 43g.
- [ ] **Step 3:** `"Read(./**/*.pem)"{{settings_edit_walls}}` trong mẫu; `level_variables` trả
  `',\n      "Edit(./.github/workflows/**)",\n      "Edit(./governance/**)"'` cho `starter`, `""`
  cho `team`.
- [ ] **Step 4:** chạy lại; 53a, 43g xanh, phần còn lại xanh (50s: bản dựng lại khớp bản đã ghi).
- [ ] **Step 5:** commit `feat: team repositories let the machine draft workflow and policy changes`.

### Task 2: Lời luật

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/+AGENTS.md/55-autonomy.md`
- Modify: `plugins/repo-setup/capabilities/github-agents/team/+AGENTS.md/60-ai-native-sdlc.md`
- Modify: `plugins/repo-setup/presets/_core/team/governance/autonomy.yaml.tmpl` (dòng 11)
- Modify: `plugins/repo-setup/README.md` (đoạn «Enforced per tool call»)
- Test: `tests/autonomy_change.sh` 53b

- [ ] **Step 1: Bài đỏ 53b.** Trong `AGENTS.md` của kho `team` có `github-agents`: không còn
  `Do not edit` hay `Never** edit` với `.github/workflows/`; có `a pull request of its own`; có
  `never merge it yourself`; có `autonomy-change`. `autonomy.yaml` không còn `must be done by a human`.
  README plugin không còn nói deny rules chặn `workflows` ở mọi bậc.
- [ ] **Step 2:** chạy, thấy FAIL.
- [ ] **Step 3:** viết lời mới (phán quyết 3, 4, 5), mỗi mục một nhãn.
- [ ] **Step 4:** chạy; 53b, 50m, 50p, 43g xanh.
- [ ] **Step 5:** commit `feat: a rule change is drafted in a pull request of its own`.

### Task 3: Kỹ năng autonomy-change

**Files:**
- Create: `plugins/repo-setup/presets/_core/team/dot.claude/skills/autonomy-change/SKILL.md`
- Test: `tests/autonomy_change.sh` 53c; thêm tệp vào danh sách quét cụm từ của 43g

- [ ] **Step 1: Bài đỏ 53c.** Kho `team` có tệp, kho `starter` không. Tệp có frontmatter `name:
  autonomy-change` và `description:`. Mọi lệnh `python3 tools/...` và `make ...` nó nêu có thật trong
  kho (tệp có, đích make có). Nó nêu `--check-codeowners`, một nhánh riêng, `gh pr create`, và không
  `gh pr merge`. Không có cụm từ dừng của 43g.
- [ ] **Step 2:** chạy, thấy FAIL.
- [ ] **Step 3:** viết kỹ năng: bảng lời → khoá của `governance/autonomy.yaml`; đổi đúng một khoá
  trên nhánh `autonomy/<slug>`; `make codeowners` rồi `make governance` (từ chối thì báo và dừng,
  không mở PR); trước và sau: dòng cũ, dòng mới, và hạng `tools/autonomy.py --files` cho một đường
  dẫn ví dụ; mở PR; dừng, không gộp.
- [ ] **Step 4:** chạy; xanh.
- [ ] **Step 5:** commit `feat: a skill drafts a change of autonomy as a pull request`.

### Task 4: Kho một chủ

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/autonomy.py` (`sole_decider`)
- Modify: `plugins/repo-setup/presets/_core/team/tools/github_setup.py` (`plan(..., code_owner_review=True)`, `run`)
- Modify: `plugins/repo-setup/scripts/doctor.py` (`branch_protection`)
- Test: `tests/run.sh` 43b, 43i; `tests/autonomy_change.sh` 53d

**Interfaces:**
- Produces: `autonomy.sole_decider(policy: dict[str, Any]) -> str` (handle `@x` hay `""`);
  `github_setup.plan(..., code_owner_review: bool = True)`; `github_setup.ONE_DECIDER_HELP: str`.

- [ ] **Step 1: Bài đỏ 53d.**
  - `sole_decider`: `["@acme"]` → `@acme`; `["@Acme", "acme "]` → `@acme`; `["@a", "@b"]` → `""`;
    `["@org/core"]` → `""`; `[]`, thiếu `owners`, `owners: x` → `""`.
  - `plan(..., code_owner_review=False)`: `require_code_owner_review` là `False`, mọi thứ khác như cũ,
    với `agents` tắt và bật.
  - Chạy thử với gh giả (kiểu 43j), policy một chủ: in `ONE_DECIDER_HELP` và tên `@acme`; thân luật
    nhánh mà `--apply` gửi có `"require_code_owner_review": false`. Policy hai người: `true`, không in.
  - `--check` với luật nhánh hiện có đòi code owner duyệt, policy một chủ: thoát 1, dòng ruleset
    nêu `pull_request`.
  - `doctor` (43i): luật không đòi code owner, kho một chủ → `pass`; kho hai người → `fail`.
- [ ] **Step 2:** chạy, thấy FAIL.
- [ ] **Step 3:** viết; dòng `what` của bước ruleset nói `no code owner review (one decider: @acme)`.
- [ ] **Step 4:** chạy; xanh; ruff của kho python (48zi) xanh.
- [ ] **Step 5:** commit `feat: a one-owner repository merges a rule change by the owner's merge`.

### Task 5: Nâng cấp

**Files:**
- Create: `tests/fixtures/autonomy-change/pre/presets/_core/starter/dot.claude/settings.json.tmpl` (bản cũ)
- Test: `tests/autonomy_change.sh` 53e

- [ ] **Step 1: Bài 53e.** Bản phát hành giả 0.0.1 = plugin này với mẫu cũ; 0.0.2 = plugin này. Kho
  `team` dựng bằng 0.0.1, nâng bằng 0.0.2 (`--base-from`): chưa sửa → `settings.json` ở nhóm
  `updated`, `diff` cũ mới chỉ khác đúng hai dòng `Edit` và dấu phẩy sau dòng `pem`; đã thêm một dòng
  `deny` sau hai dòng đó → nhóm `marked`, mã thoát 1, tệp có dấu xung đột, dòng của kho còn. Kho
  `starter` → `settings.json` không đổi.
- [ ] **Step 2:** chạy (bài này xanh ngay vì Task 1 đã dựng; ghi rõ trong commit là bài khoá hành vi
  nâng cấp, đỏ nếu đổi sang hai mẫu).
- [ ] **Step 5:** commit `test: pin how a team repository upgrades its settings`.

### Task 6: Tài liệu và changelog

**Files:**
- Modify: `docs/setup-principles.md` («Chỗ còn hở» mục repo một chủ; hàng 1 và 3 của bảng nêu 53)
- Modify: `plugins/repo-setup/skills/github/SKILL.md` (đoạn luật nhánh)
- Modify: `CHANGELOG.md` (dưới `## Unreleased`)
- Test: `tests/autonomy_change.sh` 53f

- [ ] **Step 1: Bài đỏ 53f.** `docs/setup-principles.md` mục «Chỗ còn hở» nói kho một chủ, câu
  «máy không tự gộp» giữ bằng lời; `CHANGELOG.md` dưới `## Unreleased` có mục 5.3 với
  `What breaks on upgrade`; kỹ năng github nói kho một chủ.
- [ ] **Step 2–4:** đỏ, viết, xanh (43k vẫn xanh).
- [ ] **Step 5:** commit `docs: record what a one-owner repository keeps by word`.

### Task 7: Soát cả nhánh, sửa, mở PR

- [ ] Một lượt soát độc lập trên model mạnh nhất; mỗi phát hiện nghiêm trọng hay quan trọng có một
  bài đỏ rồi bản sửa.
- [ ] `bash tests/run.sh` xanh; đẩy nhánh; `gh pr create` lên `main`; không gộp.
