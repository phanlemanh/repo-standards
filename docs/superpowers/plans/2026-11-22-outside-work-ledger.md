# Sổ việc ngoài kho (phần 5.1): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Một kho bậc `team` vừa dựng có `python3 tools/outside.py`: nó kiểm từng việc ngoài kho, áp
phần không bí mật, hỏi ẩn từng khoá, và in danh sách việc chỉ người làm được.

**Architecture:**
- Hai tệp dữ liệu trong kho được cài: `governance/outside.toml` (các loại việc, mỗi loại là một mẫu
  lệnh) và `ops/outside.toml` (từng việc, trỏ vào một loại). Cả hai nạp từ nhánh mặc định trên máy chủ.
- Hai mô-đun sinh ra ở bậc `team`: `tools/outside_ledger.py` đọc và soát hai tệp, không chạy lệnh nào;
  `tools/outside.py` chạy lệnh và in kết quả. Thư viện chuẩn, Python 3.11 trở lên (`tomllib`).
- `tools/github_setup.py` có thêm `--check`. Kit gieo các loại việc và các dòng cho GitHub qua các mảnh
  `+outside.toml/` theo lớp. Quy trình dựng có thêm chặng «ngoài kho».

**Tech Stack:** Python 3.11+ thư viện chuẩn; bash cho bài kiểm (`tests/run.sh` nạp `tests/outside.sh`).

**Spec:** [docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md](../specs/2026-11-22-outside-work-and-autonomy-card-design.md),
mục 5.1 cùng các mục 6 đến 10 có liên quan. Phần 5.3 và 5.2 có kế hoạch riêng, không dựng ở đây.

## Global Constraints

- Mã, mẫu, tên tệp, đầu ra của công cụ bằng tiếng Anh. Tài liệu trong `docs/` bằng tiếng Việt.
- Công cụ sinh ra chỉ dùng thư viện chuẩn. Python dưới 3.11: in một câu nói rõ và thoát 2.
- Lệnh là danh sách đối số, không bao giờ qua shell (`shell=False`).
- Giá trị khoá không bao giờ nằm trong đối số lệnh, đầu ra, hay tệp nào.
- `check` chạy không được hay không so được là **unknown**, không bao giờ là đã đủ.
- Không thêm câu hỏi nào lúc dựng; không thêm lần nào người xuất hiện.
- Không đổi `.claude/settings.json.tmpl`, `tools/autonomy.py`, hay luật nhánh `github_setup.py` ghi:
  đó là phần 5.3.
- Bài đỏ trước. `bash tests/run.sh` xanh trước mỗi commit. Thông điệp commit theo Conventional
  Commits, không có dòng ghi công. Không đẩy, không mở PR: chủ kho quyết.
- Thay đổi hành vi vào `CHANGELOG.md` dưới `## Unreleased`, thêm dòng mới, không sửa dòng của PR khác.

## Review Focus

Năm tình huống thiết kế hàm ý mà dễ sót; mỗi dòng có bài kiểm ở task ghi trong ngoặc.

1. Một lệnh `check` treo (mất mạng): sau `OUTSIDE_TIMEOUT` giây dòng đó là unknown, công cụ chạy tiếp
   (Task 2).
2. Một giá trị có dấu `{`, `}` hay khoảng trắng: nằm nguyên trong một đối số, không bị thay chỗ trống
   lần hai (Task 1).
3. Người bấm Enter trống hay Ctrl-C ở lệnh hỏi khoá: không gì được cất, dòng vẫn là của người, mã
   thoát khác 0 (Task 3).
4. Khoá máy sinh cất ở hai nơi, nơi thứ hai hỏng: công cụ nói nơi nào đã có, thoát 1; lượt sau dòng
   đó là partial và thuộc về người, không sinh lại (Task 3).
5. Nhánh mặc định không tên `main`, hay chạy từ thư mục con: nhánh gốc lấy từ `origin/HEAD` (Task 2).

---

### Task 1: Đọc và soát hai tệp

**Files:**
- Create: `plugins/repo-setup/presets/_core/team/tools/outside_ledger.py`
- Create: `tests/outside.sh` (đầu tệp: `# 52. work outside the repository (docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md, 5.1)`)
- Modify: `tests/run.sh` (nạp `tests/outside.sh` sau `tests/seams.sh`, cùng kiểu ba tệp trước nó)

**Interfaces:**
- Produces:
  - `KINDS = ("setting", "secret", "decision", "action")`
  - `RECIPES_PATH = "governance/outside.toml"`, `ITEMS_PATH = "ops/outside.toml"`
  - `class LedgerError(ValueError)`: tệp không đọc được như TOML, hay một loại việc sai.
  - `Recipe` (dataclass frozen): `name: str`, `where: str`, `kind: str`, `check: tuple[str, ...]`,
    `expect: str`, `expect_line: str`, `missing_exit: int | None`, `apply: tuple[str, ...]`,
    `store: tuple[str, ...]`.
  - `Item` (dataclass frozen): `id: str`, `kind: str`, `recipes: tuple[str, ...]`,
    `fields: Mapping[str, str]`, `source: str`, `how: str`, `when: str`, `done: str`.
  - `parse_recipes(text: str) -> dict[str, Recipe]`
  - `parse_items(text: str, recipes: Mapping[str, Recipe]) -> tuple[list[Item], list[str]]`: danh
    sách thứ hai là các dòng bị từ chối, mỗi dòng một câu nêu tên dòng và lý do.
  - `render(argv: Sequence[str], fields: Mapping[str, str]) -> list[str]`

