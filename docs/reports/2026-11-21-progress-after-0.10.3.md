# Tổng kết sau 0.10.3

Ngày 2026-11-21. Phạm vi: từ `main` tại `44d0814` (commit gộp PR 55, cuối phạm vi của bản trước) đến
`main` tại `0ee66bd` (commit gộp PR 67). Kế hoạch được chấm theo
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7. Bản trước:
[tổng kết sau kế hoạch tổng hợp](2026-11-21-progress-after-consolidated-plan.md).

## 1. Tóm tắt

- Từ bản trước: 12 PR đã gộp (56 đến 67), 14 commit, 25 tệp đổi, thêm 1.161 dòng, bỏ 292 dòng.
- **Một bản phát hành:** `0.10.3` (PR 64), năm thay đổi: cách gộp lưu trong `governance/autonomy.yaml`,
  số phiên bản `X.Y.Z.devN` giữa hai tag, ngưỡng trong báo cáo đo, câu về cổng chỉ còn ở kho có đường
  ống tác tử, và các dòng mới của thước đo.
- **Sáu câu chủ kho quyết ở bản trước đều đã có câu trả lời và đã dựng** (PR 57 đến 63).
- **Cả hai kho dùng đều ở `0.10.3`:** kho thử (PR 22) và `onehub-inventory` (PR 98, qua một vòng
  nghiệm thu hạng T3).
- **Kế hoạch ở mục 7 của bản thiết kế chỉ còn RS5b.** RS4 và RS5a đã đóng, không dựng. RS5b chờ
  delivery-loop.
- **`main` mang `0.10.4.dev0`**, với một bản sửa chưa phát hành (PR 66).
- **CI trên `main` xanh ở 13 lượt gần nhất;** lượt cho commit gộp PR 67 đang chạy lúc viết.

## 2. Đã thực hiện

### Kế hoạch tới nay

| Gói                                 | Trạng thái ở bản trước      | Bây giờ                                                        |
| ----------------------------------- | --------------------------- | -------------------------------------------------------------- |
| RS1, RS2a, RS2b, RS3, RS7, RS8, RS9 | Xong                        | Xong, không đổi                                                |
| RS6                                 | Xong (PR 51)                | Xong; hàng trạng thái đã sửa (PR 57)                           |
| RS10                                | Xong (PR 50), ngưỡng còn mở | Xong, kèm mục ngưỡng (PR 63); phát hành ở `0.10.3`             |
| RS5a                                | Có thiết kế, chờ chủ kho    | Đóng, không dựng: chủ kho chọn hướng A (PR 57)                 |
| RS4                                 | Hoãn                        | Đóng, không dựng: kit không đọc bản đồ phạm vi (PR 67)         |
| RS5b                                | Hoãn                        | Hoãn, kèm điều kiện: một ADR ở kit, rồi một vòng; chưa có lịch |

### Từ bản trước

| PR  | Việc                                                                                |
| --- | ----------------------------------------------------------------------------------- |
| 56  | Tổng kết sau kế hoạch tổng hợp                                                      |
| 57  | Ba hàng trạng thái RS5a, RS6, RS10; RS5a đóng theo hướng A                          |
| 58  | Câu 3: cách gộp lưu trong `governance/autonomy.yaml`                                |
| 59  | Câu 5: bản dựng giữa hai tag mang số `X.Y.Z.devN`                                   |
| 60  | Câu 6: kho không có đường ống tác tử không bị bảo rằng một cổng nâng hạng           |
| 61  | Câu 4: `CHANGELOG.md` gộp kiểu union                                                |
| 62  | Bộ kiểm không còn ống dẫn vào `grep -q` (cùng kiểu chạy đua với lần đỏ ở `bc31175`) |
| 63  | Câu 1: ngưỡng là một dòng trong báo cáo của `tools/sdlc_metrics.py`                 |
| 64  | Phát hành `0.10.3`                                                                  |
| 65  | `main` mang `0.10.4.dev0` sau bản phát hành                                         |
| 66  | Chú thích của mẫu chính sách chỉ nhắc đường ống tác tử như một điều kiện            |
| 67  | RS4 đóng; điều kiện của RS5b; hàng RS10 và hai điều còn mở số 1 và 2 được cập nhật  |

