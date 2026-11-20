# Truy nguyên: từ quyết đến gộp ở `onehub-inventory`

Ngày 2026-11-20. Đo lại hiện trạng của
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 2, sau khi phần của Repo Standards
(RS1, RS2, RS3, RS8, RS10) đã phát hành và chạy ở `onehub-inventory`. Thêm ba phép đo bản thiết kế
chưa có: thời gian từng đoạn của một hồ sơ, lý do từng job đỏ, và bài kiểm ở Máy so với ở GitHub bắt
được gì. Mục 7 đối chiếu kết quả với các gói việc đã có; mục 8 chỉ nêu việc chưa có trong kế hoạch.

## 1. Đo gì, đo thế nào

Đo trên lịch sử thật của `onehub-inventory`, nhánh chính tại `f2a49b49`, chỉ đọc. Bốn nguồn:

- **Hồ sơ của kit** (`_acceptance/<slug>/decisions.jsonl` và `run-log.jsonl`): mốc duyệt Cổng 1, từng
  lượt chấm và kết luận của nó, từng lần kiểm lại, từng lệnh kit chạy ở Máy kèm mã thoát.
- **Git:** commit đầu tiên mà `evidence-report.md` có chữ ký là mốc ký Cổng 2; commit gộp trên nhánh
  chính mang commit đó vào là mốc gộp.
- **GitHub** (`gh api`): 524 lượt `CI` từ 2026-11-09, kèm job và bước; log của mọi job đỏ.
- **`tools/sdlc_metrics.py`** của chính kho đó (RS10), chạy với `--days 11`, `5` và `2`.

73 hồ sơ có trên nhánh chính; 63 hồ sơ đã ký và đã gộp, mỗi hồ sơ một PR. Lệnh đo ở thư mục nháp của
phiên, không commit. `design-ci-probe` (có setup, không có kit, một phiên làm) là mẫu đối chứng.

## 2. Thời gian từng đoạn

| Khoảng                  | Số hồ sơ | Trung vị | 10% chậm nhất từ | Dài nhất |
| ----------------------- | -------- | -------- | ---------------- | -------- |
| Duyệt Cổng 1 → gộp      | 60       | 7,7 giờ  | 23,2 giờ         | 39,2 giờ |
| Lượt chấm đạt → gộp     | 41       | 3,2 giờ  | 11,9 giờ         | 15,7 giờ |
| Ký Cổng 2 → gộp         | 63       | 1,15 giờ | 3,6 giờ          | 10,5 giờ |
| · ký → ô bắt buộc xanh  | 63       | 0,70 giờ | 3,1 giờ          | 9,9 giờ  |
| · ô bắt buộc xanh → gộp | 63       | 0,36 giờ | 1,2 giờ          | 2,6 giờ  |

Riêng 14 hồ sơ gộp từ 15/11 có đủ mốc, «lượt chấm đạt → gộp» có trung vị 6,0 giờ.

Thời gian đi vào đâu, trên 34 hồ sơ có đủ bốn mốc (363 giờ từ Cổng 1 tới gộp):

| Đoạn                          | Giờ | Phần |
| ----------------------------- | --- | ---- |
| Duyệt Cổng 1 → lượt chấm đầu  | 112 | 31%  |
| Lượt chấm đầu → lượt chấm đạt | 71  | 20%  |
| Lượt chấm đạt → ký Cổng 2     | 113 | 31%  |
| Ký Cổng 2 → gộp               | 68  | 19%  |

Mỗi hồ sơ có trung vị 2 lượt chấm (nhiều nhất 11), 1 lượt bị REJECT, 2 lần kiểm lại (nhiều nhất 13)
và 13 quyết định ghi ở Cổng 2 (nhiều nhất 47).

## 3. Vòng lặp gộp ngược, đo lại

Mục 2 của bản thiết kế đo 93 trên 99 lần gộp nhánh chính ngược vào nhánh có xung đột, `wiki/log.md`
60 lần, `LO-TRINH.html` 71 lần. Đo lại bằng `tools/sdlc_metrics.py`, phát lại với luật gộp hiện tại
của kho:

| Cửa sổ             | PR gộp | Gộp ngược | Có xung đột | `LO-TRINH.html` | `_acceptance/config.yaml` | `wiki/log.md` |
| ------------------ | ------ | --------- | ----------- | --------------- | ------------------------- | ------------- |
| Từ 09/11 (11 ngày) | 82     | 175       | 138 (79%)   | 129             | 30                        | 0             |
| Từ 15/11 (5 ngày)  | 28     | 68        | 42 (62%)    | 37              | 13                        | 0             |
| Từ 18/11 (2 ngày)  | 9      | 7         | 4           | 2               | 1                         | 0             |

