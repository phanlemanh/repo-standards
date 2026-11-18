# Mỗi luật khai thứ giữ nó (RS7): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mỗi mục danh sách trong các mảnh `+AGENTS.md/` mang một nhãn (máy giữ, lời, không phải
luật); bài kiểm đỏ khi thiếu nhãn hay khi «máy giữ» không có bài chứng minh; `AGENTS.md` sinh ra
có mục cuối «What holds these rules» tính theo kho được cài.

**Architecture:**
- Một mô-đun mới, `scripts/rule_kinds.py`, giữ mọi luật: đọc mục danh sách và nhãn, đọc sổ, soát,
  đếm, gỡ nhãn, lắp mục tổng. Thư viện chuẩn.
- Một tệp sổ trong khuôn, `plugins/repo-setup/rule-checks.toml`, giữ danh sách máy và mọi chữ của
  mục tổng. Mã chỉ lắp, không chứa chữ nào của mục tổng.
- `apply.py` gọi `rule_kinds.finish` ở đúng một chỗ dùng chung cho lượt chạy và lượt dựng lại bản
  gốc của RS8, sau khi đã lọc tệp bị loại. Khuôn không có sổ thì kết quả giống hôm nay từng byte.

**Tech Stack:** Python 3.11+ thư viện chuẩn (`tomllib`, `re`), bash 3.2 cho bài kiểm, markdown.

**Spec:** `docs/superpowers/specs/2026-11-18-rule-kinds-design.md`. Mục 5.1 (ba nhãn, ba kiểu), 5.3
(sổ, bài chứng minh), 5.4 (mục tổng, ràng buộc RS8, `--adopt`) và 6 (bài kiểm) là luật của mọi task.

## Global Constraints

- Nhánh `feat/rule-kinds`, tách từ `main`. Commit theo Conventional Commits, không dòng ghi công.
- Mã, khuôn, `CHANGELOG.md`, tên tệp: tiếng Anh. Tài liệu trong `docs/`: tiếng Việt.
- Chỉ thư viện chuẩn; không gọi mạng. Không tạo đối tượng rồi sửa tại chỗ khi trả về kế hoạch tệp:
  trả một `dict` mới.
- Cú pháp nhãn, đúng chữ: `<!-- kept: <mã> -->`, cách câu luật một dấu cách, ở cuối dòng cuối của
  mục. `<mã>` là `word`, `none`, hoặc một mã trong sổ. Biểu thức: `[ \t]*<!-- kept: ([a-z][a-z0-9-]*) -->`.
- Thẻ bài chứng minh, đúng chữ, một dòng chú thích ngay trên phép khẳng định: `# rule-check: <mã>`.
- Mục tổng, đúng chữ (spec 5.4): đề mục `## What holds these rules`; câu mở
  `A machine catches a miss of these:`; câu cuối
  `Nothing listed here covers the other rules in this file. Do not count on a machine to catch a`
  xuống dòng `miss: keeping them is on you.` Mỗi dòng máy: `- <catches>: <reaction>`.
- Kho `--adopt`: gỡ nhãn, không thêm mục tổng. Khuôn không có `rule-checks.toml`: không gỡ, không thêm.
- «Có mặt» = đường dẫn `present_when` là một khoá của kế hoạch tệp **sau** khi lọc `left_out`.
  Không đọc đĩa của kho đích, không đọc GitHub.
- Không viết bài chứng minh mới, không đổi `doctor`, không thêm phép kiểm vào kho được cài.
- Chạy `bash tests/run.sh` trước khi nói một task xong. Mục 43 phải xanh.

## Review Focus

1. **`AGENTS.md` sinh ra phải qua trình định dạng của kho.** Preset TypeScript chạy
   `prettier --check .` và không bỏ qua `AGENTS.md`: mục tổng phải đúng khổ prettier (dòng trống
   quanh đề mục và danh sách, dòng nối của một mục thụt hai dấu cách, không dấu cách cuối dòng).
   Bộ nhanh không chạy prettier; Task 4 chạy `tests/e2e.sh`.
