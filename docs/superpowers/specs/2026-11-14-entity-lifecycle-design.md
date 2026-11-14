# Thiết kế: mỗi thực thể đủ bốn câu trả lời

Ngày: 2026-11-14. Trạng thái: đã dựng trên nhánh `feat/entity-lifecycle`, chờ chủ kho xem. Áp dụng
cho plugin `repo-setup`. Ranh giới với hai kho bên cạnh: [ranh giới ba kho](../../ranh-gioi-ba-kho.md).

## 1. Ý định

Ở onehub-inventory, chủ kho ba lần trong hai ngày tự bắt được cùng một lỗi: màn cho thêm một thứ mà
không cho sửa hay bỏ nó. Luật chữ đã có cả ba lần. Bộ dựng repo cho khai thao tác theo năm loại
nhưng phép kiểm chỉ soát cách khai, không hỏi «thực thể này thêm được, sao không bỏ được?». Thứ
chưa từng khai thì không phép kiểm nào thấy thiếu.

## 2. Hành vi

Khi repo có `ontology/actions.yaml`, mỗi thực thể phải có bốn câu trả lời: `create`, `query`,
`update`, `delete`. Một câu trả lời là một thao tác thuộc loại đó, hoặc một dòng dưới `lifecycle:`
trong tệp thực thể:

| Dòng                                        | Nghĩa                                  | Phép kiểm          |
| ------------------------------------------- | -------------------------------------- | ------------------ |
| `{ later: <ở đâu> }`                        | Sẽ làm, ghi rõ ở đâu                   | Xanh, nhắc mỗi lần |
| `{ never: <lý do>, decided_by: <người> }`   | Không bao giờ có, một người đã quyết   | Xanh, im           |
| `lifecycle: { via: <Thực thể> }`            | Sống chết theo thực thể cha            | Xanh, im           |
| Không có gì                                 | Chưa ai trả lời                        | Đỏ                 |

Câu báo đỏ nêu tên thực thể, tên thao tác và cả hai cách sửa, để tác tử đọc xong là làm được.

## 3. Lựa chọn và lý do

- **Đỏ, không phải nhắc.** `make ontology` không chạy ở chế độ chặt, nên lời nhắc không chặn được
  gì. Lỗi này đã lọt ba lần qua lời nhắc.
- **Chỉ bật khi repo có khai thao tác.** Repo chưa dùng thao tác thì không bị hỏi.
- **`never` phải có `decided_by`.** Bỏ một thao tác là quyết định của người. Phép kiểm không biết ai
  viết dòng đó; hướng dẫn và bước rà soát cấm tác tử tự điền.
- **Tên khoá là `never`, không phải `no`.** Bộ đọc YAML đọc khoá `no` thành giá trị sai/đúng. Bài
  kiểm bắt được ngay lần chạy đầu.
- **`later` hiện mỗi lần chạy.** Món nợ không biến mất, và không làm đỏ.

## 4. Đo thử

Chạy phép kiểm, chỉ đọc, trên nhánh chính của onehub-inventory ngày 2026-11-14: 44 câu chưa trả
lời ở 13 trên 16 thực thể. Trong đó có «gỡ thành viên» và cả bốn câu của «lần gửi», hai chỗ báo cáo
RS2 đã nêu bằng cách đọc tay.

## 5. Giới hạn đã biết

- Thao tác đã khai mà chưa có mã vẫn được tính là một câu trả lời: bộ dựng repo chưa có dấu «dự
  kiến». Con số 44 vì vậy còn thấp hơn thực tế.
- Không kiểm theo từng vai: một vai thêm được mà không bỏ được thứ của chính mình thì không đỏ.
- Không biết màn nào hiện thực thể nào. Phần đó thuộc design-assembly.
- Chưa có móc chạy phép kiểm sau mỗi lần sửa; mới có luật theo vùng tệp dặn chạy.
- Chưa chạy bộ kiểm đầu-cuối có cài đặt thật (`tests/e2e.sh`).