Phần của Repo Standards đã hết: `wiki/log.md` không còn xung đột lần nào. Phần còn lại gần như chỉ là
hai tệp của delivery-loop, đúng như điều 1 ở «Rà lại kế hoạch» của bản thiết kế đã đoán. Tệp đứng thứ
ba (`inventory-grid.tsx`, mã sản phẩm) chỉ 12 lần trong 11 ngày.

`LO-TRINH.html` nặng 275 KB và bị 67 trên 82 commit gộp ghi lại; `_acceptance/config.yaml` bị 47
commit gộp ghi lại.

Vòng lặp còn chạy sau khi người đã quyết. Trên 63 hồ sơ đã ký:

- 160 lần gộp ngược (trung vị 2 mỗi PR, nhiều nhất 8); 60 lần xảy ra **sau** chữ ký Cổng 2.
- Sau chữ ký, nhánh còn nhận 66 commit kiểm lại, 19 commit `test`, 16 commit `fix`.
- Chữ ký là commit cuối (15 PR): «ký → gộp» trung vị 0,6 giờ, 10% chậm nhất từ 1,3 giờ. Còn commit
  hay lần gộp sau chữ ký (48 PR): trung vị 1,5 giờ, 10% chậm nhất từ 4,1 giờ.

| Số lần gộp ngược của PR | Số PR | Duyệt Cổng 1 → gộp, trung vị |
| ----------------------- | ----- | ---------------------------- |
| 0                       | 7     | 1,7 giờ                      |
| 1 đến 2                 | 27    | 3,9 giờ                      |
| Từ 3                    | 29    | 13,1 giờ                     |

Bảng này cho thấy liên hệ, chưa chứng minh nhân quả: PR sống lâu cũng gom nhiều lần gộp ngược hơn.

Các dòng khác của mục 2, đo lại:

| Dòng                                 | Bản thiết kế (15–16/11) | Từ 15/11        | Từ 18/11       |
| ------------------------------------ | ----------------------- | --------------- | -------------- |
| Mở PR đến gộp, trung vị              | 9,6 giờ (15 PR)         | 5,1 giờ (28 PR) | 3,0 giờ (9 PR) |
| Phút máy GitHub cho mỗi PR gộp       | 548 (8 PR)              | 445             | 337            |
| Đỏ muộn trên đầu nhánh đã qua `gate` | 2 trên 16               | 17 trên 47      | 10 trên 17     |
| Nhánh chính đỏ sau gộp (`CI`)        | 0 trên 8                | 2 trên 25       | 1 trên 8       |
| «Release» đỏ sau gộp                 | 6 trên 6                | 23 trên 28      | 4 trên 9       |

«Đỏ muộn» tăng. Chưa tách được phần do ô `check` đỏ lúc PR còn nháp (khuôn xếp tầng của RS3 có từ
0.9.0): xem giới hạn ở mục 6. «Release» xanh từ 19/11.

## 4. Job đỏ vì gì

400 lượt chạy gần nhất (15–20/11): `CI` trên PR có 105 lượt, 20 xanh, 52 đỏ, 33 bị huỷ. Trong 29
nhánh có PR, 3 nhánh có mọi lượt `CI` xanh. 108 job đỏ, đọc log từng job:

| Ô                      | Job đỏ | Lý do                                                       | Còn xảy ra        |
| ---------------------- | ------ | ----------------------------------------------------------- | ----------------- |
| `gate`                 | 46     | Hồ sơ chưa đi hết đường                                     | Có, theo thiết kế |
| `release-please`       | 16     | Kho chưa cho GitHub Actions mở PR                           | Không, từ 19/11   |
| `e2e`, `e2e-db`        | 16     | Xem mục 5                                                   | Có                |
| `conventional-commits` | 14     | «No hook with id `conventional-pre-commit`»                 | Không, từ 0.10.1  |
| `check`                | 13     | 9 lần PR còn nháp; 3 lần `make check` đỏ; 1 lần lượt bị huỷ | Có, theo thiết kế |
| `conventional-title`   | 3      | Tiêu đề PR không theo khuôn                                 | Tuỳ tiêu đề       |