Luật soát, lấy từ thiết kế:

- Loại việc: `kind` thuộc `KINDS`; `setting`, `secret` phải có `check`; `secret` phải có `store` và
  không có `apply`; `setting` không có `apply` là loại chỉ kiểm. Sai thì `LedgerError` nêu tên loại.
- Dòng: `recipe` là một tên hay một danh sách tên (chỉ khi mọi loại đó là `secret`); hoặc
  `decision = "<tên>"`; hoặc `action = "<tên>"` (kèm `recipe` nếu kiểm được). Khoá dành riêng:
  `recipe`, `decision`, `action`, `source`, `how`, `when`, `done`. Mọi khoá chuỗi khác là `fields`.
- `id`: `<recipe>:<name>`, thêm `@<env>` khi có `env`; `decision:<tên>`; `action:<tên>`.
- `source` của khoá: `person` (mặc định) hay `generated`. Giá trị khác: từ chối dòng.
- Dòng bị từ chối khi: loại không có; chỗ trống `{x}` trong `check`, `expect`, `expect_line`, `apply`
  hay `store` của loại mà dòng không có khoá `x`; hai dòng trùng `id`. Các dòng khác vẫn dùng được.
- `render` thay mỗi `{khoá}` một lần, theo từng đối số; giá trị thay vào không được quét lại.

- [ ] **Step 1: Viết bài đỏ (52a)** trong `tests/outside.sh`. Bài gọi mô-đun qua `python3 - <<'PY'` với
  `sys.path` trỏ vào `$ROOT/plugins/repo-setup/presets/_core/team/tools`.

```bash
ob_tools="$ROOT/plugins/repo-setup/presets/_core/team/tools"
ob_py() { python3 - "$ob_tools" "$@"; }   # stdin: the program; argv[1]: the tools folder
# 52a. the ledger: what a recipe and a row must have; a bad row is refused alone
out=$(ob_py <<'PY' 2>&1
import sys; sys.path.insert(0, sys.argv[1])
import outside_ledger as L
R = L.parse_recipes('''
[recipe.var]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
expect_line = "{name}={value}"
apply = ["setter", "{name}", "{value}"]
[recipe.key]
where = "github"
kind = "secret"
check = ["keys"]
expect_line = "{name}"
store = ["keeper", "{name}"]
''')
items, refused = L.parse_items('''
[[item]]
recipe = "var"
name = "APP_URL"
env = "staging"
value = "https://x/{y} z"
[[item]]
recipe = "key"
name = "TOKEN"
source = "generated"
[[item]]
recipe = "var"
name = "NO_VALUE"
[[item]]
recipe = "ghost"
name = "X"
[[item]]
decision = "approve-production"
when = "each deploy to production"
[[item]]
action = "install-app"
how = "https://github.com/apps/claude"
''', R)
ids = [i.id for i in items]
assert ids == ["var:APP_URL@staging", "key:TOKEN", "decision:approve-production", "action:install-app"], ids
assert len(refused) == 2 and "NO_VALUE" in refused[0] and "ghost" in refused[1], refused
assert L.render(R["var"].apply, items[0].fields) == ["setter", "APP_URL", "https://x/{y} z"]
for bad, word in (('[recipe.a]\nwhere="g"\nkind="secret"\ncheck=["c"]', "store"),
                  ('[recipe.a]\nwhere="g"\nkind="setting"', "check"),
                  ('[recipe.a]\nwhere="g"\nkind="wish"\ncheck=["c"]', "kind"),
                  ('[recipe.a\n', "TOML")):
    try: L.parse_recipes(bad); raise SystemExit(f"accepted: {bad!r}")
    except L.LedgerError as e: assert word in str(e), (word, str(e))
print("ok")
PY
) ; [ "$out" = ok ] || miss "outside: the ledger does not hold: $out"
```

