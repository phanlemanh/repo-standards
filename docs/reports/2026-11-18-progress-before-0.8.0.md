# Tổng kết trước khi phát hành 0.8.0

Ngày 2026-11-18. Phạm vi: từ tag `repo-setup-v0.7.0` (`b220c58`) đến `main` tại `b6cfa81`. Kế
hoạch được chấm theo [thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và các
bước A đến F ở cuối mục 8. Bản trước: [tổng kết sau 0.7.0](2026-11-17-progress-after-0.7.0.md).

## 1. Tóm tắt

- Từ `0.7.0`: 3 PR đã gộp (22, 23, 24), 26 commit, 64 tệp đổi, thêm 5.334 dòng, bỏ 109 dòng.
- Bản `0.8.0` mang đúng một gói: RS2b, sổ thành mảnh. PR 23 có commit `!`: với kho dựng mới, đây là
  thay đổi phá vỡ (mục 2). Với kho đã cài thì không: nâng xong vẫn xanh, cho tới khi kho tự chạy
  `make split`.
- Từ bản tổng kết hôm qua chỉ có hai điều mới. PR 24 (chính bản tổng kết đó) đã gộp. CI «Test plugin»
  trên `main` tại `03c3b71` (commit gộp RS2b) xanh cả 4 ô, `e2e` 25 phút 17 giây. Điều kiện phát hành
  đặt hôm qua, «sau khi CI của `03c3b71` xanh», đã đạt.
- Bộ kiểm nhanh trên `b6cfa81` hôm nay qua hết, 57 mục.
- Cần làm trong PR phát hành: thêm hai mục «Verified» và «Known gaps» vào `## Unreleased` (hiện chưa
  có, trong khi `0.6.0` và `0.7.0` đều có), sửa ô trạng thái RS2b ở thiết kế tổng quan, rồi nâng số
  bản. Chi tiết ở mục 6.

## 2. Bản 0.8.0 gồm gì

| PR  | Nội dung                                                               | Trạng thái           |
| --- | ---------------------------------------------------------------------- | -------------------- |
| 22  | Thiết kế và kế hoạch bước D: RS2b (sổ thành mảnh) và RS3 (CI xếp tầng) | Đã gộp tại `266bf39` |
| 23  | `feat(core)!: ledgers as fragments (RS2b)`, 21 commit, 59 tệp          | Đã gộp tại `03c3b71` |
| 24  | Bản tổng kết sau 0.7.0                                                 | Đã gộp tại `b6cfa81` |

Chỉ PR 23 đổi hành vi. Sổ log, mục lục wiki, glossary và mã sinh từ `ontology/` thôi đi theo PR:

- Nguồn là các mảnh: mỗi mục log một tệp (`wiki/log/YYYY-MM-DD-NN-<slug>.md`), mỗi thuật ngữ một
  tệp (`ontology/glossary/<Term>.md`), và chính các trang wiki cho mục lục.
- `make derived` vẽ các tệp ở đường cũ. Các tệp đó mở đầu bằng dòng dấu và nằm ngoài git.
- Người ghi gọi lệnh, không sửa tệp: `make log m="…"`, `python3 tools/ledgers.py add-term …`. Một
  trang mới chỉ cần `type` và `title`.
- `make split L=<ledger>` chuyển một kho đang giữ sổ một tệp. Lệnh này chạy trong một PR riêng, so
  từng mục trước và sau, và dừng, không ghi gì, khi có mục sẽ mất.

Thay đổi phá vỡ, theo `CHANGELOG.md` («What breaks on upgrade»):

| Ai bị ảnh hưởng                           | Điều gì xảy ra                                                                                      |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Kho dựng mới                              | Ba sổ là mảnh ngay từ đầu; mẫu không còn cấp `wiki/log.md`, `wiki/index.md`, `ontology/glossary.md` |
| Kho đã cài, chưa `split`                  | Không có gì đỏ. Ba tệp cũ báo `dropped` và ở nguyên chỗ; `doctor` nhắc lệnh `split`                 |
| PR đang mở lúc một sổ được tách           | Một xung đột «xoá ở đây, sửa ở kia»; `git rm` tệp cũ trước, rồi `make log` hay `add-term`           |
| Bản dựng không đi qua `make` hay `npm ci` | Thiếu mã sinh từ `ontology/` trên bản clone sạch; chạy `make derived` trước                         |
| Tệp vẽ bị sửa tay, hoặc bị ép lại vào git | Đỏ: `draw` thoát 1, `derived-untracked` đỏ                                                          |

Một quyết định đáng để chủ kho đọc kỹ trước khi phát hành: job `review` trong `pr-pipeline.yml`
(lớp `github-agents`) giờ chạy với `--settings '{"disableAllHooks": true}'`. Không có cờ này, hook
`SessionStart` mới sẽ chạy Makefile của chính PR trong một job phải coi PR là dữ liệu.

## 3. Đối chiếu kế hoạch

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                                    |
| ---- | ---- | -------------------------------------------------------------- | ------------------------------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                                       |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                                          |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                                       |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2                     |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong, phát hành ở 0.7.0                                       |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | **Đã gộp, sẽ phát hành ở 0.8.0**; còn việc 9: đo trên kho thử |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | Đã thiết kế và duyệt, chưa dựng (7 việc)                      |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | Chưa thiết kế                                                 |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn                          |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                                         |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được                           |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm                                                      |

Sau `0.8.0`, bước A, B (trừ phần còn lại của RS10) và C đã phát hành. Bước D còn RS3 và phép đo của
RS2b. Không gói nào đổi trạng thái kể từ bản tổng kết hôm qua, trừ việc RS2b sắp được phát hành.

## 4. Kiểm chứng

| Phép kiểm                                                  | Kết quả                                                                    |
| ---------------------------------------------------------- | -------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main` tại `b6cfa81`, hôm nay     | Qua: 57 mục, «All tests passed.»                                           |
| CI «Test plugin» trên `main` tại `03c3b71`                 | Qua cả 4 ô; `e2e` 25 phút 17 giây                                          |
| CI «Test plugin» trên `main` tại `b6cfa81`                 | Đang chạy lúc viết; commit này chỉ thêm một tệp tài liệu                   |
| PR 23: `tests/e2e.sh` đủ tổ hợp trên `5f0c941`             | Qua, gồm «split all four ledgers after the upgrade from repo-setup-v0.7.0» |
| PR 23: `PRESETS="ts-node python" UPGRADE=1` trên `34bd93a` | Qua                                                                        |
| PR 23 và PR 24: CI                                         | Qua cả 4 ô                                                                 |

Chưa kiểm được:

- Hai PR song song trên kho thử, mỗi PR có `make log`, `add-term` và một trang mới, cùng gộp bằng
  nút GitHub mà không cần «Update branch» (RS2b, việc 9). Câu mở đầu của RS2b trong CHANGELOG đã ghi
  điều này là «not yet measured». Cần chủ kho cho phép đẩy và gộp ở `design-ci-probe`.
- `claude-code-action` có chuyển nguyên `claude_args`, và vì thế cờ tắt hook, hay không. Chỉ kho thử
  trả lời được.
- Một lần nâng thật giữa hai bản phát hành có đổi mẫu. `e2e` đã nâng từ tag `repo-setup-v0.7.0` lên
  mã hiện tại. Lần nâng từ tag `0.7.0` lên tag `0.8.0` chỉ chạy được sau khi gắn tag.
- Pipeline `github-agents` trên GitHub (`gate`, tự gộp hạng thấp), và CodeQL trên kho công khai sau
  khi nâng. Hai điều này còn mở từ `0.6.0`.

## 5. Số đo luồng

`sdlc_metrics.py --days 14` trên kho này:

| Chỉ số                             | Giá trị                                      | Hôm qua (sau 0.7.0) |
| ---------------------------------- | -------------------------------------------- | ------------------- |
| PR gộp                             | 24, không PR nào do agent mở                 | 22                  |
| Thời gian mở đến gộp               | trung vị 1,0 giờ, dài nhất 14,9 giờ          | 1,0 giờ; 14,9 giờ   |
| Gộp ngược nhánh chính vào nhánh PR | 2 trên 24 PR, 1 lần xung đột khi phát lại    | 2; 1                |
| Phút máy CI                        | 1.106,0 phút trong 58 lượt, 46,1 phút mỗi PR | 1.019,5; 46,3       |
| Đỏ trên nhánh chính                | 3 trên 26 lượt, cả ba ngày 2026-11-04        | 3 trên 25           |
| Revert                             | 0                                            | 0                   |

Số đo gần như đứng yên. Phút máy mỗi PR chỉ giảm khi RS3 bỏ được lượt `e2e` của các PR chỉ đổi tài
liệu, như PR 24. Kho này một người ghi và các phiên chạy nối tiếp, nên số xung đột thấp không nói
lên nhiều. Phép đo đáng có là trên `onehub-inventory`, trước và sau `split`.

## 6. Còn tồn

### Phải làm trong PR phát hành

1. Thêm `### Verified` vào `## Unreleased`, theo khuôn của `0.7.0`: những gì đã chạy (bộ kiểm nhanh
   trên Linux và macOS, kiểm danh sách kê, các tổ hợp `e2e` trong CI gồm «nâng từ tag
   `repo-setup-v0.7.0` rồi tách cả bốn sổ»), và dòng «Not yet run» với bốn điều ở mục 4.
