# Mỗi tệp một người ghi (RS2b): kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Log, mục lục wiki, glossary và mã sinh từ ontology thôi đi theo PR. Mảnh là nguồn; tệp
ở đường dẫn cũ được vẽ lại, nằm ngoài git; kho cũ vẫn xanh cho tới khi tự tách.

**Architecture:**
- Một công cụ mới của lõi, `tools/ledgers.py` (thư viện chuẩn), lo việc vẽ, kiểm, ghi và tách cho
  bốn sổ.
- Một tệp make mới, `mk/derived.mk`, đặt đích `derived` theo khuôn `CHECK_TARGETS`. Mọi bước kiểm
  và dựng chờ đích đó.
- Bên ghi (lời dặn trong `AGENTS.md`, các skill, workflow) chuyển sang gọi lệnh, không sửa tệp.
- Hình dạng của một sổ đọc từ git: tệp cũ còn trong git thì là «một tệp».

**Tech Stack:** Python 3.11+ thư viện chuẩn, GNU make 3.81+ (bản của macOS), git, bash 3.2 cho bộ
kiểm.

**Spec:** `docs/superpowers/specs/2026-11-17-ledger-fragments-design.md`. Đọc spec trước. Mục 5.2
(bảng bốn sổ, hình dạng, luật chung) và mục 6 (đường chuyển tiếp) là luật của Task 2 đến Task 6.

## Global Constraints

- Nhánh: `feat/ledger-fragments`, tách từ `main` tại `d9f0747` trở về sau. Không commit lên
  `docs/progress-after-rs8`.
- `tools/ledgers.py` chỉ dùng thư viện chuẩn của Python 3.11. Không đọc YAML bằng thư viện ngoài:
  phần đầu của mảnh là các dòng `khoá: giá trị`, đọc như `wiki_lint.py` đang đọc phần đầu của trang.
- Bốn tên sổ, đúng chữ, dùng ở mọi lệnh: `log`, `index`, `glossary`, `gen`.
- Hai giá trị hình dạng, đúng chữ: `one-file`, `fragments`.
- Đường dẫn:
  - mảnh log `wiki/log/YYYY-MM-DD-NN-<slug>.md`;
  - mảnh glossary `ontology/glossary/<Term>.md`;
  - phần đầu: `wiki/log.head.md`, `wiki/index.head.md`, `ontology/glossary.head.md`.
- Dòng đầu của mỗi tệp markdown được vẽ, đúng khuôn:
  `<!-- Drawn by tools/ledgers.py from <nguồn>. Edit the source, not this file. sha256:<hex> -->`,
  trong đó `<hex>` là sha256 của phần còn lại của tệp. Mã sinh ra giữ `HEADER` của
  `ontology_codegen.py` và thêm `sha256:<hex>` vào cuối dòng chú thích đầu.
- Mã thoát của `ledgers.py`: 0 xong; 1 khi từ chối (hai nguồn, sửa tay, mảnh sai, tách mất mục,
  vật dẫn xuất trong git); 2 khi gọi sai.
- Móc `SessionStart` luôn thoát 0. Không thêm luật `ask`, không thêm deny dạng `Bash(`; mục 43 của
  `tests/run.sh` phải còn xanh.
- Bộ kiểm mới là mục 48 của `tests/run.sh`, không dùng mạng.
- Thay đổi hành vi ghi dưới `## Unreleased` của `CHANGELOG.md`, có phần «what breaks on upgrade».
  Tên tệp, hàm, nhánh: tiếng Anh.

## Review Focus

1. **Một mảnh log có chữ «—» hay ký tự `|` trong nội dung.** Log vẽ ra vẫn một dòng cho một mảnh;
   ô glossary chứa `|` được thoát. Kiểm ở Task 2 (48e) và Task 3 (48h).
2. **Hai lệnh `add-log` cùng ngày, trên hai nhánh khác nhau.** Hai mảnh có cùng `NN` nhưng khác
   `slug`, nên hai tên không trùng nhau; vẽ ra đủ hai dòng, thứ tự ổn định. Kiểm ở Task 2 (48f).