2. **Mục nhiều dòng và mục lồng.** Nhãn nằm ở dòng nối cuối; mục cha kết thúc khi mục con bắt đầu.
   Bài ở Task 1.
3. **Dòng `- ` trong khối mã có rào** không phải mục danh sách. Bài ở Task 1.
4. **Máy bị preset loại (`not_applicable`) không được nêu.** Kho `claude-plugin` hạng team có mảnh
   `55-autonomy.md` nhưng có thể không có `tools/autonomy.py`. Bài ở Task 3.
5. **Lên hạng và nâng cấp.** Starter lên team: mục tổng có thêm dòng. Kho đã sửa `AGENTS.md` đúng
   một dòng bị tách: kết quả là `marked`, không bao giờ `base_unread`. Bài ở Task 4.

---

## Bản đồ tệp

| Tệp | Việc |
| --- | --- |
| Create `plugins/repo-setup/scripts/rule_kinds.py` | Đọc mục và nhãn, sổ, soát, đếm, `finish` |
| Create `plugins/repo-setup/rule-checks.toml` | Sổ máy và chữ của mục tổng (Task 3) |
| Modify `plugins/repo-setup/scripts/apply.py` | `planned_files` nhận `adopt`; một hàm dùng chung gọi `finish` |
| Modify 12 tệp `plugins/repo-setup/**/+AGENTS.md/*` | Nhãn trên từng mục; sáu mục bị tách |
| Create `tests/rule_kinds.sh` | Mục 50 của bộ kiểm, được `tests/run.sh` nạp |
| Modify `tests/run.sh` | Nạp mục 50; thẻ `# rule-check:` cạnh bảy bài |
| Create `tests/fixtures/rule-kinds/pre/` | 12 mảnh như trước RS7, để dựng bản phát hành thế thân |
| Modify `CHANGELOG.md`, `docs/three-repo-overview-design.md` | Ghi thay đổi và con số |

---

### Task 1: Công cụ đọc, soát và đếm

**Files:**
- Create: `plugins/repo-setup/scripts/rule_kinds.py`
- Create: `tests/rule_kinds.sh`
- Modify: `tests/run.sh` (nạp `tests/rule_kinds.sh` ngay sau dòng nạp `tests/tiered_ci.sh`)

**Interfaces:**
- Produces:
  - `REGISTRY_NAME = "rule-checks.toml"`, `MARKER` (biểu thức ở Global Constraints),
    `KINDS = ("red", "refuses", "raises-tier")`.
  - `@dataclass(frozen=True) Item(line: int, text: str, kinds: tuple[str, ...])`
  - `list_items(text: str) -> list[Item]`
  - `load_registry(root: Path) -> dict | None` (`None` khi không có tệp; khoá `summary`, `checks`)
  - `check(root: Path, tests_dir: Path | None = None) -> list[str]` (mỗi dòng `đường/dẫn:dòng: lỗi`)
  - `count(root: Path) -> dict[str, dict[str, int]]` (mảnh → `{"machine", "word", "none"}`)
  - CLI: `rule_kinds.py check [--root DIR] [--tests DIR] [--json]`, mã thoát 0 hoặc 1.

Luật đọc mục: một mục bắt đầu ở dòng khớp `^[ \t]*(?:[-*]|\d+\.)[ \t]+\S` và kéo tới trước mục kế,
dòng trống, dòng đề mục (`#`), hoặc hết tệp. Dòng trong khối ``` không tạo mục. Mảnh là mọi tệp
dưới một thư mục tên `+AGENTS.md` trong `root`.

- [ ] **Step 1: Viết bài đỏ** trong `tests/rule_kinds.sh` (đầu tệp ghi `# 50. rule kinds (docs/superpowers/specs/2026-11-18-rule-kinds-design.md)`), trên một cây nhỏ dựng trong `$TMP/rk`:

```bash
rk="$TMP/rk"; rk_frag="$rk/root/presets/_core/starter/+AGENTS.md"; mkdir -p "$rk_frag" "$rk/tests"
rk_tool() { python3 "$S/rule_kinds.py" check --root "$rk/root" --tests "$rk/tests" "$@"; }
cat > "$rk/root/rule-checks.toml" <<'T'
[summary]
heading = "## What holds these rules"
intro = "A machine catches a miss of these:"
closing = "Nothing listed here covers the other rules."
closing_alone = "No machine is listed."
[checks.commit-format]
catches = "commit format"
reaction = "`conventional-commits` goes red (GitHub)"
kind = "red"
present_when = ".github/workflows/pr-title.yml"
T
printf '# rule-check: commit-format\n' > "$rk/tests/x.sh"
cat > "$rk_frag/10-a.md" <<'M'
## Rules

- Commits follow the format. <!-- kept: commit-format -->
- A rule on two lines,
  kept by word. <!-- kept: word -->
- Parent:
  - child one <!-- kept: none -->

```
- not an item
```
M
# 50a. green: every item has one kind; the parent without a kind is the one problem
out=$(rk_tool 2>&1) && miss "rule kinds: an item without a kind passes"
echo "$out" | grep -q '10-a.md:6: list item has no kind' || miss "rule kinds: no line for the item without a kind: $out"
[ "$(echo "$out" | grep -c '10-a.md')" = 1 ] || miss "rule kinds: a fenced line or a nested item is misread: $out"
```

Thêm các bài cùng khuôn, mỗi bài sửa cây rồi chạy `rk_tool`:
- `50b` sửa dòng 6 thành `- Parent: <!-- kept: word -->` → mã thoát 0, dòng cuối đúng chữ
  `rule kinds: 1 held by a machine, 2 kept by word, 1 not rules`.
- `50c` hai nhãn trên một mục → `two kinds`; nhãn trong đoạn văn → `marker outside a list item`.
- `50d` mã `nope` → `unknown check 'nope'`; xoá `rk/tests/x.sh` → `check 'commit-format' has no test tagged '# rule-check: commit-format'`.
- `50e` sổ: thiếu `present_when` → `check 'commit-format' lacks present_when`; `kind = "blue"` →
  `kind must be red, refuses or raises-tier`; một mã không mục nào dùng →
  `check '<id>' is not used by any rule`; xoá tệp sổ → `rule-checks.toml is missing`.
- `50f` `--json` in `{"ok": false, "problems": [...], "counts": {...}, "total": {...}}`.