- [ ] **Step 2: Chạy, thấy đỏ.** `bash tests/run.sh 2>&1 | grep 'outside:'` → `FAIL: outside: the ledger does not hold: … No module named 'outside_ledger'`.
- [ ] **Step 3: Viết `outside_ledger.py`** theo Interfaces và luật soát ở trên. Mô-đun không nhập
  `subprocess` và không đọc tệp: nó nhận chữ, trả dữ liệu.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.`
- [ ] **Step 5: Commit.** `feat: read and check the ledger of work outside the repository`

### Task 2: `status`: ba danh sách, từ nhánh gốc

**Files:**
- Create: `plugins/repo-setup/presets/_core/team/tools/outside.py`
- Modify: `tests/outside.sh`

**Interfaces:**
- Consumes: mọi thứ Task 1 tạo ra.
- Produces:
  - `main(argv: list[str] | None = None) -> int`; lệnh con `status` (mặc định), nhận `--json`,
    `--draft`; cờ chung `--root DIR`.
  - `base_ref(root: Path) -> str | None`: `origin/<nhánh>` đọc từ `refs/remotes/origin/HEAD`; không
    có thì `None`.
  - `read_ledger(root: Path, ref: str | None) -> tuple[str, str]`: chữ của hai tệp, từ `git show
    <ref>:<path>` hay từ cây làm việc khi `ref` là `None`. Tệp thiếu là chuỗi rỗng.
  - `check_item(item: Item, recipes: Mapping[str, Recipe]) -> str`: `"ok"`, `"missing"`, `"partial"`
    hay `"unknown"`.
  - Biến môi trường `OUTSIDE_TIMEOUT` (giây, mặc định 30) cho mỗi lệnh `check`.
  - `--json` in một đối tượng có đúng các khoá: `base`, `ok`, `apply`, `yours`, `decisions`,
    `unknown`, `unmerged`, `refused`. Mỗi phần tử: `id`, `kind`, `where`, `why`, `how`. Thứ tự trong
    mỗi danh sách là thứ tự các dòng trong tệp.
  - `--draft --json` in `{"all": [<id>, …], "commands": [[<đối số>, …], …]}` của bản ở cây làm việc.

Điều `status` phải giữ:

- Một `check`: thoát 0 và khớp (`expect` so cả đầu ra đã cắt khoảng trắng; `expect_line` so từng
  dòng; không có cả hai thì thoát 0 là đủ) là `ok`. Thoát 0 mà không khớp, hay thoát đúng
  `missing_exit`, là `missing`. Mã thoát khác, quá giờ, không tìm thấy lệnh là `unknown`, kèm lý do.
- Khoá cất nhiều nơi: mọi nơi `ok` là `ok`; không nơi nào là `missing`; lẫn lộn là `partial`.
- Xếp danh sách: `ok` vào `ok`. `setting` thiếu và loại có `apply` vào `apply`. Khoá `generated`
  thiếu ở mọi nơi vào `apply`. Vào `yours`: khoá `person` thiếu; khoá `partial`; `setting` thiếu mà
  loại không có `apply`; `action` chưa xong. `decision` vào `decisions`, không tính là việc còn lại.
- `action` không có loại: có `done` thì `ok`, và `why` ghi `recorded by hand, not checked`.
- Lượt chạy trước hết thử `git fetch` nhánh mặc định, im lặng; hỏng thì in một dòng và dùng bản đã có.
- Không có `origin/HEAD`: đọc cây làm việc và in `no default branch on a remote: reading the working
  tree`.
- Dòng có ở cây làm việc mà không có ở nhánh gốc vào `unmerged`; không `check` nào của nó chạy.
- `--draft` in các lệnh mà bản ở cây làm việc sẽ chạy, mỗi lệnh một dòng, và không chạy lệnh nào.
- Mã thoát: 0 khi `apply`, `yours`, `unknown`, `refused` đều rỗng; 1 khi còn; 2 khi gọi sai, tệp không
  đọc được như TOML, hay kho không có `governance/outside.toml`.
- Python dưới 3.11: một câu nói cần 3.11 và thoát 2, trước khi nhập `tomllib`. Bộ kiểm không chạy được
  Python cũ, nên điều này không có bài; người soát đọc mã.

- [ ] **Step 1: Viết bài đỏ (52b, 52e).** Dựng một kho tạm có máy chủ là một kho trần cùng trong
  `$TMP`, nhánh mặc định tên `trunk`, và các lệnh thay thế trong `$TMP/ob-bin` (`probe`, `keys`,
  `setter`, `keeper`) ghi đối số vào `$OB_LOG`. `probe` in `PRESENT=1` cho tên `PRESENT`, không in gì
  cho `ABSENT`, thoát 3 cho `BROKEN`, ngủ 5 giây cho `SLOW`, thoát 1 cho `DRIFT`. Kho `$ob_a` có ba
  loại việc: `var` (như bài 52a), `key` (như bài 52a), `watch` (`setting`, `check = ["probe",
  "{name}"]`, `missing_exit = 1`, không `apply`); và các dòng, theo thứ tự: `var` cho `PRESENT`
  (`value = "1"`), `ABSENT`, `BROKEN`, `SLOW`; `key` cho `GENERATED` (`generated`) và `PERSON`;
  `watch` cho `DRIFT`; `action = "install-app"`; `decision = "approve-production"`. Trình trợ giúp:
  `ob_run <dir> <đối số…>` chạy `tools/outside.py` của kho đó với `PATH="$TMP/ob-bin:$PATH"
  OUTSIDE_TIMEOUT=1`; `ob_status <dir> [cờ]` là `ob_run <dir> status [cờ]`; `ob_field <khoá>` in các
  `id` của khoá đó từ JSON ở đầu vào chuẩn; `ob_put <dir> <đường dẫn> <chữ>` ghi một tệp. Các khẳng định:

```bash
# 52b. status: three lists; what cannot be checked is unknown, never in place
j=$(ob_status "$ob_a" --json); rc=$?
[ "$rc" = 1 ] || miss "outside: status with work left does not exit 1 ($rc)"
ob_ids() { python3 -c 'import json,sys; print(" ".join(e["id"] for e in json.load(sys.stdin)[sys.argv[1]]))' "$1" <<<"$j"; }
[ "$(ob_ids ok)" = "var:PRESENT" ] || miss "outside: in place is not exactly the row whose check matches"
[ "$(ob_ids apply)" = "var:ABSENT key:GENERATED" ] || miss "outside: the machine's list is wrong: $(ob_ids apply)"
[ "$(ob_ids yours)" = "key:PERSON watch:DRIFT action:install-app" ] || miss "outside: the person's list is wrong: $(ob_ids yours)"
[ "$(ob_ids decisions)" = "decision:approve-production" ] || miss "outside: a decision is not listed as one"
[ "$(ob_ids unknown)" = "var:BROKEN var:SLOW" ] || miss "outside: a check that fails or hangs is not unknown: $(ob_ids unknown)"
[ "$(ob_ids refused)" = "" ] && [ "$(ob_ids unmerged)" = "" ] || miss "outside: refused or unmerged rows where there are none"
# 52e. both files come from the default branch of the remote, whatever its name and the folder
ob_put "$ob_a" ops/outside.toml "$ob_rows_plus_one"          # a row only the working tree has
[ "$(ob_status "$ob_a/src" --json | ob_field unmerged)" = "var:LOCAL_ONLY" ] || miss "outside: a row that is not merged is not listed apart, or its check ran"
! grep -q LOCAL_ONLY "$OB_LOG" || miss "outside: the check of an unmerged row ran"
: > "$OB_LOG"; ob_status "$ob_a" --draft | grep -q '^probe LOCAL_ONLY$' || miss "outside: --draft does not print the command of the working tree"
[ ! -s "$OB_LOG" ] || miss "outside: --draft ran a command"
ob_put "$ob_a" governance/outside.toml "$ob_recipes_other_probe"   # the working tree changes a recipe's check
: > "$OB_LOG"; ob_status "$ob_a" >/dev/null; ! grep -q '^otherprobe' "$OB_LOG" || miss "outside: a recipe that is not merged ran"
ob_status "$ob_noremote" | grep -q 'no default branch on a remote: reading the working tree' || miss "outside: a repository without a remote does not say what it reads"
[ "$(cd "$ob_plain" && python3 "$ob_tools/outside.py" status >/dev/null 2>&1; echo $?)" = 2 ] || miss "outside: a repository without the recipes file does not exit 2"
```

  Thêm ba khẳng định: một kho mà mọi dòng đều `ok` thoát 0; `action` có `done` nằm ở `ok` với `why`
  chứa `not checked`; đầu ra chữ (không `--json`) có đủ bốn tiêu đề `In place`, `The machine will
  apply`, `Yours`, `Unknown`, và mỗi dòng của `Yours` có `how` cùng một câu `why`.

- [ ] **Step 2: Chạy, thấy đỏ.** `bash tests/run.sh 2>&1 | grep 'outside:'` → các dòng `FAIL: outside: …` vì chưa có `outside.py`.
- [ ] **Step 3: Viết `outside.py` với lệnh `status`** theo Interfaces và các điều ở trên. Chạy lệnh
  bằng `subprocess.run(argv, shell=False, capture_output=True, timeout=…)`.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.`