3. **Kho không phải kho git, hoặc chưa có commit nào** (`apply.py` chạy trước `git init`). Hình dạng
   đọc ra `fragments` khi tệp cũ vắng, `one-file` khi tệp cũ có mà không có git. Không lệnh nào đổ
   lỗi. Kiểm ở Task 1 (48b).
4. **Trang wiki thiếu `title`, hay phần đầu hỏng.** `draw` vẫn vẽ mục lục cho các trang khác và
   `check` nêu đúng trang đó, không đổ cả lệnh. Kiểm ở Task 4 (48k).
5. **Glossary ở `onehub-inventory` có đoạn văn viết tay giữa phần mở đầu và bảng, và có thuật ngữ
   chứa dấu cách hay dấu chấm.** `split` chuyển đoạn văn vào `glossary.head.md`. Tên mảnh suy ra
   được từ thuật ngữ, và ngược lại. Kiểm ở Task 6 (48p).

---

### Task 1: Đích `derived` và phép kiểm `derived-untracked`

**Files:**
- Create: `plugins/repo-setup/presets/_core/starter/mk/derived.mk`
- Create: `plugins/repo-setup/presets/_core/starter/tools/ledgers.py` (khung: `shape`, `untracked`)
- Modify: `plugins/repo-setup/presets/ts-node/starter/Makefile`,
  `plugins/repo-setup/presets/python/starter/Makefile.tmpl`,
  `plugins/repo-setup/presets/claude-plugin/starter/Makefile`
- Test: `tests/run.sh`, mục 48 (48a–48c)

**Interfaces:**
- Produces:
  - `make derived`.
  - Biến `DERIVED_TARGETS` và `DERIVED_FILES` (lớp khác `+=` vào).
  - `python3 tools/ledgers.py shape <ledger>` in `one-file` hoặc `fragments`.
  - `python3 tools/ledgers.py untracked`: thoát 1 và nêu tệp khi một vật dẫn xuất của sổ ở hình dạng
    `fragments` đang nằm trong git.
  - Hàm `shape_of(root: Path, ledger: str) -> str` trong `ledgers.py`.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48a. Trên kho dựng tạm bằng preset `ts-node`, thêm `mk/zz.mk` với `DERIVED_TARGETS += zz` và
  `zz: ; @touch zz.done`. Chạy `make test` trên bản clone sạch: `zz.done` phải có. Lý do: đích
  do tệp đọc sau `derived.mk` nối vào vẫn phải chạy.

  48b. `shape log` in `fragments` khi `wiki/log.md` vắng; in `one-file` khi nó nằm trong git; in
  `one-file` khi có tệp mà thư mục không phải kho git.

  48c. Sau khi đưa `wiki/log.md` ra khỏi git và `git add -f` lại, `make check` đỏ, nêu
  `wiki/log.md` và `git rm --cached wiki/log.md`. Với một sổ `one-file`, cùng tệp ấy không làm đỏ.

  Chạy `bash tests/run.sh`. Kết quả mong đợi: ba dòng `FAIL: derived …`.

- [ ] **Step 2: Viết `derived.mk` và nối thứ tự**

  - `derived` chờ `upgrade` và chạy mọi `DERIVED_TARGETS`, kể cả những đích nối vào sau khi tệp
    được đọc. Gợi ý: gọi lại `$(MAKE)` trong lệnh, vì biến trong lệnh nở ra lúc chạy.
  - Mỗi preset `Makefile`, ngay sau `-include mk/*.mk`, thêm điều kiện thứ tự `| derived` cho
    `lint typecheck test ontology build dev`, với những đích preset đó có.
  - `derived-untracked` vào `CHECK_TARGETS`.
  - Lõi khai `DERIVED_TARGETS += wiki-derived`. Task 5 thêm `gen-derived`.
  - Khi `wiki/` vắng (preset `claude-plugin`), `ledgers.py draw` in «nothing to draw» và thoát 0.

- [ ] **Step 3: Chạy lại, thấy xanh**

  Chạy `bash tests/run.sh`. Mục 48a–48c qua, và mục 1 đến 47 không đỏ thêm.

- [ ] **Step 4: Commit** `feat(core): make derived draws every file the repository keeps out of git`

