# Ranh giới ba kho: Repo Standards, design-assembly, delivery-loop

Ngày: 2026-11-14. Trạng thái: chủ kho đã chốt phần «bảng vai × màn × nút» cùng ngày («Tách ba
phần»). Phần còn lại chép từ các quyết định đã có, ghi ở mục Nguồn. Trang này chỉ nói việc nào ở
kho nào; cách làm từng việc nằm ở kho đó.

## Mỗi kho trả lời một câu

|                | Repo Standards                                           | design-assembly                                           | delivery-loop                                  |
| -------------- | -------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------- |
| Khi nào        | Lúc dựng repo, và mỗi khi thêm khái niệm nghiệp vụ       | Sau khi có nền, và ở repo đã có sẵn                       | Mỗi vòng tính năng                             |
| Trả lời câu    | Repo có gì, nghĩa là gì, ai được làm gì                  | Người dùng nhìn thấy gì, màn ứng xử thế nào               | Lần này làm gì, đã làm đúng chưa               |
| Giữ sổ nào     | Thực thể, thuộc tính, quan hệ, thao tác, vai             | Sổ màn, trạng thái, linh kiện, khuôn, quyết định thiết kế | Không giữ. Chỉ đọc sổ của hai kho kia          |
| Không làm      | Không giữ thứ gì thuộc thiết kế; chỉ gọi design-assembly | Không chấm từng vòng                                      | Không bê từ điển nghiệp vụ hay giá trị về mình |

Chiều đọc đi một hướng: delivery-loop đọc cả hai; design-assembly đọc mô hình nghiệp vụ của Repo
Standards; Repo Standards không đọc ai. Mỗi sổ chỉ có một bên được ghi.

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

## Việc đã làm và chưa làm ở kho này

- Đã làm (nhánh `feat/entity-lifecycle`): phép kiểm «mỗi thực thể đủ bốn câu trả lời», xem
  [thiết kế](superpowers/specs/2026-11-14-entity-lifecycle-design.md).
- Chưa làm: trạng thái của bản ghi và bước chuyển; quan hệ có «gỡ» và luật khi xoá; dấu «dự kiến»
  cho thao tác; móc chạy phép kiểm sau mỗi lần sửa.
- Sẽ chuyển đi khi design-assembly sẵn sàng nhận: sàn thiết kế (`capabilities/design`), câu hỏi màu
  thương hiệu và loại bề mặt. Repo Standards khi đó chỉ còn một lời gọi. Không xây thêm lên phần
  này.

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