Lý do của 46 lần `gate` đỏ (một job có thể nêu nhiều lý do): bằng chứng cũ vì có commit sau lượt chấm
15; PR chưa có hồ sơ hoặc bản ghi 13; chờ chữ ký Cổng 2 9; chờ lượt chấm 8; hồ sơ có nhưng cổng chưa
mở 5; lượt chấm REJECT 5. Chỉ nhóm cuối báo một kết quả xấu.

Ô «CodeQL» (kết quả quét, không phải một lượt chạy) đỏ ở PR 94 và PR 95 vì cảnh báo trong thước đo
của hồ sơ (`_acceptance/<slug>/rang/*.mjs`), cùng một kiểu cảnh báo ở cả hai hồ sơ.

## 5. Máy và GitHub: trùng gì, bắt được gì

| Hạng mục                                    | Ở Máy (kit ghi lại, 64 hồ sơ)                | Ở GitHub                  |
| ------------------------------------------- | -------------------------------------------- | ------------------------- |
| `make check` (lint, kiểu, 2.476 bài đơn vị) | 193 lần, trung vị 2 mỗi hồ sơ; 32 đỏ (17%)   | Mỗi lần đẩy               |
| Bài trình duyệt                             | 443 lần, trung vị 3; 56 đỏ (13%)             | `e2e`, mỗi lần đẩy        |
| Bài có cơ sở dữ liệu                        | 409 lần ở 24 hồ sơ, trung vị 14; 51 đỏ (12%) | `e2e-db`, mỗi lần đẩy     |
| Build                                       | 190 lần; 2 đỏ                                | Mỗi lần đẩy               |
| Kiểm lại sau khi mã đổi (cả bộ)             | 139 lần, trung vị 10,6 phút; 40 đỏ (29%)     | —                         |
| Quét bí mật, khuôn commit                   | Hook khi commit                              | `secret-scan`, «PR title» |
| Hồ sơ và chữ ký                             | Kit                                          | `gate`                    |
| Thước đo riêng của hồ sơ                    | 243 lần; 10 đỏ                               | Không chạy                |
| CodeQL, kiểm phụ thuộc                      | Không chạy                                   | Chỉ ở GitHub              |

Yêu cầu «không trùng và không sót» (mục 1 của bản thiết kế) chưa đạt: chỉ hai dòng cuối không trùng.
Kiểm lại ở Máy tốn tổng 27,8 giờ.

Ở GitHub, cả 524 lượt:

| Job      | Lượt | Xong xanh | Đỏ  | Bị huỷ | Trung vị  | Giờ máy |
| -------- | ---- | --------- | --- | ------ | --------- | ------- |
| `e2e`    | 508  | 322       | 25  | 151    | 26,5 phút | 134     |
| `e2e-db` | 300  | 159       | 29  | 102    | 29,4 phút | 90      |
| `check`  | 520  | 406       | 57  | 57     | 2,9 phút  | 21      |
| `quick`  | 43   | 32        | 0   | 11     | 4,8 phút  | 3       |
| `gate`   | 506  | 210       | 280 | 16     | 0,4 phút  | 3       |

Bước «cùng đầu vào với một lượt xanh» của khuôn xếp tầng trúng 6 lần ở `e2e` và 6 lần ở `e2e-db`.

84 job đỏ ở chính bước chạy bài kiểm (`make check`, `make e2e`, `make ci-db`), đọc log từng job:

| Loại                                              | Job | Phần |
| ------------------------------------------------- | --- | ---- |
| Bài chỉ đỏ ở nhánh đó: GitHub bắt được lỗi của PR | 31  | 37%  |
| Bài cũng đỏ ở nhánh khác: không do PR đó          | 45  | 54%  |
| PR của dependabot (không có lần chạy ở Máy)       | 7   | 8%   |
| Runner mất kết nối                                | 1   | 1%   |

Tỉ lệ một lượt chạy xong bắt được lỗi riêng của PR: `e2e` 10 trên 347 (2,9%); `e2e-db` 10 trên 188
(5,3%); `make check` 11 trên khoảng 463 (2,4%).

Bốn bài gây phần lớn nhóm «không do PR đó»:

| Bài                                                           | Job đỏ | Số nhánh |
| ------------------------------------------------------------- | ------ | -------- |
| `tools/round_metrics/round-metrics.test.ts`                   | 18     | 15       |
| `tests/e2e-db/lop-rieng.spec.ts` (company words on inventory) | 9      | 5        |
| `tests/e2e-db/thue-phi.spec.ts` (ve-tay-va-dieu-kien-phi-pha) | 4      | 4        |
| `tests/e2e/frame.spec.ts` (bài trợ năng trên mọi khung)       | 4      | 4        |