- [ ] **Step 2: Chạy, thấy đỏ.** `bash tests/run.sh 2>&1 | grep 'rule kinds'` → các dòng `FAIL: rule kinds: …` (chưa có `rule_kinds.py`).
- [ ] **Step 3: Viết `rule_kinds.py`** theo Interfaces. `check` gom mọi lỗi rồi mới trả; không dừng ở lỗi đầu. Không `--tests` thì bỏ phép soát thẻ.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh` → `ok  rule kinds …` và `All tests passed.`
- [ ] **Step 5: Commit.** `git add plugins/repo-setup/scripts/rule_kinds.py tests/rule_kinds.sh tests/run.sh && git commit -m "feat: read and check the kind of every rule in the AGENTS.md fragments"`

### Task 2: Gỡ nhãn và lắp mục tổng trong `apply.py`

**Files:**
- Modify: `plugins/repo-setup/scripts/rule_kinds.py`
- Modify: `plugins/repo-setup/scripts/apply.py` (`planned_files` quanh dòng 461; `main` ngay sau dòng
  lọc `left_out` quanh dòng 682; `base_of` quanh dòng 722; dòng 846)
- Test: `tests/rule_kinds.sh`

**Interfaces:**
- Consumes: `load_registry`, `list_items`, `MARKER` của Task 1.
- Produces:
  - `rule_kinds.finish(content: bytes, root: Path, present: Callable[[str], bool], adopt: bool) -> bytes`
  - `apply.RULES_FILE = "AGENTS.md"`
  - `apply.with_rule_kinds(plan: dict, root: Path, adopt: bool) -> dict` (nhận khoá `Path` hoặc `str`; trả `dict` mới)
  - `apply.planned_files(choices, variables, root=PLUGIN_ROOT, adopt: bool = False)`

Luật của `finish`:
1. Sổ là `None` → trả `content` nguyên vẹn.
2. Gỡ mọi nhãn; không để lại dấu cách cuối dòng.
3. `adopt` → trả văn bản đã gỡ.
4. Lấy các mã (khác `word`, `none`) theo thứ tự xuất hiện đầu tiên, mỗi mã một lần, giữ mã có
   `present(present_when)`.
5. Có dòng: `heading`, dòng trống, `intro`, dòng trống, các dòng `- <catches>: <reaction>`, dòng
   trống, `closing`. Không dòng nào: `heading`, dòng trống, `closing_alone`.
6. Kết quả = văn bản đã gỡ (bỏ dòng trống cuối) + một dòng trống + mục tổng + `\n`.

- [ ] **Step 1: Viết bài đỏ** gọi thẳng `finish` bằng python trên cây `$rk/root` của Task 1:

```bash
rk_finish() { python3 - "$S" "$rk/root" "$1" "$2" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
from pathlib import Path; import rule_kinds
text = Path(sys.argv[2], "presets/_core/starter/+AGENTS.md/10-a.md").read_bytes()
have = set(filter(None, sys.argv[3].split(",")))
sys.stdout.buffer.write(rule_kinds.finish(text, Path(sys.argv[2]), lambda p: p in have, sys.argv[4] == "adopt"))
PY
}
# 50g. the check is present: one line, the closing sentence, no marker left
out=$(rk_finish .github/workflows/pr-title.yml new)
echo "$out" | grep -qx -- '- commit format: `conventional-commits` goes red (GitHub)' || miss "rule kinds: no line for a present check"
echo "$out" | grep -q 'kept:' && miss "rule kinds: a marker is left in the output"
echo "$out" | grep -q ' $' && miss "rule kinds: trailing space left where a marker was"
# 50h. the check is absent: the heading and the sentence for no machine, no list
out=$(rk_finish "" new); echo "$out" | grep -qx 'No machine is listed.' || miss "rule kinds: no closing for a repo without machines"
echo "$out" | grep -q 'commit format' && miss "rule kinds: an absent check is named"
# 50i. adopt: markers go, no section
out=$(rk_finish .github/workflows/pr-title.yml adopt); echo "$out" | grep -q 'What holds' && miss "rule kinds: adopt gets the section"
```

Thêm `50j`: xoá `rule-checks.toml` khỏi một bản sao của cây → `finish` trả đúng từng byte đầu vào
(`cmp`). Thêm `50k`: với cây thật (ở task này chưa có sổ), `AGENTS.md` của một kho ts-node starter giống
từng byte phép nối mảnh viết lại trong bài: các mảnh theo thứ tự tên, mỗi mảnh kết thúc bằng một
dòng mới, một dòng trống giữa hai mảnh. Sang Task 3, bài này chạy trên bản phát hành thế thân
không có sổ (Task 4), không còn trên cây thật.

- [ ] **Step 2: Chạy, thấy đỏ** (`AttributeError: module 'rule_kinds' has no attribute 'finish'`).
- [ ] **Step 3: Viết `finish`; nối vào `apply.py`.** `with_rule_kinds` tìm khoá có dạng posix bằng `RULES_FILE`, gọi `finish` với `present = lambda p: p in {dạng posix của mọi khoá}`. Gọi nó ở `planned_files` và ở `main`, cả hai sau khi lọc `left_out`. `base_of` truyền `bool(previous.get("adopt"))`; dòng 846 truyền `adopt` hiện tại.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh` xanh trọn bộ; bài 47a (`planned_files` dựng lại đúng thứ `apply` đã ghi) vẫn xanh.
- [ ] **Step 5: Commit.** `git commit -m "feat: apply strips rule kinds and can add the section that says what holds the rules"`

### Task 3: Sổ thật, nhãn trên 12 mảnh, thẻ cạnh bài chứng minh

