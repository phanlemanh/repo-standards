# Tổng kết sau kế hoạch tổng hợp

Ngày 2026-11-21. Phạm vi: từ `main` tại `b2cb544` (commit gộp bản `0.10.1`, cuối phạm vi của bản
trước) đến `main` tại `44d0814` (commit gộp PR 55). Kế hoạch được chấm theo
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7, và theo bảy gói của «kế hoạch
tổng hợp cho Repo Standards» mà chủ kho giao cho một phiên riêng ngày 2026-11-20. Bản trước:
[tổng kết sau 0.10.1](2026-11-20-progress-after-0.10.1.md); mục 8 của bản đó (PR 44) nay nằm trong
phạm vi này.

## 1. Tóm tắt

- Từ bản trước: 12 PR đã gộp (44 đến 55), 15 commit, 25 tệp đổi, thêm 2.850 dòng, bỏ 837 dòng.
- **Một bản phát hành:** `0.10.2` (PR 47), gồm ba bản sửa: tên `gate` chỉ là ô của setup khi có
  pipeline agent, xung đột ở một tệp `mk/` kết thúc lượt chạy bằng mã 1, và đầu ra của hook không
  tới được runner như một lệnh workflow.
- **`onehub-inventory` đã ở `0.10.2`** (PR 93 lên `0.10.1`, PR 95 lên `0.10.2`). Kho thử còn ở
  `0.10.1`.
- **Một phép truy nguyên** vì sao từ quyết đến gộp ở `onehub-inventory` lâu:
  [báo cáo](2026-11-20-decision-to-merge-trace.md). Nguyên nhân lớn nhất nằm ngoài kho này (DL1 và
  DL2 của delivery-loop); phần của kho này thành kế hoạch tổng hợp.
- **Kế hoạch tổng hợp, bảy gói:** bốn gói có việc đã gộp (PR 50 đến 54), một gói mới có bản thiết kế
  (PR 55), hai gói chưa bắt đầu. Sáu câu hỏi chờ chủ kho (mục 6).
- **RS6 và RS10 xong.** RS5a có thiết kế, và thiết kế đề xuất không dựng (mục 3).
- **Chưa phát hành sau `0.10.2`:** PR 50 đổi hành vi của công cụ đo, đang nằm dưới `## Unreleased`.
- **CI trên `main` cho bảy lần gộp cuối (PR 49 đến 55) còn đang chạy lúc viết.**

## 2. Đã thực hiện

### Kế hoạch tới nay

| Gói  | Trạng thái ở bản trước        | Bây giờ                                                               |
| ---- | ----------------------------- | --------------------------------------------------------------------- |
| RS5a | Chưa thiết kế; chờ DA3        | Có thiết kế (PR 55), đề xuất không dựng; chờ chủ kho chọn A, B hay C  |
| RS6  | Chưa làm                      | Xong (PR 51): luật 8 đến 10 trong `setup-principles.md`, bài kiểm 43k |
| RS10 | Còn thiếu dòng, chưa tách mốc | Xong (PR 50): đủ các dòng của mục 2, có `--split`                     |
| RS4  | Hoãn                          | Hoãn, không đổi                                                       |
| RS5b | Hoãn                          | Hoãn, không đổi                                                       |

Ba hàng RS5a, RS6 và RS10 trong mục 7 của bản thiết kế chưa được sửa theo bảng này.

### Từ bản trước

| PR  | Việc                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------- |
| 44  | Hai bản sửa mối nối: tên `gate`; xung đột ở tệp `mk/` nêu tên phép kiểm bị bỏ lại và kết thúc bằng 1    |
| 45  | Tổng kết sau `0.10.1`                                                                                   |
| 46  | `pr-title.yml`: đầu ra của hook nằm trong rào, không giữ token sau checkout                             |
| 47  | Phát hành `0.10.2`                                                                                      |
| 48  | Báo cáo truy nguyên từ quyết đến gộp                                                                    |
| 49  | Đính chính hai dòng của báo cáo đó; đối chiếu với kế hoạch của từng kho; dòng trạng thái ở bản thiết kế |
| 50  | Gói 1: công cụ đo báo thêm                                                                              |
| 51  | Gói 3: RS6                                                                                              |
| 52  | Gói 6: bộ kiểm không còn dừng im lặng                                                                   |
| 53  | Gói 6: tách `apply.py`                                                                                  |
| 54  | Gói 5: trang hợp đồng mối nối, ba bài kiểm                                                              |
| 55  | Gói 4: bản thiết kế RS5a                                                                                |

### Kế hoạch tổng hợp, theo gói