- [ ] **Step 5: Commit.** `feat: outside.py status lists what is in place, the machine's work and the person's`

### Task 3: `apply` và `secrets`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/outside.py`
- Modify: `tests/outside.sh`

**Interfaces:**
- Consumes: `check_item`, `read_ledger`, `base_ref` của Task 2.
- Produces: lệnh con `apply` và `secrets` của `main`.

Điều phải giữ:

- `apply` chạy `apply` của mỗi `setting` trong danh sách `apply`, rồi `check` lại. Với mỗi khoá
  `generated` thiếu ở mọi nơi: sinh `secrets.token_urlsafe(32)`, đưa vào đầu vào chuẩn của từng lệnh
  `store`. Một `store` hỏng: in nơi nào đã có, thoát 1, không cất tiếp.
- `apply` không bao giờ chạy `store` của khoá `person`, không sinh lại khoá `partial`, và không áp
  dòng `unmerged`.
- `secrets` thoát 2 và in `run this in a terminal of your own` khi đầu vào chuẩn không phải TTY.
- `secrets` hỏi từng khoá `person` còn thiếu bằng `getpass`, in `how` trước mỗi câu hỏi. Nhập trống:
  bỏ qua dòng đó. Ctrl-C: dừng, không cất gì thêm. Còn dòng chưa cất thì thoát 1.
- Giá trị chỉ đi qua đầu vào chuẩn của `store`. Sau mỗi lượt, cả hai lệnh in lại ba danh sách.
- Mã thoát của `apply`: 0 khi mọi thứ nó thử đều xong; 1 khi có lệnh hỏng.

