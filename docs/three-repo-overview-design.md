# Thiết kế tổng quan: vấn đề và hướng đi trên ba kho

Ngày: 2026-11-16. Trạng thái: máy tổng hợp từ buổi thảo luận với chủ kho cùng ngày. Chủ kho đã chốt
bốn tiêu chí ở mục 1, luật «gộp là phải xanh» và sáu biên uỷ quyền ở mục 5. Mọi gói việc ở mục 7 là
đề xuất: việc ở hai kho kia chờ chủ kho cho phép tại kho đó. Trang này đứng trước bản thiết kế chi
tiết của từng kho; nó nói vấn đề là gì, hướng giải là gì, kho nào nhận phần nào. Phiên Design
Assembly đã kiểm ba gói DA với mã thật cùng ngày; kết quả ở cuối mục 7. Kế hoạch được rà lại cùng
ngày bằng số đo xung đột thật; kết quả ở mục 8. Việc nào ở kho nào xem [ranh giới ba kho](three-repo-boundaries.md); setup phải giữ điều gì xem
[nguyên tắc của setup](setup-principles.md).

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
(thời gian chấm, token, lượt gọi người) chưa đo được từ đây. Đo lại ngày 2026-11-20, kèm phía Máy:
[truy nguyên từ quyết đến gộp](reports/2026-11-20-decision-to-merge-trace.md).

| Dòng                                         | Số đo                                             |
| -------------------------------------------- | ------------------------------------------------- |
| Mở PR đến gộp (15 PR tạo từ 14/11)           | Trung vị 9,6 giờ, dài nhất 20,2 giờ               |
| Một vòng CI chạy xong (54 lượt)              | 26 đến 79 phút, trung vị 36; chờ hàng đợi tới 46  |
| Ô `check` · `e2e` · `e2e-db` (trung vị)      | 3,4 · 31 · 30 phút                                |
| Phút máy GitHub cho mỗi PR gộp               | 548 phút (73 giờ chạy, 8 PR gộp)                  |
| Phần chạy lúc ô `gate` đỏ, PR chưa thể gộp   | 64%                                               |
| Cặp PR cùng chạm ít nhất một tệp (30 PR)     | 435 trên 435                                      |
| Gộp nhánh chính ngược vào nhánh · ghim lại   | 99 lần · 71 commit trên 30 PR                     |
| Lần gộp ngược có xung đột (phát lại bằng git) | 93 trên 99                                        |
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
| `design/component-registry.json`                             | 14                   | design-assembly |
| `design/so-khoi.yaml`                                        | 13                   | design-assembly, theo luật chủ kho chốt ở cuối mục 7 |
| `wiki/index.md`                                              | 12                   | Repo Standards  |
| `design/screens.yaml`                                        | 9                    | design-assembly |

`wiki/log.md` ghi «mới nhất ở trên», nên PR nào cũng chèn vào cùng một dòng và chắc chắn xung đột.

«Cùng chạm một tệp» mới là dấu hiệu gián tiếp. Phát lại 99 lần gộp nhánh chính ngược vào nhánh bằng
`git merge-tree` cho số xung đột thật: 93 lần xung đột, ở các tệp sau.

| Tệp xung đột                                 | Số lần (trên 93) | Kho             |
| -------------------------------------------- | ---------------- | --------------- |
| `LO-TRINH.html`                              | 71               | delivery-loop   |
| `wiki/log.md`                                | 60               | Repo Standards  |
| `PRODUCT-MAP.md`                             | 45               | delivery-loop   |
| `_acceptance/config.yaml`                    | 17               | delivery-loop   |
| `design/so-khoi.yaml`, `behaviors.md`        | 9, 6             | design-assembly |
| `ontology/glossary.md`, `wiki/entities/*.md` | 8, 5             | Repo Standards  |
| Mã sản phẩm (tệp nhiều nhất: lưới hàng)      | 8                | Kho sản phẩm    |

Gỡ phần của từng kho thì còn bao nhiêu lần gộp ngược xung đột:

| Gỡ tệp của                        | Còn xung đột (trên 93) |
| --------------------------------- | ---------------------- |
| Repo Standards                    | 76                     |
| Repo Standards và design-assembly | 73                     |
| Riêng delivery-loop               | 73                     |
| Cả ba kho                         | 16                     |

Mỗi kho gỡ riêng chỉ bớt khoảng một phần năm; cả ba cùng gỡ mới bớt 83%. 16 lần còn lại là xung đột
thật ở mã sản phẩm. Hai lưu ý: `PRODUCT-MAP.md` ở kho thật có luật gộp riêng nên nhiều lần đã tự gỡ;
và con số «64 lần gộp ngược» ở bản trước đếm theo lời commit, đếm theo cấu trúc commit là 99.

## 3. Năm gốc rễ

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
4. **Luật và quyền sống bằng lời dặn.** Hai dạng:
   - Quyền: phiên giám sát điều phối thay chủ kho xếp hàng gộp, sắp lại lộ trình, mở và dọn phiên.
     Phần cơ chế đã là mã (gói `dieu-phoi`), nhưng nó được quyết gì, tới đâu, khi nào phải hỏi thì
     vẫn nằm trong lời dặn: không bền, đồng đội không đọc được, không có biên, không đo được.
   - Luật: `AGENTS.md` mà plugin sinh ra nêu khoảng 16 luật dạng «luôn» hay «không được»; máy đọc và
     xếp thì khoảng 6 luật có máy giữ, 10 luật chỉ là câu chữ. (Số đếm sau RS7, trên cả 12 mảnh và chỉ tính
     máy đã có bài chứng minh: 13 luật máy giữ, 62 luật bằng lời.) Luật «tên tệp tiếng Anh» nằm trong
     10 luật đó: `onehub-inventory` có khoảng 59 trên 62 thư mục vòng tên tiếng Việt, và bốn tệp
     tài liệu ở chính kho này từng mang tên tiếng Việt (ba tệp do máy đặt trong buổi này; đã đổi
     cùng ngày, gói RS9).
5. **Bản sao trôi khỏi nguồn.** Plugin chép mẫu vào kho một lần; sau đó bản sửa ở nguồn không tự
   tới. `onehub-inventory` dựng từ bản 0.4.0; 34 trên 81 tệp sinh ra đã bị sửa tại chỗ, gồm
   `security.yml`, `ci.yml`, `.pre-commit-config.yaml` và `AGENTS.md`. Chạy lại `apply.py` thì tệp
   đã sửa bị báo «conflict» và để nguyên, nên bản sửa quét bí mật của đợt 1 không tự tới kho đó.
   Cùng gốc: kho Repo Standards không áp bộ setup lên chính mình (không có `AGENTS.md`), nên luật nó
   dạy kho khác không ràng nó.

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
Standards, Repo Standards không đọc sổ của ai (từ ngày 2026-11-22 nó gọi design-assembly; xem trang
ranh giới).

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

