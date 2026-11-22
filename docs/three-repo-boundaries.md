# Ranh giới ba kho: Repo Standards, design-assembly, delivery-loop

Ngày: 2026-11-14. Trạng thái: chủ kho đã chốt phần «bảng vai × màn × nút» cùng ngày («Tách ba
phần»). Phần còn lại chép từ các quyết định đã có, ghi ở mục Nguồn. Mục «UX: kho nào mang gì» thêm
ngày 2026-11-15, do máy xếp. Trang này chỉ nói việc nào ở kho nào; cách làm từng việc nằm ở kho đó.
Vấn đề đang gặp và hướng đi chung của ba kho xem
[thiết kế tổng quan](three-repo-overview-design.md).

## Mỗi kho trả lời một câu

|                | Repo Standards                                           | design-assembly                                           | delivery-loop                                  |
| -------------- | -------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------- |
| Khi nào        | Lúc dựng repo, và mỗi khi thêm khái niệm nghiệp vụ       | Sau khi có nền, và ở repo đã có sẵn                       | Mỗi vòng tính năng                             |
| Trả lời câu    | Repo có gì, nghĩa là gì, ai được làm gì                  | Người dùng nhìn thấy gì, màn ứng xử thế nào               | Lần này làm gì, đã làm đúng chưa               |
| Giữ sổ nào     | Thực thể, thuộc tính, quan hệ, thao tác, vai             | Sổ màn, trạng thái, linh kiện, khuôn, quyết định thiết kế | Không giữ. Chỉ đọc sổ của hai kho kia          |
| Không làm      | Không giữ thứ gì thuộc thiết kế; chỉ gọi design-assembly | Không chấm từng vòng                                      | Không bê từ điển nghiệp vụ hay giá trị về mình |

Chiều đọc đi một hướng: delivery-loop đọc cả hai; design-assembly đọc mô hình nghiệp vụ của Repo
Standards; Repo Standards không đọc sổ của ai. Mỗi sổ chỉ có một bên được ghi. Từ ngày 2026-11-22
Repo Standards gọi design-assembly (mục cuối «Việc đã làm»), và `doctor` chỉ xem sổ lúc ra đời có mặt
không và dấu bản công cụ ghi bản nào, để chỉ tới lệnh của plugin; nó không đọc nội dung sổ.

## Phép thử khi đặt một việc mới

1. Nó là phán xét của một vòng, hay là sự thật đứng yên của repo? Của một vòng thì về
   delivery-loop.
2. Đứng yên: nó nói về nghĩa (Repo Standards) hay về thứ nhìn thấy (design-assembly)?
3. Phép kiểm nối hai sổ đặt ở bên đọc, tức bên đứng sau trong chiều đọc.

## Bảng vai × màn × nút, tách ba phần

| Phần                                                                                                              | Kho             |
| ----------------------------------------------------------------------------------------------------------------- | --------------- |
| Mỗi thực thể đủ thêm, xem, sửa, bỏ cho từng vai; trạng thái của bản ghi; quan hệ có «gỡ» và «đổi»; dấu «dự kiến»  | Repo Standards  |
| Màn hiện thứ gì, có nút nào, nút đặt ở đâu; vai không có quyền thì không thấy; bài kiểm trình duyệt theo vai      | design-assembly |
| Hàng không được bỏ quét vòng đời; thao tác bị loại phải thành câu hỏi; câu giao một động từ; thứ «dự kiến» có chủ | delivery-loop   |

## UX: kho nào mang gì

Máy xếp ngày 2026-11-15, theo phép thử ở trên; chủ kho bảo ghi vào trang này cùng ngày. Hàng «Nên
mang thêm» là đề xuất: mỗi việc vẫn chờ chủ kho cho phép ở kho đó.

UX sai theo ba kiểu, mỗi kiểu thuộc một kho:

- **Thiếu** (không có nút, không có màn): lỗi về nghĩa. Repo Standards giữ.
- **Lệch** (có nhưng đặt sai chỗ, mỗi màn một kiểu, vai không có quyền vẫn thấy): lỗi về thứ nhìn
  thấy. design-assembly giữ.
- **Sai việc** (làm đúng thứ không ai cần, hoặc máy tự bỏ một thao tác): phán xét của một vòng.
  delivery-loop giữ.