| Gói | Việc                                                    | Trạng thái                 | Còn lại                             |
| --- | ------------------------------------------------------- | -------------------------- | ----------------------------------- |
| 1   | Công cụ đo báo thêm                                     | Xong (PR 50)               | Chưa phát hành                      |
| 2   | Ngưỡng đỏ                                               | Chưa dựng                  | Chủ kho quyết, câu 1                |
| 3   | RS6                                                     | Xong (PR 51)               | —                                   |
| 4   | RS5a                                                    | Có thiết kế (PR 55)        | Chủ kho quyết, câu 2                |
| 5   | Hợp đồng mối nối; lưu cách gộp                          | Xong phần hợp đồng (PR 54) | Lưu cách gộp: chủ kho quyết, câu 3  |
| 6   | Kho tự giữ luật: năm việc                               | Xong hai việc (PR 52, 53)  | Ba việc: chủ kho quyết, câu 4 đến 6 |
| 7   | Báo cáo cuối; cập nhật bảng trạng thái của bản thiết kế | Báo cáo là bản này         | Bảng trạng thái chưa sửa            |

**Gói 1** (`tools/sdlc_metrics.py`, nay kèm bốn tệp `sdlc_gh.py`, `sdlc_jobs.py`, `sdlc_pulls.py`,
`sdlc_report.py`):

- Ô `check` đỏ lúc PR còn nháp không còn tính là đỏ muộn; nó đếm riêng một dòng.
- Mỗi job một hàng: lượt, xanh, đỏ, bị huỷ, trung vị phút, giờ máy, số lần đỏ ở bước chạy phép kiểm.
- Bước đỏ trên từ hai nhánh trở lên. Tên bài kiểm không đọc: việc đó cần log và khuôn của từng bộ chạy.
- Thời gian của một PR đã gộp, chỉ từ GitHub và git: mở đến sẵn sàng, sẵn sàng đến ô bắt buộc xanh,
  xanh đến gộp; số lần đẩy và số lần gộp nhánh chính sau khi sẵn sàng. Không đọc tệp nào của kit.
- `--split NGÀY|TAG` chia cửa sổ thành trước và từ một mốc.

**Gói 5:** [`docs/seam-contracts.md`](../seam-contracts.md) nêu bốn hợp đồng (bốn danh sách của make,
`affected.mjs --json`, tên ô `check` và `gate`, `_acceptance/**` không phải đầu vào tầng nặng) và
một mục «chưa có hợp đồng». Bài kiểm 51c đến 51e giữ chúng từ phía kho này.

**Gói 6:** `apply.py` từ 976 xuống 594 dòng, phần dựng kế hoạch tệp sang `apply_plan.py` (439 dòng).
Lần đỏ ở `bc31175`: xem mục 3.

### Kho khác

- **`onehub-inventory`:** PR 93 (`0.10.1`) và PR 95 (`0.10.2`) đã gộp, cả hai qua một vòng nghiệm
  thu của kit do một phiên riêng chạy. Giữa hai PR đó, kho ấy tự sửa hook khuôn commit của mình để
  nhận các tiêu đề kit viết (PR 94). PR 96 là PR thử của bản `pr-title.yml` mới trên runner thật: đã
  đóng, không gộp. PR 97 ghi kết quả lần thử vào hồ sơ, còn mở.
- **Kho thử (`design-ci-probe`):** không đổi, còn ở `0.10.1`.

## 3. Phát hiện

1. **Kế hoạch bảo dựng một bức tường đã có ở kho khác.** Gói 4 giao dựng RS5a: PR đụng khuôn thiết
   kế hay màu thương hiệu thì lên hạng cao. Phép kiểm `owner-calls` của design-assembly đã chặn
   khuôn mới và màu gốc, và nó nằm trong `make check`, sau ô bắt buộc `check`. Dựng RS5a như đã viết
   sẽ gọi người hai lần cho cùng một quyết định, trái luật «không thêm chỗ dừng». Bản thiết kế ở
   PR 55 đề xuất đóng RS5a.
2. **Một lỗi chỉ lộ trên dữ liệu thật.** `gh --jq` in chuỗi không có ngoặc kép, nên phần đọc ô bắt
   buộc của công cụ đo chỉ chạy được với bản `gh` giả của bộ kiểm. Đã sửa trong PR 50, kèm bài kiểm.
   Cùng loại: các công cụ của cấp `team` chưa từng được lint ở máy; bài 48zi nay lint cả kho `team`.
3. **Bộ kiểm nhanh có thể dừng mà không in dòng FAIL nào.** Dưới `set -euo pipefail`, một phép gán
   dẫn ống vào bộ đọc thoát sớm (`… | head -1`) làm cả lượt chạy dừng im lặng. Đó là cơ chế khớp với
   lần đỏ ở `bc31175`; lần chạy đua đó chưa tái hiện được. Bài 45b nay đỏ khi có kiểu viết ấy.
