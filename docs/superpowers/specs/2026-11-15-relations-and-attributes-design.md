# Thiết kế: quan hệ và thuộc tính không còn được im lặng

Ngày: 2026-11-15. Trạng thái: đã dựng trên nhánh `claude/relations-and-attributes-1dd820`, chờ chủ
kho xem. Áp dụng cho plugin `repo-setup`. Ranh giới với hai kho bên cạnh:
[ranh giới ba kho](../../three-repo-boundaries.md). Nối tiếp
[mỗi thực thể đủ bốn câu trả lời](2026-11-14-entity-lifecycle-design.md).

## 1. Ý định

Báo cáo RS2 ở onehub-inventory đếm 7 thao tác thiếu thật trên màn. Phép kiểm vòng đời ở kho này và
phép kiểm «sổ màn nối với mô hình» ở design-assembly cùng nhau thấy 4. Ba thao tác còn lại nằm ở hai
chỗ mô hình chưa nói:

- «Nhận căn chưa ai giữ» và «đổi người giữ căn»: ba thao tác dùng phạm vi «của tôi» trên căn, mà mô
  hình không khai quan hệ nào giữa thành viên và căn. Không có quan hệ thì không ai hỏi được «gắn,
  gỡ, chuyển ở đâu?».
- «Sửa thông tin căn ngoài giá»: có một thao tác sửa tả chung, nên trên giấy căn «đã có sửa». Không
  thao tác nào nói nó chạm thuộc tính nào.

Cùng một gốc với lần trước: thứ chưa từng khai thì không phép kiểm nào thấy thiếu.

## 2. Hành vi

Cả ba phép kiểm chỉ chạy khi repo có `ontology/actions.yaml`, giống phép kiểm vòng đời.

### 2.1. Phạm vi «của tôi» đòi một quan hệ

Thao tác nói vai nào chỉ được làm trên thứ của mình bằng `own: [<vai>, ...]`, đặt cạnh `roles`. Cách
viết của onehub-inventory, `scope: { <Vai>: own }`, được đọc y nguyên. Quan hệ nói «của tôi» nghĩa
là gì bằng `own: true`.

| Mô hình                                                                   | Phép kiểm |
| ------------------------------------------------------------------------- | --------- |
| Có quan hệ `own: true` mà thực thể của thao tác là một trong hai đầu      | Xanh      |
| Có quan hệ `own: true` chạm thực thể cha (`lifecycle.via` của thực thể)   | Xanh      |
| Không có quan hệ nào như vậy                                              | Đỏ        |
| `own` nêu một vai không có trong `roles`, hoặc thao tác không có `entity` | Đỏ        |
| `own` trên quan hệ không phải `true` hay `false`                          | Đỏ        |

Tính cả hai đầu của quan hệ, nên thao tác «xem vai của chính mình» trên thực thể giữ vai tự xanh
ngay khi thực thể đó có một quan hệ `own`.

### 2.2. Mỗi quan hệ trả lời gắn, gỡ, chuyển

Ba câu: `attach` (gắn), `detach` (gỡ), `reassign` (chuyển sang đầu khác). Một câu trả lời là một
thao tác khai `relations: { <tên quan hệ>: [attach, ...] }`, hoặc một dòng dưới `lifecycle:` của
chính quan hệ đó trong `ontology/relations.yaml`:

| Dòng                                      | Nghĩa                                              | Phép kiểm          |
| ----------------------------------------- | -------------------------------------------------- | ------------------ |
| `{ later: <ở đâu> }`                      | Sẽ làm, ghi rõ ở đâu                               | Xanh, nhắc mỗi lần |
| `{ never: <lý do>, decided_by: <người> }` | Không bao giờ có, một người đã quyết               | Xanh, im           |
| `lifecycle: { via: <Thực thể> }`          | Gắn lúc thực thể đó ra đời, mất theo nó, không đổi | Xanh, im           |
| Không có gì                               | Chưa ai trả lời                                    | Đỏ                 |

Quan hệ nhiều-nhiều chỉ bị hỏi gắn và gỡ. `via` phải là một trong hai đầu của quan hệ. Quan hệ ghi
`via` mà lại có thao tác gắn, gỡ hay chuyển nó thì đỏ: hai điều đó trái nhau.

### 2.3. Mỗi thuộc tính có thao tác đặt giá trị

Thao tác nói nó chạm thuộc tính nào bằng `sets: [<thuộc tính>, ...]`. Thao tác thêm hoặc sửa không
ghi `sets` thì các ô nhập trùng tên thuộc tính được tính. Thuộc tính không thao tác nào chạm thì
thực thể ghi lý do dưới `not_set:`:

| Dòng                                                        | Nghĩa                                      | Phép kiểm          |
| ----------------------------------------------------------- | ------------------------------------------ | ------------------ |
| `system: [id, version, createdAt]`                          | Máy tự ghi, hoặc tính ra từ thứ khác       | Xanh, im           |
| `import: [externalCode]`                                    | Chỉ một lần nhập tệp ghi nó                | Xanh, im           |
| `later: { <thuộc tính>: <ở đâu> }`                          | Sẽ làm, ghi rõ ở đâu                       | Xanh, nhắc mỗi lần |
| `never: { <thuộc tính>: { reason: ..., decided_by: ... } }` | Người không bao giờ sửa, đã có người quyết | Xanh, im           |
| Không có gì                                                 | Chưa ai trả lời                            | Đỏ                 |

Phép kiểm áp dụng cho thực thể có ít nhất một thao tác thêm hoặc sửa. Thực thể sống theo cha
(`lifecycle: { via: ... }`) được bỏ qua.

### 2.4. Chung cho cả ba

- Câu báo đỏ nêu tên thứ đang thiếu và mọi cách sửa, để tác tử đọc xong là làm được. Mỗi quan hệ và
  mỗi thực thể chỉ một câu, kê hết những gì còn thiếu.
- Dòng đã ghi mà nay có thao tác làm việc đó thì được nhắc là đã cũ, không đỏ.
- `never` thiếu `decided_by` thì đỏ. Tác tử không tự điền `decided_by`.
- Tên quan hệ, tên thuộc tính, tên việc viết sai đều đỏ ngay, kể cả trong dòng ghi lý do: đổi tên
  một thuộc tính mà quên một chỗ sẽ không lọt.

### 2.5. Tên khoá và hình dạng

Bên đọc (design-assembly, delivery-loop) đọc đúng các khoá này. Mọi khoá đều tuỳ chọn.

Trên một thao tác, trong `ontology/actions.yaml`:

```yaml
- name: claimListing
  entity: Listing
  kind: update
  roles: [ListAgent, TeamLead]
  own: [ListAgent] # danh sách tên vai, mỗi vai phải có trong `roles`
  relations: { keeps: [attach, reassign] } # tên quan hệ -> một việc, hoặc danh sách việc
  sets: [listPrice, fees] # danh sách tên thuộc tính của `entity`
```

Dạng của onehub-inventory, `scope: { ListAgent: own, TeamLead: company }`, được đọc thay cho `own`:
vai nào có giá trị `own` là vai «của tôi».

Trên một quan hệ, trong `ontology/relations.yaml`:

```yaml
- from: Member
  name: keeps # thao tác gọi quan hệ bằng tên này; hai quan hệ trùng tên thì thao tác nêu tên bị đỏ
  to: Listing
  cardinality: one-to-many
  own: true # chỉ `true` hoặc `false`
  lifecycle: # mỗi khoá `attach`, `detach`, `reassign` một dòng
    attach: { later: "Lộ trình hàng 14" }
    reassign: { never: "Căn ở lại với người giữ đầu", decided_by: "Lan, 2026-01-05" }
# hoặc, thay cho cả ba dòng: lifecycle: { via: Listing }
```

Trên một thực thể, trong `ontology/entities/<Tên>.yaml`:

```yaml
not_set:
  system: [id, version, createdAt] # danh sách tên thuộc tính
  import: [externalCode] # danh sách tên thuộc tính
  later: { legalStatus: "Lộ trình hàng 10" } # thuộc tính -> ở đâu
  never: # thuộc tính -> { reason, decided_by }
    closePrice: { reason: "Chỉ bước chốt bán ghi giá chốt", decided_by: "Lan, 2026-01-05" }
```

Một thuộc tính được coi là «có thao tác đặt» khi: một thao tác bất kỳ loại nào nêu nó trong `sets`,
hoặc một thao tác `create`/`update` không có `sets` có ô nhập (`input`) trùng tên với nó.

## 3. Lựa chọn và lý do

- **`own: [vai]` cạnh `roles`, không đổi sang `scope`.** `roles` vẫn là danh sách duy nhất mã sinh
  ra đọc để trả lời «vai này có được làm không». Đổi sang `scope` sẽ đổi mã sinh ra của mọi repo đang
  dùng. Thêm một khoá thì repo nào không dùng không mất gì.
- **Đọc `scope` của onehub-inventory y nguyên.** Kho đó đã có bài kiểm cho từng ô của bảng quyền;
  bắt nó viết lại bảng để hợp với kho này là đi ngược chiều đọc.