2. Thêm `### Known gaps`. Năm khoảng hở của `0.7.0` vẫn còn: từ tag tới nay, `apply.py` chỉ đổi 13
   dòng cho khoá `kept_quietly`, không sửa khoảng hở nào. Thêm hai điều:
   - hai tệp của kho thử mang băm của bản dựng thay, nên lần nâng thật kế tiếp không tìm được gốc khớp
     cho chúng;
   - `apply.py` giờ 927 dòng (lúc `0.7.0` là 916), quá luật 800 dòng.
3. Sửa ô trạng thái RS2b ở bảng mục 7 của thiết kế tổng quan, hiện là «Đã dựng (2026-11-17), mục 48
   bộ kiểm; chờ đo trên kho thử», thành «Phát hành ở 0.8.0; chờ đo trên kho thử». Ghi chú «RS2b chưa
   đo trên kho thử» ở cùng mục vẫn đúng và giữ nguyên.
4. Đổi `## Unreleased` thành `## 0.8.0 — 2026-11-18`, chạy `python3 tools/bump_version.py 0.8.0`. Gộp
   bằng merge commit, gắn tag có chú thích `repo-setup-v0.8.0` lên commit gộp, rồi
   `gh release create` với đoạn CHANGELOG.

### Chủ kho quyết

