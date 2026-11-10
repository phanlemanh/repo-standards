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
| 1 | thử | 1 | | | | |
| 1 | thử | 2 | | | | |
| 1 | thử | 3 | | | | |
| 1 | đối chứng | 1 | | | | |
| 1 | đối chứng | 2 | | | | |
| 1 | đối chứng | 3 | | | | |
| 2 | thử | 1 | | | | |
| 2 | thử | 2 | | | | |
| 2 | thử | 3 | | | | |
| 2 | đối chứng | 1 | | | | |
| 2 | đối chứng | 2 | | | | |
| 2 | đối chứng | 3 | | | | |
| 3 | thử | 1 | | | | |
| 3 | thử | 2 | | | | |
| 3 | thử | 3 | | | | |
| 3 | đối chứng | 1 | | | | |
| 3 | đối chứng | 2 | | | | |
| 3 | đối chứng | 3 | | | | |
| 4 | thử | 1 | | | | |
| 4 | thử | 2 | | | | |
| 4 | thử | 3 | | | | |
| 4 | đối chứng | 1 | | | | |
| 4 | đối chứng | 2 | | | | |
| 4 | đối chứng | 3 | | | | |

Cách đếm từng cột:

- **Trạng thái thiếu:** theo mục 4, số trạng thái cần có mà tác tử chấm đánh dấu không.
- **Lỗi rào còn lại:** sau khi tác tử dựng báo xong, sao `eslint.config.js` của nền thử ra một tệp tạm nằm ngoài repo, rồi chạy `npx eslint -c <tệp tạm đó> src --format json` trên cả hai nền. Đếm các thông báo có rule là `shadcn/*` hoặc `no-restricted-syntax`, bỏ `src/components/ui`. Kiểm tra trên trình duyệt không tính. Tác tử dựng trên nền đối chứng không bao giờ thấy cấu hình này.
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

Phiên bản Claude Code: (ghi một lần)

Việc gỡ tham chiếu treo trên nền đối chứng, nếu có: (ghi lại)

| Ngày | Người chạy | Trạng thái thiếu (thử / đối chứng) | Lỗi còn lại (thử) | Token (thử / đối chứng) | Đạt | Ghi chú |
|---|---|---|---|---|---|---|
| | | | | | | |

## Nhật ký thay đổi

| Ngày | Thay đổi | Lý do |
|---|---|---|
| 2026-11-10 | Viết lần đầu | Khoá phép đo trước khi dựng |
| 2026-11-10 | Siết giao thức: bỏ gợi ý trạng thái khỏi mô tả màn, khoá bảng trạng thái cần có, cách gộp, dấu mốc cắt nền đối chứng, lệnh chạy rào và điều kiện chạy | Sau rà soát, giao thức chưa tái lập được; sửa trước khi chạy lần nào |
