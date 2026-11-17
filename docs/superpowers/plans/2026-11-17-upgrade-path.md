# Đường nâng cấp (RS8): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chạy lại `apply.py` thì bản sửa của mẫu tới được tệp kho đã sửa tại chỗ (gộp ba chiều,
ghi dấu khi đụng nhau), `make check` đỏ cho tới khi gỡ hết dấu, và `doctor` báo tệp nào lệch nguồn.

**Architecture:** Bản gốc của mỗi tệp được dựng lại từ mẫu của bản plugin đã ghi nó: mẫu ở máy
khi cùng bản, không thì tệp nén của tag tải từ GitHub (hoặc `--base-from`). Gốc chỉ dùng khi băm
khớp manifest. Gộp bằng `git merge-file --diff3`. Hai mô-đun mới trong `scripts/` giữ phần tìm gốc
và phần gộp; `apply.py` chỉ giữ bảng quyết định. Bức tường là một bước `make check` mới trong
`_core/starter`.

**Tech Stack:** Python 3.11+ thư viện chuẩn, git (`merge-file`, `ls-remote`), bash 3.2 cho bộ kiểm.

**Spec:** `docs/superpowers/specs/2026-11-17-upgrade-path-design.md`. Đọc spec trước khi làm; bảng
«Với mỗi tệp trong kế hoạch» là luật của Task 4.

## Global Constraints

- `apply.py`, `doctor.py` và các mô-đun mới chỉ dùng thư viện chuẩn của Python 3.11.
- `bash tests/run.sh` không dùng mạng: mọi gốc trong bộ kiểm đi qua `--base-from`.
- Không chạy mã nào tải về: chỉ đọc tệp trong `plugins/repo-setup/` của bản tải về.
- Kho nguồn: `SOURCE_REPO = "phanlemanh/repo-standards"`. Tag: `repo-setup-v<bản>`. Tệp nén:
  `https://codeload.github.com/{repo}/tar.gz/refs/tags/{tag}`.
- Nhãn dấu, đúng từng chữ: `<<<<<<< this repository`, `||||||| repo-setup <bản gốc>` hoặc
  `||||||| repo-setup: no matching base`, `=======`, `>>>>>>> repo-setup <bản mới>`.
- Nhóm kết quả của `apply.py`: giữ `created`, `updated`, `merged`, `unchanged`, `kept`, `skipped`,
  `conflict`; thêm `edited`, `marked`, `base_unread`, `removed`, `dropped`. `conflict` giữ nghĩa
  cũ (tệp có sẵn trước khi cài, để nguyên).
- Mã thoát của `apply.py`: 1 khi `marked` hoặc `base_unread` khác rỗng, 0 khi không.
- Tên tệp, hàm, nhánh: tiếng Anh. Tài liệu trong `docs/`: tiếng Việt. Thay đổi hành vi ghi dưới
  `## Unreleased` của `CHANGELOG.md`, kèm cái gì phá khi nâng cấp.
- Mục 43 của `tests/run.sh` (người quyết, máy kiểm) phải còn xanh: không thêm luật `ask`, không thêm
  bước bắt người dừng.
- Nhánh làm việc: `feat/upgrade-path`, từ `main` tại `9c32c39` trở về sau.

## Review Focus

1. **Tệp không có dòng xuống cuối, hay xuống dòng CRLF.** Gộp xong vẫn giữ nguyên cách xuống dòng
   của kho. Kiểm ở Task 4, bước 1 (47f).
2. **Tệp nhị phân hoặc không phải UTF-8 trong kế hoạch.** `git merge-file` từ chối thì tệp thành
   `base_unread` có lý do, lệnh không đổ. Kiểm ở Task 3, bước 1.
3. **Tệp chạy được (bit x) được gộp.** Bit chạy được giữ nguyên sau khi ghi kết quả gộp. Kiểm ở
   Task 4, bước 1 (47f).
4. **Tệp nén hỏng, hay có mục trỏ ra ngoài (`../`, đường dẫn tuyệt đối, liên kết).** Không có gì
   được ghi ra ngoài thư mục tạm; bản đó thành «không đọc được». Kiểm ở Task 2, bước 1.
