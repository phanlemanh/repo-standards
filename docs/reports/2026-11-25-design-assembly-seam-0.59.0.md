# Đọc lại mối nối với design-assembly ở 0.59.0

Ngày 2026-11-25. Đọc design-assembly tại `origin/main` (`1049d9c`, plugin `0.59.0`), so với commit
`e2c43da` (plugin `0.35.0`, bản mẫu dữ liệu ghi trước đây). Chỉ đọc bằng `git show`; không chạy plugin,
không sửa gì bên đó. Đây là việc mà [báo cáo tổng kết](2026-11-25-progress-overall.md) (mục 3 điểm 1,
mục 7 điểm 2) đòi trước khi phát hành `0.10.5`.

## 1. Tóm tắt

- **Bốn thứ kho này dựa vào thì ba thứ không đổi:** `host-strings.json` trùng từng byte (sha1
  `809ac55…`), cột «From birth» vẫn đúng bảy sổ, dấu bản công cụ vẫn hai khoá `version` và `tree`.
  Lời gọi vẫn là `adopt.mjs --target <repo> --starter`, và vẫn không có cờ mới nào nói thay người.
- **Thứ đổi là nghĩa của mã thoát 2.** Từ `0.36.0` (quyết định 0087), `--starter` đặt sổ cả ở kho có màu
  thương hiệu. Mã 2 chỉ còn là gọi sai, hoặc kho plugin không đọc được. Kỹ năng `new` đã nói đúng từ
  PR 83; còn sai là mẫu dữ liệu `seam.json`, một câu trong `docs/seam-contracts.md`, và chú thích phiên
  bản trong `design_ledgers.py`. Ba chỗ đã sửa.
- **Có một tệp mới plugin ghi vào kho mới sinh:** `tests/e2e/floating-parts.spec.ts`, nằm trong thư mục
  test của sàn. Setup không ghi tệp này. Bài 51g giờ giữ điều đó.
- **Một bài kiểm mới làm đúng việc lẽ ra phải làm từ đầu.** Câu về mã 2 trong kỹ năng `new` phải chứa đúng
  nghĩa mà mẫu dữ liệu đọc được. Bài đỏ với mẫu dữ liệu cũ, xanh với mẫu mới. Lần sau plugin đổi nghĩa
  mã 2, chép lại mẫu dữ liệu là đủ để thấy.

## 2. Những gì đã trôi giữa 0.35.0 và 0.59.0, trên mối nối

| # | Bên design-assembly | Từ bản | Ảnh hưởng tới kho này | Đã làm |
| --- | --- | --- | --- | --- |
| 1 | `adopt --starter` không còn từ chối kho có màu riêng (vai màu chính có sắc riêng, hoặc đã nhận giá trị trước đó). Sổ vẫn được đặt, mọi giá trị ghi là của kho, thoát 0 hoặc 1 | `0.36.0` | Mã 2 không còn nghĩa «màu thương hiệu» | Sửa `seam.json`, `docs/seam-contracts.md`; thêm bài kiểm ở 51j |
| 2 | `status` nói kho có màu riêng là «bộ hướng dẫn không dành cho nó»; dòng `next:` nêu `/design-assembly:adopt` ở cả hai loại kho | `0.36.0` | Chặng 8 của `/repo-setup:new` đã chọn lời mời theo `brand_primary`, không theo `next:`. Khớp | Ghi vào `seam.json` (khoá `own_values`) |
| 3 | Kỹ năng `adopt` thêm bước «Then the plugs, once»: chạy `plugs.mjs --session` với `--skill`, `--server`, `--needs-sign-in`; từ `0.58.0` mỗi tên một cờ. Bước này có thể để câu hỏi ở `design/waiting/plug-<socket>.json` | `0.38.0` | Cờ chỉ báo phiên đang có gì, không nói thay người. Không đụng danh sách cờ cấm. Xem điểm mở 1 | Không đổi |
| 4 | `adopt --starter` thêm ba phép kiểm dưới `ledger-shapes`: món đã gỡ không còn được dùng (`taken-down`, `0.51.0`), chọn trước khi làm (`choose-first`, `0.54.0`), mở phần nổi của món ngoài (`0.57.0`) | `0.51.0`–`0.57.0` | Cổng của kho mới sinh giữ nhiều hơn. Chỉ e2e chạy thật mới thấy | Không đổi; xem điểm mở 2 |
| 5 | Ở kho có trình duyệt kiểm thử (`@playwright/test` trong `package.json`), `adopt --starter` ghi `tests/e2e/floating-parts.spec.ts` khi chưa có | `0.57.0` | Sàn `design` của kho này có `testDir: "tests/e2e"`, nên tệp chạy cùng bộ e2e của kho. Không có món ngoài thì tệp không khai bài nào | Ghi vào `seam.json` (`adopt_starter.also_writes`); 51g kiểm setup không ghi tệp đó |
| 6 | `status` có thêm một bước `next:` cho giá trị nền thiếu lời chủ kho (`status --roles`) | `0.49.0` | Kho này không đọc `next:`. Không ảnh hưởng | Không đổi |
| 7 | Hợp đồng thêm sổ `conform` (`0.51.0`) và hàng nấc tìm nguồn (`ladder`, `0.53.0`). Sổ mới là «first entry» | `0.51.0`–`0.53.0` | `doctor.py` chỉ đếm sổ «yes». Không ảnh hưởng | Không đổi |
| 8 | `host-strings.json`, cột «From birth», khoá của `tool-stamp.json`, danh sách cờ của `adopt.mjs` | — | Không đổi | Chỉ đổi `version` và `read` |