### Task 2: Sổ log

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/tools/ledgers.py`
- Modify: `plugins/repo-setup/presets/_core/starter/mk/derived.mk` (đích `log`)
- Test: `tests/run.sh`, 48d–48g

**Interfaces:**
- Consumes: `shape_of` (Task 1).
- Produces:
  - `ledgers.py add-log <text> [--date YYYY-MM-DD]`, và `make log m="<text>"`.
  - `ledgers.py draw [--quiet]`, phần log.
  - `ledgers.py check`, phần log: khoá khác tên tệp, tên sai khuôn, hai nguồn.
  - Hàm `stamp(body: str, source: str) -> str` và
    `read_stamped(path: Path) -> tuple[str | None, bool]` (nội dung, đã bị sửa tay hay chưa), dùng lại
    ở Task 3 đến 5.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48d. Ở hình dạng `one-file`, `make log m="x — #1"` thêm `- <hôm nay> — x — #1` lên đầu danh sách
  của `wiki/log.md`, như lời dặn cũ. Ở hình dạng `fragments`, lệnh đó viết đúng một tệp mới trong
  `wiki/log/` và không chạm tệp nào khác.

  48e. Ba mảnh, một mảnh có «—» và `|` trong nội dung. `draw` cho `wiki/log.md` bắt đầu bằng dòng
  dấu. Tiếp theo là nội dung của `log.head.md`, rồi ba dòng mới nhất ở trên. Vẽ lần hai thì không
  byte nào đổi.

  48f. Hai nhánh, mỗi nhánh một `make log` cùng ngày. Gộp theo hai thứ tự: không xung đột, và
  `git diff --name-only` của hai nhánh không chung tệp nào. Vẽ ra đủ hai dòng.

  48g. Thêm tay một dòng vào `wiki/log.md` đã vẽ. `draw` thoát 1, in dòng đó và lệnh `make log`,
  và tệp giữ nguyên.

  Chạy `bash tests/run.sh`. Kết quả mong đợi: dòng `FAIL: log …` cho 48d–48g.

- [ ] **Step 2: Cài phần log của `ledgers.py`**

  - `NN` là số lớn nhất của mảnh cùng ngày cộng một, viết hai chữ số.
  - `slug` lấy từ nội dung: chữ thường, chữ và số ASCII, tối đa 40 ký tự.
  - Log xếp theo tên tệp giảm dần.

- [ ] **Step 3: Chạy lại, thấy xanh** (`bash tests/run.sh`, 48d–48g qua)

- [ ] **Step 4: Commit** `feat(core): the wiki log is one file per entry`

### Task 3: Sổ glossary

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/tools/ledgers.py`
- Modify: `plugins/repo-setup/presets/_core/starter/tools/wiki_lint.py` (đọc glossary sau khi vẽ;
  không đổi luật)
- Test: `tests/run.sh`, 48h–48i

**Interfaces:**
- Consumes: `shape_of`, `stamp`, `read_stamped`.
- Produces: `ledgers.py add-term <Term> --definition <s> [--display <s>] [--not-confused-with <s>]`.
  `--display` mặc định là `<Term>`. Mảnh có phần đầu gồm `term`, `display`, `not_confused_with`
  (trống được); thân là định nghĩa một câu.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48h. Hai mảnh, một mảnh có `|` trong định nghĩa. `ontology/glossary.md` vẽ ra là phần đầu cộng
  bảng bốn cột `Term (code name)`, `Definition`, `Not to be confused with`, `Display name`, xếp
  theo `term`. Dấu `|` được thoát.

  48i. Mảnh `Customer.md` có `term: Client` thì `check` thoát 1 và nêu tệp. Thiếu `display` cũng
  thoát 1. `wiki_lint.py` còn cảnh báo khi một thực thể không có trong glossary vẽ ra.

- [ ] **Step 2: Cài.** Tên mảnh bằng đúng `term`; thuật ngữ có ký tự không hợp lệ cho tên tệp thì
  `add-term` thoát 2 và nêu ký tự đó.

- [ ] **Step 3: Chạy lại, thấy xanh**

- [ ] **Step 4: Commit** `feat(core): the glossary is one file per term`

### Task 4: Mục lục wiki

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/tools/ledgers.py`
- Modify: `plugins/repo-setup/presets/_core/starter/tools/wiki_lint.py`: bỏ cảnh báo «not linked
  from wiki/index.md» khi `index` là `fragments`; thêm lỗi «page has no type or title».
