# Thiết kế tổng quan: vấn đề và hướng đi trên ba kho

Ngày: 2026-11-16. Trạng thái: máy tổng hợp từ buổi thảo luận với chủ kho cùng ngày. Chủ kho đã chốt
bốn tiêu chí ở mục 1, luật «gộp là phải xanh» và sáu biên uỷ quyền ở mục 5. Mọi gói việc ở mục 7 là
đề xuất: việc ở hai kho kia chờ chủ kho cho phép tại kho đó. Trang này đứng trước bản thiết kế chi
tiết của từng kho; nó nói vấn đề là gì, hướng giải là gì, kho nào nhận phần nào. Việc nào ở kho nào
xem [ranh giới ba kho](ranh-gioi-ba-kho.md); setup phải giữ điều gì xem
[nguyên tắc của setup](nguyen-tac-setup.md).

## 1. Sứ mệnh và thước

Sứ mệnh lấy từ North Star của delivery-loop: sản phẩm đến tay người dùng nhanh hơn mà vẫn tin được.
Máy làm và tự chứng minh; người chỉ ra quyết định, đứng ở biên của vòng. Kết quả chỉ tính khi đã
**gộp** vào nhánh chính.

Bốn tiêu chí chủ kho dùng để chấm mọi thay đổi:

1. Ít lần người xuất hiện hơn.
2. Nhanh hơn.
3. Ít nguồn lực hơn (token và phút máy).
4. Vẫn tin cậy. Chấp nhận một tỉ lệ lỗi, miễn là nó được đo.

Hai yêu cầu đi kèm, chủ kho nêu cùng ngày:

- Việc kiểm ở Máy (máy làm việc, trước khi đẩy lên) và ở GitHub phải không trùng và không sót.
- Các phiên chạy song song không được xếp hàng và kẹt nhau ở đoạn gộp.

## 2. Hiện trạng đo được

Số đo trên `onehub-inventory`, nhánh chính tại `b6f4f29`, đọc từ GitHub ngày 15–16/11. Phía Máy
(thời gian chấm, token, lượt gọi người) chưa đo được từ đây.

| Dòng                                         | Số đo                                             |
| -------------------------------------------- | ------------------------------------------------- |
| Mở PR đến gộp (15 PR tạo từ 14/11)           | Trung vị 9,6 giờ, dài nhất 20,2 giờ               |
| Một vòng CI chạy xong (54 lượt)              | 26 đến 79 phút, trung vị 36; chờ hàng đợi tới 46  |
| Ô `check` · `e2e` · `e2e-db` (trung vị)      | 3,4 · 31 · 30 phút                                |
| Phút máy GitHub cho mỗi PR gộp               | 548 phút (73 giờ chạy, 8 PR gộp)                  |
| Phần chạy lúc ô `gate` đỏ, PR chưa thể gộp   | 64%                                               |
| Cặp PR cùng chạm ít nhất một tệp (30 PR)     | 435 trên 435                                      |
| Gộp nhánh chính ngược vào nhánh · ghim lại   | 64 lần · 71 commit trên 30 PR                     |
| Đỏ muộn trên đầu nhánh đã qua `gate`         | 2 trên 16 lượt                                    |
| Nhánh chính đỏ sau gộp                       | 0 trên 8 lượt                                     |
| Ô bắt buộc trên GitHub                       | 3 trên 9 (`check`, `e2e`, `gate`)                 |
| Ô `secret-scan`                              | Quét 0 byte, luôn xanh                            |
| «Release» sau mỗi lần gộp                    | Đỏ 6 trên 6                                       |
| Sổ giới hạn đã biết của kit (161 vòng)       | 1.325 dòng; 1.060 còn sống; 147 đã đóng           |

Tám tệp sổ làm mọi cặp PR chạm nhau. Bỏ chúng thì còn 161 trên 435 cặp (37%); tính riêng mã sản phẩm
là 29%, và con số này là trần vì hai PR cùng sửa một tệp chưa chắc xung đột.

| Tệp                                                          | Số PR chạm (trên 30) | Kho sinh ra     |
| ------------------------------------------------------------ | -------------------- | --------------- |
| `wiki/log.md`                                                | 30                   | Repo Standards  |
| `LO-TRINH.html`, `PRODUCT-MAP.md`                            | 25                   | delivery-loop   |
| `_acceptance/config.yaml`                                    | 20                   | delivery-loop   |
| `design/component-registry.json`, `so-khoi.yaml`             | 14, 13               | design-assembly |
| `wiki/index.md`                                              | 12                   | Repo Standards  |
| `design/screens.yaml`                                        | 9                    | design-assembly |