### Kho khác

- **Kho thử (`design-ci-probe`):** PR 22 đã gộp, đi thẳng từ `0.10.1` lên `0.10.3`. Lượt nâng thoát
  mã 0, không tệp nào bị đánh dấu.
- **`onehub-inventory`:** PR 98 đã gộp (`d37f3ea5`). Lượt nâng thoát mã 1 vì đánh dấu một tệp (mục 3).
  Vòng nghiệm thu của kit: hạng T3, 10 tiêu chí, lượt chấm 1 đạt 10 trên 10, hai cổng do chủ kho ký.
- **delivery-loop và design-assembly:** phiên giám sát gửi 12 mục cho delivery-loop và 6 mục cho
  design-assembly, nhờ mỗi kho đối chiếu với kế hoạch của mình rồi báo chủ kho. Delivery-loop đã trả
  lời hai câu quyết định RS4 và RS5b (nhánh `chuyen-nha` của kho đó,
  `migration/KE-HOACH-12-MUC-REPO-STANDARDS.md`, mục 5). Kết quả còn lại không quay về kho này.

## 3. Phát hiện

1. **Giá trị mặc định `squash` sai ở cả hai kho thật.** `0.10.3` ghi `merge_method: squash` cho kho
   chưa khai. Kho thử chỉ cho gộp bằng merge commit trên GitHub; `onehub-inventory` gộp bằng merge
   commit vì kit cần thế. Cả hai phải sửa tay thành `merge` trong PR nâng cấp. Để nguyên thì lần chạy
   `tools/github_setup.py --apply` kế tiếp đưa kho về squash. «Known gaps» của `0.10.3` đã ghi điều
   này cho kho dùng kit; ở kho thử thì không lường trước.
2. **Lượt nâng đánh dấu tệp chính sách ở kho có bản lệch từ trước.** Bản `governance/autonomy.yaml`
   của `onehub-inventory` chưa từng có hai khối `proof` và `required_checks`. `0.10.3` thêm khoá
   `merge_method` ngay sau hai khối ấy, nên khoá mới va vào chỗ lệch. Vùng lệch này đã đi qua
   `0.10.2` mà không bị đánh dấu, chỉ vì bản đó không đổi gì ở cạnh nó. PR 98 gỡ bằng cách lấy phía
   mẫu cho vùng đó; hồ sơ nghiệm thu đo rằng cách này và cách thêm tối thiểu cho cùng kết quả.
3. **Vòng nghiệm thu ở kho dùng bắt được một lỗi của mẫu.** Khi cân hai cách gỡ, hồ sơ chỉ ra rằng
   chú thích của mẫu nói «the PR pipeline stops running its own reviewer agent» cho cả kho không có
   đường ống tác tử: đúng chỗ sót mà `0.10.3` vừa gỡ khỏi `AGENTS.md`. Đã sửa ở PR 66, kèm bài kiểm
   đỏ trước; kỹ năng `github` mang cùng câu đó và cũng đã sửa.
4. **Vòng lặp của báo cáo truy nguyên xảy ra ngay ở kho này.** Bảy PR của sáu câu trả lời cùng sửa
   `tests/run.sh` và `CHANGELOG.md`. PR 58 phải gộp `main` ngược bốn lần, mỗi lần kéo một lượt `e2e`
   khoảng 26 phút. Sau PR 61, `CHANGELOG.md` không còn xung đột khi phát lại; `tests/run.sh` (3.852
   dòng) nay đứng đầu danh sách tệp xung đột.