- Modify: `plugins/repo-setup/presets/_core/team/tools/sdlc_metrics.py`: `link_in_index` không ghi
  khi `index` là `fragments`.
- Test: `tests/run.sh`, 48j–48l

**Interfaces:**
- Consumes: `shape_of`, `stamp`, `read_stamped`.
- Produces: phần mục lục của `draw`. Mỗi loại trang ở `ontology/page-types.yaml` cho một mục
  `## <Tên loại, số nhiều, chữ đầu viết hoa>`, theo thứ tự trong tệp đó. Loại trang không có trong
  tệp xếp cuối, theo tên. Mỗi trang cho một dòng `- [<title>](<đường dẫn từ wiki/>)`, có thêm
  ` — <summary>` khi trang có khoá `summary`. Cuối mục lục có dòng liên kết tới `log.md`.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48j. Một trang thực thể và một trang quyết định cho ra hai mục, đúng thứ tự, đúng dòng.

  48k. Một trang thiếu `title`: `draw` vẫn vẽ các trang còn lại, còn `check` và `wiki_lint` nêu
  đúng trang đó.

  48l. `sdlc_metrics.py` chạy trên kho `fragments` không tạo hay sửa `wiki/index.md` trong git.

- [ ] **Step 2: Cài**

- [ ] **Step 3: Chạy lại, thấy xanh**

- [ ] **Step 4: Commit** `feat(core): the wiki index is drawn from the pages`

### Task 5: Mã sinh từ ontology ngoài git

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/mk/derived.mk`: `gen-derived`, và
  `DERIVED_FILES += $(GEN_OUT)` khi `GEN_OUT` có giá trị.
- Modify: ba `Makefile` của preset. `ontology` giữ `--check` khi `shape gen` là `one-file`, bỏ khi
  là `fragments`.
- Modify: `plugins/repo-setup/presets/ts-node/starter/package.json.tmpl`: thêm
  `"prepare": "command -v make >/dev/null 2>&1 && make -s derived || true"`.
  `react-vite/starter/package.json.tmpl` cũng vậy.
- Modify: `plugins/repo-setup/deploy/container/team/mk/deploy.mk.tmpl` và
  `deploy/container/starter/mk/container.mk.tmpl`: đích dựng ảnh chờ `| derived`. Tệp sinh ra nằm
  trong bối cảnh dựng, vì `.dockerignore` không loại `src/`.
- Test: `tests/run.sh`, 48m–48n

**Interfaces:**
- Consumes: `shape_of("gen")`. Ở sổ này, «tệp cũ» là `$(GEN_OUT)`; `ledgers.py` đọc đường dẫn đó qua
  `--gen-out <path>`, do `derived.mk` truyền vào.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48m. Kho `ts-node` và kho `python` ở hình dạng `fragments`. Xoá tệp sinh ra rồi chạy `make test`:
  tệp được vẽ lại và bài kiểm xanh. Với `one-file`, tệp sinh ra bị sửa thì `make ontology` vẫn đỏ
  như hôm nay.

  48n. `container.mk` có `| derived` trên đích dựng ảnh; `.dockerignore` không loại tệp sinh ra.

- [ ] **Step 2: Cài.** `ledgers.py` gọi `ontology_codegen.py` ra một tệp tạm rồi đặt vào chỗ, kèm
  dấu. Không sửa thân của `ontology_codegen.py`.

- [ ] **Step 3: Chạy lại, thấy xanh**

- [ ] **Step 4: Commit** `feat(core): generated ontology code is drawn, not committed`

### Task 6: `split`

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/tools/ledgers.py`
- Test: `tests/run.sh`, 48o–48q. `tests/fixtures/ledgers/` (mới): ba sổ một tệp nhỏ, mô phỏng các
  dạng đã thấy ở `onehub-inventory`:
  - mục lục theo thứ tự chèn;
  - 20 dòng log cùng một ngày;
  - một đoạn văn viết tay giữa phần mở đầu và bảng glossary;
  - thuật ngữ có dấu cách.

  Không chép dữ liệu thật của kho đó.

