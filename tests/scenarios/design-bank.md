# Phép đo tác dụng của tầng thiết kế

Phép đo này được khoá trước khi dựng tầng thiết kế. Mô tả màn, hai nền, bảng trạng thái cần có, cách đếm và ngưỡng đạt dưới đây không được sửa sau khi đã thấy kết quả. Muốn đổi thì ghi rõ lý do và ngày ở mục "Nhật ký thay đổi" cuối tệp, không viết đè.

Phép đo chạy với Claude Code thật và tốn tiền API, nên không nằm trong CI. Chỉ chạy khi chủ repo đồng ý. Rào đỏ chỉ chứng minh rào hoạt động, còn phép đo này hỏi câu khác: tác tử dựng giao diện có làm tốt hơn khi có tầng thiết kế hay không.

## 1. Bốn màn cố định

Cả bốn màn thuộc cùng một ứng dụng quản lý đơn hàng giả định. Tên màn (kể cả "luồng xác nhận xoá") chỉ dùng trong giao thức này. Tác tử dựng chỉ nhận đúng mô tả bên dưới, chép nguyên văn, không thêm gì khác.

### Màn 1. Danh sách có lọc

Ứng dụng quản lý đơn hàng cần một trang liệt kê các đơn hàng của cửa hàng. Mỗi dòng cho thấy mã đơn, tên khách, ngày đặt, tổng tiền và tình trạng giao. Người dùng thu hẹp danh sách bằng ô tìm theo tên khách và bộ lọc theo tình trạng giao. Bấm vào một dòng thì mở đơn hàng đó.

### Màn 2. Biểu mẫu tạo mới

Ứng dụng quản lý đơn hàng cần một trang để nhập đơn hàng mới. Người dùng điền tên khách, số điện thoại, địa chỉ giao, sản phẩm, số lượng và ghi chú. Đơn mới sẽ có mặt trong danh sách đơn hàng.

### Màn 3. Trang chi tiết

Ứng dụng quản lý đơn hàng cần một trang xem đầy đủ một đơn hàng. Trang cho thấy thông tin khách, địa chỉ giao, các sản phẩm kèm số lượng và giá, tổng tiền và tình trạng giao. Từ trang này người dùng có thể quay lại danh sách hoặc chuyển sang sửa đơn.

### Màn 4. Luồng xác nhận xoá

Ứng dụng quản lý đơn hàng cần cho người dùng xoá một đơn hàng từ trang chi tiết của đơn đó. Sau khi xoá, đơn không còn trong danh sách đơn hàng. Người dùng được đưa về danh sách.

## 2. Hai nền

**Nền thử.** Repo sinh bằng:

```
--preset react-vite --level starter --with design
```

Nền thử mang các dấu mốc cố định để cắt máy móc: trong `AGENTS.md` là mục bắt đầu từ tiêu đề `## Design floor` đến tiêu đề `## ` kế tiếp; trong `eslint.config.js` là mọi thứ giữa hai dòng chú thích `// design-floor:start` và `// design-floor:end`, cộng dòng import `@shadcn/lint`.

**Nền đối chứng.** Đúng nền thử, rồi cắt các thứ sau, không làm gì thêm trừ trường hợp ghi ở cuối mục:

- xoá `.claude/rules/ui.md`
- xoá `.claude/skills/ui/`
- xoá `design/`
- xoá `tools/design_guards.mjs`
- xoá `mk/design.mk` (an toàn vì `Makefile` dùng `-include mk/*.mk`)
- xoá `tests/e2e/`
- xoá `src/example/`
- xoá `src/screens.ts`
- xoá khỏi `AGENTS.md` mục từ `## Design floor` đến tiêu đề `## ` kế tiếp
- xoá khỏi `eslint.config.js` mọi thứ giữa `// design-floor:start` và `// design-floor:end`, và dòng import `@shadcn/lint`
- đổi `src/App.tsx` về trang một tiêu đề

Phần phụ thuộc trong `package.json` giữ nguyên. Nền đối chứng vẫn còn shadcn và các linh kiện cài sẵn, chỉ mất tầng thiết kế.

Kiểm tra nền đối chứng: `npm run build` phải qua. Nếu hỏng, chỉ gỡ đúng chỗ tham chiếu treo gây lỗi, ghi lại việc đó vào phần kết quả, rồi chạy tiếp. Đây là ngoại lệ duy nhất cho "không làm gì thêm".

## 3. Cách chạy

- Mỗi màn dựng ba lần bằng tác tử mới trên mỗi nền: 4 màn x 3 lần x 2 nền = 24 lần chạy.
- Mỗi lần chạy: một bản sao sạch mới của nền, rồi chạy `claude -p "<mô tả màn, nguyên văn>" --model claude-opus-5-5 --output-format json` trong bản sao đó. Không mang ngữ cảnh từ lần trước, không ai chỉnh tay giữa chừng.
- Ghi phiên bản Claude Code một lần ở đầu phần kết quả.
- Lời nhắc chỉ gồm mô tả màn ở mục 1. Không nhắc tới trạng thái, linh kiện hay tệp thiết kế nào.
- Chạy ứng dụng cho tác tử chấm: `npm run build && npx vite preview --host 127.0.0.1 --port 4173`.
- Số trạng thái thiếu do một tác tử chấm khác, chạy trên bản đang chạy, không phải tác tử đã dựng.