`wiki/log.md` ghi «mới nhất ở trên», nên PR nào cũng chèn vào cùng một dòng và chắc chắn xung đột.

## 3. Bốn gốc rễ

1. **Độ mịn quá thô.** Hệ thống coi mọi thay đổi là thay đổi của mọi thứ, ở ba chỗ:
   - chỗ ghi: vòng nào cũng ghi vào cùng mấy tệp sổ, nên PR nào cũng chạm PR khác;
   - chỗ kiểm: sửa một màn vẫn chạy trọn 1.214 bài trình duyệt, ở cả Máy lẫn GitHub;
   - chỗ bằng chứng: một commit sau lúc chấm làm cũ mọi bằng chứng, kể cả commit chữ ký.

   Ba chỗ này nuôi nhau: một PR gộp, PR khác xung đột ở tệp sổ, phải gộp nhánh chính vào, bằng
   chứng thành cũ, ghim lại, chờ một vòng CI 36 phút, trong lúc đó PR khác gộp.

2. **Có cửa vào, không có đường ra.** Sổ giới hạn chỉ nhận thêm: 80% dòng còn sống, 38% dòng sống
   thuộc lớp «khác», sổ không có cột ngưỡng. Mục ngoài hợp đồng chờ người phân loại; một vòng đã bị
   giữ lại vì 13 mục như vậy.
3. **Tường trên danh nghĩa.** Có ô mang tên một bức tường mà không giữ gì: `secret-scan` quét 0
   byte, sáu trên chín ô không bắt buộc, ô tên PR kiểm thứ không commit nào dùng, «Release» đỏ sau
   mọi lần gộp nên màu đỏ mất nghĩa.
4. **Quyền sống bằng lời dặn.** Phiên giám sát điều phối thay chủ kho xếp hàng gộp, sắp lại lộ
   trình, mở và dọn phiên. Phần cơ chế đã là mã (gói `dieu-phoi`), nhưng nó được quyết gì, tới đâu,
   khi nào phải hỏi thì vẫn nằm trong lời dặn: không bền, đồng đội không đọc được, không có biên,
   không đo được.

## 4. Sáu nguyên tắc thiết kế

1. **Một phép kiểm, một chỗ.** Chia theo câu hỏi mà phép kiểm trả lời:

   | Câu hỏi                                               | Chỗ trả lời duy nhất | Lúc                             |
   | ----------------------------------------------------- | -------------------- | ------------------------------- |
   | Hàng có đúng hợp đồng của nó không?                   | Máy                  | Trước chữ ký                    |
   | Hàng có làm vỡ phần còn lại trên máy sạch không?      | GitHub               | Một lần, khi đầu nhánh sẵn sàng |
   | Luật chơi có bị lách không?                           | GitHub               | Mọi lần đẩy, dưới 5 phút        |
   | Sau gộp, nhánh chính còn xanh không?                  | GitHub, nhánh chính  | Sau gộp                         |

2. **Mỗi tệp một người ghi.** Một vòng chỉ ghi vào chỗ của riêng nó. Sổ chung thành mảnh theo vòng.
   Tệp tổng hợp là vật dẫn xuất: máy vẽ lại từ các mảnh trên nhánh chính, PR không mang nó.
3. **Phạm vi là vật máy đọc được.** Từ phạm vi của một vòng, máy trả lời ba câu: vòng này đụng vòng
   nào, bài nào phải chạy lại, bằng chứng nào còn hiệu lực. Một bài chỉ chạy lại khi đầu vào của nó
   đổi. Không biết thì chạy trọn bộ: hỏng về phía an toàn.
4. **Tỉ lệ lỗi được chấp nhận phải có số.** Lưới đỡ là CI trên nhánh chính, kèm đường đảo rẻ. Hai số
   đo: tỉ lệ đỏ muộn và tỉ lệ nhánh chính đỏ sau gộp. Vượt ngưỡng thì kéo đúng bài hay đỏ về sớm
   hơn, không kéo cả bộ.