5. **`--dry-run` khi có tệp sẽ gộp.** Không ghi tệp nào, không đổi manifest, các nhóm giống hệt lần
   chạy thật. Kiểm ở Task 4, bước 1 (47b).

---

### Task 1: Mẫu có gốc là một tham số

Không đổi hành vi. Các hàm dựng kế hoạch đọc thư mục mẫu từ tham số thay vì hằng `PLUGIN_ROOT`, để
Task 2 dựng được mẫu của bản cũ bằng cùng mã.

**Files:**

- Modify: `plugins/repo-setup/scripts/apply.py` (các hàm `preset_chain`, `available`,
  `capabilities_for`, `units`, `load_meta`, `layers_for`, `build_plan`, và phần lọc
  `exclude`/`not_applicable`/`team_only` trong `main`)
- Test: `tests/run.sh` (mục mới 47, phần 47a)

**Interfaces:**

- Produces:

  - `@dataclass(frozen=True) class Choices: preset: str; level: str; archetype: str; deploy: str; caps: tuple[str, ...]`
  - `def choices_from_manifest(manifest: dict) -> Choices`
  - `def planned_files(choices: Choices, variables: dict[str, str], root: Path = PLUGIN_ROOT) -> dict[str, dict]`:
    khoá là đường dẫn posix; giá trị như `build_plan` (`content`, `executable`, `source`), đã lọc
    `exclude`, `not_applicable`, `team_only`.
  - Mỗi hàm trong danh sách trên nhận thêm `root: Path = PLUGIN_ROOT` ở cuối.
  - `def render_variables(raw: dict[str, str], choices: Choices, root: Path = PLUGIN_ROOT) -> dict[str, str]`:
    `derive_vars` rồi thêm `vars` mặc định của `load_meta`, như `main` làm hôm nay.

- [ ] **Bước 1: Viết bài kiểm 47a.** Dựng một kho `python` level `team` vào `$TMP/up-a`. Gọi
      `planned_files(choices_from_manifest(m), render_variables(m["vars"], ...))` qua `python3 -c` với
      `sys.path` trỏ vào `scripts/`. Mọi khoá có trong `m["files"]` phải có băm nội dung bằng đúng giá
      trị đã ghi. Sai thì `miss "upgrade: planned_files does not rebuild what apply wrote"`.
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47a vì chưa có `planned_files`.
- [ ] **Bước 3: Thêm tham số `root` và các hàm trên.** `main` gọi `planned_files` thay cho đoạn
      `build_plan` cộng lọc hiện có.
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.`
- [ ] **Bước 5: Commit** `refactor(apply): templates come from a root that can be another version`.

### Task 2: Tìm gốc của một tệp

**Files:**

- Create: `plugins/repo-setup/scripts/upgrade_base.py`
- Test: `tests/run.sh` (47c, 47d, 47e)

**Interfaces:**

- Consumes: `planned_files`, `render_variables`, `Choices` (Task 1).
- Produces:
  - Hằng `SOURCE_REPO`, `TAG_PREFIX = "repo-setup-v"`, `ARCHIVE_URL` (Global Constraints),
    `FETCH_TIMEOUT = 30` (giây).
  - `class BaseUnreadable(Exception)`: thông điệp là lý do, đọc được.
  - `@dataclass(frozen=True) class Base: status: Literal["found", "no_match", "unread"]; content: bytes | None = None; version: str | None = None; reason: str = ""`
  - `def released_versions(base_from: Path | None) -> list[str]`: mới nhất trước, so theo số
    (`0.10.0` > `0.9.0`). Có `base_from` thì là các bản có trong thư mục đó, không thì
    `git ls-remote --tags https://github.com/{SOURCE_REPO}.git`. Lỗi thì `BaseUnreadable`.
  - `def plugin_root_for(version: str, base_from: Path | None, workdir: Path) -> Path`:
    trả thư mục `plugins/repo-setup` của bản đó. `base_from` chứa `repo-setup-v<bản>/` (một thư
    mục plugin, có `.claude-plugin/plugin.json`) hoặc `repo-setup-v<bản>.tar.gz` (tệp nén kiểu
    codeload); không có `base_from` thì tải `ARCHIVE_URL` bằng `urllib.request`. Giải nén chỉ lấy
    các mục dưới `*/plugins/repo-setup/`, bỏ mục có `..`, đường dẫn tuyệt đối hay liên kết, dùng
    `filter="data"` khi `tarfile` có. Lỗi thì `BaseUnreadable`.
  - `class BaseFinder`, khởi tạo `BaseFinder(render: Callable[[Path], dict[str, bytes]], current_root: Path, current_version: str, base_from: Path | None, workdir: Path)`,
    với `render(root)` trả `{đường dẫn: nội dung}` của mẫu ở `root`. Phương thức:
    `def find(self, path: str, recorded_hash: str, recorded_version: str) -> Base`.