4. **Báo cáo truy nguyên có hai dòng sai, đã đính chính trong PR 49.** Dòng đề xuất «cho kho khai
   thêm tệp sinh ra» (cơ chế `DERIVED_FILES` đã có từ RS2b) và dòng «sửa bốn bài đỏ chéo nhánh» (các
   bài đó đã thôi đỏ từ 19/11). Nguyên nhân chung: đề xuất được viết trước khi đối chiếu với kế
   hoạch và trạng thái của kho phải làm.
5. **Hai thứ kit đã phát hành mà `onehub-inventory` chưa bật:** luật gộp `tep-sinh` cho
   `LO-TRINH.html`, và lối gộp nhanh. Chi tiết ở mục 9 của báo cáo truy nguyên.

## 4. Kiểm chứng

| Phép kiểm                                                                              | Kết quả                                                        |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| CI «Test plugin» trên `main` tại `c1dbe05`, `e7646bb`, `a6491c7`, `2f8f141`, `4d7940b` | Qua                                                            |
| CI trên PR 44 đến 55, ở đầu nhánh được gộp                                             | Qua cả 5 ô                                                     |
| Sáu PR 50 đến 55 gộp chung trên một bản sao nháp                                       | Không xung đột; `bash tests/run.sh` qua                        |
| Cây của `main` tại `44d0814`                                                           | Trùng cây của bản gộp thử đã chạy bộ kiểm                      |
| Công cụ đo mới trên `onehub-inventory`, hai ngày gần nhất                              | Chạy được: đỏ muộn 8 trên 19, đỏ vì chờ 3, 10 PR có đủ ba đoạn |
| Công cụ đo mới trên chính kho này, có và không có `--split`                            | Chạy được (mục 5)                                              |
| `onehub-inventory`: bản ghi phiên bản trên `main`                                      | `0.10.2`                                                       |
| `onehub-inventory`: `conventional-commits` sau `0.10.1`                                | Xanh trên PR 94 và PR 95                                       |

Chưa kiểm được:

- CI trên `main` tại bảy commit gộp cuối (`1cb2a27` đến `44d0814`): đang chạy lúc viết.
- Bản `pr-title.yml` có rào trên runner thật. PR 96 ở `onehub-inventory` là lần thử; kết quả do phiên
  nghiệm thu đọc và ghi ở PR 97, bản này chưa đọc lại log.
- CI trên `main` của `onehub-inventory` sau PR 95: đang chạy lúc viết. Lượt trước đó (`f2a49b49`) đỏ
  vì runner mất kết nối giữa `make ci-db`, không phải vì một bài kiểm.
- Số lần gộp ngược có xung đột mà công cụ đo in lệch 1 so với báo cáo truy nguyên; chưa rõ vì sao.
- Chưa bài kiểm nào chạy công cụ thật của design-assembly hay delivery-loop; ba bài 51c đến 51e giữ
  hợp đồng từ phía kho này.