- [ ] **Step 1: Viết bài đỏ (52c, 52d).** Lệnh thay thế `keeper` ghi đối số vào `$OB_LOG` và đầu vào
  chuẩn vào `$OB_STDIN.<tên>`; biến `OB_FAIL_STORE=<tên>` làm nó thoát 1 cho tên đó. Lượt có TTY dùng
  một trình trợ giúp `ob_tty <chữ nhập> -- <lệnh…>` viết bằng mô-đun `pty` của Python.

```bash
# 52c. apply: settings that are missing and generated keys, nothing of the person's
: > "$OB_LOG"; ob_run "$ob_a" apply >"$TMP/ob-apply.out" 2>&1
grep -q '^setter ABSENT ' "$OB_LOG" || miss "outside: apply did not apply the missing setting"
! grep -q '^setter PRESENT' "$OB_LOG" || miss "outside: apply applied a setting that is in place"
grep -q '^keeper GENERATED$' "$OB_LOG" && [ "$(wc -c < "$OB_STDIN.GENERATED")" -ge 32 ] || miss "outside: apply did not generate and store the key"
! grep -q '^keeper PERSON' "$OB_LOG" || miss "outside: apply stored a key only a person may enter"
! grep -qF "$(cat "$OB_STDIN.GENERATED")" "$OB_LOG" "$TMP/ob-apply.out" || miss "outside: a generated value is in the arguments or the output"
# a key stored in two places, the second fails: say where it is, exit 1, never generate again
: > "$OB_LOG"; OB_FAIL_STORE=TWIN_B ob_run "$ob_twin" apply >"$TMP/ob-twin.out" 2>&1; [ $? = 1 ] || miss "outside: a store that fails does not exit 1"
grep -q 'TWIN_A' "$TMP/ob-twin.out" || miss "outside: apply does not say where the key already is"
: > "$OB_LOG"; ob_run "$ob_twin" apply >/dev/null 2>&1; ! grep -q '^keeper TWIN' "$OB_LOG" || miss "outside: a key present in one place was generated again"
[ "$(ob_status "$ob_twin" --json | ob_field yours)" = "key:TWIN" ] || miss "outside: a partial key is not the person's to decide"
# 52d. secrets: a terminal of the person's own, and the value goes nowhere but the store's stdin
: > "$OB_LOG"; ob_run "$ob_a" secrets </dev/null >"$TMP/ob-notty.out" 2>&1; [ $? = 2 ] || miss "outside: secrets ran without a terminal"
! grep -q '^keeper' "$OB_LOG" || miss "outside: secrets stored something without a terminal"
ob_tty 's3cr3t-VALUE' -- ob_run "$ob_a" secrets >"$TMP/ob-tty.out" 2>&1 || miss "outside: secrets with a terminal failed"
[ "$(cat "$OB_STDIN.PERSON")" = "s3cr3t-VALUE" ] || miss "outside: the entered value did not reach the store"
! grep -qF 's3cr3t-VALUE' "$OB_LOG" "$TMP/ob-tty.out" || miss "outside: the entered value is in the arguments or the output"
rm -f "$OB_STDIN.PERSON2"; ob_tty '' -- ob_run "$ob_b" secrets >/dev/null 2>&1; [ $? = 1 ] && [ ! -e "$OB_STDIN.PERSON2" ] || miss "outside: an empty answer stored something or exited 0"
ob_tty $'\003' -- ob_run "$ob_b" secrets >/dev/null 2>&1; [ $? != 0 ] && [ ! -e "$OB_STDIN.PERSON2" ] || miss "outside: Ctrl-C at the prompt stored something or exited 0"
```

  `$ob_twin` là một kho có một dòng `recipe = ["key", "key2"]`, `name = "TWIN"`, `source =
  "generated"`, mà hai loại cất vào `TWIN_A` và `TWIN_B`. `$ob_b` là một kho chỉ có một khoá `person`
  tên `PERSON2`.

- [ ] **Step 2: Chạy, thấy đỏ.** `bash tests/run.sh 2>&1 | grep 'outside:'` → `FAIL` cho 52c và 52d.
- [ ] **Step 3: Viết `apply` và `secrets`** trong `outside.py`.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.`
- [ ] **Step 5: Commit.** `feat: outside.py applies settings and takes keys through a hidden prompt`

### Task 4: `github_setup.py --check`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/github_setup.py`
- Modify: `tests/outside.sh`

**Interfaces:**
- Produces: cờ `--check`, không dùng cùng `--apply`. Thoát 0 khi một lượt áp sẽ không đổi gì; 1 khi sẽ
  đổi, hay khi một bước không so được; 2 khi không có `gh`, không phải kho GitHub, hay một lượt đọc
  trạng thái hỏng. Mỗi bước in một dòng: `= <what>` (đã đúng), `~ <what>` (sẽ đổi), `? <what>` (không
  đọc được). Không gọi lệnh ghi nào.