## 4. Bảng trạng thái cần có

Dùng sáu tên của `design/behaviors.md`: loading, empty, error, no results, saving, confirm delete. Mỗi màn cần các trạng thái sau, đúng như bảng, cho cả hai nền (kể cả nền đối chứng đã mất tệp `design/behaviors.md`):

| Màn | Trạng thái cần có | Số |
|---|---|---|
| Danh sách có lọc | loading, empty, error, no results | 4 |
| Biểu mẫu tạo mới | error, saving | 2 |
| Trang chi tiết | loading, error | 2 |
| Luồng xác nhận xoá | confirm delete, saving, error | 3 |

Tổng 11 cơ hội cho một bộ bốn màn. Một trạng thái được tính là có khi mã dựng ra giao diện nhìn thấy riêng cho trạng thái đó và nhánh ấy đạt tới được. Tác tử chấm đánh dấu có hoặc không cho từng trạng thái và viết một dòng bằng chứng. Token của tác tử chấm không tính.

## 5. Bảng đếm

Một hàng cho mỗi lần chạy, 24 hàng.

| Màn | Nền | Lần | Trạng thái thiếu (trên bảng mục 4) | Lỗi rào còn lại | Số vòng sửa | Token |
|---|---|---|---|---|---|---|
| 1 | thử | 1 | 0 | 0 | 0 | 3.352.854 |
| 1 | thử | 2 | 0 | 0 | 1 | 1.918.949 |
| 1 | thử | 3 | 0 | 0 | 0 | 2.805.194 |
| 1 | đối chứng | 1 | 0 | 7 | 0 | 1.928.353 |
| 1 | đối chứng | 2 | 0 | 9 | 0 | 1.748.265 |
| 1 | đối chứng | 3 | 0 | 6 | 1 | 1.380.240 |
| 2 | thử | 1 | 0 | 0 | 2 | 2.877.232 |
| 2 | thử | 2 | 0 | 0 | 0 | 2.559.373 |
| 2 | thử | 3 | 0 | 0 | 0 | 2.338.688 |
| 2 | đối chứng | 1 | 0 | 6 | 0 | 1.606.906 |
| 2 | đối chứng | 2 | 1 | 8 | 0 | 2.069.228 |
| 2 | đối chứng | 3 | 1 | 5 | 0 | 1.483.869 |
| 3 | thử | 1 | 0 | 0 | 0 | 2.780.369 |
| 3 | thử | 2 | 2 | 0 | 0 | 508.240 |
| 3 | thử | 3 | 2 | 0 | 0 | 587.530 |
| 3 | đối chứng | 1 | 2 | 0 | 0 | 714.264 |
| 3 | đối chứng | 2 | 0 | 9 | 1 | 1.970.798 |
| 3 | đối chứng | 3 | 0 | 7 | 1 | 2.500.029 |
| 4 | thử | 1 | 0 | 0 | 0 | 1.897.239 |
| 4 | thử | 2 | 0 | 0 | 1 | 2.777.575 |
| 4 | thử | 3 | 3 | 0 | 0 | 794.381 |
| 4 | đối chứng | 1 | 0 | 1 | 0 | 2.250.291 |
| 4 | đối chứng | 2 | 2 | 4 | 0 | 864.619 |
| 4 | đối chứng | 3 | 2 | 4 | 0 | 1.225.262 |

Cách đếm từng cột:

- **Trạng thái thiếu:** theo mục 4, số trạng thái cần có mà tác tử chấm đánh dấu không.
- **Lỗi rào còn lại:** sau khi tác tử dựng báo xong, trong bản sao đang đo (cả hai nền), sao `eslint.config.js` của nền thử thành `.eslint.measure.config.js` ở thư mục gốc bản sao, chạy `npx eslint -c .eslint.measure.config.js src --format json`, rồi xoá tệp đó. Đếm các thông báo có rule là `shadcn/*` hoặc `no-restricted-syntax`, bỏ `src/components/ui`. Kiểm tra trên trình duyệt không tính. Tệp chỉ xuất hiện sau khi tác tử dựng đã xong, nên tác tử dựng trên nền đối chứng không bao giờ thấy cấu hình này.
- **Số vòng sửa:** số lệnh `make check`, `npm run lint`, `npx eslint` hoặc `npx tsc` trong bản ghi mà kết thúc với mã khác 0.
- **Token:** chỉ token của tác tử dựng, lấy từ đầu ra JSON của `claude -p`.

## 6. Đọc nhật ký

Với mỗi màn, đọc nhật ký ít nhất một lần chạy nền thử và một lần chạy nền đối chứng, tổng cộng ít nhất tám lần đọc, do người chạy phép đo đọc. Ghi lại những cải thiện hay hỏng hóc mà không chỉ số nào bắt được, vì giá trị thật có thể nằm ở đó.