| Mã   | Gói việc                                                                                                                              | Gốc rễ  | Tiêu chí         | Trạng thái                           |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------- | ------- | ---------------- | ------------------------------------ |
| RS1  | Tường thật: quét bí mật quét được; «Release» không đỏ vô cớ; ô khuôn commit theo cách gộp; ruleset bắt buộc đúng các ô kho khai       | 3       | Tin cậy          | Đã gộp (PR 14); đã chạy ở kho thử    |
| RS2a | `wiki/log.md` gộp kiểu hợp (`merge=union` trong `.gitattributes`): một dòng mẫu                                                       | 1       | Nhanh            | Đã dựng (2026-11-16), mục 46 bộ kiểm |
| RS2b | Luật «mỗi tệp một người ghi»: sổ thành mảnh; tệp tổng hợp và mã sinh ra là vật dẫn xuất PR không mang; cơ chế dùng chung với DA1      | 1       | Nhanh            | Phát hành ở 0.8.0 và đo ở kho thử (2026-11-18), mục 48 bộ kiểm |
| RS3  | Khuôn CI xếp tầng: tầng nhẹ mọi lần đẩy, tầng nặng khi PR sẵn sàng, một ô tổng luôn chạy; ô trình duyệt nhận danh sách màn hoặc bài   | 1       | Nguồn lực, nhanh | Phát hành ở 0.9.0 và đo ở kho thử (2026-11-18), mục 49 bộ kiểm |
| RS4  | Bản đồ phạm vi: từ tệp đổi ra mô-đun bị ảnh hưởng, dựa trên `architecture/modules.yaml`                                               | 1       | Nền cho DL       | Đóng, không dựng (chủ kho, 2026-11-21): kit xếp vòng bằng `ranh_gioi` và `vung` của chính nó, không đọc `architecture/modules.yaml`; nếu gói DL4 của kit mở, kit đọc thẳng tệp đó |
| RS5a | Tường cho biên thiết kế: PR đụng khuôn hay dòng màu thương hiệu thì lên hạng cao                                                      | 4       | Ít người         | Không dựng: `owner-calls` của design-assembly giữ, GitHub bắt buộc qua `check`; chủ kho chọn hướng A ngày 2026-11-21 (PR 55), mục 51c bộ kiểm |
| RS5b | Khe uỷ quyền trong `governance/`: sáu việc ở mục 5, nạp từ nhánh gốc                                                                  | 4       | Ít người         | Hoãn: chờ một ADR ở kit rồi một vòng «giám sát chủ động» (issue 5 của delivery-loop), chưa có lịch; tệp nằm ở `governance/` của kho dùng, kit chỉ đọc |
| RS6  | Thêm nguyên tắc 1, 2 và 5 vào [nguyên tắc của setup](setup-principles.md), kèm bài kiểm                                               | 4       | Giữ hướng        | Đã gộp (PR 51): luật 8 đến 10, mục 43k bộ kiểm                         |
| RS7  | Mỗi luật trong `AGENTS.md` sinh ra hoặc nêu tên phép kiểm giữ nó, hoặc ghi rõ «giữ bằng lời»; bài kiểm đỏ khi thêm luật không có loại | 4       | Tin cậy          | Phát hành ở 0.10.0 và chạy ở kho thử (2026-11-19), mục 50 bộ kiểm: 13 luật máy giữ, 62 lời |
| RS8  | Đường nâng cấp: bản sửa ở mẫu tới được tệp đã sửa tại chỗ; `doctor` báo tệp nào lệch nguồn và lệch mấy bản                            | 5       | Tin cậy, nhanh   | Đã dựng và chạy ở kho thử (2026-11-17), mục 47 bộ kiểm |
| RS9  | Kho này giữ luật của chính nó: tên tệp và tên nhánh tiếng Anh, ghi vào `CLAUDE.md`; đổi tên bốn tệp tài liệu                          | 4, 5    | Giữ hướng        | Đã làm (2026-11-16), mục 45 bộ kiểm  |
| RS10 | Thước lặp lại được: `tools/sdlc_metrics.py` in các dòng của mục 2 (mở đến gộp, xung đột khi gộp ngược, phút máy mỗi PR gộp, đỏ muộn)  | Mọi gốc | Đo               | Đủ các dòng của mục 2, tách theo mốc (`--split`) và mục ngưỡng; phát hành ở 0.10.3 (PR 50, PR 63), mục 46 bộ kiểm. Ngưỡng là một dòng trong báo cáo (chủ kho, 2026-11-21) |

Bản chi tiết đã có: RS1, [tường thật](superpowers/specs/2026-11-16-real-walls-design.md); RS8,
[đường nâng cấp](superpowers/specs/2026-11-17-upgrade-path-design.md); RS2b,
[mỗi tệp một người ghi](superpowers/specs/2026-11-17-ledger-fragments-design.md) (kế hoạch:
[ledger-fragments](superpowers/plans/2026-11-17-ledger-fragments.md)); RS5a, [tường cho biên thiết kế](superpowers/specs/2026-11-20-design-boundary-wall-design.md); RS3,
[CI xếp tầng](superpowers/specs/2026-11-17-tiered-ci-design.md) (kế hoạch:
[tiered-ci](superpowers/plans/2026-11-17-tiered-ci.md)).

Hai điều bản thiết kế bước D đổi so với ghi chú bên dưới:

- **RS3 không chờ ô `gate`.** Ô `gate` của kit đỏ tới khi có chữ ký, trong khi vòng làm việc chờ
  CI xanh rồi mới mời ký. Chờ `gate` thì hai bên chờ nhau. Chủ kho chọn: tầng nặng chạy lại khi
  đầu vào của nó đổi so với lần xanh trước; commit chữ ký dùng lại kết quả cũ.
- **RS2b không gồm `ontology/labels.yaml`.** Tệp đó và `src/generated/labels.ts`, `display.ts` do
  công cụ riêng của `onehub-inventory` sinh ra. Kho này cấp cơ chế (`make derived`); kho đó tự nối
  vào ở bước chạy trên kho đó.

Ghi chú cho các gói mới và gói đổi:

- **RS2b đã dựng (bước D), phát hành ở 0.8.0.** Kho này cấp `make derived` và
  `tools/ledgers.py` (`add-log`, `add-term`, `draw`, `draw-gen`, `shape`, `split`): sổ log, sổ
  thuật ngữ và mục lục wiki thành mảnh, mã sinh ra từ `ontology/` thành vật dẫn xuất; `split` chuyển
  một kho đang giữ sổ một tệp, mỗi sổ một PR, và so từng mục trước sau. Mục 48 của bộ kiểm giữ phần
  này; `bash tests/e2e.sh` chạy thật các tổ hợp preset và đường nâng cấp từ bản đã phát hành. Bốn điều
  đổi so với bản thiết kế và kế hoạch:
  - Hình dạng của một sổ đọc theo dấu, không đọc theo «có trong git». Sổ là `one-file` khi tệp cũ
    nằm trong git mà dòng đầu không phải dòng dấu; mọi trường hợp khác là `fragments`. Đọc theo chữ
    của bản thiết kế thì phép kiểm `derived-untracked` không bao giờ đỏ được, vì tệp ép thêm vào git
    cũng «nằm trong git». Kho cũ chưa từng có dấu nên vẫn xanh sau khi nâng cấp.
  - Tệp đầu (`wiki/log.head.md`, `wiki/index.head.md`, `ontology/glossary.head.md`) đi qua danh sách
    kê của bản cài (`.repo-setup.json`). `split` chỉ ghi đè tệp đầu còn đúng băm bản cài ghi, rồi gỡ
    nó khỏi danh sách kê; khoá mới `kept_quietly` của preset làm nâng cấp giữ các tệp này mà không
    nhắc ai gộp tay.
  - Mục lục không bao giờ là «hai nguồn»: nó không có thư mục mảnh, nên `wiki/index.md` viết tay
    cạnh tệp `index.head.md` không bị chặn; kho nâng cấp giữ nguyên.
  - `mk/derived.mk` chạy các công cụ sổ bằng `LEDGERS_PYTHON` (mặc định `python3`, chỉ thư viện chuẩn),
    không bằng `PYTHON`, để móc `SessionStart` ở kho python không kéo `uv run`. Các công cụ này
    cũng qua `ruff` của preset python, nên được tách thành `ledgers.py`, `ledgers_ontology.py`,
    `ledgers_split.py`, `ledgers_split_read.py`, mỗi tệp dưới 800 dòng.
- **RS3 đã đo trên kho thử (2026-11-18).** Kho thử `design-ci-probe` nâng lên `main` của kho này tại
  `7e8a1b5` (PR 16): không tệp nào bị đánh dấu, `make check` xanh. Sáu phép thử ở mục 8 của spec chạy
  trên một PR, mỗi phép thử một commit (PR 17, đóng không gộp). Cả sáu đạt:

  | Phép thử                                   | `quick` | `heavy`                                            | `check` |
  | ------------------------------------------ | ------- | -------------------------------------------------- | ------- |
  | 1. Lỗi kiểu, `quick` cố ý đỏ               | đỏ      | bỏ qua                                             | đỏ      |
  | 2. Sửa lỗi, vẫn khác `main`                | xanh    | chạy thật, 1 phút 43 giây; ghi lượt xanh, lưu khoá | xanh    |
  | 3. Commit chỉ đổi `docs/`                  | xanh    | xanh sau 6 giây, nêu lượt và commit của phép thử 2 | xanh    |
  | 4. Commit đổi mã                           | xanh    | chạy lại thật, 1 phút 55 giây                      | xanh    |
  | 5. Huỷ tay lúc `make check-heavy` đang chạy | xanh    | huỷ                                                | đỏ      |
  | 6. Bản nháp, rồi chuyển sang sẵn sàng      | xanh    | bỏ qua, rồi chạy thật khi sẵn sàng                 | đỏ, rồi xanh |

  Lời của `check` nói rõ từng trường hợp: tầng nào không chạy vì tầng trước chưa qua, vì bị huỷ, hay
  vì PR là bản nháp, «chưa tới lượt». Ở phép thử 6, cùng một đầu nhánh có hai lượt `check`, một đỏ một
  xanh. GitHub tính lượt mới nhất, nên ô bắt buộc `check` của kho thử không chặn PR. Bộ nhớ đệm được
  kiểm ở hai chỗ: một PR đọc lại khoá do chính nó lưu (phép thử 3), và lượt bị huỷ không lưu khoá
  (phép thử 5). Còn chưa kiểm: hai lượt cùng lưu một khoá, và một PR dùng lại khoá do nhánh chính lưu.
  Số đo trước khi dựng nằm ở `docs/reports/2026-11-18-heavy-reuse-measure.md`: 12,4% số lượt lúc
  `gate` đỏ dùng lại được tầng nặng. Phép so «phút máy mỗi PR gộp» của `sdlc_metrics.py` (hôm nay
  44,2) sau 10 PR gộp chưa làm. Ruleset trên `main` của kho này vẫn chưa có (spec mục 9).
- **RS2b đã đo trên kho thử (2026-11-18).** Kho thử `design-ci-probe` nâng từ bản dựng thay 0.6.1
  lên tag `repo-setup-v0.8.0` (PR 10), `split` bốn sổ trong một PR, mỗi sổ một commit (PR 11). Hai
  PR mở cùng lúc từ cùng một gốc, mỗi PR một `make log`, một `add-term`, một trang wiki (PR 12 và
  13). Hai PR không chung tệp nào. Gộp PR 12 xong, GitHub vẫn báo PR 13 gộp được; PR 13 gộp bằng nút
  của GitHub, không «Update branch», dù đi sau nhánh chính 4 commit. Trên nhánh chính, `make derived`
  vẽ đủ cả hai dòng log, hai thuật ngữ và hai trang trong mục lục, và CI trên nhánh chính sau hai
  lần gộp xanh. Ba điều lộ ra khi nâng:
  - `package.json` bị đánh dấu. Mẫu thêm `prepare` vào cuối `scripts`, sát chỗ `npm install` của kho
    đã thêm `devDependencies`, nên `git merge-file` coi hai thay đổi kề nhau là xung đột. Kho preset
    Node nào đã `npm install` nhiều khả năng gặp điều này khi nâng lên 0.8.0. Phép `e2e` nâng từ
    0.7.0 không bắt được, vì nó chạy preset python, không có `package.json`.
  - `.editorconfig` và `AGENTS.md` mang băm của bản dựng thay, nên được gộp hai chiều với gốc rỗng và
    bị đánh dấu cả tệp, đúng như «Known gaps» của 0.8.0 đã ghi. Ba tệp được gộp tay; `make check`
    xanh ở máy và trên CI.
  - Ô `dependency-audit` (không bắt buộc, trong workflow «Security») đỏ trên mọi PR của lần đo và
    trên nhánh chính: `npm audit` báo 8 lỗ hổng mức cao trong `shadcn` và các gói nó kéo theo, công
    bố sau lần chạy xanh trước trên nhánh chính. Lỗi không do bản nâng: PR 10 không đổi
    `package-lock.json`.
