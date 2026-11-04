# Bản thiết kế mẫu có mâu thuẫn cố ý

Dán nội dung bên dưới vào `/repo-setup:new`.

Tôi dựng dịch vụ hỗ trợ khách hàng tên Support Desk.

- Stack: fastapi, kiến trúc service-api, level team, container.
- AI: `ai_tier: agent`, dùng Tool Runner.
- Agent chạy nền theo lịch, không có người duyệt, chạy không tương tác.
- Agent phải tự xoá được phiếu hỗ trợ cũ, và action xoá để `agent: confirm`.

**Mâu thuẫn phản biện phải bắt được:** action `confirm` luôn bị từ chối khi chạy không tương tác, nên agent chạy nền sẽ không bao giờ xoá được phiếu. Muốn tiếp tục phải đổi một trong hai vế.