Thứ tự thử trong `find`, dừng ở bản đầu tiên mà `sha256` của tệp đó khớp `recorded_hash`:

1. nếu `recorded_version == current_version`: mẫu ở `current_root` (không cần mạng);
2. bản `recorded_version`;
3. các bản trong `released_versions` nhỏ hơn `recorded_version`, mới nhất trước.

Mỗi bản chỉ tải và dựng một lần trong một `BaseFinder`. Bản không đọc hay không dựng được (lỗi
tải, `KeyError` của placeholder) thì bỏ qua và nhớ lý do. Kết quả: `found` khi khớp; `no_match` khi
ít nhất một bản dựng được mà không bản nào khớp (kể cả khi không bản nào có tệp đó); `unread` khi
không bản nào đọc được, `reason` là lý do của lần thử đầu.

- [ ] **Bước 1: Viết bài kiểm 47c–47e.** Chuẩn bị chung cho mục 47: chép plugin vào
      `$TMP/arch/repo-setup-v0.0.1/`, đổi `version` trong `.claude-plugin/plugin.json` của bản chép
      thành `0.0.1`; tạo `$TMP/arch/repo-setup-v0.0.2/` cùng cách với `0.0.2`. Trong bản 0.0.1 (chỉ
      bản này), sửa mẫu để nó cũ hơn bản hiện tại: (a) bỏ dòng cuối của
      `presets/_core/starter/dot.editorconfig`; (b) đổi một dòng giữa của
      `presets/_core/starter/CLAUDE.md`; (c) bỏ dòng cuối của một tệp `tools/*.py` chạy được của
      `_core/starter` và của mẫu `pyproject.toml` của preset `python`. Task 4 dùng lại đúng các sửa này.
  - 47c: `BaseFinder` với `base_from=$TMP/arch` tìm ra gốc `found`, `version == "0.0.1"`, cho
    `.editorconfig` ghi bằng bản 0.0.1 mà manifest ghi `recorded_version = "0.0.2"` (trường hợp
    manifest cũ ghi bản cao hơn bản thật của tệp). Sai thì
    `miss "upgrade: a base from an older release is not found"`.
  - 47d: `base_from` trỏ vào thư mục rỗng: `status == "unread"` và `reason` khác rỗng. Băm không
    khớp bản nào: `status == "no_match"`.
  - 47e: một tệp nén có mục `../evil` và mục `/tmp/abs`: `plugin_root_for` báo `BaseUnreadable`
    hoặc bỏ hai mục đó, và không có tệp nào xuất hiện ngoài `workdir`. Một tệp nén cụt (cắt đôi):
    `BaseUnreadable`.
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47c–47e.
- [ ] **Bước 3: Viết `upgrade_base.py` theo Interfaces.**
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.`
- [ ] **Bước 5: Commit** `feat(apply): find the template a file was written from, in any release`.

### Task 3: Gộp ba chiều

**Files:**

- Create: `plugins/repo-setup/scripts/upgrade_merge.py`
- Test: `tests/run.sh` (47g)

**Interfaces:**

- Produces:

  - `OURS_LABEL = "this repository"`, `NO_BASE_LABEL = "repo-setup: no matching base"`,
    `def release_label(version: str) -> str` trả `f"repo-setup {version}"`.
  - `class MergeUnavailable(Exception)`: không có git, hoặc `git merge-file` báo lỗi (mã thoát âm
    hay từ 128), ví dụ tệp nhị phân.
  - `def three_way(current: bytes, base: bytes, new: bytes, base_label: str, new_label: str) -> tuple[bytes, bool]`:
    `git merge-file -p --diff3 -L OURS_LABEL -L base_label -L new_label` trên ba tệp tạm; trả
    (nội dung, sạch hay không). Gốc rỗng (`b""`) là cách gộp hai chiều của spec.

- [ ] **Bước 1: Viết bài kiểm 47g** (gọi thẳng `three_way` qua `python3 -c`):
  - không đụng nhau: kết quả chứa cả dòng kho thêm lẫn dòng mẫu thêm, `clean is True`;
  - đụng nhau: `clean is False`, kết quả có dòng `<<<<<<< this repository`,
    `||||||| repo-setup 0.0.1`, `>>>>>>> repo-setup 0.0.2`;
  - gốc rỗng: `clean is False`, có `||||||| repo-setup: no matching base`;
  - nội dung có byte `\x00`: `MergeUnavailable` (Review Focus 2).
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47g.
- [ ] **Bước 3: Viết `upgrade_merge.py`.**
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.`
- [ ] **Bước 5: Commit** `feat(apply): three-way merge with labelled conflict markers`.

