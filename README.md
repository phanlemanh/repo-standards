# repo-standards — Claude Code marketplace

Marketplace chứa plugin **repo-setup**: dựng, chuẩn hóa và kiểm tra repo cho **SDLC AI-native**
(Claude Code làm phần chính, con người ở biên), theo chuẩn top tier: ontology sinh ra types,
API contract và tool cho agent; wiki do agent duy trì; tự động hóa GitHub có phân tầng rủi ro.
Dành cả cho người chưa có kinh nghiệm setup. Chi tiết: [plugins/repo-setup/README.md](plugins/repo-setup/README.md).

## Cài đặt (mỗi người làm một lần)

Đẩy thư mục này lên GitHub (ví dụ `your-org/repo-standards`), rồi trong Claude Code:

```
/plugin marketplace add your-org/repo-standards
/plugin install repo-setup@repo-standards
```

Thử ngay trên máy mà chưa cần GitHub:

```bash
claude --plugin-dir ./plugins/repo-setup
```

## Dùng

Mở Claude Code trong thư mục dự án:

- Repo mới / trống → `/repo-setup:setup-new`
- Repo đang có code → `/repo-setup:setup-adopt`
- Kiểm tra sức khỏe → `/repo-setup:setup-doctor`
- Làm tính năng: `/repo-setup:sdlc-run` (từ ý định đến PR), hoặc trên GitHub: issue "Intent" +
  nhãn `agent:implement`
- Bật SDLC trên GitHub: `/repo-setup:sdlc-github-setup`
- Hằng ngày: `/repo-setup:ontology-add`, `/repo-setup:wiki-ingest`, `/repo-setup:wiki-query`,
  `/repo-setup:wiki-health`, `/repo-setup:setup-explain`

## Chia sẻ cho cả team

Commit vào repo dự án file `.claude/settings.json` để ai clone về cũng được gợi ý cài:

```json
{
  "extraKnownMarketplaces": {
    "repo-standards": {
      "source": { "source": "github", "repo": "your-org/repo-standards" }
    }
  },
  "enabledPlugins": {
    "repo-setup@repo-standards": true
  }
}
```

## Phát triển plugin

```bash
bash tests/run.sh                        # kiểm thử nhanh, không cần mạng (~20 giây)
SKIP=gitleaks bash tests/e2e.sh          # cài đặt thật + make check cho mọi preset (cần mạng)
PRESETS="fastapi:service-api:container" bash tests/e2e.sh   # một tổ hợp stack:archetype:deploy:caps
claude plugin validate .                 # kiểm tra manifest
python3 tools/bump_version.py minor      # tăng version ở mọi nơi + mục CHANGELOG
```

Lịch sử thay đổi: [CHANGELOG.md](CHANGELOG.md).
