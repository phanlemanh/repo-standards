# Hợp đồng mối nối với design-assembly và delivery-loop

Ngày 2026-11-20. Trạng thái: máy viết từ phép rà mối nối ở
[tổng kết sau 0.10.1](reports/2026-11-20-progress-after-0.10.1.md), mục 8. Trang này nêu điều setup
hứa ở mỗi chỗ nó gặp hai công cụ kia, và bài kiểm nào ghim lời hứa đó **từ phía kho này**. Setup không
chạy công cụ nào của hai bên kia từ script của mình ([ranh giới ba kho](three-repo-boundaries.md)); một
mối nối ở đây là một cái tên hay một dạng dữ liệu mà hai bên cùng dùng. Từ ngày 2026-11-22 có hai ngoại
lệ đã nêu: kỹ năng `new` và `adopt` gọi kỹ năng của design-assembly (mục 6), và `doctor.py` đọc vài tệp
design-assembly để lại trong kho được kiểm (mục 7).

Đổi một dòng của trang này là đổi điều công cụ khác dựa vào: ghi vào `CHANGELOG.md`, mục «What breaks
on upgrade», và báo bên kia.

## 1. `-include mk/*.mk` và bốn danh sách của make

**Bên định nghĩa:** kho này. **Bên dùng:** design-assembly (`mk/design-assembly.mk`), và mọi lớp khác.

Mỗi `Makefile` của preset đọc mọi tệp `mk/*.mk` của kho (`-include mk/*.mk`). Một tệp như vậy thêm
tên đích vào một trong bốn danh sách, và setup hứa:

| Danh sách | Setup hứa | Bài kiểm |
| --- | --- | --- |
| `CHECK_TARGETS` | Chạy trong `make check-quick`, tức tầng nhẹ của CI ở mọi lần đẩy, nằm sau ô bắt buộc `check`. Đích đỏ thì `check` đỏ | 51c |
| `HEAVY_TARGETS` | Chạy trong `make check-heavy`, tầng nặng, khi PR rời bản nháp và đầu vào đổi. Không chạy ở tầng nhẹ | 51c, 49e |
| `DERIVED_TARGETS` | Chạy trong `make derived`, trước `make test` và trước tầng nặng trên một checkout sạch | 48a, 51c |
| `DERIVED_FILES` | Tệp được vẽ ra, không vào git: một bản trong git làm `make check` đỏ (`derived-untracked`), khi dòng đầu của nó mang dấu của tệp vẽ ra: `sha256:` với tệp không phải markdown, dòng dấu của `tools/ledgers.py` với tệp `.md`. Tệp không có dấu là tệp của kho, và không đỏ | 48c, 51c |

Một tệp riêng của kho nằm đúng chỗ một tệp `mk/` của setup mà không nối các đích đó thì lượt cài thoát
mã 1 và nêu tên chúng (51b).

## 2. `tools/design-assembly/affected.mjs --json`

**Bên định nghĩa:** design-assembly. **Bên dùng:** `tools/ui_select.mjs` của lớp `design`.

`ui_select.mjs` gọi `node tools/design-assembly/affected.mjs --json [--base <commit>]` chỉ trên một
pull request trong CI, và chỉ khi tệp đó có. Nó đọc đúng các khoá sau, không khoá nào khác:

| Khoá | Dạng | Dùng làm gì |
| --- | --- | --- |
| `all` | `true` hay `false` | `true`: chạy mọi bài |
| `why` | danh sách `{file, reason}`, `file` có thể là `null` | Lý do in ra khi chạy mọi bài |
| `screens` | danh sách `{route}` | Các màn thay đổi chạm tới |
| `grep` | chuỗi mẫu, hay `null` khi không màn nào | Mẫu chọn bài trình duyệt |