|               | Repo Standards                                                                                                                                          | design-assembly                                                                                         | delivery-loop                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Câu hỏi UX    | Ai làm được gì, với thứ gì                                                                                                                              | Thứ đó hiện ở đâu, trông và ứng xử thế nào                                                              | Lần này làm gì, đã đúng và đáng chưa                                                                               |
| Đang có       | Thực thể, thuộc tính, quan hệ, thao tác, vai; phép kiểm «mỗi thực thể đủ thêm, xem, sửa, bỏ»                                                            | Bảy tầng quyết định, bảng trạng thái của màn, luật sau một thao tác, sổ màn, sổ chữ, sổ lỗi lọt         | Bốn cổng người, bản đặc tả UX ở Cổng Phạm vi, bước quét cho đủ, phiên thiết kế trên bản bấm được, phiên nghiệm thu |
| Nên mang thêm | Quan hệ có gắn, gỡ, chuyển; phạm vi «của tôi» đòi một quan hệ đã khai; thao tác sửa nêu thuộc tính; thao tác theo trạng thái của bản ghi; dấu «dự kiến» | Sổ màn nối với mô hình nghiệp vụ; bài kiểm trình duyệt theo vai; một thực thể hiện giống nhau ở mọi màn | Đọc hai cuốn sổ kia thay vì khai lại; ba luật của vòng ở dưới                                                      |
| Không mang    | Màn, vị trí nút, luồng                                                                                                                                  | Nghĩa nghiệp vụ, điểm chấm từng vòng                                                                    | Giá trị đứng yên nào                                                                                               |

### Ba chỗ đang lệch

1. **delivery-loop khai lại thứ design-assembly giữ.** Bản đặc tả UX của mỗi tính năng tự kê màn và
   bảng trạng thái. Tìm cả kho delivery-loop ngày 2026-11-15 (nhánh `chuyen-nha`, bản 12/11): không
   tệp nào đọc sổ màn hay bảng trạng thái của design-assembly, không tệp nào nêu tên kho đó. Cùng
   một điều có hai nơi ghi, trái luật «mỗi sổ một bên ghi». Phép đo máy cho bản đặc tả ấy đã bị cắt
   ngày 24/08 vì phải dò chữ trên văn bản; trỏ vào dòng của sổ màn thì đo được mà không dò chữ.
2. **Phần nghĩa của quan hệ, thuộc tính, trạng thái chưa ai nhận.** Ba thao tác thiếu ở
   onehub-inventory mà hai phép kiểm hiện có không thấy đều nằm ở đây:
   - «Nhận căn chưa ai giữ» và «đổi người giữ căn»: mô hình không khai quan hệ nào giữa thành viên
     và căn, trong khi ba thao tác đã dùng phạm vi «của tôi» trên căn. Phép kiểm chỉ soi quan hệ đã
     khai sẽ không bắt được; dấu máy đọc được là phạm vi «của tôi» không có quan hệ đứng sau.
   - «Sửa thông tin căn ngoài giá»: căn khai pháp lý, tài chính, nội thất, tình trạng sử dụng,
     nhưng chỉ có một thao tác sửa tả chung «giá, phí hoặc chi tiết».

   Phần của design-assembly cho hai việc này chờ phần nghĩa ở kho này. Phần nghĩa đã dựng ngày
   2026-11-15 (xem cuối trang): cả ba giờ làm mô hình đỏ; hai thao tác về người giữ căn đỏ qua hai
   bước, xem mục 4 của bản thiết kế.

3. **Ba luật của vòng chưa vào delivery-loop.** Báo cáo RS2 quy khoảng 14 trên 19 ô thiếu cho bước
   thiết kế, không cho sổ nào:
   - hàng có màn không được bỏ bước quét vòng đời;
   - câu giao một động từ phải kê đủ thêm, sửa, bỏ, hoặc nói vế nào để hàng nào;
   - thao tác máy định loại phải thành câu hỏi cho người, có cột «ai quyết».

### Khung UX đặt ở đâu

| Khung                                                                | Chữa kiểu lỗi | Kho                                        |
| -------------------------------------------------------------------- | ------------- | ------------------------------------------ |
| OOUX/ORCA, phần nghĩa: đối tượng, quan hệ, việc làm được, thuộc tính | Thiếu         | Repo Standards                             |
| OOUX/ORCA, phần thể hiện: đối tượng hiện ở màn nào, giống nhau không | Lệch          | design-assembly                            |
| Hook, và các khung về giá trị hay thói quen                          | Sai việc      | delivery-loop, ở Cổng Đáng và Cổng Giá trị |