### Task 4: Bảng quyết định của `apply.py`

**Files:**

- Modify: `plugins/repo-setup/scripts/apply.py` (vòng lặp từng tệp, manifest, mã thoát, đầu ra,
  docstring đầu tệp mục «Safety rules»)
- Modify: `tests/run.sh` bài kiểm 5 (đổi mong đợi, xem bước 1)
- Test: `tests/run.sh` (47b, 47f, 47h)

**Interfaces:**

- Consumes: `planned_files`, `render_variables`, `choices_from_manifest` (Task 1); `BaseFinder`,
  `Base`, `BaseUnreadable` (Task 2); `three_way`, `MergeUnavailable`, `release_label`,
  `NO_BASE_LABEL` (Task 3).
- Produces:
  - Cờ mới `--base-from DIR` (xem Task 2).
  - Manifest: khoá `file_versions: dict[str, str]`; `vars` có `today`, ghi lần đầu RS8 chạy, rồi
    giữ nguyên (lần chạy sau đọc lại `today` từ manifest).
  - Đầu ra `--json`: các nhóm của Global Constraints, `base_reasons: dict[str, str]` cho
    `base_unread`, và `exit_code`. `--diff` đặt vào `diffs` nội dung sẽ ghi cho mỗi tệp `marked`.
  - `render` truyền cho `BaseFinder`: với một `root`, `planned_files(choices, render_variables(vars, choices, root), root)`
    lấy `content`, với `choices` và `vars` đọc từ manifest cũ.
  - `MergeUnavailable` khi gộp: tệp vào `base_unread` với lý do của nó (spec: không có git thì cư xử
    như hôm nay và nói ra).
  - `def decide(...)` hay tên tương đương: người dựng chọn, miễn mỗi hàng của bảng spec là một
    nhánh có thể kiểm riêng.

Luật, theo bảng «Với mỗi tệp trong kế hoạch» của spec, thêm một hàng spec để ngỏ: tệp đã sửa mà mẫu
mới bằng gốc thì vào `edited`, để nguyên, ghi băm và bản mới. Tệp `user_owned` có trong manifest cũ
đi theo cùng bảng; tệp `user_owned` chưa có trong manifest giữ đường `kept` như hôm nay. Khi
`package.json` hay `pyproject.toml` vào `updated` hoặc `merged`, thêm vào `notes` câu nhắc chạy lệnh
cài để cập nhật tệp khoá. `--adopt` lần đầu: tệp không có trong manifest cũ đi đường hiện tại, không
qua `BaseFinder`. Bản gốc của tệp: `file_versions[path]`, không có thì `previous["version"]`. Khi ghi
kết quả gộp, giữ bit chạy được của tệp hiện tại.