Thiếu tệp, thoát mã khác 0, không in JSON, hay một khoá sai dạng: chạy mọi bài, và in lý do. Không biết
thì chạy trọn bộ. Đọc lại bên design-assembly ngày 2026-11-20 (plugin 0.21.0): `affected.mjs` in đúng
bốn khoá này, thoát 0 khi có câu trả lời và 2 khi gọi sai.

Bài kiểm: 49h chạy `ui_select.mjs` với các bản thay thế của `affected.mjs`; 51d ghim rằng bốn khoá ở
bảng trên là đúng những khoá `ui_select.mjs` đọc.

## 3. Tên ô CI: `check` và `gate`

**Bên định nghĩa:** kho này. **Va tên với:** delivery-loop (ô của kit cũng tên `gate`).

- `check`: job tổng của `ci.yml` ở mọi preset, đứng cho mọi tầng. Luôn là của setup.
- `gate`: job của `pr-pipeline.yml`, chỉ có khi kho cài lớp `github-agents`. Ở kho không có lớp đó,
  tên này là của kho, và `governance/autonomy.yaml` nhận nó làm `proof.check` hay dưới
  `required_checks` (51a).

Bài kiểm: 51a; 51e ghim tên hai job trong các tệp workflow.

## 4. `_acceptance/**` và `LO-TRINH.html` không phải đầu vào của tầng nặng

**Bên định nghĩa:** kho này. **Bên dùng:** delivery-loop, nơi ghi các tệp đó.

`HEAVY_NOT_INPUTS` của `ci.yml` ở mọi preset có `_acceptance/**` và `LO-TRINH.html`, và
`tools/ci_inputs.py` dùng cùng danh sách khi biến đó không có. Một PR chỉ đổi các tệp đó dùng lại lượt
nặng xanh có cùng đầu vào. Setup không đọc nội dung các tệp đó.

