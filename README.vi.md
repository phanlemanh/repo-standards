# repo-standards: marketplace cho Claude Code

[English](README.md)

Marketplace này chứa một plugin là **repo-setup**. Plugin dựng, chuẩn hoá và kiểm tra repo theo từng tầng quyết định, dùng được cho cả người mới giao hết cho Claude lẫn người chuyên nghiệp đã có sẵn lựa chọn. Ontology sinh ra types, API contract và tool cho agent; mỗi repo có wiki và quy trình cho agent của riêng nó. Repo chứa plugin cho Claude Code là một loại riêng (`claude-plugin`): được dựng manifest, một plugin mẫu, công cụ kiểm manifest và công cụ nâng phiên bản thay cho bộ công cụ của ứng dụng, và được chấm bằng các mục dành riêng cho repo plugin. Plugin dừng ở việc setup: muốn làm tính năng theo vòng có agent và cổng nghiệm thu, hãy dùng công cụ riêng như [Acceptance Gate Kit](https://github.com/phanlemanh/acceptance-gate-kit). Chi tiết: [plugins/repo-setup/README.md](plugins/repo-setup/README.md).

## Cài đặt

Bạn cần [Claude Code](https://code.claude.com) và Python 3.11 trở lên cho các script của plugin. Tài khoản GitHub chỉ cần khi muốn đẩy code lên. Trong Claude Code:

```
/plugin marketplace add phanlemanh/repo-standards
/plugin install repo-setup@repo-standards
```

## Cách dùng

Mở Claude Code trong thư mục dự án:

- Repo mới hoặc trống: `/repo-setup:new`
- Repo đã có code: `/repo-setup:adopt`
- Kiểm tra sức khoẻ: `/repo-setup:doctor`
- "Tệp này là gì, vì sao commit bị chặn?": `/repo-setup:explain`
- Cài đặt GitHub: `/repo-setup:github`
- Hằng ngày, trong repo đã sinh, không cần plugin: `/ontology-add`, `/wiki-ingest`, `/wiki-query`, `/wiki-health`, `/review-change`

Mã nguồn, tên tệp và commit của repo được dựng luôn bằng tiếng Anh. Claude trò chuyện theo ngôn ngữ của bạn, và tài liệu cho người đọc theo `docs_language`.

## Chia sẻ cho cả đội

Hướng dẫn và đoạn cấu hình nằm trong [README.md](README.md#share-with-a-team). Đồng đội chỉ được gợi ý cài sau khi tin cậy thư mục; trước đó, cấu hình bị bỏ qua mà không có thông báo.