- **Dấu `own: true` nằm trên quan hệ, không phải thao tác nêu tên quan hệ.** Giữa thành viên và căn
  có thể có hai quan hệ («giữ» và «đã tạo»); chỉ một cái là nghĩa của «của tôi». Dấu trên quan hệ
  nói điều đó một lần cho mọi thao tác, và onehub-inventory không phải sửa dòng thao tác nào.
- **Không khai «vai do thực thể nào giữ».** Mô hình mẫu của kho này có vai mà không có thực thể
  người dùng. Đòi khai thêm điều đó là bắt mọi repo trả một câu chỉ để phục vụ phép kiểm. Đầu còn lại
  của quan hệ `own` được hiểu là bên giữ vai; máy không soát điều này (mục 5).
- **Dòng ghi lựa chọn nằm ngay trên quan hệ, cùng chữ với thực thể** (`lifecycle`, `later`, `never`,
  `decided_by`, `via`). Một bộ chữ cho cả hai nơi; tác tử đã biết cách viết.
- **`via` cho quan hệ gắn một lần.** Phần lớn quan hệ là «công ty giữ thứ của mình»: gắn lúc tạo,
  không bao giờ đổi. Bắt ba dòng `never` có tên người quyết cho từng cái sẽ biến `decided_by` thành
  thủ tục và gọi người vì câu hỏi không ai đặt ra. Một dòng `via` nói đủ.
- **Quan hệ nhiều-nhiều không bị hỏi «chuyển».** Ở đó chuyển chính là gỡ rồi gắn. Hỏi thì chỉ nhận
  về một dòng `never` vô nghĩa có tên người.
- **Ô nhập trùng tên được tính là chạm.** Repo dựng từ kho này đã khai ô nhập cho mọi thao tác, vì
  mã sinh ra cần. Bắt ghi lại bằng `sets` là khai một điều hai lần. `sets` có mặt thì thắng: nó là
  câu nói rõ.
- **`sets` được đặt trên mọi loại thao tác, kể cả `command`.** Thao tác «đưa căn lên bán» đặt trạng
  thái của căn. Việc này để ngỏ cho phần trạng thái và bước chuyển, chưa làm ở đây.
- **`system` và `import` là danh sách một dòng, không cần người quyết.** Mã định danh, dấu thời
  gian, số phiên bản là sự thật về việc ai ghi giá trị, không phải quyết định bỏ một thao tác. Không
  đoán theo tên thuộc tính: máy không tự miễn `id` hay `createdAt`, vì dò chữ là thứ đã phải cắt ở
  delivery-loop.
- **Thực thể chưa có thao tác thêm hay sửa thì không bị hỏi từng thuộc tính.** Phép kiểm vòng đời đã
  báo chỗ thiếu ở mức thực thể. Hỏi thêm từng thuộc tính là ghi một món nợ hai lần, và bắt danh mục
  chỉ nhập từ tệp phải kê hết thuộc tính của nó.
- **Một câu báo cho mỗi thực thể và mỗi quan hệ.** Căn có 18 thuộc tính; 18 câu báo đỏ giống nhau
  che mất các lỗi khác. Trên onehub-inventory: 5 câu thay cho 44, và 26 câu thay cho 76. Gom không
  làm kho im lặng về thuộc tính được xanh: thao tác sửa không nêu gì thì mọi thuộc tính của thực
  thể đó vẫn đỏ.
- **«Thao tác nào được tính» và «thao tác chạm thực thể nào» mỗi câu ở một hàm.** Cả ba phép kiểm
  (và phép kiểm vòng đời) hỏi qua `answering_actions` và `action_entities`. Dấu «dự kiến» và thao
  tác nêu nhiều thực thể, khi làm, mỗi việc sửa một chỗ.
- **Tên khoá `never`, và `own` chỉ nhận đúng hoặc sai.** Hai bộ đọc YAML đọc `no`, `yes` khác nhau:
  một bên ra đúng/sai, một bên giữ nguyên chữ. Thứ gì không phải đúng/sai thì đỏ, nên chữ `no`
  không bao giờ bị hiểu thành «có». Bài kiểm chạy cả hai bộ đọc.
- **Đỏ, không phải nhắc.** Cùng lý do với phép kiểm vòng đời: lời nhắc không chặn được gì.

## 4. Đo thử

Chạy phép kiểm, chỉ đọc, trên một bản sao mô hình của onehub-inventory (nhánh chính `20a13c2`,
ngày 2026-11-15; kho đó không bị ghi gì):