5. **Bậc thang thay người.** Mỗi việc đang dặn bằng lời rơi vào bậc cao nhất có thể: bỏ bằng cấu
   trúc, rồi luật trong mã, rồi uỷ quyền có biên, sau cùng mới là người quyết. Mỗi biên phải quy
   được về một bất biến máy so trước và sau; chưa quy được thì nó vẫn là lời dặn.
6. **Sổ nào cũng có đường ra.** Giới hạn đã chấp nhận có ngưỡng theo lớp và có hạn. Mỗi câu người
   đã trả lời thành một dòng sổ để máy không hỏi lại.

## 5. Bản uỷ quyền (chủ kho đã chốt)

Người quyết duy nhất là chủ kho. Sáu việc, cùng một khuôn:

| Việc               | Máy tự làm                                                    | Phải hỏi chủ kho                                       | Bất biến máy so                      |
| ------------------ | ------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------ |
| Lộ trình           | Đổi thứ tự, tách hàng                                         | Hoãn, cắt                                              | Bảng phủ của lộ trình không đổi      |
| Gộp                | Gộp PR đã qua cổng, theo thứ tự làn, khi mọi ô xanh           | Không có: đỏ thì sửa                                   | Mọi ô xanh trên đúng commit được gộp |
| Phiên              | Mở phiên cho hàng sẵn sàng; dọn phiên đã gộp hoặc đã bàn giao | Dọn phiên còn việc chưa commit                         | Không commit nào bị mất              |
| Mục ngoài hợp đồng | Xếp «để sau» theo chính sách chốt ở Cổng Đáng                 | Mục chạm bất biến sản phẩm, bảo mật, dữ liệu           | Mọi mục có đúng một đích             |
| Thiết kế           | Chọn từ sổ quyết định và danh mục linh kiện                   | Khuôn mới, màu thương hiệu                             | Mọi lựa chọn trỏ về một dòng sổ      |
| Luật chơi          | Không gì cả                                                   | Mọi thay đổi tới bản uỷ quyền, `governance/`, workflow | Tệp luật đổi thì PR lên hạng cao     |

Ba điều đi kèm:

- Câu hỏi cho chủ kho gom lên thẻ ở cổng đã có, không thêm lượt gọi giữa chừng.
- Mỗi quyết định máy tự làm để lại một sự kiện, kèm tên quyền đã dùng và cách đảo.
- Phiên giám sát không đổi được phạm vi, luật, hay bản uỷ quyền của chính nó.

## 6. Kiến trúc: kho nào giữ gì

Chiều đọc giữ nguyên như trang ranh giới: delivery-loop đọc cả hai, design-assembly đọc Repo
Standards, Repo Standards không đọc ai.

|                    | Repo Standards                                                          | design-assembly                                   | delivery-loop                                                            |
| ------------------ | ----------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------ |
| Câu hỏi của kho    | Repo có gì, ai được làm gì                                              | Người dùng thấy gì                                | Lần này làm gì, đã đúng chưa                                             |
| Cấp cho thiết kế   | Khuôn CI, tường GitHub, luật chỗ ghi, bản đồ mô-đun, khe uỷ quyền       | Sổ thiết kế theo mảnh, bản đồ màn đến bài kiểm    | Bằng chứng theo đầu vào, điều phối theo phạm vi, thực thi bản uỷ quyền   |
| Vai máy đứng thay  | Người giữ luật                                                          | Trưởng thiết kế                                   | Người điều phối, chủ sản phẩm trong vòng                                 |
| Đọc gì             | Không đọc ai                                                            | Mô hình nghiệp vụ                                 | Bản đồ mô-đun, bản đồ màn, bản uỷ quyền                                  |

Phạm vi của một vòng có hai nguồn bản đồ: mô-đun (nghĩa, ở Repo Standards) và màn (thứ nhìn thấy, ở
design-assembly). delivery-loop chỉ đọc, đúng luật «không giữ sổ».

## 7. Gói việc theo kho

Mỗi gói chỉ có tên và mục tiêu. Cách làm nằm ở bản thiết kế chi tiết của kho đó.

**Repo Standards**