`LO-TRINH.html` là trang lộ trình delivery-loop vẽ lại trong commit chữ ký. Nó có tên trong danh sách
từ ngày 2026-11-21 ([issue 71](https://github.com/phanlemanh/repo-standards/issues/71)): trước đó commit
chữ ký đổi khoá, và tầng nặng chạy lại trên một cây không đổi mã. Chỉ tệp đúng tên đó ở gốc kho được
bỏ qua; một trang `.html` khác, hay một tệp cùng tên trong thư mục con, vẫn là đầu vào. `PRODUCT-MAP.md`
đã được `*.md` ở gốc che.

Kho nào có bài tầng nặng đọc trang lộ trình thì bỏ tên đó khỏi `HEAVY_NOT_INPUTS` trong `ci.yml` của
mình. Không bài kiểm nào ở đây biết một kho có bài như thế.

Bài kiểm: 49a (tệp nào là đầu vào theo danh sách mặc định), 49c (khoá đầu vào bỏ qua `_acceptance/`),
49f (dòng `HEAVY_NOT_INPUTS` của mọi preset đúng là danh sách mặc định); 51e ghim hai tên ở trên trong
dòng đó.

## 5. Chưa có hợp đồng

- **Cách gộp PR.** delivery-loop cần merge commit; `tools/github_setup.py` mặc định squash và không
  lưu lựa chọn, nên một lượt chạy quên `--merge-method merge` đưa kho về squash. Lưu vào
  `governance/autonomy.yaml` là đổi luật chơi: chủ kho quyết.
- **Không bài kiểm nào chạy công cụ thật của bên kia.** Mọi bài ở trang này dùng bản thay thế: chúng
  ghim lời hứa của phía này, không chứng minh bên kia giữ phần của mình. Ba mục sau cũng vậy: chỉ lượt
  thử cuối của đề bài 0013 bên design-assembly chạy cả hai plugin thật.

## 6. Lời gọi design-assembly

**Bên định nghĩa:** design-assembly: cờ `--starter` của lối `adopt` (quyết định 0085 của nó), `audit`,
`new`, `upgrade`. **Bên gọi:** ba kỹ năng của kho này. Plugin ghi bộ sổ thiết kế; kho này chỉ gọi. Mẫu dữ
liệu đọc ở design-assembly 0.35.0, ngày 2026-11-22: `tests/fixtures/design-assembly/seam.json`.

| Chỗ gọi | Gọi gì | Khi nào |
| --- | --- | --- |
| `/repo-setup:new`, chặng 6, bước 4 | `/design-assembly:adopt` với `--starter` | Lớp `design` bật và phiên có plugin; sau các lệnh cài và bước viết miền, trước `next_commands.verify` |
| `/repo-setup:new`, chặng 8 | Mời một lần đi tiếp `/design-assembly:new`, ngay hay để sau | Khi bước 4 đã đặt sổ |
| `/repo-setup:adopt`, bước 4c | `/design-assembly:audit`, rồi `/design-assembly:adopt` không `--starter` | Kho có giao diện web, phiên có plugin, Makefile đã đọc `mk/*.mk` |
| `/repo-setup:doctor` | Chỉ tới `/design-assembly:adopt` hay `/design-assembly:upgrade` | Mục 7 |

Lời gọi đứng sau lệnh cài vì linh kiện và `@axe-core/playwright`, hai thứ plugin đọc để đặt sổ linh kiện
và bảng bề rộng màn, chỉ tới cùng lệnh cài; và đứng trước bước kiểm để bước kiểm chạy cả cổng của
plugin. Không cờ nào khác được truyền (`--conformance-level`, `--product-type`, `--record`, `--hold`,
`--replace` là lời của người): mọi lựa chọn chỉ người làm được nằm trên hàng chờ của plugin, và máy
không trả lời câu hỏi của nó.

Mã thoát của `adopt --starter`, như kỹ năng xử lý:

| Mã | Plugin nói | Kỹ năng làm |
| --- | --- | --- |
| 0 | Đã đặt bộ sổ lúc ra đời, không gì chờ người | Đi tiếp |
| 1 | Đã đặt, còn câu chờ người trên hàng chờ | Không phải lỗi; đi tiếp |
| 2 | Gọi sai, hoặc kho có giá trị của riêng nó (màu chính có sắc riêng, hay đã nhận giá trị trước đó) | Nói một dòng điều plugin in ra và rằng `adopt` không `--starter` giữ các giá trị ấy; đi tiếp |

Phiên không có plugin thì kỹ năng nói một dòng thiếu gì và cách cài, rồi đi tiếp; không dừng.

Mỗi bản sao của kho có lớp `design` có plugin: `.claude/settings.json` sinh ra biết chợ
`phanlemanh/design-assembly` và bật `design-assembly@design-assembly`, bên cạnh mục repo-standards khi
có `--var marketplace`. Kho không có lớp `design` không có gì của plugin. Mẫu dùng chỗ giữ chỗ mới
`plugins_enabled`; chỗ cũ `plugin_settings` vẫn vẽ đúng điều các bản đến 0.10.4 đã ghi, để lượt nâng cấp
tìm được bản gốc của một `settings.json` đã sửa tay và gộp ba bên.

Bài kiểm: 51h (settings), 51i (nâng cấp một `settings.json` để nguyên và một tệp đã sửa), 51j (chỗ của
lời gọi trong ba kỹ năng, mã thoát, lời mời, không cờ nào nói thay người).

## 7. Bộ sổ lúc ra đời và dấu bản công cụ

**Bên định nghĩa:** design-assembly: cột «From birth» của hợp đồng, và `design/tool-stamp.json`. **Bên
đọc:** `plugins/repo-setup/scripts/design_ledgers.py`, gọi từ `doctor.py`.

Bảy sổ một kho có từ lúc ra đời, theo design-assembly 0.35.0:

- `design/decisions.yaml`
- `design/tokens.json`
- `design/component-registry.json`
- `design/column-types.json`
- `design/states.json`
- `design/screen-sizes.json`
- `design/screens.yaml`

Sổ chỉ có khi có mục đầu (bản thiết kế, sổ cột, sổ bộ phận, sổ nhập kho, sổ nguồn, trang kiểu màn)
không tính là thiếu.

`doctor.py`, ở kho có lớp `design` hay kho đã có dấu bản công cụ, in một khối không tính điểm và khoá JSON
`design_ledgers`: `missing` (sổ lúc ra đời không có, chỉ tới `/design-assembly:adopt`), `stamp` (khoá
`version` của dấu bản), `installed` (bản plugin đã cài, do bên gọi đưa qua `--design-assembly-version`;
kỹ năng lấy từ `claude plugin list --json`), `behind` (dấu bản cũ hơn bản đã cài; null khi một trong hai
không biết), `next` (`/design-assembly:upgrade` khi `behind`). Nó chỉ đọc tệp; không chạy gì của plugin,
không tìm plugin trên máy.

Kho này không ghi tệp nào trong bảy sổ, dấu bản, `tools/design-assembly/` hay `mk/design-assembly.mk`:
mỗi sổ một người ghi.

Bài kiểm: 51f (danh sách của `design_ledgers.py`, mẫu dữ liệu và trang này khớp nhau), 51g (setup không
ghi tệp nào của plugin), 51k (doctor trên một kho có sàn: thiếu cả bảy, rồi dấu bản cũ, bằng, không biết;
điểm không đổi).

## 8. Chuỗi design-assembly đọc trong Makefile và `mk/`

**Bên định nghĩa:** kho này. **Bên dùng:** design-assembly, qua `host-make.mjs` của nó.

`tests/fixtures/design-assembly/host-strings.json` là bản chép nguyên `references/host-strings.json` của
design-assembly 0.35.0: mọi chuỗi plugin đọc trong Makefile, `mk/` và `package.json` của kho chủ. Plugin
không đọc workflow nào. Trên một kho sinh với `--preset react-vite --with design`, chưa chạy lệnh cài, mỗi
chuỗi có một câu trả lời:

| Chuỗi | Kho này giữ bằng |
| --- | --- |
| `include-mk`, `rule-line`, `check-target` | `Makefile` có `-include mk/*.mk` và luật `check` |
| `check-targets-word`, `check-runs-this` | Đi theo điều kiện của `check` thì tới `$(CHECK_TARGETS)` |
| `gate-joins-check`, `gate-runs-check`, `gate-step-file` | Bước cổng `mk/design-assembly.mk` là của plugin: setup không ghi tệp đó |
| `tool-pointer` | `tools/design_guards.mjs` của sàn có trong `mk/design.mk`; ba dòng sổ của plugin trỏ vào nó |
| `test-in-check-targets`, `derived-targets-defined`, `derived-files` | `mk/derived.mk`, đọc trước `mk/design-assembly.mk`, khai `DERIVED_TARGETS` và `DERIVED_FILES`; `derived` chạy mọi đích trong danh sách, `derived-untracked` đọc danh sách tệp |

Ba dòng bước cổng ghi (`CHECK_TARGETS += design-assembly`, `DERIVED_TARGETS += design-derived`,
`DERIVED_FILES += …`) chạy đúng chỗ mục 1 hứa, và `make_wiring.py` nhận ra hai đích. Tệp JSON plugin khai
vào `DERIVED_FILES` không mang dấu `sha256:` nên `derived-untracked` của kho này không bắt chúng; phép kiểm
riêng của plugin bắt một bản lọt vào git.

Một chuỗi mới trong tệp của plugin mà bảng trên không có câu trả lời thì 51g đỏ, một khi tệp đã được
chép sang đây: đó là một quyết định ở kho này. Không bài nào đọc tệp của plugin, nên plugin đổi mà chưa ai
chép thì ở đây chưa thấy. Đọc bản mới: chép đè `host-strings.json` từ plugin, đổi `version` và `read` trong `seam.json`, đọc
lại cột «From birth» và kỹ năng `adopt` của plugin, rồi chạy `bash tests/run.sh`.

Bài kiểm: 51g.