## 7. Ngưỡng đạt

Chép nguyên từ spec mục 10:

| Chỉ số | Ngưỡng |
|---|---|
| Số trạng thái thiếu | giảm ít nhất một nửa so với nền đối chứng |
| Lỗi còn lại khi tác tử báo xong | bằng 0 |
| Token | tăng không quá 30% |

Cách gộp: mọi số là tổng trên 12 lần chạy của mỗi nền, tính chung, không tính theo từng màn. Đạt khi đủ cả ba:

1. Trạng thái thiếu của nền thử <= trạng thái thiếu của nền đối chứng / 2.
2. Tổng lỗi rào còn lại trên 12 lần chạy nền thử = 0.
3. Token nền thử <= 1,30 x token nền đối chứng, chỉ tính token tác tử dựng.

Nếu trạng thái thiếu của nền đối chứng bằng 0 thì phép đo không nói được gì về tác dụng: ghi lại điều đó và dừng, chờ chủ repo.

Không đạt thì sửa thiết kế trước khi phát hành. Không sửa ngưỡng để cho đạt.

## Kết quả

Phiên bản Claude Code: 2.1.281. Tác tử dựng: claude-opus-5-5. Lượt chạy hợp lệ là lượt thứ hai (lượt thứ nhất bị huỷ, xem nhật ký thay đổi).

Việc gỡ tham chiếu treo trên nền đối chứng: xoá `tests/App.test.tsx` vì tệp này nhập `src/example/` và `tests/e2e/routes.ts` đã bị cắt; sau đó `npm run build` qua.

| Ngày | Người chạy | Trạng thái thiếu (thử / đối chứng) | Lỗi còn lại (thử) | Token (thử / đối chứng) | Đạt | Ghi chú |
|---|---|---|---|---|---|---|
| 2026-11-11 | Claude (phiên dựng tầng thiết kế), chủ repo cho phép chạy | 7 / 8 | 0 | 25.197.624 / 19.742.124 (x1,28) | Không | Ngưỡng 1 trượt (cần <= 4). Ngưỡng 2 và 3 đạt. Tổng chi phí 34,86 USD gồm 1,79 USD chạy thử |
| 2026-11-11 | Claude (phiên dựng tầng thiết kế). chủ repo cho phép chạy | 0 / 6 | 0 | 24.796.847 / 20.004.042 (x1.24) | Có. theo luật khoá | Lần đo hai. Đọc chặt (trạng thái phải do điều kiện thật dẫn tới): 15 / 6. nền thử kém hơn. Xem mục Lần đo hai |
| 2026-11-11 | Claude (phiên dựng tầng thiết kế), chủ repo cho phép chạy | 0 / 18 | 0 | 35.445.848 / 24.824.052 (x1,43) | Không | Lần đo ba, luật chấm chặt khoá trước. Ngưỡng 1 và 2 đạt, ngưỡng 3 trượt. Chi phí 41,81 USD gồm 1,57 USD chạy thử. Xem mục Lần đo ba |
| 2026-11-11 | Claude (phiên dựng tầng thiết kế), chủ repo cho phép chạy | 0 / 14 | 0 | 21.766.485 / 24.743.621 (x0,88) | Có | Lần đo bốn, luật chấm chặt, sau khi cắt chi phí đọc. Đạt cả ba ngưỡng. Chi phí 35,15 USD gồm 1,59 USD chạy thử. Xem mục Lần đo bốn |

### Đọc kết quả

- **Bốn lần chạy không ghi được tệp nào** (thử màn 3 lần 2 và 3, thử màn 4 lần 3, đối chứng màn 3 lần 1). Tác tử dựng gõ sai đường dẫn tuyệt đối của thư mục đo (gạch ngang thay cho gạch chéo), nên mọi lần ghi nằm ngoài thư mục làm việc và bị từ chối. Đây là lỗi môi trường đo, không do tầng thiết kế. Cả 7 trạng thái thiếu của nền thử nằm ở ba lần chạy này.
- **Chỉ tính các lần chạy dựng được:** nền thử thiếu 0 trạng thái trên 9 lần, nền đối chứng thiếu 6 trên 11 lần. Nhưng token mỗi lần là 2,59 triệu so với 1,73 triệu (x1,50), vượt ngưỡng 30%. Vì vậy chạy lại bốn lần hỏng cũng không đổi được kết luận: không đạt.
- **Người chấm:** bốn tác tử chấm, mỗi màn một tác tử, bản dựng đổi nhãn A-F để giấu nền (không giấu trọn: tệp thiết kế vẫn nằm trong repo). Mỗi tác tử dùng một cổng riêng 4174-4177 thay cho 4173 để chạy song song. Trạng thái mở được bằng `?state=` được tính là có, đúng luật mục 4; đọc chặt hơn (phải do dữ liệu thật dẫn tới) thì hai bản nền thử ở màn 1 thiếu thêm 3 trạng thái mỗi bản.
- **Nền đối chứng không sạch hoàn toàn:** một tác tử đối chứng đọc lại màn mẫu đã cắt qua lịch sử git của nền. Lần đo sau nên dựng nền đối chứng thành một commit không có lịch sử.