**Files:**
- Create: `plugins/repo-setup/rule-checks.toml`
- Modify: 12 tệp `+AGENTS.md/*` (danh sách ở bảng dưới)
- Modify: `tests/run.sh` (thẻ cạnh bảy bài), `tests/rule_kinds.sh`
- Create: `tests/fixtures/rule-kinds/pre/` (12 mảnh như trước RS7, cho Task 4)

**Interfaces:**
- Consumes: CLI `rule_kinds.py check`, `finish` qua `apply.py`.
- Produces: bảy mã trong sổ; số đếm kỳ vọng `14 held by a machine, 61 kept by word, 33 not rules` (108 mục sau khi tách).

**Sổ.** `[summary]` theo Global Constraints, thêm `closing_alone`:
`No machine is listed for the rules in this file. Do not count on one to catch a miss: keeping`
xuống dòng `them is on you.`

| Mã | `catches` | `reaction` | `kind` | `present_when` | Thẻ đặt ở (`tests/run.sh`) |
| --- | --- | --- | --- | --- | --- |
| `wiki-format` | a wiki page that breaks its page format | `make check` goes red | red | `tools/wiki_lint.py` | Mục 11, bài «bad decision page» |
| `secret-scan` | a secret in a commit | `secret-scan` goes red (GitHub) | red | `.github/workflows/security.yml` | Mục 44b, `a committed token passes` |
| `commit-format` | commit format | `conventional-title` or `conventional-commits` goes red (GitHub) | red | `.github/workflows/pr-title.yml` | Mục 44d, phép khẳng định chiều đỏ của ô commit |
| `autonomy-gate` | a deleted or weakened test, a looser `agent:` setting, a change to `.github/workflows/` or `governance/` | the gate raises the tier, and a person decides | raises-tier | `tools/autonomy.py` | Mục 17 (`describe.skip added`), 43a, 43d |
| `module-boundaries` | a module reaching past another module's public API | `make check` goes red | red | `tools/boundaries.py` | Mục 14 |
| `api-compat` | a breaking change to the API contract | `make check` goes red | red | `tools/api_compat.py` | Mục 15 |
| `plugin-lint` | manifest versions that disagree, a plugin whose source is the repository root | `make check` goes red | red | `tools/plugin_lint.py` | Mục 35, `version mismatch accepted` |

Dòng của `autonomy-gate` dài hơn 100 ký tự: ngắt trong `catches` bằng xuống dòng và hai dấu cách.
Ba dòng của bảng xuất phát trong spec (5.3) không vào sổ, theo luật «không chắc thì là lời»:

- «Tệp dẫn xuất không nằm trong git» và «`agent: forbidden` trong `can()`»: không mục danh sách
  nào đòi đúng điều bài kiểm chứng minh, và sổ không giữ mã mà không luật nào dùng.
- «Mã sinh ra khớp `ontology/`»: xem dưới.

`make gen … (never edit generated files)` là `word`, không phải máy giữ: kho mới giữ tệp sinh ra
ngoài git và vẽ lại trước mỗi lượt kiểm, nên không phép kiểm nào đỏ; bài «codegen drift» chỉ đúng
cho kho còn giữ tệp đó trong git.

Trước khi đặt mỗi thẻ, đọc bài đó và xác nhận nó phạm luật rồi thấy máy phản ứng đúng `kind`. Bài
không làm vậy thì bỏ mã khỏi sổ, đổi các mục dùng mã đó thành `word`, và ghi lại trong báo cáo task.

**Nhãn.** Mặc định của bảng: mục không được nêu là `word`.