Bài đầu là bài đơn vị nhưng đọc trạng thái hồ sơ thật của kho, nên đỏ theo việc của nhánh khác.
Không bài nào trong bốn bài này đỏ từ 19/11: xem mục 9.

Hai số về độ phủ: 113 bài từng đỏ ở GitHub; và trong 102 lần một bài trình duyệt đỏ ở một lượt, 57
lần chỉ đỏ ở một cỡ màn, 33 lần ở hai cỡ, 12 lần ở cả bốn. Chạy bốn cỡ không phải là lặp thuần tuý.

Mẫu đối chứng `design-ci-probe`: 15 PR gộp, mở đến gộp trung vị 0,1 giờ, 15 phút máy mỗi PR, 1 lần
gộp ngược, không xung đột.

## 6. Giới hạn

- Giờ tính theo đồng hồ, gồm cả đêm và lúc chủ kho không ở máy. Đoạn «lượt chấm đạt → ký Cổng 2»
  vì thế không tách được phần chờ người khỏi phần hồ sơ chưa sẵn.
- 29 trên 63 hồ sơ thiếu mốc lượt chấm dùng được (không có lượt đạt nào ghi trước chữ ký, hoặc Cổng
  1 được duyệt lại sau lượt chấm đầu). Bảng phần trăm ở mục 2 chỉ dựa trên 34 hồ sơ còn lại.
- Số ở Máy chỉ gồm các lần kit ghi vào `run-log.jsonl`, không gồm lần chạy tay.
- «Chỉ đỏ ở nhánh đó» là ước lượng: một bài chập chờn đỏ đúng một lần vẫn được tính là lỗi của PR;
  một bài hỏng thật trên nhánh chính trong vài giờ được tính là «không do PR đó».
- «Đỏ muộn» của `tools/sdlc_metrics.py` chưa được đọc lại sau RS3: ô `check` đỏ lúc PR còn nháp có
  thể đang được đếm vào đó.
- Chưa đọc `db/scripts/ci-db.sh`. Bộ `tools/e2e_templates/suite.ts` chiếm 35% thời gian bài của
  `e2e` và 63% của `e2e-db`; hai job có chạy trùng nó không thì chưa rõ.
- Chưa đọc mã của kit để biết vì sao `PRODUCT-MAP.md` (có luật gộp riêng) không còn xung đột.
- Mẫu đối chứng nhỏ, PR đơn giản, một phiên làm.
- Cửa sổ 11 ngày; job `e2e-db` có từ 13/11, `quick` từ 18/11.

## 7. Đối chiếu với kế hoạch đã có

Phần lớn nguyên nhân đo được ở đây đã có gói việc trong mục 7 của bản thiết kế. Báo cáo này không
thêm gói nào cho chúng; nó cho số mới để xếp thứ tự.

| Điều đo được                                                              | Gói đã có | Trạng thái của gói                                  |
| ------------------------------------------------------------------------- | --------- | --------------------------------------------------- |
| `LO-TRINH.html` và `_acceptance/config.yaml` gây gần hết xung đột còn lại | DL1       | Kit có bước đầu từ 2.36.0, dạng tuỳ chọn; xem mục 9 |
| Gộp ngược và commit chữ ký làm bằng chứng cũ, kéo kiểm lại và một vòng CI | DL2       | Vài mảnh đã giao, dạng tuỳ chọn; xem mục 9          |
| Bộ nặng chạy ở Máy mỗi lượt chấm rồi chạy lại ở GitHub; `gate` đỏ khi chờ | DL3       | Chưa có trong kế hoạch của delivery-loop; xem mục 9 |
| `wiki/log.md` hết xung đột                                                | RS2       | Xong, số ở mục 3 xác nhận                           |
| Phút máy mỗi PR gộp giảm từ 548 xuống 337                                 | RS3       | Xong; mới 9 PR sau 0.9.0                            |
| Thước lặp lại được                                                        | RS10      | Xong; thiếu ba dòng ở mục 8                         |

Hai giả thuyết bị loại trong lúc truy nguyên: tầng nặng chạy nối tiếp sau chữ ký (chỉ 6 PR rời bản
nháp sau khi ký, trung vị 0,17 giờ), và bản nâng setup bị xếp hạng T3 (PR 93 và PR 94 đi từ Cổng 1
tới gộp trong 1,7 và 1,1 giờ).