### Đọc nhật ký (mục 6)

Đọc tám nhật ký, mỗi màn một lần thử và một lần đối chứng.

- **Tầng thiết kế làm được:** bài kiểm trình duyệt bắt lỗi tương phản của nhãn huỷ (màn 1) và bảng tràn ngang ở khổ 390 px (màn 3). Tác tử nền thử dựng đủ trạng thái đang lưu và lỗi ở màn 2 và 4. Cả bốn tác tử đối chứng đều nói chưa từng xem trang.
- **Hỏng mà không chỉ số nào bắt:** ở màn 1, để qua kiểm tương phản, tác tử đổi trạng thái "đã trả" sang cùng kiểu nhãn với "đang chờ", làm mất phân biệt.
- **Đối chứng làm tốt hơn ở vài chỗ nhỏ:** giữ bộ lọc khi quay lại (màn 1), có thông báo đã lưu (màn 2), ít lượt hơn.
- **Token thêm của nền thử đến từ:** vòng sửa do rào và bài kiểm trình duyệt (4-7 lần `make check` so với 2-3), đọc tầng thiết kế trước khi sửa, và nối mỗi màn vào `App.tsx`, `routes.ts` và test đơn vị.
- **Hai lỗi nằm sẵn trong bộ linh kiện của capability** làm mọi tác tử vấp: nhãn huỷ không đủ tương phản, và vùng cuộn của bảng không nhận được tiêu điểm bàn phím.

Theo mục 7: không đạt, phải sửa thiết kế trước khi phát hành. Không sửa ngưỡng.

### Lần đo hai (2026-11-11)

Sau khi sửa tầng thiết kế để giảm chi phí. Cách dựng nền ghi ở nhật ký thay đổi. Cả 24 lần chạy đều ghi được tệp và build được. Chi phí 35,04 USD gồm 1,60 USD chạy thử. Cột "đọc chặt" tính thêm là thiếu những trạng thái chỉ mở được bằng công tắc trạng thái (`?state=` hay mục trong `src/screens.ts`) mà không điều kiện thật nào trong ứng dụng dẫn tới; cột này không thuộc luật đã khoá và không dùng để xét đạt.

| Màn | Nền | Lần | Trạng thái thiếu (luật khoá) | Thiếu (đọc chặt) | Lỗi rào còn lại | Số vòng sửa | Token |
|---|---|---|---|---|---|---|---|
| 1 | thử | 1 | 0 | 3 | 0 | 0 | 1.893.633 |
| 1 | thử | 2 | 0 | 3 | 0 | 0 | 1.398.807 |
| 1 | thử | 3 | 0 | 3 | 0 | 0 | 1.980.935 |
| 1 | đối chứng | 1 | 0 | 0 | 8 | 0 | 1.926.498 |
| 1 | đối chứng | 2 | 0 | 0 | 8 | 0 | 1.508.871 |
| 1 | đối chứng | 3 | 0 | 0 | 7 | 0 | 2.316.970 |
| 2 | thử | 1 | 0 | 0 | 0 | 0 | 2.056.338 |
| 2 | thử | 2 | 0 | 0 | 0 | 0 | 1.936.495 |
| 2 | thử | 3 | 0 | 0 | 0 | 0 | 2.692.934 |
| 2 | đối chứng | 1 | 0 | 0 | 7 | 0 | 2.354.651 |
| 2 | đối chứng | 2 | 1 | 1 | 5 | 0 | 1.833.717 |
| 2 | đối chứng | 3 | 1 | 1 | 9 | 0 | 1.862.513 |
| 3 | thử | 1 | 0 | 2 | 0 | 0 | 2.154.447 |
| 3 | thử | 2 | 0 | 2 | 0 | 0 | 2.783.502 |
| 3 | thử | 3 | 0 | 2 | 0 | 0 | 2.547.848 |
| 3 | đối chứng | 1 | 0 | 0 | 7 | 0 | 1.609.809 |
| 3 | đối chứng | 2 | 0 | 0 | 8 | 1 | 1.321.939 |
| 3 | đối chứng | 3 | 2 | 2 | 6 | 0 | 1.104.135 |
| 4 | thử | 1 | 0 | 0 | 0 | 0 | 1.545.144 |
| 4 | thử | 2 | 0 | 0 | 0 | 0 | 1.855.532 |
| 4 | thử | 3 | 0 | 0 | 0 | 0 | 1.951.232 |
| 4 | đối chứng | 1 | 0 | 0 | 3 | 0 | 1.183.331 |
| 4 | đối chứng | 2 | 2 | 2 | 2 | 0 | 1.156.706 |
| 4 | đối chứng | 3 | 0 | 0 | 4 | 0 | 1.824.902 |

Tổng: trạng thái thiếu 0 / 6 theo luật khoá. 15 / 6 khi đọc chặt; lỗi rào còn lại 0 / 74; token 24.796.847 / 20.004.042 (x1.24).

