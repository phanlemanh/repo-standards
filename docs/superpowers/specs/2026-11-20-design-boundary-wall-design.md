# RS5a: tường cho biên thiết kế

Ngày 2026-11-20. Trạng thái: chủ kho chọn hướng A ngày 2026-11-21: không dựng RS5a. Không có mã. Gói RS5a ở mục 7 của
[thiết kế tổng quan ba kho](../../three-repo-overview-design.md): «PR đụng khuôn hay dòng màu thương
hiệu thì lên hạng cao». Gói này chờ design-assembly nêu đường dẫn; nay đã nêu.

Kết luận trước: **đọc phía design-assembly thì thấy bức tường RS5a muốn dựng đã có, và đã được GitHub
bắt buộc qua ô `check`.** Dựng RS5a như đã viết sẽ gọi chủ kho lần thứ hai cho cùng một quyết định.
Bản này đề xuất không dựng nó, và nêu hai hướng khác để chủ kho chọn.

## 1. Đọc được gì ở design-assembly

Đọc bản sao chỉ-đọc của `phanlemanh/design-assembly` tại `9bac868` (plugin 0.21.0), ngày 2026-11-20.
Setup không đọc tệp nào của công cụ đó lúc chạy; mục này chỉ để biết đường dẫn.

- **Hai thứ chủ kho quyết** (bản uỷ quyền, mục 5 của thiết kế tổng quan, hàng «Thiết kế»: khuôn mới,
  màu thương hiệu) có tên máy đọc được:
  - một trang thêm vào dưới `design/patterns/` (một loại màn mới);
  - dòng màu gốc: giá trị `--primary` cuối cùng của khối `:root` cấp trên cùng trong tệp kiểu.
- **Phép kiểm `owner-calls`** (`tools/design-assembly/owner-calls.mjs`, `references/checks.md`):
  đỏ khi nhánh thêm một trang như vậy, hay đổi dòng màu so với nhánh gốc, cho tới khi danh sách
  chờ (`design/waiting/<id>.json`) có câu hỏi nêu đúng mục đó (`pattern:TÊN` hay
  `source-color:GIÁ_TRỊ`) và chủ kho đã trả lời «giữ». Hỏi mà chưa trả lời, hay trả lời từ chối,
  vẫn đỏ.
- **Phép kiểm chạy trong `make check`.** `templates/mk/design-assembly.mk` ghi
  `CHECK_TARGETS += design-assembly`; tầng nhẹ của CI do setup sinh ra chạy `make check-quick`, tức
  `$(CHECK_TARGETS)`, ở mọi lần đẩy; ô `check` là ô bắt buộc. Vậy một PR thêm khuôn hay đổi màu
  không gộp được cho tới khi chủ kho đã trả lời.
- design-assembly tự nói phần còn lại không phải của nó: «Raising a pull request's rank on the
  hosting service is not this tool's».

## 2. Vì sao RS5a như đã viết đi ngược luật

Nếu dựng RS5a như đã viết, PR đó lên hạng high; hạng high đòi code owner duyệt. Chủ kho khi ấy xuất
hiện hai lần cho một quyết định: một lần trả lời trong danh sách chờ, một lần duyệt PR.

- Luật 3 của [nguyên tắc](../../setup-principles.md): chỉ một nơi quyết khi nào cần người. Nơi đó đã
  có (cổng của design-assembly, câu hỏi gom vào danh sách chờ).
- Luật 6: không trả hai lần cho một phán xét. Ở đây trả bằng người, đắt hơn token.
- Luật 5: hạng high chỉ dành cho việc đổi luật chơi, không đoán theo tên đường dẫn. `design/patterns/**`
  là sổ của công cụ khác; setup ghi tên nó vào chính sách là đoán theo tên, và là nối ngầm vào bố cục
  tệp của design-assembly, trái luật «Repo Standards không đọc ai» ở
  [ranh giới ba kho](../../three-repo-boundaries.md).
- Mục 5 của thiết kế tổng quan: «Câu hỏi cho chủ kho gom lên thẻ ở cổng đã có, không thêm lượt gọi
  giữa chừng».

## 3. Chỗ còn hở thật

Một chỗ, và nó không phải chỗ RS5a nhắm tới: **ai ghi câu trả lời của chủ kho.** Câu trả lời nằm
trong `design/waiting/<id>.json`, một tệp trong PR. Một agent ghi «giữ» thay chủ kho thì `owner-calls`
xanh. design-assembly đã ghi giới hạn cùng loại cho phép kiểm bên cạnh (`decision-sheet-trusts-the-note`:
«an agent that writes one in is not caught»).

## 4. Ba hướng

| Hướng | Làm gì | Người xuất hiện | Setup phải biết gì của design-assembly |
| --- | --- | --- | --- |
| **A. Không dựng RS5a (đề xuất)** | Đóng RS5a ở mục 7: «tường đã có ở `owner-calls`, GitHub bắt buộc qua `check`». Thêm một bài ở mục 51 của bộ kiểm (mối nối) ghim điều setup hứa: đích mà một tệp `mk/*.mk` thêm vào `CHECK_TARGETS` chạy trong ô bắt buộc `check` | Một lần, ở danh sách chờ, như hôm nay | Không gì |
| B. Chặn chỗ ghi câu trả lời | Kho dùng design-assembly khai `design/waiting/**` vào danh sách `high` của `governance/autonomy.yaml` của chính nó (setup không ghi sẵn). PR ghi câu trả lời cần code owner | Một lần: duyệt PR chính là câu trả lời. Nhưng repo một chủ không tự duyệt được PR của mình (chỗ hở «repo một chủ» ở nguyên tắc) | Không gì; kho tự khai |
| C. RS5a như đã viết | `design/patterns/**` và tệp kiểu vào danh sách `high` | Hai lần cho một quyết định | Hai đường dẫn của công cụ khác |

Hướng B đóng chỗ hở ở mục 3, nhưng chạm hai điều chủ kho quyết: nó thêm một chỗ người xuất hiện, và
ở repo một chủ nó chưa có đường gộp ngoài quyền quản trị. Nếu chọn B, setup chỉ viết một dòng ví dụ
trong lời chú thích của `governance/autonomy.yaml`, không bật sẵn, và một bài kiểm cho thấy một
đường dẫn kho tự khai vào `high` làm PR lên high.

## 5. Nếu chọn A: việc cần làm

1. Bài kiểm: đã có ở PR của gói 5 (`docs/seam-contracts.md`, mục 1; `tests/seams.sh`, 51c): đích mà
   một tệp `mk/*.mk` thêm vào `CHECK_TARGETS` chạy trong `make check-quick`, tầng nhẹ nằm sau ô bắt
   buộc `check`, và một `Makefile` quên nó thì bài đỏ. Không cần bài mới.
2. Dòng trạng thái của RS5a ở mục 7 của thiết kế tổng quan: «Không dựng: `owner-calls` của
   design-assembly giữ, GitHub bắt buộc qua `check`». Đổi dòng này là đổi kế hoạch: chủ kho duyệt.
3. Không đổi `CHANGELOG.md` (không đổi hành vi).

## 6. Câu hỏi cho chủ kho

Chọn A, B hay C? Máy đề xuất A.