## 3. Điều đã đổi ở kho này

- `tests/fixtures/design-assembly/seam.json`: `version` `0.59.0`, `read` `2026-11-25`. `from` thêm mục 2
  «Preview» của kỹ năng `adopt` (nơi nói các mã thoát) và `scripts/adopt.mjs` (lời dùng, và phép kiểm
  `--starter` ghi tệp nào). Nghĩa mã 2 theo lời plugin. Khoá mới `own_values` (điểm 1 và 2) và
  `also_writes` (điểm 5).
- `host-strings.json`: chép đè, không đổi byte nào.
- `docs/seam-contracts.md`: ba chỗ ghi phiên bản lên `0.59.0`; bỏ câu nói mẫu dữ liệu vẫn ghi nghĩa cũ;
  mục 7 thêm tệp kiểm phần nổi vào danh sách setup không ghi.
- `plugins/repo-setup/scripts/design_ledgers.py`: chú thích phiên bản.
- `tests/seams.sh`: 51j so câu mã 2 của kỹ năng `new` với nghĩa trong mẫu dữ liệu (đỏ trước, xanh sau);
  51g thêm các tệp trong `also_writes` vào danh sách setup không ghi.

Hành vi của `repo-setup` không đổi, nên `CHANGELOG.md` không có dòng mới. Dòng đang có dưới
`## Unreleased` («With design-assembly 0.35.0, a repository born with a brand colour gets no ledgers…»)
vẫn đúng với bản 0.35.0 và đã nói bản 0.36.0 sửa điều đó, nên để nguyên, theo luật không sửa lời PR khác.

## 4. Phiên trước, dừng ở 0.36.1

Worktree `.claude/worktrees/call-design-assembly-4e6e87`, nhánh
`claude/fixture-design-assembly-0-36-1-86c51d`, ba tệp chưa commit: `seam.json`,
`docs/seam-contracts.md`, `design_ledgers.py`. Mọi thay đổi ở đó đều có trong bản này, ở bản plugin mới
hơn:

- đổi phiên bản ở ba chỗ (bên đó ghi `0.36.1`, bên này `0.59.0`);
- bỏ câu «mẫu dữ liệu vẫn ghi nghĩa của bản đó»;
- `from` thêm mục «2. Preview»;
- nghĩa mã 2: bên đó gộp cả câu về kho có màu riêng vào nghĩa mã 2. Bên này để nghĩa mã 2 đúng lời
  plugin và đưa câu về kho có màu riêng sang khoá `own_values`, để bài kiểm mới so được câu mã 2 của kỹ
  năng.

Bản này phủ hết việc bên đó. Chủ kho có thể bỏ nhánh và worktree ấy.

## 5. Còn mở

1. **Bước plugs khi gọi với `--starter`.** Kỹ năng `adopt` của plugin có đoạn riêng cho `--starter`
   («When a repository has only just been given its floor»), rồi các bước 1 đến 5 cho lối thường. Chưa
   rõ khi `/repo-setup:new` gọi `/design-assembly:adopt` với `--starter`, tác tử có chạy bước plugs không.
   Nếu chạy, kho mới sinh có thể có câu hỏi ở `design/waiting/plug-*.json`. Không nói thay người, nên không
   phạm luật. Câu hỏi này thuộc về design-assembly: hỏi bên đó, không sửa ở đây.
2. **e2e chưa chạy.** Bài nhanh không chạy plugin. Ba phép kiểm mới (điểm 4) và tệp kiểm phần nổi
   (điểm 5) chỉ thấy được khi `bash tests/e2e.sh` chạy với plugin thật. Đó vẫn là việc thử đầu tiên trước
   `0.10.5`.
3. **Không gì báo khi plugin đi trước bản chép.** Bản chép tụt 24 phiên bản trong ba ngày. Có thể dựng
   một phép kiểm so `version` trong `seam.json` với bản plugin thật, nhưng nếu nó chặn thì đó là một
   phép kiểm đỏ bắt buộc mới: cần chủ kho duyệt trước. Đề xuất, chưa dựng: một dòng chỉ báo, không chặn,
   trong `doctor` hoặc trong e2e (nơi đã có mạng), khi bản plugin cài được mới hơn `version` của bản chép.
