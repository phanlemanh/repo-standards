# Hợp đồng mối nối với design-assembly và delivery-loop

Ngày 2026-11-20. Trạng thái: máy viết từ phép rà mối nối ở
[tổng kết sau 0.10.1](reports/2026-11-20-progress-after-0.10.1.md), mục 8. Trang này nêu điều setup
hứa ở mỗi chỗ nó gặp hai công cụ kia, và bài kiểm nào ghim lời hứa đó **từ phía kho này**. Setup không
đọc tệp nào của hai công cụ kia lúc chạy ([ranh giới ba kho](three-repo-boundaries.md)); một mối nối
ở đây là một cái tên hay một dạng dữ liệu mà hai bên cùng dùng.

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
  ghim lời hứa của phía này, không chứng minh bên kia giữ phần của mình.