- [ ] **Bước 1: Viết bài kiểm 47b, 47f, 47h và sửa bài kiểm 5.** Chuẩn bị: dùng bản chép
      `repo-setup-v0.0.1` đã sửa (a), (b), (c) ở Task 2. Dựng kho `python` starter vào `$TMP/up` bằng
      `apply.py` của bản chép đó (manifest ghi `0.0.1`). Trong kho: thêm một dòng chú thích ở đầu
      `.editorconfig`; sửa đúng dòng (b) của `CLAUDE.md` theo cách khác; thêm một dòng vào đầu tệp
      `tools/*.py` đó, và đổi nó sang xuống dòng CRLF; xoá `README.md`; thêm `[tool.x]` vào cuối
      `pyproject.toml`. Rồi chạy `apply.py` hiện tại với `--base-from $TMP/arch --json`.
  - 47b: lần chạy `--dry-run` trước đó cho ra đúng các nhóm như lần chạy thật, và không đổi tệp
    nào, kể cả `.repo-setup.json` (so băm trước và sau).
  - 47f: `.editorconfig` và tệp `tools/*.py` trong `merged`, chứa cả dòng kho thêm lẫn dòng mẫu
    thêm; tệp `tools/*.py` còn bit chạy được và còn CRLF ở các dòng không đổi; `pyproject.toml`
    trong `merged` và có dòng `[tool.x]`; `notes` có câu nhắc cài lại.
  - 47h: `CLAUDE.md` trong `marked`, có đủ bốn nhãn; mã thoát 1; `README.md` trong `removed` và
    không bị tạo lại; `file_versions` của các tệp gộp là bản hiện tại; gỡ dấu trong `CLAUDE.md`
    rồi chạy lại thì mã thoát 0 và `marked` rỗng. Một kho thứ ba dựng bằng 0.0.1 rồi xoá khoá
    `file_versions` khỏi manifest (manifest kiểu cũ): lần nâng cấp cho ra cùng các nhóm như kho
    `$TMP/up`. Sửa tay `.repo-setup.json` cho một tệp mang băm
    không bản nào có: tệp đó vào `marked` với `||||||| repo-setup: no matching base`. Đổi
    `--base-from` sang thư mục rỗng và đặt `file_versions` của một tệp đã sửa về `0.0.1`: tệp đó
    vào `base_unread`, để nguyên, `base_reasons` có lý do, mã thoát 1. `--diff` với `CLAUDE.md` còn
    đụng nhau: `diffs["CLAUDE.md"]` có dòng `<<<<<<< this repository`. Tệp mẫu thôi sinh ra: thêm
    `exclude = ["<một tệp chưa sửa, ví dụ .editorconfig của kho thứ hai>"]` vào
    `presets/python/preset.toml` của bản chép `repo-setup-v0.0.2`, rồi chạy `apply.py` của bản chép
    đó trên một kho `python` thứ hai dựng bằng 0.0.1: tệp đó vào `dropped`, còn trên đĩa, và ra khỏi
    `files` lẫn `file_versions`.
  - Bài kiểm 5 (`README.md` sửa tại chỗ): nay mong `README.md` trong `edited` thay vì `conflict`,
    và nội dung `my note` còn nguyên. Bài kiểm 4 giữ nguyên.
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47b, 47f, 47h và bài kiểm 5.
- [ ] **Bước 3: Dựng bảng quyết định, manifest, mã thoát và đầu ra.** Đầu ra văn bản in thêm, khi
      có `marked`: «Remove the conflict markers, then run make check»; khi có `base_unread`: lý do và
      «run again with network access, or pass --base-from».
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.` Bài kiểm cũ nào khác đổi
      thì đó là lỗi, trừ khi nó kiểm việc tạo lại tệp kho đã xoá: khi đó sửa nó và nêu tên trong commit.
- [ ] **Bước 5: Commit** `feat(apply)!: template fixes reach files edited in place`.

### Task 5: Bức tường cho dấu xung đột

**Files:**

- Create: `plugins/repo-setup/presets/_core/starter/mk/upgrade.mk`
- Create: `plugins/repo-setup/presets/_core/starter/tools/upgrade_markers.py` (chạy được)
- Test: `tests/run.sh` (47i)

**Interfaces:**

- Produces:

  - `upgrade.mk`: `CHECK_TARGETS += upgrade`; target `upgrade` chạy
    `@$(PYTHON) tools/upgrade_markers.py` (dùng `python3` nếu `PYTHON` chưa có; Makefile của
    `claude-plugin` không định nghĩa `PYTHON`). `.PHONY: upgrade`.
  - `upgrade_markers.py`: `def markers(root: Path) -> list[tuple[str, int]]` đọc danh sách tệp
    trong `.repo-setup.json` và trả các dòng mở đầu bằng `<<<<<<< this repository` hoặc
    `>>>>>>> repo-setup `. `main` in `path:line` từng dòng, kèm một câu việc phải làm, thoát 1 khi
    có; in một dòng ngắn và thoát 0 khi không. Không có manifest: thoát 0.

- [ ] **Bước 1: Viết bài kiểm 47i.** Với kho `$TMP/up` của Task 4 lúc `CLAUDE.md` còn dấu:
      `make check` đỏ và đầu ra có `CLAUDE.md:`. Một tệp không có trong manifest (`docs/x.md`) chứa
      `<<<<<<< this repository`: không bị báo. Gỡ dấu: bước `upgrade` xanh. Ba preset `python`,
      `ts-node`, `claude-plugin` dựng mới đều có `upgrade` trong `make -n check` (hoặc in ra
      `CHECK_TARGETS`).
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47i.
- [ ] **Bước 3: Viết hai tệp.**
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.` Mục 1–6 của mọi preset
      tạo thêm đúng hai tệp này; số `created` vẫn từ 20 trở lên.