- **RS2a đã thử.** Phát lại 99 lần gộp ngược với luật gộp kiểu hợp cho `wiki/log.md` và
  `wiki/index.md`: xung đột ở hai tệp này từ 60 và 3 về 0, số lần gộp ngược sạch từ 6 lên 22, một
  bản gộp soi tay không mất dòng nào. Nó chỉ gỡ xung đột; hai PR vẫn «cùng chạm một tệp», nên lối
  gộp nhanh của lệnh gộp vẫn đóng. Vì thế vẫn cần RS2b.
- **RS2a và RS10 đã dựng (bước B).** Mẫu `.gitattributes` có dòng `wiki/log.md merge=union`, và
  `tools/sdlc_metrics.py` in thêm phần «Flow». Chạy lệnh đó trên một bản sao đầy đủ của
  `onehub-inventory`, cửa sổ 3 ngày tới 16/11:

  | Dòng                                               | Luật gộp hiện tại   | Thêm dòng của RS2a |
  | -------------------------------------------------- | ------------------- | ------------------ |
  | Gộp nhánh chính ngược vào nhánh (38 PR)            | 103                 | 103                |
  | Lần gộp ngược xung đột khi phát lại                | 96                  | 76                 |
  | Lần `wiki/log.md` xung đột                         | 65                  | 0                  |
  | Phút máy cho mỗi PR gộp (880 lượt chạy, 30 PR gộp) | 430                 | không đổi          |
  | Đỏ muộn: đầu nhánh có job đỏ sau khi `gate` đã qua | 11 trên 55          | không đổi          |
  | Nhánh chính đỏ: `CI` · `Security` · `Release`      | 0/29 · 0/30 · 30/30 | không đổi          |

  Số gộp ngược khớp lần đo tay ở mục 2 (99 lần, 93 xung đột, `wiki/log.md` 60). Lệnh cho thấy ba
  điều lần đo tay chưa thấy. Kho có khoảng 300 lượt chạy mỗi ngày, nên lệnh hỏi GitHub theo từng
  ngày (GitHub cắt danh sách ở 1.000 lượt). «Đỏ muộn» đếm cả lượt đã được chạy lại cho xanh, nên
  11 trên 55 (20%) cao hơn con số 2 trên 16 đo tay. Và chỗ nào không đọc được thì lệnh ghi «not
  read» kèm lý do, không ghi 0. Ba giới hạn còn lại: GitHub không theo luật gộp kiểu hợp (xem mục
  kế tiếp); `onehub-inventory` chưa nhận được dòng mẫu vì tệp `.gitattributes` của nó đã sửa tại
  chỗ (chờ RS8); và một tuần của kho này là khoảng 2.000 lượt hỏi GitHub, quá hạn mức mỗi giờ của
  khoá Actions, nên báo cáo hằng tuần trong CI sẽ ghi phần CI là «not read» cho tới khi lệnh đọc
  rẻ hơn.
- **Chạy thật ở kho thử (16/11).** Kho riêng `design-ci-probe`, dựng từ bản 0.4.0 như
  `onehub-inventory`, được nâng lên `main` tại `1446c1e` (37 tệp cập nhật, 4 tệp mới, không tệp
  nào xung đột), rồi mở bốn PR thử.

  | Phép thử                                                    | Kết quả trên GitHub                                                                                                                               |
  | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
  | Quét bí mật, nhánh sạch                                     | Xanh                                                                                                                                              |
  | Quét bí mật, token cấy vào rồi xoá ở commit sau             | Đỏ, chỉ đúng commit và tệp                                                                                                                        |
  | Một commit sai khuôn, tên PR đúng khuôn, kho cho gộp thường | `conventional-commits` đỏ chỉ đúng commit; `conventional-title` xanh                                                                              |
  | Commit gộp ngược `main` vào nhánh                           | Bỏ qua đúng (commit hai cha), ô xanh                                                                                                              |
  | «Release» sau khi gộp, chưa có khoá                         | Xanh, báo «Releases are off»                                                                                                                      |
  | Hai PR cùng thêm một dòng vào `wiki/log.md`                 | Gộp PR thứ nhất xong, GitHub báo PR thứ hai xung đột; «Update branch» từ chối. Gộp ngược ở máy thì sạch, đẩy lên là gộp được, log giữ đủ hai dòng |

  Ba điều phép thử ở máy không thấy được:

  1. **RS2a chỉ có tác dụng ở máy.** Nút gộp, «Update branch» và tự gộp của GitHub không theo
     `merge=union`. Ở `onehub-inventory` các lần gộp ngược do phiên làm ở máy, nên con số 65 về 0
     vẫn đúng cho luồng đang chạy. Nhưng bước gộp nào dựa vào nút của GitHub vẫn kẹt ở
     `wiki/log.md`: lệnh gộp của delivery-loop phải gộp ngược ở máy, không gọi «Update branch».
     RS2b (log thành mảnh) không có giới hạn này.
  2. **Đường nâng cấp bỏ sót một bản sửa và không báo gì (ca đầu tiên cho RS8).** Mẫu đã làm tối
     `--destructive` trong `src/index.css` để chữ đỏ trên nền nhạt đạt tương phản 4,5:1. `apply.py`
     coi tệp này là của người dùng nên không cập nhật, kể cả khi chưa ai sửa từ lúc cài, và chỉ nhắc
     «gộp tay» ở lần cài đầu. Ngay sau khi nâng cấp, 8 bài trình duyệt của màn `/example` đỏ vì
     `color-contrast`; gộp tay token đó thì xanh. `tests/e2e.sh` luôn cài mới nên không bao giờ đi
     qua đường này. Cách sửa thuộc RS8: tệp `package.json` cập nhật mà khoá phụ thuộc không đổi
     thì `npm ci` đỏ, nên «chưa sửa thì cập nhật» không đủ.
  3. **`codeql` không bao giờ xanh trên kho riêng tư không có GitHub Advanced Security.** Nó đỏ từ
     lần đẩy đầu tiên ở 0.4.0. Thêm quyền `actions: read` thì qua lỗi quyền, rồi vấp «Code scanning
     is not enabled for this repository». Đây là tường đỏ vô cớ cùng loại với «Release» trước RS1:
     nên báo «tắt» rồi kết thúc xanh khi kho không bật code scanning. Luật «mỗi bức tường phải có
     bài kiểm chiều đỏ» cần thêm vế ngược lại: bức tường cũng phải xanh được.
     **Đã sửa (RS1, lượt tiếp):** job hỏi GitHub trước; câu trả lời «not enabled» thì bỏ qua phân
     tích, báo «CodeQL is off» và xanh. Trên kho thử, với khoá của Actions: ba bước CodeQL bị bỏ
     qua, ô xanh. Mục 44i của bộ kiểm.

  Sau đó `tools/github_setup.py --merge-method merge --apply` đặt ruleset trên `main`: PR bắt buộc,
  ô bắt buộc `check` và `secret-scan`, chủ mã theo `.github/CODEOWNERS`, không cần ai duyệt. PR có
  `secret-scan` đỏ bị chặn gộp. Thêm hai điều:

  4. **Tường khuôn commit chưa chặn gì lúc gộp.** PR có `conventional-commits` đỏ vẫn gộp được, vì
     ruleset chỉ bắt buộc `check`, `secret-scan` và các ô kho tự khai. Ô đó đỏ đúng lý do nhưng là
     tường trên danh nghĩa (gốc rễ 3) cho tới khi nó, hoặc `conventional-title`, vào danh sách bắt
     buộc theo cách gộp kho chọn. Chủ mã không chặn PR của chính chủ mã, nên ở kho một người chỉ
     còn ô kiểm là tường.
     **Đã sửa (RS1, lượt tiếp):** `github_setup.py` bắt buộc cả `conventional-title` lẫn
     `conventional-commits`, khi workflow trên nhánh gốc đã có job đó (chúng chạy từ nhánh gốc).
     Trên kho thử, PR có commit sai khuôn chuyển từ gộp được sang bị chặn. Mục 44j, 44k.
  5. **Trên kho riêng tư gói miễn phí, «production cần người duyệt» không dựng được.** GitHub từ chối
     quy tắc người duyệt của môi trường («billing plan», 422). Lệnh báo `!` và trả mã 1, nhưng môi
     trường `production` vẫn được tạo, không có quy tắc nào. Job `production` trong `deploy.yml` khi
     đó chạy mà không ai duyệt. Đây là chỗ duy nhất mà nguyên tắc đặt một người, nên cách thay
     (ví dụ: chỉ chạy production khi một người tự bấm chạy) là việc chủ kho quyết. Ở
     `onehub-inventory` khâu triển khai đang tắt, nên hiện chưa có hậu quả.