Phải so được ít nhất: cách gộp và `delete_branch_on_merge`; hai môi trường có tồn tại; người duyệt
`production`; và luật nhánh (danh sách check bắt buộc, phần code owner). Bước nào khác không so được
thì tính là `~`.

- [ ] **Step 1: Viết bài đỏ (52g)** với một `gh` thay thế kiểu mục 36 của `tests/run.sh`: nó trả trạng
  thái từ các tệp JSON trong `$TMP`, và ghi mọi lệnh có `-X PUT|POST|PATCH` vào `$OB_LOG`.

```bash
# 52g. github_setup --check: says whether a run would change anything, and writes nothing
ob_gh_state same; ob_setup "$ob_t" --check >"$TMP/ob-check.out"; [ $? = 0 ] || miss "outside: --check on a repository that matches does not exit 0"
ob_gh_state squash_but_policy_merges; ob_setup "$ob_t" --check >"$TMP/ob-check.out"; [ $? = 1 ] && grep -q '^~ ' "$TMP/ob-check.out" || miss "outside: --check does not see a merge setting that differs"
ob_gh_state no_production_environment; ob_setup "$ob_t" --check >/dev/null; [ $? = 1 ] || miss "outside: --check does not see a missing environment"
ob_gh_state rulesets_unreadable; ob_setup "$ob_t" --check >/dev/null; [ $? = 2 ] || miss "outside: --check with a state it cannot read does not exit 2"
[ ! -s "$OB_LOG" ] || miss "outside: --check wrote to GitHub: $(cat "$OB_LOG")"
if ob_setup "$ob_t" --check --apply >/dev/null 2>&1; then miss "outside: --check and --apply together are accepted"; fi
```

- [ ] **Step 2: Chạy, thấy đỏ.** → `FAIL: outside: --check …` (cờ chưa có).
- [ ] **Step 3: Thêm `--check`.** Đọc trạng thái bằng các lệnh `gh api` chỉ đọc; dùng lại `plan()`,
  `existing_ruleset()` và `reviewer_entity()` sẵn có. Lượt chạy thử và `--apply` không đổi hành vi.
- [ ] **Step 4: Chạy lại.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.` (mục 42, 43, 44
  của `tests/run.sh` dùng `github_setup.py`: chúng phải giữ xanh).
- [ ] **Step 5: Commit.** `feat: github_setup.py --check says whether a run would change anything`

### Task 5: Kit gieo sổ vào kho bậc `team`

**Files:**
- Create: `plugins/repo-setup/presets/_core/team/governance/outside.toml`
- Create: `plugins/repo-setup/presets/_core/team/ops/+outside.toml/10-core.toml`
- Create: `plugins/repo-setup/presets/_core/team/ops/+outside.toml/20-release.toml`
- Create: `plugins/repo-setup/capabilities/github-agents/team/ops/+outside.toml/40-agents.toml`
- Create: `plugins/repo-setup/deploy/container/team/ops/+outside.toml/50-deploy.toml`
- Create: `plugins/repo-setup/presets/_core/team/mk/outside.mk`
- Modify: `tests/outside.sh`

**Interfaces:**
- Consumes: định dạng của Task 1; `--check` của Task 4.
- Produces: các loại việc có tên `github-variable`, `github-env-variable`, `github-secret`,
  `github-env-secret`, `github-setup`; đích `make outside`.

Nội dung chốt:

```toml
# governance/outside.toml — the kinds of work the machine may do outside the repository.
# Adding or changing one is a change to the rules of the game: a person decides.
[recipe.github-variable]
where = "github"
kind = "setting"
check = ["gh", "variable", "list", "--json", "name,value", "--jq", '.[] | "\(.name)=\(.value)"']
expect_line = "{name}={value}"
apply = ["gh", "variable", "set", "{name}", "--body", "{value}"]

[recipe.github-secret]
where = "github"
kind = "secret"
check = ["gh", "secret", "list", "--json", "name", "--jq", ".[].name"]
expect_line = "{name}"
store = ["gh", "secret", "set", "{name}"]

[recipe.github-setup]
where = "github"
kind = "setting"
check = ["python3", "tools/github_setup.py", "--check"]
missing_exit = 1
```

- `github-env-variable` và `github-env-secret` giống hai loại trên, thêm `"--env", "{env}"` vào mọi
  lệnh. `github-setup` không có `apply`: áp nó vẫn là `python3 tools/github_setup.py --apply` sau một
  lần người đồng ý.
- `10-core.toml`: lời đầu tệp (từng việc; thêm dòng ở đây đi như mã sản phẩm), và một dòng
  `recipe = "github-setup"`, `name = "repository"`, `how = "python3 tools/github_setup.py shows the
  changes; --apply makes them after your go-ahead"`.
- `20-release.toml`: `RELEASE_PLEASE_TOKEN`, `recipe = "github-secret"`, `source = "person"`, `how`
  lấy lời từ câu về khoá này ở cuối `github_setup.py`. Mảnh này không vào kho `claude-plugin` nếu
  preset đó không dùng release-please: thêm đường dẫn mảnh vào `not_applicable` của preset khi cần,
  và bài 52f kiểm theo `uses_release_please`.