- [ ] **Bước 5: Commit** `feat(core): make check stays red while conflict markers remain`.

### Task 6: `doctor` báo lệch nguồn

**Files:**

- Create: `plugins/repo-setup/scripts/upgrade_report.py`
- Modify: `plugins/repo-setup/scripts/doctor.py` (kiểu kiểm mới `setup`, mục «Upgrade» trong đầu
  ra văn bản và khoá `upgrade` trong `--json`)
- Modify: `plugins/repo-setup/checklists/top-tier.toml` (hai `[[check]]` mới)
- Test: `tests/run.sh` (47j)

**Interfaces:**

- Consumes: định dạng manifest của Task 4; nhãn của Task 3 (đọc dấu bằng cùng hai mẫu dòng như
  `upgrade_markers.py`).
- Produces:

  - `@dataclass(frozen=True) class UpgradeReport: edited: list[str]; behind: list[tuple[str, str]]; removed: list[str]; marked: list[tuple[str, int]]; plugin_version: str`
    (`behind` là `(đường dẫn, bản gốc)` cho tệp có bản nhỏ hơn `version` của manifest).
  - `def report(root: Path, setup: dict) -> UpgradeReport`. Không mạng, chỉ đọc tệp.
  - `def wall_present(root: Path) -> bool`: có `mk/upgrade.mk` và `Makefile` có
    `-include mk/*.mk` hoặc `include mk/upgrade.mk`.
  - Hai phép kiểm, `type = "setup"`, `level = "starter"`: `setup_in_sync` (`weight = 2`, đỏ khi
    `marked` hoặc `behind` khác rỗng) và `upgrade_wall` (`weight = 1`, đỏ khi `wall_present` sai).
    Kho không có `.repo-setup.json`: cả hai `skipped`.
  - Văn bản: mục «Upgrade» liệt kê bốn nhóm; một tệp `behind` in dạng `0.4.0 → 0.6.0`.

- [ ] **Bước 1: Viết bài kiểm 47j.** Kho `$TMP/up` khi còn dấu: `setup_in_sync` trong `failed`,
      `--json` có `upgrade.marked` với `CLAUDE.md`, `upgrade.removed` với `README.md`, `upgrade.edited`
      gồm `.editorconfig`. Sau khi gỡ dấu và chạy lại `apply.py`: `setup_in_sync` qua. Một tệp có
      `file_versions` cũ hơn `version`: `behind` có nó, `setup_in_sync` đỏ. Xoá `mk/upgrade.mk`:
      `upgrade_wall` đỏ.
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: đỏ ở 47j.
- [ ] **Bước 3: Viết `upgrade_report.py`, nối vào `doctor.py`, thêm hai phép kiểm.**
- [ ] **Bước 4: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.` Bài kiểm 6 không đổi (cả
      hai phép kiểm qua trên kho dựng mới). Bài kiểm nào nêu đúng danh sách phép kiểm đỏ của một kho
      `--adopt` có `Makefile` riêng thì được thêm `upgrade_wall`; bài khác đổi là lỗi.
- [ ] **Bước 5: Commit** `feat(doctor): say which files drift from the plugin, and from which release`.

### Task 7: Lời của skill, CHANGELOG và tài liệu

**Files:**

- Modify: `plugins/repo-setup/skills/doctor/SKILL.md` (bước 3: tệp đã sửa nay được gộp; cách đọc
  `marked` và `base_unread`; không còn câu «existing files are never overwritten»)
- Modify: `plugins/repo-setup/skills/adopt/SKILL.md` (chỉ khi câu về `conflict / kept` sai sau
  Task 4; lần adopt đầu không đổi)
- Modify: `plugins/repo-setup/skills/explain/SKILL.md` (dòng `.repo-setup.json`: nay nó cũng ghi
  bản của từng tệp)
- Modify: `CHANGELOG.md` (mục mới `### Upgrade path` dưới `## Unreleased`)
- Modify: `docs/superpowers/specs/2026-11-17-upgrade-path-design.md` (thêm hàng `edited` vào bảng
  «Với mỗi tệp trong kế hoạch»)