**Theo luật đã khoá: đạt cả ba ngưỡng.** Khi đọc chặt thì ngược lại: nền thử thiếu nhiều hơn nền đối chứng. Lý do đọc được trong mã: màn mẫu lấy trạng thái từ công tắc trên đường dẫn. và danh sách màn chung khiến việc thêm một trạng thái chỉ là thêm một mục; tác tử nền thử chép đúng cách đó. nên trạng thái đang tải và lỗi có giao diện nhưng dữ liệu mẫu nạp tức thì và không bao giờ lỗi. Tác tử đối chứng. không có màn mẫu. thường viết một hàm nạp dữ liệu bất đồng bộ có thể trả rỗng hay báo lỗi. Ghi lại để chủ repo quyết định. không đổi luật đã khoá.

### Lần đo ba (2026-11-11)

Sau khi sửa màn mẫu để trạng thái đến từ nguồn dữ liệu (độ trễ thật, lỗi khi mất mạng, thêm và xoá thật trong bộ nhớ; móc kiểm thử `?scenario=` nằm riêng trong nguồn dữ liệu). Luật chấm chặt đã khoá trước khi chạy (nhật ký thay đổi). Bản sao để đo nằm ở `/private/tmp/dm3`, nền dựng như lần hai. Cả 24 lần chạy đều ghi được tệp, thoát không lỗi và build được sau `make gen`. Bốn tác tử chấm, mỗi màn một tác tử, bản dựng đổi nhãn A-F, cổng 4174-4177 như lần hai.

| Màn | Nền | Lần | Trạng thái thiếu (luật chặt) | Lỗi rào còn lại | Số vòng sửa | Token | Chi phí (USD) |
|---|---|---|---|---|---|---|---|
| 1 | thử | 1 | 0 | 0 | 0 | 2.761.210 | 1,81 |
| 1 | thử | 2 | 0 | 0 | 0 | 5.497.710 | 2,95 |
| 1 | thử | 3 | 0 | 0 | 0 | 2.069.312 | 1,64 |
| 1 | đối chứng | 1 | 1 | 8 | 0 | 2.745.786 | 1,70 |
| 1 | đối chứng | 2 | 1 | 9 | 0 | 3.768.344 | 2,07 |
| 1 | đối chứng | 3 | 1 | 6 | 0 | 2.755.605 | 1,81 |
| 2 | thử | 1 | 0 | 0 | 3 | 2.886.327 | 1,83 |
| 2 | thử | 2 | 0 | 0 | 0 | 2.866.458 | 1,79 |
| 2 | thử | 3 | 0 | 0 | 0 | 1.742.208 | 1,38 |
| 2 | đối chứng | 1 | 2 | 8 | 0 | 1.577.438 | 1,33 |
| 2 | đối chứng | 2 | 1 | 4 | 0 | 1.320.946 | 1,20 |
| 2 | đối chứng | 3 | 1 | 6 | 0 | 2.467.544 | 1,64 |
| 3 | thử | 1 | 0 | 0 | 0 | 2.683.086 | 1,82 |
| 3 | thử | 2 | 0 | 0 | 0 | 3.988.421 | 2,21 |
| 3 | thử | 3 | 0 | 0 | 0 | 3.118.044 | 1,96 |
| 3 | đối chứng | 1 | 2 | 8 | 0 | 1.657.331 | 1,37 |
| 3 | đối chứng | 2 | 1 | 15 | 1 | 2.337.330 | 1,55 |
| 3 | đối chứng | 3 | 2 | 6 | 0 | 1.800.452 | 1,29 |
| 4 | thử | 1 | 0 | 0 | 0 | 2.584.143 | 1,83 |
| 4 | thử | 2 | 0 | 0 | 0 | 2.441.708 | 1,76 |
| 4 | thử | 3 | 0 | 0 | 0 | 2.807.221 | 1,80 |
| 4 | đối chứng | 1 | 2 | 1 | 0 | 1.049.703 | 1,02 |
| 4 | đối chứng | 2 | 2 | 1 | 0 | 1.425.134 | 1,12 |
| 4 | đối chứng | 3 | 2 | 4 | 0 | 1.918.439 | 1,36 |

Tổng: trạng thái thiếu 0 / 18; lỗi rào còn lại 0 / 76; token 35.445.848 / 24.824.052 (x1,43); chi phí 22,77 / 17,47 USD (x1,30); số lượt 679 / 593 (x1,15).

**Theo mục 7: không đạt.** Ngưỡng 1 (0 <= 9) và ngưỡng 2 (0) đạt; ngưỡng 3 trượt (x1,43, cần <= x1,30). Không sửa ngưỡng.