## 8. Đề xuất, chỉ gồm việc chưa có trong kế hoạch

Mỗi việc chờ chủ kho cho phép ở kho của nó.

| Việc                                                                                                             | Kho                | Căn cứ                                          |
| ---------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------- |
| Đưa DL1 và DL2 lên đầu hàng của delivery-loop                                                                    | delivery-loop      | Mục 3: 60 lần gộp ngược sau chữ ký              |
| Đưa «hàng siết bộ kiểm lần hai» vào lộ trình; sửa thật bài `thue-phi` đang được che bằng một lần chạy lại        | `onehub-inventory` | Mục 9: hứa ở Cổng 2 ngày 16/11, chưa có hàng    |
| `tools/sdlc_metrics.py` in thêm: thời gian từng đoạn của hồ sơ, tỉ lệ bắt lỗi theo job, bài đỏ trên từ hai nhánh | Repo Standards     | Ba phép đo ở đây làm tay, chưa lặp lại được     |
| `tools/sdlc_metrics.py` đỏ khi một tệp chiếm phần lớn xung đột                                                   | Repo Standards     | Công cụ đã in `LO-TRINH.html: 129`, không gì đỏ |
| Bật luật gộp `tep-sinh` của kit cho `LO-TRINH.html`                                                              | `onehub-inventory` | Mục 9: kit có từ 2.36.0, kho chưa bật           |
| Ghi mốc «thẻ Cổng 2 đã trình» trong hồ sơ                                                                        | delivery-loop      | Mục 6: không tách được chờ người khỏi chuẩn bị  |
| Thước đo hồ sơ dùng một `lib.mjs` chung đã sạch cảnh báo CodeQL                                                  | delivery-loop      | Mục 4: cùng cảnh báo ở PR 94 và PR 95           |

Cho `tools/sdlc_metrics.py` đỏ là thêm một phép kiểm làm đỏ. Theo luật của kho này đó là đổi luật: chủ
kho quyết.

Không đề xuất cho ô `check` xanh khi PR còn nháp: «bỏ qua» được tính là đạt với ô bắt buộc, nên trong
vài giây sau khi PR rời bản nháp, auto-merge có thể gộp trước khi `e2e` chạy.

## 9. Đính chính và đối chiếu với kế hoạch của từng kho

Thêm cùng ngày, sau khi báo cáo đã gộp. Mục 7 chỉ đối chiếu với bản thiết kế ở kho này; mục này đọc
kế hoạch của chính từng kho: delivery-loop tại `8baa836`, design-assembly tại `3e1dbf1`,
`onehub-inventory` tại `f2a49b49`. Ba tác tử chỉ-đọc đọc ba kho đó. Máy tự kiểm lại các dòng có ghi
«đã kiểm»; các dòng còn lại là lời tác tử.

### Hai dòng sai ở mục 8 của bản đầu

- **`derived-untracked`.** Bản đầu đề xuất «cho kho khai thêm tệp sinh ra» và ghi rằng mục này chỉ soi
  tệp setup tự biết. Sai: `mk/derived.mk` đã cho mọi lớp khai `DERIVED_FILES += <đường dẫn>` từ RS2b
  (đã kiểm). Điều còn thiếu nằm ở phía kit và `onehub-inventory`, xem dưới.
- **«Sửa bốn bài đỏ chéo nhánh».** Số ở mục 5 đúng, nhưng các bài này đã thôi đỏ (đã kiểm trên log):

| Bài                     | Ngày đỏ     | Đã xử lý ở `onehub-inventory`                                   |
| ----------------------- | ----------- | --------------------------------------------------------------- |
| `lop-rieng.spec.ts`     | 14–15/11    | Sửa ngày 15/11 (PR 66)                                          |
| `dia-ly.spec.ts`        | 16/11       | Sửa ngày 16/11 (PR 80)                                          |
| `thue-phi.spec.ts`      | 16 và 18/11 | Từ 19/11 CI chạy lại một lần; bản sửa thật hoãn, không hàng nào |
| `round-metrics.test.ts` | 11–17/11    | Không có ghi chú; nằm trong `make test` theo thiết kế           |
| `frame.spec.ts`         | 11–12/11    | Không có ghi chú                                                |

### Đã có sẵn nhưng chưa bật ở `onehub-inventory` (đã kiểm)