- `40-agents.toml`: `CLAUDE_CODE_OAUTH_TOKEN` (`github-secret`, `person`; `how` nói đổi `name` thành
  `ANTHROPIC_API_KEY` nếu kho dùng khoá đó) và `action = "install-claude-github-app"`.
- `50-deploy.toml`: `decision = "approve-production"`, `when = "each deploy to production"`. Không
  gieo `DEPLOY_ENABLED`.
- `mk/outside.mk`: đích `outside` chạy `python3 tools/outside.py status`, có dòng `##` mô tả như các
  đích khác. Không thêm vào `CHECK_TARGETS`: nó cần mạng.

- [ ] **Step 1: Viết bài đỏ (52f).**

```bash
# 52f. what the kit seeds: every row names a recipe that exists, by layer
ob_new() { local d="$TMP/ob-$1"; shift; mkdir -p "$d" && git -C "$d" init -q -b main && python3 "$S/apply.py" --target "$d" --var project_name=O --var description=x --var owner=acme "$@" >/dev/null; printf '%s' "$d"; }
ob_team=$(ob_new team --preset ts-node --level team)
ob_agents=$(ob_new agents --preset ts-api --level team --with github-agents --deploy container)
ob_start=$(ob_new start --preset ts-node)
[ ! -e "$ob_start/tools/outside.py" ] && [ ! -e "$ob_start/ops/outside.toml" ] || miss "outside: a starter repository got the ledger"
for d in "$ob_team" "$ob_agents"; do
  out=$(ob_seed_problems "$d") || miss "outside: the seeded ledger of ${d##*/} does not hold: $out"
done
ob_seed_ids() { python3 "$1/tools/outside.py" --root "$1" status --draft --json | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)["all"]))'; }
case " $(ob_seed_ids "$ob_team") " in *" github-setup:repository "*" github-secret:RELEASE_PLEASE_TOKEN "*) ;; *) miss "outside: team seeds are not the setup row and the release key" ;; esac
case " $(ob_seed_ids "$ob_agents") " in *" github-secret:CLAUDE_CODE_OAUTH_TOKEN "*" action:install-claude-github-app "*" decision:approve-production "*) ;; *) miss "outside: the agent and deploy layers did not add their rows" ;; esac
! grep -q DEPLOY_ENABLED "$ob_agents/ops/outside.toml" || miss "outside: DEPLOY_ENABLED is seeded"
grep -q '^outside:.*##' "$ob_team/mk/outside.mk" || miss "outside: no make target"
[ "$(python3 "$ob_team/tools/autonomy.py" --files governance/outside.toml | ob_tier)" = high ] || miss "outside: the recipes file is not a rule of the game"
[ "$(python3 "$ob_team/tools/autonomy.py" --files ops/outside.toml | ob_tier)" != high ] || miss "outside: a row of the ledger is a rule of the game"
```

  `ob_seed_problems` nạp hai tệp của kho bằng `outside_ledger`, in mọi dòng bị từ chối và mọi loại
  việc không có `check`. `ob_tier` đọc hạng từ đầu ra của `tools/autonomy.py` như mục 16 của
  `tests/run.sh` đang đọc.

- [ ] **Step 2: Chạy, thấy đỏ.** → `FAIL: outside: …` cho 52f.
- [ ] **Step 3: Tạo các tệp** theo «Nội dung chốt».
- [ ] **Step 4: Kiểm lệnh thật, không cần mạng.** `gh variable list --help | grep -- --json`,
  `gh secret list --help | grep -- --json`, `gh secret set --help | grep 'standard input'`: mỗi lệnh
  in một dòng. Không in thì ghi một `Ruling:` và đổi loại việc cho khớp `gh` đang có.
- [ ] **Step 5: Chạy cả bộ.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.` Các mục đếm tệp
  của bậc `team` (7, 23, 47) đổi theo số tệp mới nếu chúng đỏ.
- [ ] **Step 6: Commit.** `feat: team repositories get the ledger of work outside the repository`

### Task 6: Luật, quy trình dựng, tài liệu

**Files:**
- Create: `plugins/repo-setup/presets/_core/team/+AGENTS.md/57-outside.md`
- Create: `plugins/repo-setup/skills/new/references/outside.md`
- Modify: `plugins/repo-setup/skills/new/SKILL.md`, `plugins/repo-setup/skills/github/SKILL.md`,
  `plugins/repo-setup/skills/adopt/SKILL.md`, `plugins/repo-setup/skills/new/references/tour.md`,
  `plugins/repo-setup/skills/new/references/layers/delivery.md`
- Modify: `docs/setup-principles.md`, `tests/run.sh` (43k), `tests/outside.sh`, `CHANGELOG.md`

**Interfaces:**
- Consumes: tên lệnh và tên tệp của các task trước.

Nội dung chốt:

- `57-outside.md`, tiêu đề `## Work outside the repository`, ba mục, mỗi mục kết bằng
  `<!-- kept: word -->`:
  1. Việc ngoài kho (cài đặt GitHub, biến, khoá, nơi chạy ứng dụng) đi qua `python3 tools/outside.py`:
     `status`, rồi `apply`. Không giao cho người một bước mà công cụ áp được.
  2. Khi cần người: đưa đúng danh sách `Yours` của công cụ, một lần, kèm lệnh
     `python3 tools/outside.py secrets`.
  3. Không bao giờ nhận giá trị một khoá trong cuộc trò chuyện, trên dòng lệnh, hay trong tệp.
  Lời không chứa cụm nào trong danh sách cấm của bài 43g.