- **Chạy thật đường nâng cấp ở kho thử (17/11).** Ba PR trên `design-ci-probe`, theo đúng ba bước
  của thiết kế RS8:

  1. PR 7: nâng lên tag `repo-setup-v0.6.0` bằng `apply.py` của 0.6.0. Kết quả: 1 tệp `updated`
     (`tools/github_setup.py`), 1 tệp `conflict` (`wiki/log.md`, sổ log của kho, để nguyên). CI
     xanh, đã gộp.
  2. PR 8: sửa tại chỗ hai tệp do setup ghi, dòng ghi chú ở đầu `.editorconfig` và dòng
     `make check` trong `AGENTS.md`. Đã gộp.
  3. PR 9: nâng bằng mã của nhánh RS8. Nhánh không đổi mẫu nào có sẵn, nên mã chạy từ một bản
     phát hành dựng thay, `0.6.1`: bản sao của nhánh, với hai bản sửa ở mẫu (một khối ở cuối
     `.editorconfig`, dòng `make check` của `AGENTS.md`). Gốc dựng lại từ tag `0.6.0` tải thật.

  | Tệp             | Kết quả                                                                                                                      |
  | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
  | `.editorconfig` | `merged`: giữ dòng ghi chú của kho ở đầu, nhận khối mới của mẫu ở cuối                                                       |
  | `package.json`  | `merged`: nhận một bản sửa thật của mẫu từ bản cũ hơn (`prettier --check --log-level warn`), bản mà 0.6.0 chỉ để nguyên được |
  | `AGENTS.md`     | `marked`: kho và mẫu sửa cùng một dòng; nhãn `this repository`, `repo-setup 0.6.0`, `repo-setup 0.6.1`                       |
  | `wiki/log.md`   | `marked`, `no matching base`: manifest của 0.6.0 không ghi `today`, đúng như thiết kế đã lường                               |

  Ô `check` đỏ; gỡ dấu bằng tay thì xanh, PR gộp được, và đã gộp. Sau đó `doctor` báo
  `setup_in_sync` và `upgrade_wall` đều qua. Có hai điều mà bộ kiểm và e2e không thấy được:

  1. **Bức tường bị che, rồi bị gỡ mất.** Lần đẩy đầu tiên, ô `check` đỏ ở `lint` (Prettier), trước
     khi chạy tới bước `upgrade`. Lời khuyên của nó, `prettier --write`, thụt lề và thoát ký tự cho
     các dấu trong tệp Markdown, nên công cụ dò không còn thấy dấu nào trong `AGENTS.md`; danh sách
     «Next» của `apply.py` cũng có `make format`. **Đã sửa:** `upgrade` chạy đầu tiên trong
     `make check`, `make format` chờ nó, và dấu bị bộ định dạng thụt lề vẫn bị đếm. Mục 47l của bộ
     kiểm. Lần đẩy sau, ô đỏ ở đúng bước `upgrade`, nêu đúng tệp và dòng.
  2. **Mỗi kho cũ có sổ log sẽ đỏ một lần.** `wiki/log.md` luôn bị kho sửa, và gốc của nó không
     dựng lại được khi manifest không ghi `today`. Vì vậy lần nâng RS8 đầu tiên ở mọi kho cài trước
     RS8 đều ghi dấu cả sổ log. Thiết kế đã chấp nhận chi phí này; ở `onehub-inventory` cần dặn
     trước: giữ phần của kho, bỏ phần của mẫu.

  Hai tệp sửa ở bước 3 mang băm của bản dựng thay, nên lần nâng thật kế tiếp của kho thử sẽ không
  tìm được gốc khớp cho chúng.
- **RS2b rộng hơn bản trước.** Ngoài `wiki/`, kho này còn sinh ra tệp cùng dạng: `src/generated/*`
  (mã sinh từ mô hình, 5 đến 8 trên 30 PR chạm), `ontology/glossary.md` và `ontology/labels.yaml`
  (danh sách chung, 7 đến 8). design-assembly cần cùng cơ chế cho sổ linh kiện và bảng vai × màn ×
  nút.
- **Bảng markdown được căn cột là một tệp nóng tự tạo.** `ontology/glossary.md` do mẫu của kho này
  sinh ra là một bảng. Ở `onehub-inventory`, bảy lần sửa gần đây mỗi lần đổi 21 đến 27 dòng trên một
  bảng 34 dòng: thêm một thuật ngữ dài thì bộ định dạng căn lại cả bảng. Phiên Design Assembly thấy
  cùng bệnh ở trang mẫu hành vi và báo sang. RS2b vì thế gồm cả việc đổi dạng của bảng này (mỗi thuật
  ngữ một mảnh, hoặc một dạng không căn cột).