5. **Ngưỡng báo «vượt» lần đầu trên số sống, và là ở chính kho này.** `tools/sdlc_metrics.py` in:
   đỏ trên nhánh chính của «Test plugin» 5 trên 69, vượt ngưỡng 1 trên 20. Năm lần đỏ đều cũ, từ
   trước 20/11. Hai dòng còn lại ghi «quá ít để kết luận».
6. **RS4 và RS5a hỏng theo cùng một kiểu.** Cả hai được viết ở kho này từ nhu cầu đoán của kho khác,
   rồi kho kia tự giải theo cách của nó. Lần nào việc đọc mã thật của bên đọc cũng cho câu trả lời
   trước khi dựng.

## 4. Kiểm chứng

| Phép kiểm                                                                | Kết quả                                                                           |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| CI «Test plugin» trên `main`, 13 commit gộp gần nhất, từ PR 54 tới PR 66 | Qua cả 13                                                                         |
| CI trên PR 56 đến 67, ở đầu nhánh được gộp                               | Qua cả 5 ô                                                                        |
| Bảy PR 57 đến 63 gộp chung trên một bản sao nháp, trước khi gộp thật     | Sáu PR sạch và `bash tests/run.sh` qua; PR 62 xung đột ở `tests/run.sh`           |
| Cây của commit gộp PR 64 so với đầu nhánh phát hành                      | Trùng nhau                                                                        |
| Job `conventional-commits` có rào của `0.10.2` trên runner thật          | Đã chạy ở `onehub-inventory` (PR thử 96); đọc được rào và chú thích lỗi trong log |
| Kho thử ở `0.10.3`: `make check` ở máy; CI trên PR 22; CI trên `main`    | Qua; 8 ô xanh; xanh                                                               |
| `onehub-inventory` ở `0.10.3`: `make check` ở máy (2.476 bài)            | Qua                                                                               |
| `onehub-inventory`: `tools/github_setup.py` chạy thử với `merge`         | In «merge commits only»                                                           |
| Công cụ đo của `0.10.3` trên `onehub-inventory` và trên kho này          | Chạy được, in đủ các mục mới                                                      |
| Bài kiểm của PR 66                                                       | Đỏ trên dòng cũ của mẫu, xanh sau khi sửa                                         |

Chưa kiểm được:

- CI trên `main` tại `0ee66bd` (commit gộp PR 67) và CI trên `main` của `onehub-inventory` tại
  `d37f3ea5`: đang chạy lúc viết.
- `tools/github_setup.py --apply` trên một kho thật với `merge_method`: chưa kho nào chạy. Ở
  `onehub-inventory`, GitHub vẫn cho cả squash và rebase trong khi chính sách ghi `merge`.