- **Luật gộp của kit cho hai tệp sinh.** Kit 2.36.0 hướng dẫn khai `PRODUCT-MAP.md merge=tep-sinh` và
  `LO-TRINH.html merge=tep-sinh` trong `.gitattributes`, kèm `git config merge.tep-sinh.driver true`.
  `.gitattributes` của `onehub-inventory` chỉ có `PRODUCT-MAP.md merge=generated-file`. Khớp với số ở
  mục 3: `PRODUCT-MAP.md` hết xung đột, `LO-TRINH.html` thì không. Luật này chỉ có tác dụng khi gộp
  bằng git ở Máy.
- **Lối gộp nhanh.** Không tệp nào ở `onehub-inventory` nêu khoá `gop_khong_chay_lai_ci`. Đây là câu
  trả lời cho điều còn mở số 5 của bản thiết kế. Lối này chỉ mở khi PR không chung tệp với nhánh
  chính, nên cần luật gộp ở trên hoặc DL1 trước.
- **Thước đo chưa từng được ghi ra.** `onehub-inventory` không có `wiki/metrics/`.

### Kế hoạch của từng kho mang gì

| Gói ở bản thiết kế | Trong kế hoạch của kho phải làm                                                                                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DL1                | Bước đầu đã giao (2.36.0, 30/10). «Vẽ lại trên nhánh chính» là một ý đã đạt ngưỡng từ 26/10, chờ chủ kho gọi tên vòng; không thuộc 3.0. Tách `_acceptance/config.yaml`: không có |
| DL2                | Vài mảnh đã giao, đều tuỳ chọn (cũ theo `paths`, commit chữ ký không làm cũ, gộp không chạy lại CI). Dạng tổng quát gác lại 26/10. Issue 10 còn mở                               |
| DL3                | Không có. Một ý còn đi ngược hướng: thêm bộ chỉ chạy ở CI vào lượt chấm                                                                                                          |
| DL4                | Đã giao ở dạng «vùng» (24/10 và 28/10)                                                                                                                                           |
| DL5                | Không có                                                                                                                                                                         |
| DL6                | Issue 5, còn mở, chưa mở vòng                                                                                                                                                    |
| DA1, DA2, DA3      | Xong: giai đoạn 8 của `docs/plan/plan.json` ở design-assembly, đóng ngày 18/11 (đã kiểm). `onehub-inventory` nhận qua PR 84 và PR 86                                             |

delivery-loop không có hàng nào xếp sau bản 3.0; kho đó chỉ mở một vòng khi chủ kho gọi tên. Các mã DL
vì thế chỉ có ở bản thiết kế của kho này.

### Không có ở kế hoạch nào

- **delivery-loop:** mốc «thẻ Cổng 2 đã trình»; `gate` phân biệt chờ với hỏng; tên `gate` trùng với ô
  của repo-setup; thư viện chung cho thước đo hồ sơ; tách `_acceptance/config.yaml` theo hồ sơ.
- **Mối nối, hai bên đều biết, không bên nào nhận:** lưu cách gộp; hạng của bản nâng công cụ máy móc.
- **`onehub-inventory`:** «hàng siết bộ kiểm lần hai»; bản sửa thật cho `thue-phi.spec.ts`; PR tách sổ
  thứ hai (`wiki/index.md`, `ontology/glossary.md`) chưa có ngày; ba cảnh báo CodeQL mở trên nhánh
  chính, đều ở `rang/lib.mjs` của hồ sơ.
- **Kế hoạch nâng `onehub-inventory`** (các PR 6, 7, 8) chỉ nằm trong một tệp chưa commit ở Máy của kho
  này; hợp đồng bên đó trích nó (đã kiểm: tệp chưa được theo dõi).
- **design-assembly:** `design/behaviors.md` chưa tách mảnh; phép đo lại sau 30 PR chưa chạy;
  `onehub-inventory` ở bản 0.7.1 trong khi plugin là 0.21.0 (đã kiểm), không việc nào kéo lên; giới
  hạn «`affected` chưa có bên gọi» đã cũ, vì repo-setup 0.9.0 đã gọi nó.
- **Repo Standards:** ba phép đo ở mục 8 và ngưỡng đỏ; RS5a hết bị chặn vì DA3 đã nêu đường dẫn.

Một số đo trả lời giới hạn ở mục 6: bước `khong-phien` của job `e2e-db` chạy lại đúng 540 bài của
`tools/e2e_templates/suite.ts` mà job `e2e` đã chạy, khoảng 7 phút mỗi lượt. Việc này cố ý, để lấy số
đếm bàn giao.