| Mã  | Gói việc                                                                                           | Tiêu chí          |
| --- | -------------------------------------------------------------------------------------------------- | ----------------- |
| RS1 | Tường thật: quét bí mật quét được; «Release» không đỏ vô cớ; ô tên PR theo cách gộp; ruleset bắt buộc đúng các ô kho khai | Tin cậy           |
| RS2 | Luật «mỗi tệp một người ghi»: `wiki/log.md` thành mảnh, `wiki/index.md` thành vật dẫn xuất, có phép kiểm | Nhanh             |
| RS3 | Khuôn CI xếp tầng: tầng nhẹ mọi lần đẩy, tầng nặng khi PR sẵn sàng, một ô tổng luôn chạy, chia song song | Nguồn lực, nhanh  |
| RS4 | Bản đồ phạm vi: từ tệp đổi ra mô-đun bị ảnh hưởng, dựa trên `architecture/modules.yaml`             | Nền cho DL và DA  |
| RS5 | Khe uỷ quyền trong `governance/`: sáu việc ở mục 5, nạp từ nhánh gốc, đổi nó là đổi luật chơi      | Ít người          |
| RS6 | Thêm nguyên tắc 1, 2 và 5 vào [nguyên tắc của setup](nguyen-tac-setup.md), kèm bài kiểm            | Giữ hướng         |

Bản chi tiết đã có: RS1, [tường thật](superpowers/specs/2026-11-16-tuong-that-design.md).

**design-assembly**

| Mã  | Gói việc                                                                         | Tiêu chí  |
| --- | -------------------------------------------------------------------------------- | --------- |
| DA1 | Ba sổ thiết kế nằm trong tám tệp nóng: tách thành mảnh theo màn hoặc linh kiện   | Nhanh     |
| DA2 | Bản đồ màn đến bài trình duyệt, kèm khổ màn nào cần cho màn nào                  | Nguồn lực |
| DA3 | Sổ quyết định trả lời thay vai trưởng thiết kế; câu chưa có thì hỏi một lần rồi ghi | Ít người  |

**delivery-loop**

| Mã  | Gói việc                                                                                              | Tiêu chí            |
| --- | ----------------------------------------------------------------------------------------------------- | ------------------- |
| DL1 | Không ghi tệp tổng hợp trong PR: bản đồ sản phẩm và lộ trình vẽ lại trên nhánh chính; lệnh kiểm về hồ sơ từng vòng | Nhanh               |
| DL2 | Bằng chứng tính theo đầu vào: chỉ cũ khi đầu vào của hàng đổi; commit chữ ký không kéo một vòng CI     | Nhanh, nguồn lực    |
| DL3 | Máy thôi chạy trọn bộ mỗi lượt chấm; bằng chứng hồi quy đọc từ GitHub; cấp ô bằng chứng với tên khác `gate` | Nguồn lực, ít người |
| DL4 | Điều phối đọc bản đồ phạm vi để xếp vòng nối tiếp hay song song                                       | Nhanh               |
| DL5 | Sổ giới hạn có ngưỡng theo lớp, có hạn, đo sự quay lại; mặc định định tuyến cho mục ngoài hợp đồng     | Ít người, tin cậy   |
| DL6 | Phiên giám sát đọc bản uỷ quyền thay lời dặn; mỗi quyết định ghi sự kiện kèm tên quyền                 | Ít người            |

## 8. Thứ tự

| Đợt | Gói việc           | Vì sao ở đây                                                                 | Thước kỳ vọng dịch chuyển                    |
| --- | ------------------ | ---------------------------------------------------------------------------- | -------------------------------------------- |
| 1   | RS1                | Rẻ, không phụ thuộc gì, đóng lỗ tin cậy đang mở                              | `secret-scan` quét được; nhánh chính hết đỏ giả |
| 2   | RS2, DL1, DA1      | Gỡ kẹt ở gốc; mở được lối gộp nhanh mà lệnh gộp đã có sẵn                    | Cặp PR chạm nhau từ 100% về gần 37%          |
| 3   | RS3                | Bỏ phần chạy lúc PR chưa thể gộp                                             | Phút máy mỗi PR gộp; hàng đợi                |
| 4   | RS4, rồi DL2–DL4, DA2 | Lợi lâu dài nhất, khó nhất; cần bản đồ trước rồi bên đọc mới dùng được    | Số lần ghim lại; phút chạy bài; mở đến gộp   |
| 5   | RS5, DL6, DA3, DL5 | Biên đã chốt; khai trước, ép sau                                             | Lượt gọi người; tỉ lệ câu hỏi lặp lại        |
| 6   | RS6                | Ghi lại khi các đợt trên đã chứng minh được                                  | Bài kiểm giữ hướng                           |