- Còn từ trước: một lần chuyển từ starter lên team trên kho thật có luật riêng trong `AGENTS.md`; hai
  lượt cùng lưu một khoá đầu vào; pipeline `github-agents` trên GitHub.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 17` của `main` trên chính kho này. Cửa sổ bắt đầu 2026-11-03,
sớm hơn bản trước một ngày.

| Dòng                                | Bây giờ                               | Bản trước                             |
| ----------------------------------- | ------------------------------------- | ------------------------------------- |
| PR đã gộp                           | 55                                    | 43                                    |
| Trung vị từ mở đến gộp              | 0,7 giờ                               | 0,7 giờ                               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                              | 14,9 giờ                              |
| Gộp nhánh chính vào nhánh PR        | 7 trên 55 PR, 5 xung đột khi phát lại | 7 trên 43 PR, 5 xung đột khi phát lại |
| Phút máy CI                         | 2.930,0 trong 129 lượt                | 2.445,8 trong 103 lượt                |
| Phút máy mỗi PR gộp                 | 53,3                                  | 56,9                                  |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 51                             | 5 trên 46                             |
| Revert                              | 0                                     | 0                                     |

- Không lượt đỏ mới trên `main` trong 5 lượt đã xong; 7 lượt cuối chưa xong nên chưa tính.
- 12 PR mới không thêm lần gộp ngược nào. `CHANGELOG.md` vẫn đứng đầu danh sách tệp xung đột, 3 lần.
- Các dòng mới của công cụ, 24 PR gộp từ tag `0.9.0`: sẵn sàng đến ô bắt buộc xanh trung vị 0,48
  giờ (lâu nhất 4,88); xanh đến gộp trung vị 0,15 giờ (lâu nhất 7,18); 31 lần đẩy sau khi sẵn sàng,
  trung vị 1 mỗi PR. Trước tag đó chỉ 3 trên 31 PR có đủ số để tính đoạn «đến xanh», nên chưa so
  được hai phía.
- `--split repo-setup-v0.9.0` cho 51,5 phút máy mỗi PR trước mốc (31 PR) và 55,5 từ mốc (24 PR). Số
  này không đo RS3: kho này không dùng khuôn CI xếp tầng mà RS3 sinh ra. Phép so của RS3 thuộc
  `onehub-inventory`, nơi báo cáo truy nguyên đo 548 phút trước và 337 phút trên 9 PR sau.
- Lần đẩy lên `main` sau mỗi lần gộp vẫn chạy `e2e` trọn bộ, cả khi PR chỉ đổi tài liệu: bảy lần gộp
  liền nhau ngày 21/11 mở bảy lượt như vậy.

## 6. Còn lại

### Chủ kho quyết

1. **Ngưỡng (gói 2, và điều còn mở số 1 của bản thiết kế).** Máy đề xuất: đỏ muộn 20%, nhánh chính
   đỏ 1 trên 20, một tệp chiếm quá nửa số lần gộp ngược xung đột. `onehub-inventory` hiện ở 21%, 8%
   và 92%; kho thử không vượt ngưỡng nào. Ngưỡng bắt ở đâu: một dòng trong báo cáo (máy đề xuất), mã
   thoát khác 0 của công cụ, hay một đích trong `make check`.
2. **RS5a:** A (không dựng, máy đề xuất), B hay C, theo bản thiết kế ở PR 55.
3. **Cách gộp (gói 5):** có lưu vào `governance/autonomy.yaml` thay cho cờ `--merge-method` không.
4. **`CHANGELOG.md` (gói 6):** một dòng `merge=union`, hay mỗi PR một mảnh gộp lại lúc phát hành. Cả
   hai cách đều đổi một dòng của `CLAUDE.md`.
5. **Số phiên bản của bản dựng giữa hai tag (gói 6):** `0.10.3.dev0` ngay sau mỗi bản phát hành, hay
   manifest ghi kèm commit của plugin.
6. **Câu «the gate sees both and raises the tier» trong `55-autonomy.md` (gói 6):** sửa, bỏ hay giữ
   với kho không có pipeline agent.
7. **Tệp kế hoạch nâng `onehub-inventory`** (`docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`)
   vẫn chưa commit; hợp đồng ở kho đó trích nó.
8. **Có gửi các đề xuất ở mục 9 của báo cáo truy nguyên sang delivery-loop, design-assembly và
   `onehub-inventory` không.**
9. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí); các mục 2, 3,
   4, 6, 7 và 9 ở mục 10 của bản thiết kế. Mục 5 đã có câu trả lời (lối gộp nhanh chưa bật).

### Theo kế hoạch

- **Sửa ba hàng trạng thái** (RS5a, RS6, RS10) ở mục 7 của bản thiết kế.
- **Phát hành** phần đang nằm dưới `## Unreleased` (PR 50), rồi đưa tới kho thử và `onehub-inventory`.
- **Bước F:** RS4 và RS5b, khi delivery-loop chuyển nhà xong.
- **`ontology_actions.py` dài 856 dòng**, quá giới hạn 800. Đây là mẫu mọi kho nhận, nên chưa tách.
- **Một bài kiểm chạy công cụ thật** của design-assembly cho hợp đồng `affected.mjs`.
- **RS7 để lại** và **RS3 để lại:** như bản trước, trừ phép so phút máy nay đã có công cụ để làm.

### Vệ sinh

- 26 nhánh trên GitHub ngoài `main`, nhánh nào cũng đã gộp.
- Hai worktree: `.claude/worktrees/rs-consolidated-plan-2f7ac9` (của phiên kế hoạch, đứng ở nhánh
  `feat/flow-metrics-tell-more` đã gộp) và `.claude/worktrees/rule-kinds-design-1c073a`.
- Kho thử: hai PR của dependabot (15, 19) còn mở.

## 7. Đề xuất hạng mục tiếp tục

1. **Đọc CI trên `main` tại bảy commit gộp cuối.** Xanh thì phần đã gộp có chứng cứ ở cả hai nơi.
2. **Trả lời câu 1 đến câu 6.** Bốn trong sáu câu là việc nhỏ một khi đã chọn; câu 1 và câu 4 đổi
   luật của kho.
3. **Phát hành bản kế tiếp** sau khi câu 5 có câu trả lời, để số phiên bản của nó theo cách mới.
4. **Sửa ba hàng trạng thái ở bản thiết kế**, kèm dòng đóng RS5a nếu chủ kho chọn A.
5. **Ở `onehub-inventory`: bật luật gộp `tep-sinh` cho `LO-TRINH.html`.** Đây là việc rẻ nhất trong
   báo cáo truy nguyên, và có thước để đo trước và sau (`--split`). Việc này thuộc kho đó, cần chủ
   kho cho phép.
