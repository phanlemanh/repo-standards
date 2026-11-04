# repo-standards: marketplace cho Claude Code

[English](README.md)

Marketplace này chứa một plugin là **repo-setup**. Plugin dựng, chuẩn hoá và kiểm tra repo theo từng tầng quyết định, dùng được cho cả người mới giao hết cho Claude lẫn người chuyên nghiệp đã có sẵn lựa chọn. Ontology sinh ra types, API contract và tool cho agent; agent duy trì wiki; các thay đổi được phân tầng theo rủi ro. Chi tiết: [plugins/repo-setup/README.md](plugins/repo-setup/README.md).

## Cài đặt

Bạn cần [Claude Code](https://code.claude.com) và Python 3.11 trở lên cho các script của plugin. Tài khoản GitHub chỉ cần khi muốn đẩy code lên. Trong Claude Code:

```
/plugin marketplace add phanlemanh/repo-standards
/plugin install repo-setup@repo-standards
```

## Cách dùng

Mở Claude Code trong thư mục dự án:

- Repo mới hoặc trống: `/repo-setup:setup-new`
- Repo đã có code: `/repo-setup:setup-adopt`
- Kiểm tra sức khoẻ: `/repo-setup:setup-doctor`
- "Tệp này là gì, vì sao commit bị chặn?": `/repo-setup:setup-explain`
- Làm một tính năng từ ý định đến PR: `/repo-setup:sdlc-run`
- Cài đặt GitHub: `/repo-setup:sdlc-github-setup`
- Hằng ngày: `/repo-setup:ontology-add`, `/repo-setup:wiki-ingest`, `/repo-setup:wiki-query`, `/repo-setup:wiki-health`

Mã nguồn, tên tệp và commit của repo được dựng luôn bằng tiếng Anh. Claude trò chuyện theo ngôn ngữ của bạn, và tài liệu cho người đọc theo `docs_language`.

## Chia sẻ cho cả đội

Hướng dẫn và đoạn cấu hình nằm trong [README.md](README.md#share-with-a-team). Đồng đội chỉ được gợi ý cài sau khi tin cậy thư mục; trước đó, cấu hình bị bỏ qua mà không có thông báo.