Khung khác xếp bằng phép thử ở trên.

### Thứ tự

1. Repo Standards: quan hệ, thuộc tính, trạng thái. Hai kho kia đọc từ đây.
2. design-assembly: sổ màn nối với mô hình (đề bài 0003, chủ kho duyệt và đã xây ngày
   2026-11-15), rồi phần quan hệ và thuộc tính bên nhìn thấy.
3. delivery-loop: đọc hai sổ kia, và ba luật của vòng.

## Việc đã làm và chưa làm ở kho này

- Đã làm (gộp vào nhánh chính ngày 2026-11-15): phép kiểm «mỗi thực thể đủ bốn câu trả lời», xem
  [thiết kế](superpowers/specs/2026-11-14-entity-lifecycle-design.md).
- Đã làm (PR 11, gộp vào nhánh chính ngày 2026-11-15, phát hành ở 0.6.0): phạm vi «của tôi» đòi
  một quan hệ đã khai; mỗi quan hệ trả lời gắn, gỡ, chuyển; mỗi thuộc tính có thao
  tác đặt giá trị hoặc có lý do. Xem
  [thiết kế](superpowers/specs/2026-11-15-relations-and-attributes-design.md), mục 4 có số đo trên
  onehub-inventory.
- Chưa làm: trạng thái của bản ghi và bước chuyển; luật khi xoá một đầu của quan hệ; dấu «dự kiến»
  cho thao tác; một thao tác xem nêu nhiều thực thể; đưa «của tôi» vào mã sinh ra; móc chạy phép
  kiểm sau mỗi lần sửa.
- Đã làm (ngày 2026-11-22, lát 3 của đề bài 0013 bên design-assembly): lời gọi. Kỹ năng `new` đặt bộ
  sổ lúc ra đời qua `/design-assembly:adopt --starter` khi lớp `design` bật, rồi mời đi tiếp
  `/design-assembly:new`; `adopt` gọi `audit` rồi `adopt` của plugin ở kho đã có; `doctor` nêu sổ lúc ra
  đời thiếu và dấu bản công cụ tụt; `.claude/settings.json` của kho có lớp `design` bật plugin. Xem
  [hợp đồng mối nối](seam-contracts.md), mục 6 đến 8. Chưa thử với hai plugin thật: đó là lượt thử cuối
  của đề bài, bên design-assembly.
- Sàn chưa chuyển: sàn thiết kế (`capabilities/design`), câu hỏi màu thương hiệu và loại bề mặt vẫn ở
  đây, đúng như đề bài 0013 chốt (câu 5). Chúng sẽ chuyển đi khi design-assembly sẵn sàng nhận; khi đó
  Repo Standards chỉ còn lời gọi. Không xây thêm lên phần này.

Hai kho kia chưa nhận phần của mình: đây là đề xuất gửi sang, mỗi việc chờ chủ kho cho phép ở kho
đó.

## Nguồn

- design-assembly, quyết định 0005 «Đầu ra theo bậc; ranh giới với hai kho bên cạnh» (duyệt
  2026-11-12) và 0030 «Một sổ màn» (2026-11-14).
- design-assembly, đề bài 0002 «Lớp meta cho nhiều kho», mục Intent: ba điều chủ kho chốt ngày
  2026-11-13.
- delivery-loop, kế hoạch chuyển nhà, mục 6 «Đồng bộ với Repo Standards» (2026-11-11).
- onehub-inventory, báo cáo rà soát RS2 ngày 2026-11-14: 7 thao tác thiếu thật, 5 chỉ hứa trên
  giấy, 7 do máy tự loại.
- design-assembly, đề bài 0003 «Sổ màn nối với mô hình nghiệp vụ» (nhánh
  `claude/so-man-noi-mo-hinh-95de70`; chủ kho duyệt ngày 2026-11-15, phép kiểm đã xây trên nhánh
  đó): số đo trên onehub-inventory.
- onehub-inventory, mô hình nghiệp vụ ở nhánh chính `20a13c2`, đọc ngày 2026-11-15: sổ quan hệ, sổ
  thao tác, thực thể `Listing`.
- delivery-loop, hồ sơ «Bản đặc tả UX» (`dac-ta-ux-vat-hoa-cau-truc`): phép đo máy cắt ngày
  2026-08-24.