- Nâng một kho được dựng từ một bản `devN`.
- GitHub có áp `merge=union` khi nó tự gộp một PR hay không.
- Số 10 trên 10 của vòng nghiệm thu PR 98 là của phiên nghiệm thu; bản này không chạy lại thước đo.
- Còn từ trước: không bài kiểm nào chạy công cụ thật của design-assembly hay delivery-loop.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 17` của `main` trên chính kho này. Cửa sổ bắt đầu 2026-11-04,
muộn hơn bản trước một ngày.

| Dòng                                | Bây giờ                                | Bản trước                             |
| ----------------------------------- | -------------------------------------- | ------------------------------------- |
| PR đã gộp                           | 67                                     | 55                                    |
| Trung vị từ mở đến gộp              | 0,7 giờ                                | 0,7 giờ                               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                               | 14,9 giờ                              |
| Gộp nhánh chính vào nhánh PR        | 15 trên 67 PR, 5 xung đột khi phát lại | 7 trên 55 PR, 5 xung đột khi phát lại |
| Phút máy CI                         | 4.015,5 trong 161 lượt                 | 2.930,0 trong 129 lượt                |
| Phút máy mỗi PR gộp                 | 59,9                                   | 53,3                                  |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 69                              | 5 trên 51                             |
| Revert                              | 0                                      | 0                                     |

- Không lượt đỏ mới trên `main`.
- Số lần gộp ngược tăng gấp đôi, từ 7 lên 15, chỉ trong 12 PR, chủ yếu ở PR 58 (bốn lần), PR 59 và PR 63
  (mục 3, điều 4). Sau khi sẵn sàng, cả 67 PR có 11 lần gộp ngược, nhiều nhất 4 ở
  một PR.
- Số lần xung đột khi phát lại vẫn là 5, nhưng thành phần đổi: `CHANGELOG.md` rời danh sách nhờ luật
  union; `tests/run.sh` vào với 3 lần.
- Phút máy mỗi PR tăng từ 53,3 lên 59,9: mỗi lần gộp ngược ở một PR đổi mã chạy lại `e2e` trọn bộ.
- 39 PR có đủ số: sẵn sàng đến ô bắt buộc xanh trung vị 0,48 giờ; xanh đến gộp trung vị 0,09 giờ.

## 6. Còn lại

### Chủ kho quyết

1. **`onehub-inventory`: khai `e2e` và `gate` vào `required_checks`, rồi chạy
   `tools/github_setup.py --apply`.** Hôm nay ruleset trên GitHub đòi `check`, `e2e`, `gate`, còn
   chính sách để `required_checks` trống; GitHub cho cả squash và rebase, còn chính sách ghi `merge`.
2. **Phát hành bản sửa ở PR 66** (`0.10.4`), hay chờ gom thêm.
3. **Tệp kế hoạch nâng `onehub-inventory`** (`docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`)
   vẫn chưa commit; hợp đồng ở kho đó trích nó.
4. **`tests/run.sh` là tệp chung mới của kho này** (mục 3, điều 4). Tách nó theo mục là một gói mới,
   chưa có trong kế hoạch.
5. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí); các mục 3, 4,
   6, 7 và 9 ở mục 10 của bản thiết kế.

### Theo kế hoạch

- **RS5b:** chờ một ADR ở kit rồi một vòng «giám sát chủ động». Không chờ việc gì ở kho này.
- **Giá trị mặc định của `merge_method`** (mục 3, điều 1): lượt nâng có thể đọc cách gộp GitHub đang
  cho phép thay vì ghi `squash`. Chưa thiết kế.
- **`ontology_actions.py` dài 856 dòng**, quá giới hạn 800.
- **Một bài kiểm chạy công cụ thật** của design-assembly cho hợp đồng `affected.mjs`.
- **Ngưỡng** vẫn là ba giá trị khởi đầu, chưa giá trị nào được suy ra từ dữ liệu.

### Vệ sinh

- 38 nhánh trên GitHub ngoài `main`; chưa kiểm cả 38 đã gộp.
- Hai worktree: `.claude/worktrees/rs-consolidated-plan-2f7ac9` và
  `.claude/worktrees/rule-kinds-design-1c073a`.
- Kho thử: hai PR của dependabot (15, 19) còn mở.

## 7. Đề xuất hạng mục tiếp tục

1. **Đọc CI trên `main` của hai kho** tại `0ee66bd` và `d37f3ea5`.
2. **Chốt chính sách của `onehub-inventory`** (mục 6, điều 1). Đây là chỗ lệch duy nhất còn lại giữa
   điều kho ghi và điều GitHub đang làm, và là lần đầu `--apply` chạy với `merge_method`.
3. **Sửa giá trị mặc định của `merge_method`** để kho kế tiếp không phải sửa tay. Cả hai kho thật đều
   đã vấp.
4. **Đo lại `onehub-inventory` bằng `--split`** tại mốc PR 98, khi đủ PR gộp sau nó: báo cáo truy
   nguyên có số «trước», công cụ nay cho số «sau» mà không phải làm tay.
5. **Tách `tests/run.sh`** nếu chủ kho nhận gói ở mục 6, điều 4.
