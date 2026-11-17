# Tổng kết sau RS8

Ngày 2026-11-17. Phạm vi: toàn bộ kho, từ bản đầu `0.1.0` (2026-11-03) đến `main` tại `ec42a6a`.
Kế hoạch được chấm theo [thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và
các bước A đến F ở cuối mục 8. Bản trước:
[tổng kết trước 0.6.0](2026-11-17-progress-before-0.6.0.md).

## 1. Tóm tắt

- Ba trong sáu bước của Repo Standards đã xong và đã chạy trên GitHub thật: A (RS1, RS9), B
  (RS2a, RS10), C (RS8). Bước C là điều kiện chủ kho đặt trước khi chạy trên
  `onehub-inventory`, nên đường tới bước đó đã mở.
- Còn lại: D (RS2b, RS3) và E (RS7, RS5a) chưa thiết kế; F (RS4, RS5b) hoãn tới khi delivery-loop
  đọc được. RS6 chưa làm dù RS9 đã xong.
- 19 PR đã gộp, 6 bản đã phát hành (`0.1.0` đến `0.6.0`), 143 commit trong 14 ngày.
- RS8 đã gộp (PR 19) nhưng **chưa phát hành**. `onehub-inventory` chỉ dùng được nó sau khi có bản
  `0.7.0`, vì đường nâng cấp dựng gốc từ tag của bản phát hành.
- Bộ kiểm nhanh trên `main` qua hết: 56 mục, 670 phép kiểm `miss` (trước 0.6.0 là 557). CI trên
  `main` xanh liên tục từ 2026-11-05.

## 2. Kho này có gì hôm nay

Một marketplace với một plugin, `repo-setup`, dựng và giữ setup cho kho khác:

| Phần            | Nội dung                                                                                              |
| --------------- | ----------------------------------------------------------------------------------------------------- |
| Bộ mẫu (preset) | `_core` cộng sáu ngăn xếp: `python`, `fastapi`, `ts-node`, `ts-api`, `react-vite`, `claude-plugin`    |
| Kỹ năng         | `new`, `adopt`, `doctor`, `explain`, `github`                                                         |
| Mã chạy         | 2.342 dòng Python trong `plugins/repo-setup/scripts/`, chỉ dùng thư viện chuẩn                        |
| Luật nền        | «Người quyết, máy kiểm» ([nguyên tắc](../setup-principles.md)); mục 43 của bộ kiểm đỏ khi luật bị phá |
| Bộ kiểm         | `tests/run.sh` (2.214 dòng), `tests/upgrade.sh` (412 dòng), `tests/e2e.sh` cài thật mỗi tổ hợp        |

| Bản   | Ngày       | Điểm chính                                                                         |
| ----- | ---------- | ---------------------------------------------------------------------------------- |
| 0.1.0 | 2026-11-03 | Bản đầu                                                                            |
| 0.2.0 | 2026-11-03 | Bộ máy ontology và wiki, hook của Claude Code, nhận kho có sẵn                     |
| 0.3.0 | 2026-11-04 | SDLC theo hướng AI (người ở biên), ontology ra thao tác, vai, dữ liệu cá nhân      |
| 0.4.0 | 2026-11-05 | Plugin chỉ còn phần setup; setup có hướng dẫn theo tầng quyết định                 |
| 0.5.0 | 2026-11-11 | Preset `claude-plugin` và hồ sơ `doctor` cho marketplace                           |
| 0.6.0 | 2026-11-17 | Tường thật, gộp kiểu hợp cho sổ log, thước luồng, tầng thiết kế, vòng đời thực thể |

## 3. Đối chiếu kế hoạch

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                        | Bằng chứng                            |
| ---- | ---- | -------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, đã phát hành ở 0.6.0                        | PR 14, 17; kho thử; mục 44            |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                              | PR 14; mục 45                         |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, đã phát hành ở 0.6.0                        | PR 15; mục 46; phát lại trên kho thật |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2         | PR 15; mục 46                         |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong, **chưa phát hành**                          | PR 19; mục 47; PR 7–9 ở kho thử       |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | Chưa thiết kế; theo hướng DA1 của design-assembly | —                                     |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | Chưa thiết kế                                     | —                                     |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | Chưa thiết kế                                     | —                                     |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn              | —                                     |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                             | —                                     |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được               | —                                     |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm, dù ô ghi «làm cùng RS9»                 | —                                     |

Bước sau C trong thứ tự chủ kho chốt là chạy trên `onehub-inventory`. Bước đó chưa bắt đầu, cần
chủ kho cho phép ở kho đó, và cần bản `0.7.0` trước.

Các gói DA và DL thuộc hai kho kia. Kho này không dựng chúng; trạng thái của chúng không đọc từ
đây.

## 4. Chấm theo bốn tiêu chí

| Tiêu chí               | Đã dịch chuyển                                                                                                                                                          | Chưa đo hoặc chưa dịch chuyển                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Ít lần người xuất hiện | Bỏ luật `ask` và duyệt vì lệ (PR 13); ruleset không cần người duyệt. Với RS8, người chỉ gộp tay chỗ hai bên sửa cùng một dòng, thay vì 34 tệp lệch ở `onehub-inventory` | Lượt gọi người phía Máy chưa đo                                                               |
| Nhanh                  | Khi phát lại trên `onehub-inventory`, xung đột ở `wiki/log.md` từ 65 về 0, gộp ngược xung đột từ 96 về 76                                                               | Chỉ đúng khi gộp ở máy; nút của GitHub không theo `merge=union`. Phần lớn lợi chờ RS2b và DL1 |
| Ít nguồn lực           | —                                                                                                                                                                       | 44,2 phút máy cho mỗi PR gộp ở kho này, phần lớn là `e2e` (khoảng 22 phút). Chờ RS3           |
| Vẫn tin cậy            | Sáu bức tường trước chỉ có trên danh nghĩa nay đều giữ thật, mỗi bức có bài kiểm đỏ và bài kiểm xanh. Bản sửa của mẫu không còn bị bỏ sót mà không báo                  | Ngưỡng tỉ lệ lỗi chấp nhận chưa chốt (mục 10 của thiết kế)                                    |

## 5. Kiểm chứng

| Phép kiểm                                                 | Kết quả                                                                               |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main` tại `ec42a6a`, hôm nay    | Qua: 56 mục, «All tests passed.»                                                      |
| CI của PR 19 (`offline` Ubuntu, macOS, `validate`, `e2e`) | Qua; `e2e` 22 phút, gồm tổ hợp mới «nâng từ `repo-setup-v0.6.0`» (`marked: []`)       |
| CI «Test plugin» trên `main`                              | 19 lượt xanh liên tiếp từ 2026-11-05; 3 lượt đỏ đều ngày 2026-11-04                   |
| Kho thử `design-ci-probe`, PR 7–9                         | Hai tệp `merged`, hai tệp `marked`; ô `check` đỏ đúng bước `upgrade`, gỡ dấu thì xanh |

Chưa kiểm được:

- Pipeline `github-agents` trên GitHub (`gate`, tự gộp hạng thấp). Kho thử không cài phần này.
- Kho công khai sau khi nâng: CodeQL còn phân tích không.
- Một lần nâng thật giữa hai bản phát hành có đổi mẫu. Lần chạy ở kho thử dùng bản dựng thay
  `0.6.1`, vì nhánh RS8 không đổi mẫu nào có sẵn.

## 6. Số đo luồng

`sdlc_metrics.py --days 14` trên kho này:

| Chỉ số                             | Giá trị                                      |
| ---------------------------------- | -------------------------------------------- |
| PR gộp                             | 19, không PR nào do agent mở                 |
| Thời gian mở đến gộp               | trung vị 0,8 giờ, dài nhất 14,9 giờ          |
| Gộp ngược nhánh chính vào nhánh PR | 2 lần, 1 lần xung đột khi phát lại           |
| Phút máy CI                        | 839 phút trong 47 lượt, 44,2 phút mỗi PR gộp |
| Đỏ trên nhánh chính                | 3 trên 22 lượt, cả ba ngày 2026-11-04        |
| Revert                             | 0                                            |

Kho này một người ghi và các phiên chạy nối tiếp, nên số xung đột thấp không nói lên nhiều. Thước
luồng đáng xem là ở `onehub-inventory`.

## 7. Còn tồn

### Chủ kho quyết

1. Số bản và lúc phát hành RS8. Có commit `!`, nên đề xuất `0.7.0`.
2. Cho phép chạy trên `onehub-inventory`. Cần dặn trước: lần nâng đầu sẽ ghi dấu `wiki/log.md`
   với nhãn `no matching base`; giữ phần của kho, bỏ phần của mẫu.
3. Phát hiện 5 từ lần trước: môi trường `production` trên kho riêng tư gói miễn phí không có
   người duyệt.
4. Các mục ở mục 10 của thiết kế tổng quan: ngưỡng tỉ lệ lỗi, chỗ đặt tệp uỷ quyền, có bắt buộc cả
   chín ô không.

### Theo kế hoạch

- Bước D: thiết kế RS2b cùng nhịp với DA1, và RS3.
- RS6: đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- RS10: in nốt các dòng còn thiếu của mục 2.

### Lỗi nhỏ đã biết của RS8, chưa sửa

- `apply.py` 916 dòng, quá luật 800 dòng.
- Tệp không có dòng trống cuối thì bị ghi dấu thay vì gộp sạch khi mẫu thêm một dòng cuối.
- `--dry-run` trả mã 1 khi có tệp sẽ bị ghi dấu; các kỹ năng chưa nói điều này.
- Phép kiểm `upgrade_wall` so khớp dòng `include` đúng từng chữ.
- Công cụ dò dấu bỏ sót dấu đóng bị Prettier biến thành trích dẫn (`> > > > > > >`).
- Thư mục `plugins/repo-setup/` trong tệp nén được nhận ở bất kỳ độ sâu nào.
- Hai tệp của kho thử mang băm của bản dựng thay, nên lần nâng thật kế tiếp sẽ không tìm được gốc
  khớp cho chúng.

### Vệ sinh

- Bảy nhánh cũ đã gộp trên GitHub: `claude/github-setup-merge-style-a16ed8`,
  `claude/plugin-marketplace-preset-7a7427`, `claude/relations-and-attributes-1dd820`,
  `feat/design-layer`, `feat/entity-lifecycle`, `fix/boundaries-alias-and-server-door`,
  `release/0.5.0`.
- Một worktree cũ: `.claude/worktrees/github-setup-merge-style-a16ed8`.

## 8. Đề xuất bước kế

1. PR phát hành `0.7.0`, rồi gắn tag `repo-setup-v0.7.0`.
2. Nâng kho thử từ tag `0.7.0` để có một lần nâng thật giữa hai bản phát hành.
3. Khi chủ kho cho phép: nâng `onehub-inventory` (đang ở `0.4.0`, 34 tệp đã sửa tại chỗ), rồi đo
   lại bằng `sdlc_metrics.py` để có số trước và sau.
4. Thiết kế bước D.
