# Tổng kết sau 0.7.0

Ngày 2026-11-17. Phạm vi: toàn bộ kho, đến `main` tại `03c3b71`. Kế hoạch được
chấm theo [thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và các bước A đến F
ở cuối mục 8. Bản trước: [tổng kết sau RS8](2026-11-17-progress-after-rs8.md).

## 1. Tóm tắt

- Bản `0.7.0` đã phát hành (PR 21, tag `repo-setup-v0.7.0` trên `b220c58`). Đường nâng cấp (RS8)
  giờ dùng được ở kho khác, vì nó dựng gốc của mỗi tệp từ tag phát hành. Điều kiện chủ kho đặt
  trước khi chạy trên `onehub-inventory` đã đủ.
- Bước D đã qua phần thiết kế: hai bản thiết kế và hai kế hoạch (RS2b, RS3) được chủ kho duyệt và
  đã gộp (PR 22).
- RS2b đã dựng xong tám trong chín việc của kế hoạch và đã gộp (PR 23, `03c3b71`), nhưng **chưa
  phát hành**. Việc còn lại là đo trên kho thử, và việc đó cần chủ kho cho phép.
- RS3 chưa dựng. Bước E (RS7, RS5a) chưa thiết kế. Bước F hoãn. RS6 vẫn chưa làm.
- 23 PR đã gộp, 7 bản đã phát hành (`0.1.0` đến `0.7.0`), 171 commit trên `main`.
- Bộ kiểm nhanh trên `main` qua hết, 57 mục. CI «Test plugin» trên `main` xanh 22 lượt liền từ
  2026-11-05; lượt của `03c3b71` còn đang chạy lúc viết.

## 2. Thay đổi từ bản tổng kết trước

| PR  | Nội dung                                                      | Trạng thái                                |
| --- | ------------------------------------------------------------- | ----------------------------------------- |
| 20  | Bản tổng kết sau RS8                                          | Đã gộp                                    |
| 21  | Phát hành `0.7.0`                                             | Đã gộp, đã gắn tag, đã đăng bản phát hành |
| 22  | Thiết kế và kế hoạch bước D (RS2b, RS3)                       | Đã gộp tại `266bf39`                      |
| 23  | `feat(core)!: ledgers as fragments (RS2b)`, 21 commit, 59 tệp | Đã gộp tại `03c3b71`, CI xanh cả 4 ô      |

## 3. Đối chiếu kế hoạch

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                                       | Bằng chứng                      |
| ---- | ---- | -------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                                          | PR 14, 17; mục 44               |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                                             | PR 14; mục 45                   |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                                          | PR 15; mục 46                   |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2                        | PR 15; mục 46                   |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | **Xong, phát hành ở 0.7.0**                                      | PR 19, 21; mục 47               |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | **Đã gộp, chưa phát hành** (việc 1–8 của 9); còn đo trên kho thử | PR 22 (thiết kế), PR 23; mục 48 |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | **Đã thiết kế và duyệt**, chưa dựng (7 việc)                     | PR 22                           |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | Chưa thiết kế                                                    | —                               |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn                             | —                               |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                                            | —                               |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được                              | —                               |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm, dù ô ghi «làm cùng RS9»                                | —                               |

Từ PR 23, sổ log, mục lục wiki, glossary và mã sinh từ `ontology/` không còn đi theo PR. Nguồn
là các mảnh: mỗi mục log một tệp, mỗi thuật ngữ một tệp, và chính các trang wiki cho mục lục.
`make derived` vẽ lại các tệp ở đường cũ, và các tệp đó nằm ngoài git. Kho đã cài vẫn giữ một tệp
và vẫn xanh sau khi nâng, cho tới khi kho tự chạy `make split` trong một PR riêng.

Những quyết định người dựng tự đưa ra khi dựng, khác với câu chữ của kế hoạch, đều ghi ở mô tả PR 23. Một quyết định đáng để chủ kho đọc kỹ: ô duyệt PR trong `pr-pipeline.yml` giờ tắt mọi hook, để
hook mới không chạy Makefile của chính PR trong một job phải coi PR là dữ liệu.

Các gói DA và DL thuộc hai kho kia. Kho này không dựng chúng.

## 4. Chấm theo bốn tiêu chí

| Tiêu chí               | Đã dịch chuyển                                                                                                                                                               | Chưa đo hoặc chưa dịch chuyển                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Ít lần người xuất hiện | Với RS8 đã phát hành, kho đã cài nhận bản sửa của mẫu mà người chỉ gộp tay những chỗ hai bên sửa cùng một dòng                                                               | Lượt gọi người phía Máy chưa đo                                                            |
| Nhanh                  | Khi RS2b được phát hành và một kho chạy `split`, bốn tệp hay xung đột nhất không còn trong PR. Lỗi của nút gộp GitHub (không theo `merge=union`) hết tác dụng với các tệp đó | Chưa đo: hai PR song song trên kho thử cùng gộp bằng nút GitHub, không cần «Update branch» |
| Ít nguồn lực           | —                                                                                                                                                                            | 46,3 phút máy mỗi PR gộp (trước: 44,2). `e2e` vẫn chạy mọi lần đẩy. Chờ RS3                |
| Vẫn tin cậy            | Mọi bước kiểm chờ `make derived`, nên kiểm chạy trên tệp vừa vẽ chứ không trên tệp cũ. `split` so từng mục và dừng, không ghi gì, khi có mục sẽ mất                          | Ngưỡng tỉ lệ lỗi chấp nhận chưa chốt (mục 10 của thiết kế)                                 |

## 5. Kiểm chứng

| Phép kiểm                                              | Kết quả                                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------------------ |
| `bash tests/run.sh` trên `main` tại `03c3b71`, hôm nay | Qua: 57 mục, «All tests passed.»                                         |
| CI của PR 21 (phát hành `0.7.0`)                       | Qua cả 4 ô; `e2e` 22 phút 39 giây                                        |
| CI «Test plugin» trên `main`                           | 22 lượt xanh liên tiếp từ 2026-11-05; 3 lượt đỏ đều ngày 2026-11-04      |
| PR 23: `tests/run.sh` (mục 48 mới, 48a–48zo)           | Qua, theo mô tả PR                                                       |
| PR 23: `tests/e2e.sh` đủ tổ hợp                        | Qua, gồm «nâng từ `repo-setup-v0.7.0` rồi tách cả bốn sổ», theo mô tả PR |
| PR 23: CI                                              | Qua cả 4 ô trên `7783041`; `e2e` 20 phút 57 giây                         |

Chưa kiểm được:

- Hai PR song song trên kho thử, mỗi PR có `make log`, `add-term` và một trang mới, cùng gộp bằng
  nút GitHub (RS2b, việc 9). Cần chủ kho cho phép đẩy và gộp ở `design-ci-probe`.
- `claude-code-action` có chuyển nguyên `claude_args`, và vì thế cờ tắt hook, không. Chỉ kho thử
  trả lời được.
- Một lần nâng thật giữa hai bản phát hành có đổi mẫu. `0.7.0` không đổi mẫu nào có sẵn; bản kế
  tiếp có RS2b sẽ là lần đầu.
- Pipeline `github-agents` trên GitHub (`gate`, tự gộp hạng thấp), và CodeQL trên kho công khai sau
  khi nâng.

## 6. Số đo luồng

`sdlc_metrics.py --days 14` trên kho này:

| Chỉ số                             | Giá trị                                      | Trước (sau RS8)   |
| ---------------------------------- | -------------------------------------------- | ----------------- |
| PR gộp                             | 22, không PR nào do agent mở                 | 19                |
| Thời gian mở đến gộp               | trung vị 1,0 giờ, dài nhất 14,9 giờ          | 0,8 giờ; 14,9 giờ |
| Gộp ngược nhánh chính vào nhánh PR | 2 trên 23 PR, 1 lần xung đột khi phát lại    | 2; 1              |
| Phút máy CI                        | 1.019,5 phút trong 55 lượt, 46,3 phút mỗi PR | 839; 44,2         |
| Đỏ trên nhánh chính                | 3 trên 25 lượt, cả ba ngày 2026-11-04        | 3 trên 22         |
| Revert                             | 0                                            | 0                 |

Phút máy mỗi PR tăng vì ba PR mới đều chạy `e2e` đủ, kể cả hai PR chỉ đổi tài liệu (PR 20, 22).
Đây đúng là phần RS3 bỏ đi. Kho này một người ghi và các phiên chạy nối tiếp, nên số xung đột thấp
không nói lên nhiều. Thước luồng đáng xem là ở `onehub-inventory`.

## 7. Còn tồn

### Chủ kho quyết

1. Số bản và lúc phát hành RS2b. PR 23 có commit `!`, nên đề xuất `0.8.0`.
2. Cho phép đo trên kho thử `design-ci-probe`: việc 9 của RS2b, và sau này việc 7 của RS3.
3. Có đặt ruleset bắt buộc ô `check` trên `main` của kho này không (thiết kế RS3, mục 9). Không có
   ruleset thì ô tổng chỉ để đọc. Đây là đổi luật của kho, nên gói RS3 không tự làm.
4. Cho phép chạy trên `onehub-inventory`, và chạy với `0.7.0` ngay hay chờ `0.8.0`. Với `0.7.0`,
   lần nâng đầu sẽ ghi dấu `wiki/log.md` với nhãn `no matching base`; khi đó giữ phần của kho, bỏ
   phần của mẫu. Với `0.8.0`, kho nâng một lần rồi chạy `split`.
5. Phát hiện 5 từ trước: môi trường `production` trên kho riêng tư gói miễn phí không có người
   duyệt.
6. Các mục ở mục 10 của thiết kế tổng quan: ngưỡng tỉ lệ lỗi, chỗ đặt tệp uỷ quyền, có bắt buộc cả
   chín ô không.

### Theo kế hoạch

- Dựng RS3. RS2b đã gộp, nên RS3 dựng ngay trên `main` mà không phải gộp ngược, dù hai gói cùng
  đụng `Makefile` và CI.
- Thiết kế bước E: RS7 trước, RS5a khi DA3 đã nêu đường dẫn.
- RS6: đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- RS10: in nốt các dòng còn thiếu của mục 2.

### Lỗi nhỏ đã biết của RS8, chưa sửa

Ghi ở `CHANGELOG.md`, mục «Known gaps» của `0.7.0`. Thêm hai điều không có ở đó:

- `apply.py` vẫn 916 dòng, quá luật 800 dòng.
- Hai tệp của kho thử mang băm của bản dựng thay, nên lần nâng thật kế tiếp sẽ không tìm được gốc
  khớp cho chúng.

### Vệ sinh

- Bảy nhánh cũ đã gộp vẫn còn trên GitHub: `claude/github-setup-merge-style-a16ed8`,
  `claude/plugin-marketplace-preset-7a7427`, `claude/relations-and-attributes-1dd820`,
  `feat/design-layer`, `feat/entity-lifecycle`, `fix/boundaries-alias-and-server-door`,
  `release/0.5.0`.
- Một worktree cũ: `.claude/worktrees/github-setup-merge-style-a16ed8`.

## 8. Đề xuất bước kế

1. Phát hành `0.8.0`, sau khi lượt CI của `03c3b71` trên `main` xanh.
2. Khi chủ kho cho phép: đo RS2b trên kho thử, nâng kho thử từ `0.7.0` lên `0.8.0`. Đó sẽ là lần nâng
   thật đầu tiên giữa hai bản phát hành có đổi mẫu.
3. Dựng RS3.
4. Khi chủ kho cho phép: nâng `onehub-inventory` lên `0.8.0`, chạy `split`, rồi đo lại bằng
   `sdlc_metrics.py` để có số trước và sau.
