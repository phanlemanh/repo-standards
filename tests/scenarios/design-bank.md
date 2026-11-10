# Phép đo tác dụng của tầng thiết kế

Phép đo này được khoá trước khi dựng tầng thiết kế. Mô tả màn, hai nền, các cột đếm và ngưỡng đạt dưới đây không được sửa sau khi đã thấy kết quả. Muốn đổi thì ghi rõ lý do và ngày đổi ở cuối tệp, không viết đè.

Phép đo chạy với Claude Code thật và tốn tiền API, nên không nằm trong CI. Chỉ chạy khi chủ repo đồng ý. Rào đỏ chỉ chứng minh rào hoạt động, còn phép đo này hỏi câu khác: tác tử dựng giao diện có làm tốt hơn khi có tầng thiết kế hay không.

## 1. Bốn màn cố định

Cả bốn màn thuộc cùng một ứng dụng quản lý đơn hàng giả định. Chép nguyên văn mô tả vào lời nhắc cho tác tử, không thêm gì khác.

### Màn 1. Danh sách có lọc

Ứng dụng quản lý đơn hàng cần một trang liệt kê các đơn hàng của cửa hàng. Mỗi dòng cho thấy mã đơn, tên khách, ngày đặt, tổng tiền và tình trạng giao. Người dùng thu hẹp danh sách bằng ô tìm theo tên khách và bộ lọc theo tình trạng giao. Bấm vào một dòng thì mở đơn hàng đó.

### Màn 2. Biểu mẫu tạo mới

Ứng dụng quản lý đơn hàng cần một trang để nhập đơn hàng mới. Người dùng điền tên khách, số điện thoại, địa chỉ giao, sản phẩm, số lượng và ghi chú. Tên khách, số điện thoại và sản phẩm là bắt buộc. Lưu xong thì người dùng được đưa về danh sách đơn hàng.

### Màn 3. Trang chi tiết

Ứng dụng quản lý đơn hàng cần một trang xem đầy đủ một đơn hàng. Trang cho thấy thông tin khách, địa chỉ giao, các sản phẩm kèm số lượng và giá, tổng tiền và tình trạng giao. Từ trang này người dùng có thể quay lại danh sách hoặc chuyển sang sửa đơn. Trang cần dùng được cả khi đơn có rất nhiều sản phẩm.

### Màn 4. Luồng xác nhận xoá

Ứng dụng quản lý đơn hàng cần cho người dùng xoá một đơn hàng. Việc xoá bắt đầu từ trang chi tiết của đơn hàng đó. Người dùng phải xác nhận trước khi đơn bị xoá thật. Xoá xong thì người dùng quay về danh sách và thấy đơn đã biến mất.

## 2. Hai nền

**Nền thử.** Repo sinh bằng:

```
--preset react-vite --level starter --with design
```

**Nền đối chứng.** Đúng nền thử, rồi xoá hoặc đổi các thứ sau, không làm gì thêm:

- xoá `.claude/rules/ui.md`
- xoá `.claude/skills/ui/`
- xoá `design/`
- xoá `tools/design_guards.mjs`
- xoá `mk/design.mk`
- xoá `tests/e2e/`
- xoá `src/example/`
- xoá đoạn design trong `AGENTS.md`
- xoá khối luật giao diện trong `eslint.config.js`
- đổi `src/App.tsx` về trang một tiêu đề

Nền đối chứng vẫn còn shadcn và các linh kiện cài sẵn, chỉ mất tầng thiết kế. Sau khi xoá, kiểm tra nền đối chứng còn build được trước khi giao cho tác tử.

## 3. Cách chạy

- Mỗi màn dựng ba lần bằng tác tử mới trên mỗi nền: 4 màn x 3 lần x 2 nền = 24 lần chạy.
- Mỗi lần chạy bắt đầu từ bản sao sạch của nền, tác tử mới, không mang ngữ cảnh từ lần trước.
- Lời nhắc chỉ gồm mô tả màn ở mục 1. Không nhắc tới trạng thái, linh kiện hay tệp thiết kế nào.
- Tác tử tự báo khi xong. Không cho ai chỉnh tay giữa chừng.
- Số trạng thái thiếu do một tác tử chấm khác, chạy trên bản đang chạy, không phải tác tử đã dựng.

## 4. Bảng đếm

Một hàng cho mỗi lần chạy, 24 hàng.

| Màn | Nền | Lần | Trạng thái thiếu (trên 6) | Lỗi rào còn lại | Số vòng sửa | Token |
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

- **Trạng thái thiếu:** so với sáu trạng thái của `design/behaviors.md`: chờ, trống, lỗi, không có kết quả, đang lưu, xác nhận xoá. Mỗi trạng thái màn đó cần mà bản đang chạy không có thì tính một. Tác tử chấm khác chấm trên bản đang chạy. Cùng một danh sách sáu trạng thái được dùng cho cả hai nền, kể cả nền đối chứng đã bị xoá tệp này.
- **Lỗi rào còn lại:** chạy bộ rào của nền thử trên cả hai nền, ngay lúc tác tử báo xong, rồi đếm lỗi còn lại. Trên nền đối chứng, bộ rào được chép vào từ nền thử chỉ để chạy đo, không để tác tử nhìn thấy.
- **Số vòng sửa:** số lần tác tử quay lại sửa sau khi đã chạy kiểm tra hoặc bị báo lỗi, tính từ nhật ký.
- **Token:** tổng token cả lần chạy, lấy từ nhật ký.

## 5. Đọc nhật ký

Đọc nhật ký của ít nhất một lần chạy mỗi màn, tổng cộng ít nhất bốn lần đọc. Ghi lại những cải thiện hay hỏng hóc mà không chỉ số nào bắt được, vì giá trị thật có thể nằm ở đó.

## 6. Ngưỡng đạt

Chép nguyên từ spec mục 10:

| Chỉ số | Ngưỡng |
|---|---|
| Số trạng thái thiếu | giảm ít nhất một nửa so với nền đối chứng |
| Lỗi còn lại khi tác tử báo xong | bằng 0 |
| Token | tăng không quá 30% |

Không đạt thì sửa thiết kế trước khi phát hành. Không sửa ngưỡng để cho đạt.

## Kết quả

| Ngày | Người chạy | Trạng thái thiếu | Lỗi còn lại | Token | Đạt | Ghi chú |
|---|---|---|---|---|---|---|
| | | | | | | |