- **RS2b không cần cơ chế đẩy lên nhánh chính.** design-assembly chọn hướng cho DA1 (đề bài 0005 của
  kho đó, chờ chủ kho duyệt): mảnh là nguồn, tệp ở đường dẫn cũ thành vật dẫn xuất không commit,
  lệnh sinh chạy trước cổng. Kho này nên theo cùng hướng cho `wiki/index.md` và `src/generated/*`,
  để hai kho không dựng hai cơ chế. DA1 vì thế không chờ RS2b.
- **Đầu vào từ design-assembly cho RS3 và RS5a đã rõ.** DA2 cấp một lệnh in danh sách màn bị ảnh
  hưởng, khổ màn, hoặc «trọn bộ»; nối lệnh đó vào CI là RS3, và lệnh chạy bài trình duyệt nằm ở
  `mk/design.mk` do kho này giữ. Tường cho khuôn mới và màu gốc: design-assembly dựng phép kiểm
  trong cổng, còn nâng hạng PR trên GitHub là RS5a.
- **RS7 không gồm tường cho tên tệp.** Máy thử kiểm tên tệp bằng từ điển tiếng Anh trên
  `onehub-inventory`: bắt được 38 trên 61 thư mục vòng tên tiếng Việt và báo nhầm 26 trên 277 tên
  trong `src/`. Tiếng Việt không dấu trùng nhiều từ tiếng Anh ngắn, nên phép kiểm này không đủ làm ô
  bắt buộc. Luật tên tệp vì thế được ghi là «giữ bằng lời», và sửa ở nơi tên sinh ra: tên vòng do
  vòng làm việc đặt, rồi lan sang tên thư mục, tên bài kiểm và tên lệnh.
- **RS8 đứng trước bước «chạy trên `onehub-inventory`».** Không có nó, mỗi bản sửa phải có người gộp
  tay vào 34 tệp đã lệch.

**design-assembly**

| Mã  | Gói việc                                                                         | Tiêu chí  |
| --- | -------------------------------------------------------------------------------- | --------- |
| DA1 | Các sổ thiết kế nằm trong tệp nóng (sổ linh kiện, sổ màn, sổ khối, bảng vai × màn × nút): PR không còn phải mang chúng | Nhanh     |
| DA2 | Từ tệp đổi ra màn bị ảnh hưởng, rồi ra bài trình duyệt; khổ màn theo từng màn     | Nguồn lực |
| DA3 | Sổ quyết định thay vai trưởng thiết kế: thêm hàng chờ cho câu mới, phép so tổng, tường cho khuôn mới và màu thương hiệu | Ít người  |

Phiên Design Assembly kiểm ba gói này với mã thật ngày 2026-11-16 (design-assembly tại `75d55cc`,
`onehub-inventory` tại `b6f4f29`). Chưa dựng gì; hướng làm do chủ kho quyết ở kho đó.

**Cập nhật 2026-11-20.** Cả ba gói đã xong ở design-assembly: giai đoạn 8 của `docs/plan/plan.json` ở
kho đó, đóng ngày 2026-11-18. `onehub-inventory` nhận qua PR 84 (17/11) và PR 86 (18/11). Để lại,
không hàng nào giữ: `design/behaviors.md` chưa tách mảnh, và phép đo lại sau 30 PR chưa chạy. Các
nhận xét dưới đây là của ngày 16/11.

- **DA1 đúng với hai trên ba tệp.** Sổ linh kiện là vật dẫn xuất mà vẫn commit: `make check` đỏ khi
  sổ lệch mã, nên PR nào đụng linh kiện cũng phải ghi lại tệp. Sổ màn là một danh sách chung, thêm
  mỗi màn một mục. Vướng: vòng nghiệm thu đang đọc đúng đường dẫn của sổ linh kiện, nên bỏ tệp khỏi
  PR cần một đường chuyển tiếp không đụng delivery-loop.
- **`design/so-khoi.yaml` hôm nay chưa thuộc design-assembly.** Hợp đồng sổ của kho đó không có nó;
  phiên Repo-standards tìm cả kho design-assembly cũng không thấy tên tệp này. Vòng làm việc ghi nó,
  `tools/proof_gate` của `onehub-inventory` đọc nó. Chủ của nó xếp theo luật bên dưới.
- **DA2 đã có một nửa nền.** Bài trình duyệt đã sinh theo màn và trạng thái, sổ màn có mã và đường
  dẫn. Thiếu phép tính từ tệp đổi ra màn bị ảnh hưởng; khổ màn hiện là một danh sách chung.
- **DA3 đã có một phần.** Sổ quyết định 55 dòng, 49 dòng có lệnh kiểm, và có lệnh ghi lời đáp của
  chủ kho để không hỏi lại. Thiếu ba thứ: đường cho tác tử đang dựng đẩy câu mới vào hàng chờ thay
  vì hỏi giữa chừng; phép so tổng «mọi lựa chọn trỏ về một dòng sổ»; và tường cho «khuôn mới, màu
  thương hiệu phải hỏi».
- **Hai tệp nóng nữa** chưa ai nhận: `design/behaviors.md` (8 trên 30 PR) và `design/vai-man-nut.md`
  (6).

**Luật xếp chủ cho tệp chưa ai nhận (chủ kho chốt ngày 2026-11-16):** liên quan thiết kế thì về
design-assembly, không thì về delivery-loop. Máy áp luật đó cho ba tệp trên, đọc đầu tệp ở
`onehub-inventory` tại `b6f4f29`; cả ba về design-assembly, kho đó xác nhận khi nhận:

| Tệp                     | Nó là gì                                                                            | Về kho          |
| ----------------------- | ----------------------------------------------------------------------------------- | --------------- |
| `design/so-khoi.yaml`   | Sổ khối: khối giao diện đã chọn từ ReUI hoặc tự làm. Cổng chứng minh màn đọc nó     | design-assembly |
| `design/behaviors.md`   | Mẫu hành vi: câu trả lời đóng cho việc lặp lại, mỗi mục có nguồn trong sổ quyết định | design-assembly |
| `design/vai-man-nut.md` | Bảng vai × màn × nút, máy sinh từ sổ thao tác, sổ màn và nút trong mã               | design-assembly |

Hai điều kéo theo. Sổ khối có hai cột do vòng làm việc ghi (hồ sơ nhận khối và ngày duyệt), nên
khi chuyển chủ phải giữ luật «mỗi sổ một bên ghi». Bảng vai × màn × nút là vật dẫn xuất mà vẫn
commit, cùng dạng với sổ linh kiện.