| Mảnh | `none` | Máy giữ |
| --- | --- | --- |
| `_core/starter/10-guide.md.tmpl` | Commands trừ `make gen` và `make check`; bước 2 của «Before you change code»; ba mục con đầu của «Update the wiki» (`make log`, `a new term`, `a new wiki page`); cả «Project map» | «Never commit secrets.» → `secret-scan`; Conventional Commits → `commit-format`; «Follow the page formats…» → `wiki-format` |
| `_core/starter/15-language.md.tmpl` | — | — |
| `_core/team/55-autonomy.md` | — | «Do not edit `.github/workflows/` or `governance/`» và «Never delete or weaken a test…» → `autonomy-gate` |
| `modular-monolith/40-…md` | — | «A module uses another module **only** through its public API…» → `module-boundaries` |
| `service-api/40-…md` | — | «`make check` runs `api-contract` … and `api-compat`…» → `api-compat` |
| `mcp/45-mcp.md` | Mục 1 (`ontology/actions.yaml` is the single list…), mục 3 (`agent: confirm` tools carry…) | «A wider `agent:` setting…» → `autonomy-gate` |
| `ai/46-ai.md`, `design/47-design.md` | — | — |
| `github-agents/60-ai-native-sdlc.md` | — | Hai mục tách ra ở dưới → `autonomy-gate` |
| `container/70-container.md` | Mục 1 (`make image` builds…) | — |
| `claude-plugin/10-guide.md.tmpl` | Commands trừ `make check`; ba bước của «Before you change a plugin»; cả «Project map» | «A plugin's `source`…» và «Never edit a version by hand…» → `plugin-lint`; «Never commit secrets.» → `secret-scan`; Conventional Commits → `commit-format` |
| `claude-plugin/15-language.md.tmpl` | — | — |

**Sáu mục bị tách** (chữ mới, đúng từng chữ; mục thứ nhất giữ chỗ của mục cũ, mục thứ hai ngay sau):

| Mảnh | Mục cũ | Hai mục mới |
| --- | --- | --- |
| `_core` 10-guide | Never commit secrets or `.env`. Configuration goes in `.env.example`. | `Never commit secrets.` [`secret-scan`] · ``Never commit `.env`. Configuration goes in `.env.example`.`` [`word`] |
| `_core` 10-guide | Follow the page formats in `ontology/page-types.yaml`. Link to code paths, do not paste code into the wiki. | ``Follow the page formats in `ontology/page-types.yaml`.`` [`wiki-format`] · `Link to code paths, do not paste code into the wiki.` [`word`] |
| 60-ai-native-sdlc | **Never** push to the default branch, merge a medium/high PR, approve your own work, or edit `.github/workflows/` and `governance/` (blocked in `.claude/settings.json`; humans own them). | ``**Never** edit `.github/workflows/` and `governance/` (blocked in `.claude/settings.json`; humans own them).`` [`autonomy-gate`] · `**Never** push to the default branch, merge a medium/high PR, or approve your own work.` [`word`] |
| 60-ai-native-sdlc | Every acceptance criterion maps to at least one test. Never delete or weaken a test to pass CI (it raises the tier anyway). | `Every acceptance criterion maps to at least one test.` [`word`] · `Never delete or weaken a test to pass CI (it raises the tier anyway).` [`autonomy-gate`] |
| `claude-plugin` 10-guide | One folder per plugin … each with `.claude-plugin/plugin.json`. A plugin's `source` in the marketplace is never the repository root: an install copies the whole source folder. | Câu thứ nhất [`word`] · câu thứ hai [`plugin-lint`] |
| `claude-plugin` 10-guide | Never commit secrets or `.env`. | `Never commit secrets.` [`secret-scan`] · ``Never commit `.env`.`` [`word`] |

- [ ] **Step 0: Giữ lại 12 mảnh như hiện nay** trước khi sửa: chép từng tệp `+AGENTS.md/*` vào `tests/fixtures/rule-kinds/pre/<cùng đường dẫn tính từ plugins/repo-setup>`. Task 4 dùng chúng để dựng một bản phát hành không có RS7; không lấy từ thẻ git, vì CI không tải thẻ.
- [ ] **Step 1: Viết bài đỏ** trong `tests/rule_kinds.sh`, trên cây thật và trên kho sinh thử:

```bash
# 50m. the real tree: every item has a kind, every machine has a tagged test
rk_real=$(python3 "$S/rule_kinds.py" check --tests "$ROOT/tests" 2>&1) || miss "rule kinds: the plugin's own fragments fail: $(echo "$rk_real" | head -5)"
# 50n. the red direction, on a copy: one bullet without a kind
rk_copy="$TMP/rk-copy"; cp -R "$ROOT/plugins/repo-setup" "$rk_copy"
printf -- '- A rule nobody owns.\n' >> "$rk_copy/presets/_core/team/+AGENTS.md/55-autonomy.md"
python3 "$S/rule_kinds.py" check --root "$rk_copy" --tests "$ROOT/tests" >/dev/null 2>&1 && miss "rule kinds: a new rule without a kind passes"
# 50o. by install: starter has no line for the commit format or the secret scan; team has both
rk_new() { mkdir -p "$1"; git -C "$1" init -q -b main; shift; python3 "$S/apply.py" --target "$@" --var project_name=R --var description=x --var owner=acme >/dev/null; }
rk_s="$TMP/rk-starter"; rk_new "$rk_s" "$rk_s" --preset ts-node
rk_t="$TMP/rk-team"; rk_new "$rk_t" "$rk_t" --preset ts-node --level team --archetype modular-monolith
grep -q '^- commit format:' "$rk_s/AGENTS.md" && miss "rule kinds: starter names the commit check it does not have"
for line in '^- commit format:' '^- a secret in a commit:' '^- a module reaching past' '^- a deleted or weakened test'; do
  grep -q -- "$line" "$rk_t/AGENTS.md" || miss "rule kinds: team lacks the line $line"
done
```

Thêm các bài:
- `50p` mọi `AGENTS.md` trong `$TMP/combo-*` và `$TMP/newrepo-*` (bộ kiểm đã sinh sẵn): có đúng một
  dòng `## What holds these rules`, không chứa `kept:`, và mỗi dòng máy của nó có tệp
  `present_when` trên đĩa (đọc `present_when` từ sổ bằng `tomllib`).
- `50q` kho `--adopt` (dựng như mục 9 của `run.sh`): không có `What holds`, không có `kept:`.
- `50r` kho `claude-plugin` hạng team: mục tổng có `plugin-lint`; nếu kho không có
  `tools/autonomy.py` thì không có dòng `a deleted or weakened test`.
- `50s` hai bản sao hỏng của cây thật: gỡ một thẻ `# rule-check:` khỏi bản sao của `tests/` → đỏ;
  đổi một nhãn thành mã lạ → đỏ.
- `50t` mục tổng của `$rk_t` không chứa cụm cấm nào của mục 43g (dùng lại đúng danh sách cụm đó).
- Dòng cuối của mục 50: `echo "ok  rule kinds: $(python3 "$S/rule_kinds.py" check --tests "$ROOT/tests" | tail -1 | sed 's/^rule kinds: //') (or misses reported above)"`.

- [ ] **Step 2: Chạy, thấy đỏ** (`rule-checks.toml is missing`, rồi 102 dòng `list item has no kind`).
- [ ] **Step 3: Tạo sổ; tách sáu mục; ghi nhãn trên cả 12 mảnh; đặt thẻ cạnh bảy bài.** Sau đó `python3 plugins/repo-setup/scripts/rule_kinds.py check --tests tests` in `rule kinds: 14 held by a machine, 61 kept by word, 33 not rules`. Số lệch thì đối chiếu lại với hai bảng trên; không sửa bảng cho khớp số.
- [ ] **Step 4: Chạy trọn bộ.** `bash tests/run.sh` → `All tests passed.` Bài nào của bộ cũ đỏ vì một câu bị tách thì sửa phép `grep` của bài theo chữ mới, không sửa chữ.
- [ ] **Step 5: Commit.** `git commit -m "feat: every rule in the generated AGENTS.md says what holds it"`

### Task 4: Đường nâng cấp, tài liệu, chạy thật

**Files:**
- Modify: `tests/rule_kinds.sh`, `CHANGELOG.md`, `docs/three-repo-overview-design.md`
- Modify nếu có nhắc cấu trúc `AGENTS.md`: `plugins/repo-setup/README.md`, `plugins/repo-setup/skills/explain/SKILL.md`