**Thứ tự theo kho (chủ kho chốt ngày 2026-11-16).** `onehub-inventory` đang chạy và delivery-loop
đang chuyển nhà, nên:

1. dựng ở Repo Standards và design-assembly trước;
2. rồi chạy trên `onehub-inventory`;
3. delivery-loop nâng cấp sau khi chuyển nhà xong.

Hệ quả: mọi gói DL đứng sau cùng trong đợt của nó. Ở đợt 2, hai kho đầu chỉ gỡ được tệp sổ của
mình (`wiki/` và `design/`); `LO-TRINH.html`, `PRODUCT-MAP.md` và `_acceptance/config.yaml` còn
nguyên cho tới DL1, nên phần lớn mức giảm va chạm đến sau bước 3.

Đợt 5 có thể khai sớm hơn vì nó không phụ thuộc đợt nào; nó xếp sau vì các đợt trước dịch chuyển số
đo nhiều hơn. Mọi mức lợi là ước tính từ số đo ở mục 2, chưa đợt nào được thử.

## 9. Rủi ro và giới hạn đã biết

- **GitHub không ép được «chỉ gộp qua lệnh gộp».** Lệnh gộp của gói `dieu-phoi` đòi mọi ô xanh,
  nhưng một phiên gọi thẳng `gh pr merge` chỉ bị chặn bởi các ô bắt buộc. RS1 thu hẹp khoảng này.
- **Ô bị bỏ qua được tính là xanh**, ở cả GitHub lẫn lệnh gộp. Xếp tầng CI (RS3) phải có một ô tổng
  luôn chạy, nếu không tầng nặng bị bỏ qua sẽ lọt.
- **Chọn bài có thể bỏ sót.** Bài trình duyệt gọi ứng dụng qua HTTP nên máy không tự lần ra ảnh
  hưởng; nó cần bản đồ màn khai tay (DA2). Bộ có cơ sở dữ liệu phụ thuộc cả lược đồ lẫn mã nên bớt
  được ít hơn.
- **Gom ba quyền vào một phiên.** Phiên giám sát vừa sắp lộ trình, vừa theo dõi tiến độ, vừa gộp.
  Biên tối thiểu là ba điều cuối mục 5.
- **Một người quyết.** Chủ kho vắng thì mọi mục «phải hỏi» đứng lại. Danh sách đó vì thế phải ngắn.
- **Chưa đọc design-assembly.** DA1 đến DA3 suy ra từ dữ liệu của `onehub-inventory`.
- **Chưa đo phía Máy.** Thời gian chấm, token và lượt gọi người lấy từ lời báo cáo của phiên làm
  việc, chưa được kiểm.

## 10. Điều còn mở cho chủ kho

1. Ngưỡng tỉ lệ lỗi chấp nhận. Máy gợi ý: đỏ muộn 20%, nhánh chính đỏ 1 trên 20.
2. Tên và chỗ đặt tệp uỷ quyền. Máy gợi ý: trong `governance/` của kho tiêu thụ.
3. Kho nào giữ phép so của từng bất biến ở mục 5.
4. Có bắt buộc cả chín ô trên GitHub không, hay chỉ các ô kho khai là tường.
5. Khoá bật lối gộp nhanh của gói `dieu-phoi` có đang bật ở `onehub-inventory` không.

## Nguồn

- delivery-loop, `CLAUDE.md`: North Star, năm dòng số, luật dừng (đọc ngày 2026-11-16, nhánh
  `chuyen-nha`).
- delivery-loop, `dieu-phoi/scripts/gop.mjs`: luật «mọi ô xanh», lối gộp nhanh khi không trùng tệp.
- delivery-loop, `docs/research/known-limits-ledger.tsv`: sổ giới hạn đã biết, bản ngày 2026-11-15.
- `onehub-inventory`: 83 lượt CI từ 15/11, 30 PR gộp gần nhất, năm tệp workflow, ruleset của nhánh
  chính, đọc qua GitHub ngày 15–16/11.
- Phép thử `secret-scan`: cấy một token giả vào bản clone tạm; lệnh của móc báo 0 commit được
  quét, hai lệnh quét đối chứng đều bắt được.
- Chủ kho, buổi thảo luận ngày 2026-11-16: bốn tiêu chí, «gộp là phải xanh», sáu biên uỷ quyền,
  «chỉ mình tôi quyết».