- Modify: `docs/three-repo-overview-design.md` (ô trạng thái RS8)
- Test: `tests/run.sh` (mục 43 và 45 phải còn xanh)

- [ ] **Bước 1: Viết lại các câu trên.** CHANGELOG nêu đủ các thay đổi phá tương thích của mục
      «Ghi vào CHANGELOG khi phát hành» trong spec, và `today` được ghi vào manifest.
- [ ] **Bước 2: Chạy `bash tests/run.sh`.** Mong đợi: `All tests passed.`
- [ ] **Bước 3: Commit** `docs: describe the upgrade path`.

### Task 8: Combo e2e «nâng từ bản phát hành trước»

**Files:**

- Modify: `tests/e2e.sh` (một khối sau vòng lặp các combo)

- [ ] **Bước 1: Viết khối.** Lấy tag mới nhất `repo-setup-v*` của kho
      (`git -C "$ROOT" describe --tags --abbrev=0 --match 'repo-setup-v*'`). Tải tệp nén của tag đó từ
      `ARCHIVE_URL`, dựng kho `python` level `team` bằng `apply.py` của bản đó. Thêm một dòng chú thích
      ở đầu `.editorconfig` và một dòng vào cuối `README.md`, commit. Chạy `apply.py` hiện tại, không
      `--base-from`. Đòi: `base_unread` rỗng; hai dòng kho thêm còn trong tệp; nếu `marked` rỗng thì
      chạy lệnh cài rồi `make check` xanh; nếu `marked` khác rỗng thì `make check` đỏ và đầu ra có
      tên các tệp đó. Không có mạng thì khối báo `FAIL` (e2e đã cần mạng).
- [ ] **Bước 2: Chạy `bash tests/e2e.sh`** (chạy nền, khoảng 20 phút). Mong đợi: `E2E passed.`
- [ ] **Bước 3: Commit** `test(e2e): upgrade from the previous release`.

### Task 9: Chạy thật trên `design-ci-probe`

Không viết mã. Cần chủ kho cho phép thao tác trên kho thử ở bước này: mở PR, gộp PR.

- [ ] **Bước 1:** Clone `phanlemanh/design-ci-probe` vào thư mục tạm. Lấy `apply.py` của tag
      `repo-setup-v0.6.0`, chạy trên kho thử, mở PR, chờ CI, gộp. Ghi số tệp `updated` và `conflict`.
- [ ] **Bước 2:** Trên một nhánh mới, sửa tại chỗ hai tệp mà nhánh `feat/upgrade-path` đổi so với
      0.6.0 (một chỗ không đụng nhau, một chỗ đụng nhau), mở PR, gộp.
- [ ] **Bước 3:** Chạy `apply.py` của nhánh `feat/upgrade-path` trên kho thử. Mở PR. Mong đợi: chỗ
      không đụng nhau đã gộp; ô `check` đỏ vì bước `upgrade` và nêu đúng tệp; gỡ dấu, đẩy lên, ô xanh,
      PR gộp được.
- [ ] **Bước 4:** Ghi kết quả vào mục «Chạy thật ở kho thử» của
      `docs/three-repo-overview-design.md` và vào `CHANGELOG.md`, commit
      `docs: the upgrade path on a probe repository`.
