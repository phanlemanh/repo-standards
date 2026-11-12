# Kịch bản chạy thật cho setup có dẫn dắt

Các kịch bản này chạy với Claude Code thật và tốn tiền API, nên không nằm trong CI. Chỉ chạy khi chủ repo đồng ý. Mỗi kịch bản bắt đầu trong một thư mục trống, cài plugin từ nhánh đang thử.

## 1. Người mới, giao cho Claude

Tin nhắn đầu: "Tôi muốn làm một công cụ nhỏ quản lý quán cà phê, tôi mới học lập trình cơ bản."

| Phải thấy | Không được xảy ra |
|---|---|
| Bức tranh 10 tầng, ngắn, không thuật ngữ thừa | Hỏi chọn `starter` hay `team` |
| Chỉ dừng ở tổng duyệt | Bật `github-agents` |
| `doctor` 100, có giải thích điểm đo gì | Nói điểm 100 nghĩa là ứng dụng đã xong |
| `docs/START-HERE.md` viết tiếng Việt | Tên tệp hay mã nguồn tiếng Việt |
| Slug `quan-ca-phe` nếu đặt tên có dấu | Commit hay push khi chưa hỏi |

## 2. Người chuyên nghiệp, duyệt từng tầng

Tin nhắn đầu: "Dựng API đơn hàng, tôi muốn xem từng lựa chọn kiến trúc và CI."

| Phải thấy | Không được xảy ra |
|---|---|
| 2 đến 3 phương án có lý do, đánh đổi, trường hợp sai, nhãn | Phương án thiếu nhãn |
| Tầng chỉ có một đáp án thì nói một dòng rồi đi tiếp | Hỏi ở tầng không có lựa chọn thật |
| Đổi `architecture` thì các tầng phụ thuộc thành `needs_review` | Bỏ qua tầng phụ thuộc |
| `setup-blueprint.yaml` có `why` và `rejected`, có ghi chép trong `wiki/decisions/` | Hứa sẽ dựng phương án `manual` |

## 3. Người chuyên nghiệp, dán bản thiết kế

Tin nhắn đầu: nội dung `tests/fixtures/blueprints/prepared-conflict.md`, phần sau dòng "Dán nội dung".

| Phải thấy | Không được xảy ra |
|---|---|
| Giữ nguyên các lựa chọn đã nêu, gắn `source: user` | Tự sửa lựa chọn của người dùng khi chưa hỏi |
| Chỉ hỏi chỗ thiếu hoặc mâu thuẫn | Hỏi lại từ đầu |
| Phản biện nêu đúng mâu thuẫn về `confirm` khi chạy không tương tác | Phản biện chỉ đồng ý |

## 4. Gọi API thật ở từng nấc

Với mỗi `ai_tier` (`call`, `workflow`, `agent`), trên Python và TypeScript: đặt `ANTHROPIC_API_KEY`, chạy `make eval`, ghi lại tỉ lệ đạt và số token. Ở nấc `agent`, tác vụ xoá phải giữ nguyên ghi chú.

## 5. Skill có được kích hoạt bằng tiếng Việt không

Đo bằng `claude plugin eval` với các câu tiếng Việt như "dựng repo mới", vì mô tả skill viết tiếng Anh.

## 6. Repo chứa plugin cho Claude Code

Tin nhắn đầu: "Tôi muốn dựng một repo chứa vài plugin cho Claude Code, phát hành qua marketplace."

| Phải thấy | Không được xảy ra |
|---|---|
| Stack `claude-plugin` được nói trong một dòng, không hỏi chọn ngôn ngữ | Hỏi chọn TypeScript hay Python |
| Năm tầng kiến trúc, AI, miền nghiệp vụ, thiết kế, triển khai: mỗi tầng một dòng "không áp dụng" kèm lý do | Lặng lẽ bỏ qua tầng, hoặc sinh `ontology/`, `wiki/`, `.env.example` |
| Một plugin mẫu trong `plugins/<tên>/`, `make check` xanh, `doctor` 100 kèm danh sách mục không áp dụng | `package.json`, `tsconfig.json`, ESLint hay Prettier ở gốc repo |
| Ghi chép quyết định nằm ở `docs/decisions/` | Tạo `wiki/decisions/` |

Trên repo plugin đã có sẵn (`/repo-setup:adopt`): bản xem trước không thêm plugin mẫu, không đụng manifest đang có; các lỗi làm đổi thứ người dùng cài (nguồn là gốc repo, mô tả quá dài, lệch phiên bản) được nêu riêng, không sửa chung trong commit chuẩn hoá.

## Kết quả

| Kịch bản | Ngày | Người chạy | Đạt | Ghi chú |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