- **Chất lượng:** sửa màn mẫu đã đảo kết quả đọc chặt của lần hai (15 / 6) thành 0 / 18. Nền đối chứng thiếu chủ yếu trạng thái đang tải (dữ liệu mẫu nạp tức thì nên khung chờ không kịp hiện), trạng thái đang lưu, và trạng thái lỗi khi nguồn dữ liệu không bao giờ thất bại.
- **Phán đoán của người chấm:** màn 1, trạng thái rỗng và lỗi được tính là có khi màn quyết định từ kết quả yêu cầu, kể cả khi dữ liệu mẫu không tự gây ra. Đọc khắt hơn nữa (dữ liệu mẫu phải tự gây ra) thì tổng là 3 / 24, vẫn đạt ngưỡng 1. Màn 2, một bản đối chứng chỉ có thông báo nhập sai, không có thông báo lưu thất bại, nên bị tính thiếu lỗi; tính nhẹ thì đối chứng còn 17. Màn 3, một bản đối chứng được tính có lỗi dù dữ liệu mẫu không bao giờ gây ra. Không phán đoán nào đổi được kết luận.
- **Token:** nền thử chỉ nhiều hơn 15% số lượt nhưng mỗi lượt mang ngữ cảnh lớn hơn, nên token tăng 43%. Chi phí tiền chỉ tăng 30% vì phần lớn token là đọc lại bộ nhớ đệm.
- **Bản dựng sửa ngoài màn:** một bản nền thử ở màn 3 chuyển hai hàm hỗ trợ kiểm thử ra khỏi nguồn dữ liệu của màn mẫu sang tệp dùng chung; hành vi không đổi.

Đọc nhật ký (mục 6), tám lần chạy, mỗi màn một lần thử và một lần đối chứng, đối chiếu tổng token với số báo cáo (lệch dưới 1%):

- **Token thêm của nền thử (10,5 triệu) đến từ:** khoảng một phần ba là tệp tầng thiết kế đọc lúc đầu rồi mang theo mọi lượt: test ứng dụng `tests/App.test.tsx` (29% phần này), màn mẫu (27%), trang luật (15%), nguồn dữ liệu (9%), danh sách màn (7%). Khoảng một phần ba là 72 lượt thêm, mỗi lượt đọc lại phần đầu chung 47,8 nghìn token. Khoảng một phần tư là chữ viết ra và suy nghĩ dài hơn. Ảnh chụp màn hình, chữ in của `make check` và lỗi bài trình duyệt gần như không đáng kể.
- **Danh sách màn chưa làm đúng lời hứa:** trang luật nói đăng ký màn vào `src/screens.ts` là "không còn gì để nối", nhưng 9 trên 12 bản nền thử vẫn sửa `tests/App.test.tsx`, và có sáu kiểu ghi đường dẫn màn khác nhau giữa các bản. Đây là chỗ cắt token lớn nhất (ước 1,5-2 triệu).
- **Rào bảng mâu thuẫn trang luật:** rào bắt ô bảng ở 4 trên 12 bản và lời báo lỗi trái với trang luật, gây vòng sửa (ước 0,8-1 triệu).
- **Hỏng mà không chỉ số nào bắt:** mọi bản nền thử giữ nguyên màn mẫu (9 trên 12 bản để nó ở trang chủ) và móc kiểm thử `?scenario=` trong mã chạy thật.
- **Làm được mà nền đối chứng không có:** các trạng thái hiện thật trên ứng dụng đang chạy và được kiểm ở khổ 390 px cùng kiểm truy cập; không bản đối chứng nào làm vậy.

### Lần đo bốn (2026-11-11)

Sau khi cắt chi phí đọc của tầng thiết kế (nhật ký thay đổi, dòng lần bốn). Bản sao để đo nằm ở `/private/tmp/dm4`. Cả 24 lần chạy đều ghi được tệp, thoát không lỗi và build được sau `make gen`; mọi lần nền thử kết thúc với `make check` qua. Bốn tác tử chấm, mỗi màn một tác tử, bản dựng đổi nhãn A-F, chấm trên bản `npm run build` thường, cổng 4174-4177.

| Màn | Nền | Lần | Trạng thái thiếu (luật chặt) | Lỗi rào còn lại | Số vòng sửa | Token | Chi phí (USD) |
|---|---|---|---|---|---|---|---|
| 1 | thử | 1 | 0 | 0 | 0 | 2.375.091 | 1,59 |
| 1 | thử | 2 | 0 | 0 | 0 | 1.741.512 | 1,35 |
| 1 | thử | 3 | 0 | 0 | 0 | 1.957.860 | 1,49 |
| 1 | đối chứng | 1 | 0 | 17 | 0 | 3.060.115 | 2,01 |
| 1 | đối chứng | 2 | 0 | 7 | 0 | 3.534.423 | 2,08 |
| 1 | đối chứng | 3 | 0 | 7 | 0 | 2.086.592 | 1,46 |
| 2 | thử | 1 | 0 | 0 | 0 | 1.493.961 | 1,23 |
| 2 | thử | 2 | 0 | 0 | 0 | 1.838.944 | 1,39 |
| 2 | thử | 3 | 0 | 0 | 0 | 2.173.024 | 1,50 |
| 2 | đối chứng | 1 | 2 | 3 | 0 | 1.716.543 | 1,29 |
| 2 | đối chứng | 2 | 2 | 8 | 0 | 1.281.614 | 1,14 |
| 2 | đối chứng | 3 | 1 | 9 | 0 | 1.844.756 | 1,33 |
| 3 | thử | 1 | 0 | 0 | 0 | 1.775.636 | 1,32 |
| 3 | thử | 2 | 0 | 0 | 0 | 2.004.132 | 1,41 |
| 3 | thử | 3 | 0 | 0 | 0 | 1.749.378 | 1,26 |
| 3 | đối chứng | 1 | 1 | 6 | 0 | 1.664.017 | 1,21 |
| 3 | đối chứng | 2 | 1 | 9 | 0 | 1.791.594 | 1,40 |
| 3 | đối chứng | 3 | 1 | 8 | 0 | 2.313.286 | 1,45 |
| 4 | thử | 1 | 0 | 0 | 0 | 1.461.597 | 1,25 |
| 4 | thử | 2 | 0 | 0 | 0 | 1.531.413 | 1,19 |
| 4 | thử | 3 | 0 | 0 | 0 | 1.663.937 | 1,28 |
| 4 | đối chứng | 1 | 2 | 2 | 0 | 2.037.390 | 1,35 |
| 4 | đối chứng | 2 | 2 | 5 | 0 | 1.467.127 | 1,18 |
| 4 | đối chứng | 3 | 2 | 3 | 0 | 1.946.164 | 1,38 |