**Interfaces:**
- Produces: `ledgers.py split <ledger> [--dry-run]`.
  - In mọi tệp sẽ viết.
  - So theo mục: tập mục trước và sau bằng nhau, chữ của từng mục giữ nguyên.
  - In những chỗ thứ tự đổi.
  - Mất hay thừa một mục thì thoát 1 và không ghi gì.
  - Xong thì `git rm --cached` tệp cũ và thêm dòng `.gitignore` nếu còn thiếu.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48o. Với mỗi sổ trong `log`, `index`, `glossary`, `gen`: `split --dry-run` không ghi gì; `split`
  xong thì `shape` là `fragments`, `make check` xanh, và tệp vẽ ra có cùng tập mục với tệp cũ.

  48p. Ba dạng của bộ mẫu:
  - đoạn văn của glossary về `glossary.head.md`;
  - dòng ví dụ `_Example:_` bị bỏ, và lệnh có nói điều đó;
  - 20 dòng cùng ngày giữ đúng thứ tự trong ngày;
  - mô tả sau «—» của mục lục về khoá `summary` của trang.

  48q. Sau khi tách, bỏ một mảnh rồi chạy lại phép so: lệnh thoát 1 và nêu mục mất. Một tệp
  `.head.md` còn đúng như mẫu thì bị viết đè; tệp đã bị sửa thì lệnh từ chối.

- [ ] **Step 2: Cài**

- [ ] **Step 3: Chạy lại, thấy xanh**

- [ ] **Step 4: Commit** `feat(core): split moves a one-file ledger into fragments without losing an entry`

### Task 7: Mẫu và bên ghi

**Files:**
- Delete: `plugins/repo-setup/presets/_core/starter/wiki/log.md.tmpl`,
  `plugins/repo-setup/presets/_core/starter/ontology/glossary.md.tmpl`,
  `plugins/repo-setup/presets/_core/starter/wiki/+index.md/`.
- Create:
  - `wiki/log.head.md.tmpl` (đầu trang cũ, không có dòng «Repository created»);
  - `wiki/index.head.md.tmpl` (nội dung của `10-main.md.tmpl`, bỏ các mục liệt kê);
  - `ontology/glossary.head.md.tmpl`;
  - `wiki/log/.gitkeep`, `ontology/glossary/.gitkeep`.

  Tất cả nằm dưới `_core/starter/`.
- Modify: `_core/starter/dot.gitignore`: ba tệp markdown được vẽ. Dòng của `GEN_OUT` thêm ở
  `.gitignore` của từng preset có ontology.
- Modify: `presets/ts-node/starter/dot.prettierignore`: ba tệp markdown được vẽ (`src/generated/` đã
  có sẵn).
- Modify: `_core/starter/+AGENTS.md/10-guide.md.tmpl`. Thêm một câu: `wiki/log.md`, `wiki/index.md`
  và `ontology/glossary.md` do `make derived` vẽ; sửa ở mảnh, không sửa ở tệp vẽ.
- Modify: `_core/starter/dot.claude/settings.json.tmpl`: móc `SessionStart` chạy `make -s derived`,
  luôn thoát 0, in lỗi nếu có. Móc phải ghép được với `{{plugin_settings}}`.
- Modify:
  - `_core/starter/+AGENTS.md/10-guide.md.tmpl`;
  - các skill `ontology-add`, `wiki-ingest`, `wiki-health`;
  - `plugins/repo-setup/skills/adopt/SKILL.md`, `skills/github/SKILL.md`;
  - `capabilities/github-agents/team/dot.github/workflows/agent-ci-fix.yml`;
  - `_core/starter/+AGENTS.md/15-language.md.tmpl`, `_core/starter/ontology/README.md`;
  - `checklists/top-tier.toml`: `ontology/glossary.md` thành «glossary hoặc `ontology/glossary/`».
- Modify: `tests/run.sh`, mục 46. Ca `merge=union` chạy trên một kho đặt ở hình dạng `one-file`. Dòng
  `.gitattributes` giữ nguyên cho kho cũ.
- Test: `tests/run.sh`, 48r–48t