Thứ design-assembly có thể cần ở kho này, sơ bộ: cơ chế vẽ lại tệp tổng hợp trên nhánh chính, dùng
chung với `wiki/index.md` (RS2); ô trình duyệt nhận danh sách màn hoặc bài để chạy (RS3); tường nâng
hạng cho PR đụng khuôn hay dòng màu thương hiệu (RS5). DA2 không cần RS4.

**delivery-loop**

| Mã  | Gói việc                                                                                              | Tiêu chí            |
| --- | ----------------------------------------------------------------------------------------------------- | ------------------- |
| DL1 | Không ghi tệp tổng hợp trong PR: bản đồ sản phẩm và lộ trình vẽ lại trên nhánh chính; lệnh kiểm về hồ sơ từng vòng | Nhanh               |
| DL2 | Bằng chứng tính theo đầu vào: chỉ cũ khi đầu vào của hàng đổi; commit chữ ký không kéo một vòng CI     | Nhanh, nguồn lực    |
| DL3 | Máy thôi chạy trọn bộ mỗi lượt chấm; bằng chứng hồi quy đọc từ GitHub; cấp ô bằng chứng với tên khác `gate` | Nguồn lực, ít người |
| DL4 | Điều phối đọc bản đồ phạm vi để xếp vòng nối tiếp hay song song                                       | Nhanh               |
| DL5 | Sổ giới hạn có ngưỡng theo lớp, có hạn, đo sự quay lại; mặc định định tuyến cho mục ngoài hợp đồng     | Ít người, tin cậy   |
| DL6 | Phiên giám sát đọc bản uỷ quyền thay lời dặn; mỗi quyết định ghi sự kiện kèm tên quyền                 | Ít người            |

**Đọc lại 2026-11-20.** Kế hoạch của chính delivery-loop mang các gói này tới đâu: xem mục 9 của
[truy nguyên từ quyết đến gộp](reports/2026-11-20-decision-to-merge-trace.md). Tóm tắt: DL1 và DL2 có
từng mảnh đã giao ở dạng tuỳ chọn, DL4 đã giao ở dạng «vùng», DL3 và DL5 không có, DL6 là một issue
còn mở. Kho đó không có hàng nào xếp sau bản 3.0.

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
mình (`wiki/` và các sổ trong `design/`); `LO-TRINH.html`, `PRODUCT-MAP.md` và
`_acceptance/config.yaml` còn nguyên cho tới DL1, nên phần lớn mức giảm va chạm đến sau bước 3.

Đợt 5 có thể khai sớm hơn vì nó không phụ thuộc đợt nào; nó xếp sau vì các đợt trước dịch chuyển số
đo nhiều hơn. Mọi mức lợi là ước tính từ số đo ở mục 2, chưa đợt nào được thử.

### Rà lại kế hoạch (2026-11-16)

Bảng đợt ở trên viết trước khi có số xung đột thật và trước khi biết thứ tự theo kho. Bảy điều lệch:

1. **Đợt 2 không trả công nếu thiếu delivery-loop.** Kỳ vọng «va chạm từ 100% về 37%» chỉ đúng khi
   cả ba kho cùng gỡ. Hai kho đi trước gỡ xong thì còn 73 trên 93 lần gộp ngược xung đột; đòn lớn
   nhất nằm ở kho đi sau cùng.
2. **Có một bước rẻ chưa được tính:** RS2a, một dòng mẫu, bỏ 60 lần xung đột ở `wiki/log.md`.
3. **RS4 chưa có bên đọc.** DA2 không cần nó; DL2 và DL4 chờ delivery-loop chuyển nhà. Dựng bây giờ
   là dựng trước khi cần.
4. **RS5 chỉ có bên đọc cho một phần:** tường cho biên thiết kế (RS5a). Khe uỷ quyền đầy đủ (RS5b)
   chờ DL6.
5. **Bước «chạy trên `onehub-inventory`» chưa có đường đi** (gốc rễ 5): thiếu RS8.
6. **Chưa có thước lặp lại được.** Mọi số ở mục 2 do máy đo tay một lần. Không có RS10 thì không đợt
   nào chứng minh được là đã dịch chuyển số đo.
7. **RS6 xếp cuối là sai thứ tự.** Lỗi đặt tên tệp trong buổi này xảy ra vì luật chưa được ghi ở kho
   này. Phần ghi luật (RS9) rẻ và nên đi trước.

Thứ tự đề xuất cho Repo Standards, thay cột của kho này trong bảng đợt:

| Bước | Gói việc             | Vì sao ở đây                                                   | Xong là gì                                                         |
| ---- | -------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------ |
| A    | RS1 (gộp PR 14), RS9 | Đã dựng; và kho phải giữ luật của mình trước khi dạy tiếp      | Ba workflow chạy thật trên một kho thử; bốn tệp có tên tiếng Anh   |
| B    | RS2a, RS10           | Rẻ nhất, đo được ngay; có thước rồi mới chấm được các bước sau | `wiki/log.md` hết xung đột khi phát lại; lệnh in đủ các dòng mục 2 |
| C    | RS8                  | Điều kiện để mọi bản sửa tới được `onehub-inventory`           | Kho thử có tệp sửa tại chỗ vẫn nhận được bản sửa của mẫu           |
| D    | RS2b, RS3            | Phần cấu trúc; dùng chung với DA1 và DA2                       | PR không mang tệp dẫn xuất; tầng nặng chỉ chạy khi PR sẵn sàng     |
| E    | RS7, RS5a            | Luật có máy giữ hoặc khai là lời                               | Bài kiểm đỏ khi thêm luật không có chủ                             |
| F    | RS4, RS5b            | Chỉ khi delivery-loop chuyển nhà xong và sẵn sàng đọc          | Có bên đọc dùng thật                                               |

Bước A đến C không phụ thuộc kho nào khác. Bước D nên đi cùng nhịp với design-assembly. Sau bước C
mới chạy trên `onehub-inventory`.

**Cập nhật 2026-11-21.** Bước F chỉ còn RS5b. RS4 đã đóng: delivery-loop trả lời rằng kit không đọc
`architecture/modules.yaml` và không cần gói này; RS5b chờ một ADR ở kit, chưa có lịch. Nguồn: nhánh
`chuyen-nha` của delivery-loop, `migration/KE-HOACH-12-MUC-REPO-STANDARDS.md` mục 5 (commit `f575b7fc`).

## 9. Rủi ro và giới hạn đã biết

- **GitHub không ép được «chỉ gộp qua lệnh gộp».** Lệnh gộp của gói `dieu-phoi` đòi mọi ô xanh,
  nhưng một phiên gọi thẳng `gh pr merge` chỉ bị chặn bởi các ô bắt buộc. RS1 thu hẹp khoảng này.