- `skills/new/SKILL.md`: bỏ đoạn «Stop and ask for anything outside the folder…». Thêm mục
  `## 7. Outside the repository` với bốn bước của thiết kế (5.1, «Chặng ngoài kho»), chỉ chạy ở bậc
  `team` khi kho đã có máy chủ GitHub; tạo kho và đẩy lần đầu vẫn hỏi một lần. Mục `Finish` thành 8.
- `references/outside.md`: cách máy soạn loại việc và dòng cho một nền tảng kit không sinh: ưu tiên
  lệnh dòng của chính dịch vụ; mỗi loại có `check` dạng liệt kê rồi so dòng; phần bí mật là dòng
  `secret` riêng; thử từng lệnh trực tiếp trong phiên trước khi viết; loại việc mới đi trong một PR
  riêng để một người quyết; `DEPLOY_ENABLED` chỉ thêm khi `make deploy` đã chạy được.
- `skills/github/SKILL.md` và `skills/adopt/SKILL.md`: một đoạn nói kỹ năng này là phần GitHub của
  chặng «ngoài kho», và kết thúc bằng `python3 tools/outside.py status`.
- `tour.md` mục 6 và `layers/delivery.md` (lựa chọn `manual`): trỏ tới `make outside` và trang
  `references/outside.md`.
- `docs/setup-principles.md`: tiêu đề `## Mười luật` thành `## Mười một luật`; dòng trạng thái đầu
  trang ghi luật 11 thêm ngày 2026-11-22; luật 11 «**Việc ngoài kho: máy làm.** Người tạo khoá, nhập
  khoá và quyết. Loại việc máy được làm ngoài kho nạp từ nhánh gốc.»; hàng 11 ở bảng «Luật nằm ở
  đâu trong mã»: `tools/outside.py`, `governance/outside.toml` | `52b, 52c, 52d, 52e`.
- `tests/run.sh` 43k: chuỗi `## Mười luật` thành `## Mười một luật` ở cả hai chỗ.
- `CHANGELOG.md`, dưới `## Unreleased`: mục «Added: work outside the repository goes through one
  tool», nói có gì, và «What breaks on upgrade»: không gì gãy; kho bậc `team` nhận sáu tệp mới; công
  cụ cần Python 3.11; phần 5.3 và 5.2 của thiết kế chưa có.

- [ ] **Step 1: Viết bài đỏ (52h).**

```bash
# 52h. the rule, the setup stage and the page that say it
grep -q 'python3 tools/outside.py' "$ob_team/AGENTS.md" || miss "outside: AGENTS.md of a team repository does not name the tool"
! grep -q 'tools/outside.py' "$ob_start/AGENTS.md" || miss "outside: a starter repository is told of a tool it does not have"
nw="$ROOT/plugins/repo-setup/skills/new/SKILL.md"
! grep -q 'Stop and ask for anything outside the folder' "$nw" || miss "outside: the new-repository skill still stops for everything outside the folder"
grep -q '^## 7. Outside the repository$' "$nw" && grep -q 'tools/outside.py secrets' "$nw" || miss "outside: the new-repository skill has no outside stage"
[ -s "$ROOT/plugins/repo-setup/skills/new/references/outside.md" ] || miss "outside: no page on writing recipes for a platform the kit does not generate"
for s in github adopt; do grep -q 'tools/outside.py status' "$ROOT/plugins/repo-setup/skills/$s/SKILL.md" || miss "outside: the $s skill does not end with the status"; done
grep -q '^11\. \*\*Việc ngoài kho: máy làm\.\*\*' "$ROOT/docs/setup-principles.md" || miss "outside: rule 11 is not on the principles page"
```

- [ ] **Step 2: Chạy, thấy đỏ.** → `FAIL: outside: …` cho 52h.
- [ ] **Step 3: Viết các tệp và sửa các trang** theo «Nội dung chốt».
- [ ] **Step 4: Chạy cả bộ.** `bash tests/run.sh 2>&1 | tail -1` → `All tests passed.` Chú ý 43g, 43k,
  50m, 50n, 50p và mục 26, 29.
- [ ] **Step 5: Thử nâng cấp trên bản sao.** Chép một kho bậc `team` dựng bằng bản 0.10.4 (thẻ
  `repo-setup-v0.10.4`) vào `$TMP`, chạy `apply.py --target` bằng mã của nhánh này: thoát 0, không
  dấu xung đột, sáu tệp mới ở danh sách `created`. Ghi kết quả vào mục changelog.
- [ ] **Step 6: Commit.** `feat: the setup has an outside-the-repository stage, and rule 11 says who does what`