| Phép kiểm                  | Đỏ                                                                                                             |
| -------------------------- | -------------------------------------------------------------------------------------------------------------- |
| «Của tôi» không có quan hệ | 10 thao tác: 4 trên góc nhìn đã lưu, 2 trên căn, 2 trên liên hệ, 1 trên liên kết chủ căn, 1 «xem vai của mình» |
| Quan hệ chưa trả lời       | 26 trên 26 quan hệ, 76 câu hỏi (2 quan hệ nhiều-nhiều chỉ bị hỏi hai câu)                                      |
| Thuộc tính chưa ai đặt     | 44 thuộc tính ở 5 thực thể: căn 18, góc nhìn đã lưu 8, và ba thực thể mỗi cái 6                                |

Con số 9 thao tác «của tôi» đếm tay ở trang ranh giới khớp; thao tác thứ mười là «xem vai của chính
mình», tự xanh khi thành viên có một quan hệ `own`.

Ba thao tác thiếu mà hai phép kiểm trước không thấy:

- **«Nhận căn chưa ai giữ» và «đổi người giữ căn»: đỏ, qua hai bước.** Hôm nay phép kiểm 2.1 đỏ ở
  «đưa căn lên bán», «bỏ căn» và «xem số điện thoại chủ căn», với câu «chưa có quan hệ nào nói "của
  tôi" nghĩa là gì». Câu báo chưa gọi tên «nhận» hay «đổi», vì quan hệ chưa tồn tại để hỏi. Thử trên
  bản sao: khai quan hệ «thành viên giữ căn» có `own: true` thì hai lỗi trên căn hết, và phép kiểm
  2.2 đỏ ngay ở quan hệ đó với ba câu gắn, gỡ, chuyển. «Nhận» là câu gắn, «đổi người giữ» là câu
  chuyển.
- **«Sửa thông tin căn ngoài giá»: đỏ, bởi phép kiểm 2.3.** Căn bị báo cả 18 thuộc tính, vì chưa
  thao tác nào của kho đó nêu thuộc tính. Thử trên bản sao: ghi thao tác sửa căn chỉ đặt giá thì
  còn 17, trong đó có đủ pháp lý, tài chính, nội thất, tình trạng sử dụng.

Phép kiểm vòng đời trên cùng bản sao cho 60 câu chưa trả lời (hôm 14/11 là 44; kho đó đã thêm thực
thể).

## 5. Giới hạn đã biết

- Máy không soát đầu kia của quan hệ `own` có đúng là bên giữ vai không, và không soát từng vai. Hai
  quan hệ `own` cùng chạm một thực thể thì mô hình chưa nói vai nào dùng cái nào.
- `own` chưa vào mã sinh ra: hàm trả lời «vai này có được làm không» chưa biết «chỉ trên thứ của
  mình». Việc chặn lúc chạy vẫn là của mã trong repo.
- `via` trên quan hệ là lời khẳng định «không bao giờ đổi» mà không có tên người. Ai viết sai thì
  ba câu hỏi biến mất; bước rà soát thay đổi phải nhìn dòng này.
- Thao tác đã khai mà chưa có mã vẫn được tính là một câu trả lời, như ở phép kiểm vòng đời: chưa
  có dấu «dự kiến».
- Ô nhập trùng tên thuộc tính mà chỉ dùng để tìm bản ghi vẫn được tính là chạm. Ghi `sets` để nói
  rõ.
- Thuộc tính của thực thể sống theo cha không được hỏi: thao tác của cha chưa có cách nêu thuộc
  tính của con.
- Không biết màn nào hiện thuộc tính nào, nút gắn hay gỡ đặt ở đâu. Phần đó thuộc design-assembly.

Không chặn đường các việc để sau: trạng thái của bản ghi và bước chuyển (`states` trên thao tác
không bị đụng tới, `sets` trên `command` là chỗ nối), dấu «dự kiến», một thao tác xem nêu nhiều thực
thể (phép kiểm «của tôi» đã chạy theo từng thực thể thao tác nêu), và móc chạy phép kiểm sau mỗi lần
sửa.

Một điều việc «dự kiến» phải giữ: thao tác dự kiến không còn là câu trả lời cho vòng đời, nhưng vẫn
phải làm thực thể bị hỏi về thuộc tính. Ở onehub-inventory mọi thao tác trên căn đều đang «dự
kiến»; nếu bỏ hẳn chúng khỏi phép kiểm 2.3 thì căn thành «chưa có thao tác thêm hay sửa» và chỗ
thiếu «sửa thông tin căn ngoài giá» lại im lặng.