- **Ô bị bỏ qua được tính là xanh**, ở cả GitHub lẫn lệnh gộp. Xếp tầng CI (RS3) phải có một ô tổng
  luôn chạy, nếu không tầng nặng bị bỏ qua sẽ lọt.
- **Chọn bài có thể bỏ sót.** Chiều từ tệp đổi ra màn lần được tĩnh, từ đồ thị `import` của tệp
  trang; chiều từ bài ra màn lấy từ mã và đường dẫn trong sổ màn. Phần không lần được (dữ liệu, CSS
  toàn cục, khung) phải khai tay, và không biết thì chạy trọn bộ. Bộ có cơ sở dữ liệu phụ thuộc cả
  lược đồ lẫn mã nên bớt được ít hơn.
- **Gom ba quyền vào một phiên.** Phiên giám sát vừa sắp lộ trình, vừa theo dõi tiến độ, vừa gộp.
  Biên tối thiểu là ba điều cuối mục 5.
- **Một người quyết.** Chủ kho vắng thì mọi mục «phải hỏi» đứng lại. Danh sách đó vì thế phải ngắn.
- **Phần DA do phiên khác kiểm.** Nhận định ở cuối mục 7 là báo cáo của phiên Design Assembly.
  Phiên Repo-standards chỉ tự kiểm lại hai điều: kho design-assembly không nhắc tới `so-khoi.yaml`,
  và hợp đồng sổ của nó có sổ linh kiện và sổ màn.
- **Chưa đo phía Máy.** Thời gian chấm, token và lượt gọi người lấy từ lời báo cáo của phiên làm
  việc, chưa được kiểm.
- **Luật gộp kiểu hợp mới thử ở máy.** Phép phát lại dùng git tại chỗ, đúng nơi các phiên gộp nhánh
  chính vào nhánh. GitHub có theo luật đó khi tự tính «có xung đột» hay không thì chưa kiểm.
- **Cách xếp 16 luật của `AGENTS.md`** thành «máy giữ» và «lời» là do máy đọc và xếp, chưa đối
  chiếu từng luật với một bài kiểm chiều đỏ. RS7 (2026-11-18) đã thay cách xếp đó bằng nhãn trên
  từng mục; nhãn «máy giữ» chỉ hợp lệ khi bộ kiểm có một bài phạm luật và thấy máy phản ứng. Xem
  [thiết kế RS7](superpowers/specs/2026-11-18-rule-kinds-design.md).
- **Số xung đột phát lại không dùng luật gộp riêng của kho thật** cho `PRODUCT-MAP.md`, nên 45 lần
  ở tệp đó cao hơn thực tế.

## 10. Điều còn mở cho chủ kho

1. Ngưỡng tỉ lệ lỗi chấp nhận. Máy gợi ý: đỏ muộn 20%, nhánh chính đỏ 1 trên 20. Chủ kho chọn ngày
   2026-11-21: ngưỡng chỉ là một dòng trong báo cáo của `tools/sdlc_metrics.py`, không đổi mã thoát.
   Ba giá trị khởi đầu là hai số trên và «một tệp chiếm quá nửa số lần gộp ngược xung đột», với mẫu
   tối thiểu 20; chưa giá trị nào được suy ra từ dữ liệu.
2. Tên và chỗ đặt tệp uỷ quyền. Máy gợi ý: trong `governance/` của kho tiêu thụ. Trả lời của
   delivery-loop ngày 2026-11-21: ở `governance/` của kho dùng, kit chỉ đọc; cần một ADR ở kit trước.
3. Kho nào giữ phép so của từng bất biến ở mục 5.
4. Có bắt buộc cả chín ô trên GitHub không, hay chỉ các ô kho khai là tường.
5. Khoá bật lối gộp nhanh của gói `dieu-phoi` có đang bật ở `onehub-inventory` không. Đọc ngày
   2026-11-20: chưa bật; không tệp nào ở kho đó nêu khoá `gop_khong_chay_lai_ci`.
6. Đã chốt: tệp chưa ai nhận thì theo luật ở cuối mục 7. Còn mở: design-assembly xác nhận nhận ba
   tệp, và cách chuyển sổ khối mà không sửa delivery-loop trước khi kho đó chuyển nhà xong.
7. Thứ tự A đến F cho Repo Standards ở cuối mục 8.
8. Đã chốt và đã làm: RS9. `CLAUDE.md` ghi luật tên tiếng Anh; bốn tệp tài liệu đã đổi tên. Nhánh
   `claude/thiet-ke-tong-quan-ba-kho` giữ tên cũ vì PR 14 đang mở trên nó.
9. Một kho thử trên GitHub để chạy thật ba workflow của RS1 trước khi gộp PR 14.

## Nguồn

- delivery-loop, `CLAUDE.md`: North Star, năm dòng số, luật dừng (đọc ngày 2026-11-16, nhánh
  `chuyen-nha`).
- delivery-loop, `dieu-phoi/scripts/gop.mjs`: luật «mọi ô xanh», lối gộp nhanh khi không trùng tệp.
- delivery-loop, `docs/research/known-limits-ledger.tsv`: sổ giới hạn đã biết, bản ngày 2026-11-15.
- `onehub-inventory`: 83 lượt CI từ 15/11, 30 PR gộp gần nhất, năm tệp workflow, ruleset của nhánh
  chính, đọc qua GitHub ngày 15–16/11.
- Phép thử `secret-scan`: cấy một token giả vào bản clone tạm; lệnh của móc báo 0 commit được
  quét, hai lệnh quét đối chứng đều bắt được.
- Phát lại gộp ngược: 30 PR gộp gần nhất của `onehub-inventory`, 99 commit gộp nhánh chính vào
  nhánh, `git merge-tree --write-tree` trên hai cha của từng commit; chạy lại với luật gộp kiểu hợp
  cho hai tệp `wiki/`.
- `onehub-inventory`, `.repo-setup.json` ở nhánh chính: bản 0.4.0, 81 tệp ghi băm; so băm với tệp
  hiện có: 38 nguyên, 34 đã sửa, 9 đã bỏ.
- design-assembly, đề bài 0005 «ledgers stop riding pull requests» và quyết định 0048, nhánh
  `docs/ledgers-stop-riding-pull-requests` tại `9ab2d54` (chưa đẩy, đọc trên máy ngày 2026-11-16).
- `onehub-inventory`, 12 commit gần nhất chạm `ontology/glossary.md`: số dòng thêm và bớt của tệp đó
  trong từng commit.
- Phép thử tên tệp: tách tên thành từ, tra `/usr/share/dict/words` cộng một danh sách từ kỹ thuật.
- Chủ kho, buổi thảo luận ngày 2026-11-16: bốn tiêu chí, «gộp là phải xanh», sáu biên uỷ quyền,
  «chỉ mình tôi quyết».