**Interfaces:**
- Consumes: mọi lệnh của Task 1 đến 6.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48r. Kho cài mới ở cả sáu preset:
  - `shape` của `log`, `index`, `glossary` là `fragments`;
  - sau commit đầu tiên, `git ls-files` không có tệp được vẽ nào;
  - `make check` xanh trên bản clone sạch.

  48s. Không skill, không `AGENTS.md`, không workflow nào còn bảo «append» hay «add a line to»
  `wiki/log.md`. Chúng gọi `make log`; `ontology-add` gọi `add-term`.

  48t. `settings.json` sinh ra có móc `SessionStart` với `make -s derived`; mục 43 vẫn xanh.

- [ ] **Step 2: Sửa mẫu và lời dặn.** Skill giữ một câu cho kho chưa tách: «nếu `wiki/index.md`
  còn trong git, thêm liên kết ở đó».

- [ ] **Step 3: Chạy lại, thấy xanh** (`bash tests/run.sh`, mọi mục qua)

- [ ] **Step 4: Commit** `feat(core)!: new repositories keep their ledgers as fragments`

### Task 8: `doctor` và kho đã cài

**Files:**
- Modify: `plugins/repo-setup/scripts/doctor.py` và các tệp kiểm của nó: một mục thông báo
  `ledgers_split`, liệt kê sổ còn `one-file` kèm `ledgers.py split <sổ>`, không trừ điểm.
- Test: `tests/run.sh`, 48u; `tests/e2e.sh`, ca nâng cấp.

- [ ] **Step 1: Viết bài kiểm, thấy đỏ**

  48u. Kho dựng bằng mẫu của bản này nhưng đặt ở hình dạng cũ (`wiki/log.md`, `wiki/index.md`,
  `ontology/glossary.md` và tệp sinh ra đều trong git), rồi chạy `apply.py` lần nữa:
  - không mảnh nào được tạo;
  - `make check` xanh;
  - `make log` ghi vào `wiki/log.md`;
  - `doctor` nêu bốn sổ chưa tách mà điểm không đổi.

  `tests/e2e.sh`: thêm ca nâng từ `repo-setup-v0.6.0`, rồi chạy `split` cho cả bốn sổ và
  `make check`.

- [ ] **Step 2: Cài**

- [ ] **Step 3: Chạy lại, thấy xanh** (`bash tests/run.sh`; `bash tests/e2e.sh` với
  `PRESETS="ts-node react-vite:none:none:design python"`)

- [ ] **Step 4: Commit** `feat(doctor): say which ledgers still ride pull requests`

### Task 9: Ghi lại, và đo trên kho thử

**Files:**
- Modify: `CHANGELOG.md`, dưới `## Unreleased`: mục mới «Ledgers as fragments». Có phần «what
  breaks on upgrade»:
  - PR đang mở lúc tách sẽ gặp một xung đột «xoá ở một bên»;
  - bản dựng nào không qua `make` hay `npm ci` thì thiếu tệp sinh ra;
  - Prettier không đụng các tệp được vẽ.
- Modify: `docs/three-repo-overview-design.md`, mục 7: ô trạng thái RS2b thành «Đã dựng (ngày), mục
  48 bộ kiểm». Kết quả của kho thử đưa vào ghi chú bên dưới bảng.

- [ ] **Step 1: Chạy toàn bộ**

  Chạy `bash tests/run.sh`, mong đợi «All tests passed.». Chạy `bash tests/e2e.sh`, mong đợi thoát
  0.

- [ ] **Step 2: Kho thử `design-ci-probe`** (chủ kho cho phép riêng bước này)

  1. Nâng kho thử bằng nhánh này.
  2. Chạy `split` cho bốn sổ trong một PR.
  3. Mở hai PR song song, mỗi PR một `make log`, một `add-term`, một trang wiki.
  4. Gộp PR thứ nhất bằng nút của GitHub.

  Mong đợi: PR thứ hai gộp được mà không cần «Update branch», và hai PR không chung tệp nào.

- [ ] **Step 3: Commit** `docs: ledgers as fragments, measured on the probe repository`

## Thứ tự với RS3

- Kế hoạch RS3 (`docs/superpowers/plans/2026-11-17-tiered-ci.md`) sửa cùng ba `Makefile` của preset
  và mẫu `ci.yml`.
- Làm RS2b trước. Tách nhánh RS3 từ `main` sau khi RS2b đã gộp.
- RS2b không sửa `ci.yml`. Việc đổi `npm run build` thành `make build` thuộc RS3.