1. Phát hành trước hay đo trên kho thử trước. Lần `0.6.0` đã chọn phát hành trước và ghi những gì
   chưa chạy vào «Verified». Đề xuất làm như vậy: nâng kho thử từ tag `0.7.0` lên tag `0.8.0` sẽ vừa
   là phép đo của RS2b, vừa là lần nâng thật đầu tiên giữa hai bản phát hành có đổi mẫu. Cái giá: nếu
   phép đo tìm ra lỗi thì phải có `0.8.1`.
2. Cho phép đo trên kho thử `design-ci-probe`: việc 9 của RS2b, và sau này việc 7 của RS3.
3. Có đặt ruleset bắt buộc ô `check` trên `main` của kho này không (thiết kế RS3, mục 9). Đây là đổi
   luật của kho, nên gói RS3 không tự làm.
4. Cho phép chạy trên `onehub-inventory` với `0.8.0`: nâng một lần, rồi `split` từng sổ, mỗi sổ một
   PR.
5. Phát hiện 5 từ trước: môi trường `production` trên kho riêng tư gói miễn phí không có người duyệt.
6. Các mục ở mục 10 của thiết kế tổng quan: ngưỡng tỉ lệ lỗi, chỗ đặt tệp uỷ quyền, có bắt buộc cả
   chín ô không.

### Theo kế hoạch

- Dựng RS3, ngay trên `main`.
- Thiết kế bước E: RS7 trước, RS5a khi DA3 đã nêu đường dẫn.
- RS6: đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- RS10: in nốt các dòng còn thiếu của mục 2.

### Vệ sinh

- Tám nhánh đã gộp vẫn còn trên GitHub: bảy nhánh cũ đã nêu ở bản trước, cộng
  `feat/ledger-fragments` (PR 23).
- Hai worktree: `.claude/worktrees/github-setup-merge-style-a16ed8` (cũ, đầu tách rời) và
  `.claude/worktrees/ledger-fragments`. Worktree thứ hai thuộc phiên bước D và đứng ở `7783041`, commit
  đã có trong `main`. Phiên đó dọn được khi nó không còn việc.

## 7. Đề xuất bước kế

1. Một PR phát hành `0.8.0` làm đủ bốn mục «Phải làm trong PR phát hành».
2. Sau khi gắn tag, khi chủ kho cho phép: nâng kho thử từ `0.7.0` lên `0.8.0`, `split` bốn sổ, rồi mở
   hai PR song song.
3. Dựng RS3.
4. Khi chủ kho cho phép: nâng `onehub-inventory` lên `0.8.0`, `split`, rồi đo lại bằng
   `sdlc_metrics.py` để có số trước và sau.