Tổng: trạng thái thiếu 0 / 14; lỗi rào còn lại 0 / 84; token 21.766.485 / 24.743.621 (x0,88); chi phí 16,28 / 17,28 USD.

**Theo mục 7: đạt cả ba ngưỡng.** Ngưỡng 1: 0 <= 7. Ngưỡng 2: 0. Ngưỡng 3: x0,88 <= x1,30.

- **Phán đoán của người chấm:** người chấm màn 1 và màn 3 lần này tính trạng thái đang tải là có khi dữ liệu mẫu không có độ trễ mà khung chờ vẫn hiện được một khung hình; người chấm lần ba tính là thiếu. Đọc theo cách lần ba thì đối chứng thiếu thêm 5 (19), nền thử không đổi. Đọc khắt hơn nữa (dữ liệu mẫu phải tự gây ra trạng thái rỗng và lỗi) thì nền thử thiếu 3, đối chứng ít nhất 23. Không cách đọc nào đổi kết luận.
- **Token giảm là việc thật bớt đi, không phải bỏ việc:** ngữ cảnh mỗi lượt hai nền ngang nhau (77,7 so với 79,0 nghìn token); nền thử ít lượt hơn (277 so với 310). Nền đối chứng tốn thêm ở lệnh bị từ chối, đào `node_modules`, mở trình duyệt (8 trên 12 lần; nền thử không lần nào) và các vòng `make check`. Lượng mã hai nền như nhau. Tệp tầng thiết kế mang theo giảm từ 3,5 triệu xuống khoảng 1,4 triệu token.
- **Những gì lần cắt đã sửa:** không bản nào sửa tệp thuộc plugin; rào ô bảng không còn bắt lần nào (lần ba 4 trên 12); danh sách màn chỉ còn một cách ghi đường dẫn (lần ba sáu cách); móc kiểm thử không còn trong bản build thường.
- **Biến động lớn theo màn:** màn 1 x0,70, màn 4 x0,85, màn 3 x0,96, màn 2 x1,14, mỗi ô chỉ 3 lần chạy. Ngưỡng tính trên tổng nên vẫn đạt, nhưng không nên đọc x0,88 là nền thử luôn rẻ hơn.

Đọc nhật ký (mục 6), tám lần chạy và tổng 24 lần:

- **Nền thử viết ít test đơn vị hơn** (74 so với 127) và ít trang quyết định trong wiki hơn (1 so với 5); ở màn 3 và 4 thiếu vài thực thể và vai trò trong ontology. Nút thử lại và xoá tìm kiếm ở màn 1 có trên màn nhưng không test nào bấm. Mọi trạng thái vẫn được bài kiểm trình duyệt ghé ở hai khổ.
- **Màn mẫu vẫn đi theo bản phát hành:** `/example` có trong mọi bản build và được liệt kê trên trang không tìm thấy (màn 3 không có trang ở `/`).
- **Điều hướng phía khách tự chế ở màn 4:** cả ba bản viết lại `src/App.tsx` với một `navigate` riêng, mỗi bản một kiểu.
- **Một bản nền thử ở màn 1 sửa nguồn dữ liệu của màn mẫu** để dời hàm móc kiểm thử sang tệp dùng chung, như lần ba.

## Nhật ký thay đổi

| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-10 | Viết lần đầu | Khoá phép đo trước khi dựng |
| 2026-11-10 | Siết giao thức: bỏ gợi ý trạng thái khỏi mô tả màn, khoá bảng trạng thái cần có, cách gộp, dấu mốc cắt nền đối chứng, lệnh chạy rào và điều kiện chạy | Sau rà soát, giao thức chưa tái lập được; sửa trước khi chạy lần nào |
| 2026-11-11 | Lệnh dựng thêm --permission-mode acceptEdits --allowedTools "Bash(npm:*)" "Bash(npx:*)", như nhau trên hai nền | Repo sinh ra chỉ cho chạy make và đọc git; ở chế độ -p tác tử dựng không ghi được tệp nào, phép đo sẽ vô nghĩa |
| 2026-11-11 | Lượt chạy thứ nhất (24 lần, chưa chấm) bị huỷ. Lệnh dựng thay bằng --permission-mode acceptEdits --allowedTools "Bash(make:*)" "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(python3 tools/:*)" "Bash(npm:*)" "Bash(npx:*)", như nhau trên hai nền. Lần chạy nền thử chạy lần lượt từng lần một | Bản sao để đo là thư mục chưa được tin cậy nên Claude Code bỏ qua quyền trong .claude/settings.json; lệnh cũ chỉ cho npm và npx, cả 24 lần đều bị từ chối make, nền thử chưa từng chạy được make check và 12/24 bản không build được vì không chạy được make gen. Lệnh mới cho đúng các quyền repo vốn cho. make check của nền thử mở cổng 4173 cho bài trình duyệt nên hai lần nền thử không được chạy cùng lúc |
| 2026-11-11 | Nền đối chứng xoá thêm `src/screens.ts` | Sau phép đo, danh sách màn chung `src/screens.ts` thay cho việc nối từng màn vào `App.tsx`, `routes.ts` và test đơn vị; tệp này nhập `src/example/`, nên để lại thì nền đối chứng không build được |
| 2026-11-11 | Bước xoá `.claude/skills/ui/` không còn việc gì để làm | Skill `ui` đã gộp vào `.claude/rules/ui.md` (vẫn bị xoá ở nền đối chứng), để tác tử dựng chỉ đọc một trang |
| 2026-11-11 | Đo lần hai sau khi sửa tầng thiết kế để giảm chi phí (danh sách màn chung, sửa hai linh kiện, bước kiểm in ít chữ, gộp tài liệu). Bản sao để đo nằm ở `/private/tmp/dm`. Nền đối chứng cắt thêm `src/screens.ts`, `tests/App.test.tsx`, `tools/patch_ui.mjs` và cài lại `table` gốc bằng `npx shadcn@4.23.0 add table -y --overwrite` rồi `make format`; sau khi cắt, nền đối chứng được dựng lại thành một commit duy nhất không có lịch sử. Lệnh dựng, bảng trạng thái, cách đếm và ngưỡng giữ nguyên | Lần đo thứ nhất không đạt (token x1,50 trên các lần dựng được). Đường dẫn dài làm bốn lần chạy gõ sai đường dẫn và không ghi được tệp. Một tác tử đối chứng đọc lại màn mẫu qua lịch sử git. Bản vá `table` thuộc tầng thiết kế nên không được để lại ở nền đối chứng |
| 2026-11-11 | Đo lần ba sau khi sửa màn mẫu để trạng thái đến từ dữ liệu. Khoá luật chấm chặt trước khi chạy: một trạng thái chỉ được tính là có khi một điều kiện thật trong ứng dụng đang chạy dẫn tới nó (yêu cầu đang chờ hoặc thất bại, kết quả rỗng, bộ lọc không khớp, thao tác của người dùng); trạng thái chỉ mở được bằng công tắc (`?state=`, tham số, mục trong danh sách màn) mà dữ liệu thật không bao giờ gây ra thì tính là thiếu. Nguồn dữ liệu giả có độ trễ hay có thể báo lỗi được tính là điều kiện thật. Ngưỡng, màn, lệnh dựng và cách dựng nền như lần hai | Lần hai đạt theo luật cũ nhưng đọc chặt thì nền thử kém hơn (15 / 6): màn mẫu dạy bật trạng thái bằng công tắc. Chủ repo chọn sửa rồi đo lại với luật chặt |
| 2026-11-11 | Đo lần bốn sau khi cắt chi phí đọc của tầng thiết kế (danh sách màn nhận đường dẫn có tham số, test ứng dụng gọn và thuộc plugin, màn mẫu dời sang `/example`, móc kiểm thử tắt trong bản build thường, bẫy ô bảng, rút một phần ba lượng chữ phải đọc). Bản sao để đo nằm ở `/private/tmp/dm4`. Nền đối chứng cắt như lần ba và thêm `playwright.config.ts`. Cả hai nền được chấm trên bản `npm run build` thường; người chấm không nhận bản build cho bài kiểm trình duyệt. Luật chấm chặt, ngưỡng, màn và lệnh dựng giữ nguyên. Công khai: trang luật của nền thử có một dòng "bài kiểm trình duyệt là bước xem giao diện, không cần chụp màn hình"; dòng này chỉ có ở nền thử. Nền đối chứng vẫn giữ `src/lib/labels.ts` như ba lần trước (nghiêng về phía đối chứng) | Lần ba đạt chất lượng (0 / 18) nhưng token x1,43. Đọc nhật ký cho thấy token thêm đến từ tệp đọc lúc đầu, lượt nối danh sách màn bằng tay và vòng sửa do rào ô bảng. Chủ repo chọn cắt rồi đo lại |