**Interfaces:**
- Consumes: mọi thứ ở trên; `up_apply`, `in_group` và khuôn «bản phát hành thế thân» của `tests/upgrade.sh` (mục 47).

- [ ] **Step 1: Viết bài đỏ.** Một bản phát hành thế thân không có RS7: chép `plugins/repo-setup` vào `$TMP/rk-arch/repo-setup-v0.0.1`, xoá `rule-checks.toml`, chép đè 12 mảnh từ `tests/fixtures/rule-kinds/pre/`, đặt `version` trong `.claude-plugin/plugin.json` như `tests/upgrade.sh` làm. Bản `0.0.2` là cây hiện tại với `version` 0.0.2.
  - `50u` cài bằng `0.0.1`, chạy lại bằng `0.0.2` với `--base-from`: `AGENTS.md` ở nhóm `updated`, có mục tổng, mã thoát 0.
  - `50v` như trên nhưng trước đó thêm một dòng riêng vào giữa `AGENTS.md`: nhóm `merged`, dòng riêng còn, mục tổng có.
  - `50w` sửa đúng dòng `- Never commit secrets or \`.env\`…` trước khi nâng cấp: nhóm `marked`, không ở `base_unread`.
  - `50x` cài bằng `0.0.2`, sửa `AGENTS.md`, chạy lại `0.0.2`: không ở `base_unread` (bản gốc có mục tổng dựng lại được).
  - `50y` kho `--adopt` cài bằng `0.0.2`, sửa `AGENTS.md`, chạy lại: không ở `base_unread`.
  - `50z` starter lên team (`--level team`) bằng `0.0.2`: `AGENTS.md` có thêm dòng `- commit format:`.
- [ ] **Step 2: Chạy.** Bài nào đỏ là lỗi thật ở Task 2 (thường là `adopt` chưa tới `base_of`): sửa ở `apply.py`.
- [ ] **Step 3: Ghi `CHANGELOG.md`** dưới đề mục mới `## Unreleased`, tiếng Anh: thay đổi là gì; con số (dòng cuối của `rule_kinds.py check`); nâng cấp đổi gì (`AGENTS.md` nhận một mục cuối, sáu mục bị tách, bản đã sửa đúng dòng bị tách sẽ `marked`; kho `--adopt` không nhận mục tổng); thêm luật vào một mảnh thì phải ghi nhãn.
- [ ] **Step 4: Sửa `docs/three-repo-overview-design.md`** (tiếng Việt): dòng RS7 ở mục 7 thành «Đã dựng (ngày), mục 50 bộ kiểm» kèm con số; ở mục 9, dòng «Cách xếp 16 luật…» ghi rằng đã thay bằng nhãn có bài chứng minh; gốc rễ 4 ở mục 3 giữ nguyên số cũ và thêm một câu trỏ sang số mới.
- [ ] **Step 5: Đọc `plugins/repo-setup/README.md` và `skills/explain/SKILL.md`.** Chỗ nào tả các phần của `AGENTS.md` thì thêm một câu về mục «What holds these rules». Không chỗ nào tả thì không sửa.
- [ ] **Step 6: Chạy thật.** `bash tests/run.sh` → `All tests passed.` Rồi `bash tests/e2e.sh` (cần mạng, chạy nền): mọi tổ hợp qua `make check`, tức là `prettier --check` nhận `AGENTS.md` có mục tổng. Đỏ ở prettier thì sửa khổ của mục tổng trong `finish` hoặc trong sổ, và thêm một bài nhanh ghim khổ đó.
- [ ] **Step 7: Commit.** `git commit -m "docs: rule kinds in the changelog and the three-repo plan"` (bài kiểm của Step 1 commit riêng: `test: rule kinds survive an upgrade`).

---

## Giới hạn kế hoạch này để lại, như spec mục 11

- Luật trong đoạn văn và trong bảng không được soát.
- Thẻ chỉ nối bài với máy; đúng luật hay không do người đặt thẻ đọc bài mà giữ.
- Mục 44b bị bỏ qua trên máy không có gitleaks; thẻ `secret-scan` vẫn được tính là có.
