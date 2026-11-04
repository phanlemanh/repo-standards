# repo-setup

Set up, adopt and audit repositories for an **AI-native SDLC**: Claude Code does the work,
humans stay at the edges (intent, risky decisions, production). Top-tier engineering
standards, a domain ontology that generates types, API contract and agent tools, an
agent-maintained wiki, and GitHub automation with autonomy tiers — through a short interview.

Dựng, chuẩn hóa và kiểm tra repo cho **SDLC AI-native**: Claude Code làm phần chính, con người
đứng ở biên (ý định, quyết định rủi ro, production).

## Cài đặt

```
/plugin marketplace add <owner>/<repo>
/plugin install repo-setup@repo-standards
```

## Cấu hình theo 4 trục

| Trục | Lựa chọn | Hỏi người dùng (theo nhu cầu, không theo tên kiến trúc) |
| --- | --- | --- |
| **Stack** | `ts-node`, `ts-api` (Fastify), `react-vite`, `python`, `fastapi` | Viết bằng gì, làm loại ứng dụng gì |
| **Archetype** | `service-api`, `modular-monolith` (hoặc không) | Ai dùng (người qua UI / app khác, đối tác, AI agent qua API), mấy miền nghiệp vụ |
| **Capability** | `mcp` | AI agent có cần thao tác hệ thống không |
| **Deploy** | `container` | Chạy trên server/cloud không |

Cùng với **level**: `starter` (mọi dự án) hoặc `team` (repo dùng chung + SDLC AI-native trên
GitHub). `apply.py --list-options` liệt kê mọi lựa chọn kèm "khi nào dùng".

## Skills

| Lệnh | Dùng khi |
| --- | --- |
| `/repo-setup:setup-new` | Dựng repo mới: phỏng vấn theo nhu cầu → kế hoạch → áp dụng → cài đặt → kiểm chứng → chấm điểm |
| `/repo-setup:setup-adopt` | Đưa repo **đang có code** lên chuẩn, từng bước nhỏ, không phá |
| `/repo-setup:setup-doctor` | Chấm điểm 0–100 (`--remote`: kiểm tra GitHub thật), sửa chỗ thiếu |
| `/repo-setup:setup-explain` | Giải thích file/công cụ, hoặc vì sao commit/CI/agent bị chặn |
| `/repo-setup:sdlc-run` | **Từ ý định đến PR**: spec → cổng rủi ro → test trước → code → review độc lập → wiki → PR |
| `/repo-setup:sdlc-spec` | Viết spec (tiêu chí nghiệm thu, tác động domain, tier) và quyết định có cần người duyệt |
| `/repo-setup:sdlc-implement` | Hiện thực spec đã duyệt trên nhánh riêng, `make check` xanh, PR có bằng chứng |
| `/repo-setup:sdlc-review` | Review độc lập PR do người khác/agent khác viết, một verdict |
| `/repo-setup:sdlc-github-setup` | Bật SDLC AI-native trên GitHub: nhãn, môi trường, ruleset, Claude App, secret |
| `/repo-setup:ontology-add` | Thêm/đổi khái niệm, **action**, **role**, dữ liệu cá nhân (PII) |
| `/repo-setup:wiki-ingest` · `wiki-query` · `wiki-health` | Ghi lại, tra cứu, rà soát tri thức của dự án |

Subagents: `code-reviewer`, `security-reviewer` (chỉ đọc, dùng cho review độc lập).

## SDLC AI-native (level team)

- **Con người ở biên**: viết issue "Intent" (mục tiêu + tiêu chí nghiệm thu) và gắn nhãn
  `agent:implement`; duyệt spec rủi ro cao (`spec:approved`); duyệt PR medium/high; duyệt môi
  trường `production`.
- **Agent làm phần giữa** (GitHub Actions + `claude-code-action`, nạp chính plugin này): spec →
  code → PR; agent review độc lập; gắn nhãn `risk:low|medium|high` theo
  `governance/autonomy.yaml`; PR `low` tự merge khi CI xanh + agent review duyệt; sửa `main`
  khi đỏ; bảo trì wiki và báo cáo chỉ số hằng tuần.
- **Rào chắn thật**: `.claude/settings.json` (không đọc `.env`, không sửa workflow/governance,
  không force-push; hỏi trước khi merge/release); hook **PreToolUse** hỏi người trước mỗi lần
  sửa file high-tier (CI: chỉ cho phép khi một *người* gắn `spec:approved`); luật của cổng luôn
  lấy từ nhánh gốc, PR không tự sửa được luật chấm mình; CODEOWNERS sinh từ chính sách.

## Hooks (chỉ trong repo có `.repo-setup.json`)

- **SessionStart**: đưa bản đồ repo (wiki, glossary, skill) vào ngữ cảnh.
- **PreToolUse**: cổng con người cho file high-tier (xem trên).
- **Stop**: code đổi → chạy `make check`, bắt sửa khi đỏ (tối đa 3 lượt); nhắc cập nhật wiki một lần.
- Tắt: `.repo-setup.json` → `"hooks": {"stop_check": false, "wiki_reminder": false}`; tạm thời:
  `REPO_SETUP_HOOKS=off`.

## Ontology → mọi thứ

```
ontology/entities/*.yaml   khái niệm (kiểu, enum, ref, subtype có luật, pii: true)
ontology/actions.yaml      việc có thể làm: input, output, roles, agent: allowed|confirm|forbidden
ontology/roles.yaml        vai trò, kế thừa (kể cả role "agent")
        │ make gen
        ├── types + ActionHandlers + can() + redactPII()   (TypeScript / Python)
        ├── contracts/openapi.json → POST /v1/actions/{name} (service-api) + kiểm tra breaking change
        └── MCP tools cho AI agent (mcp): kiểm quyền, kiểm input, che PII
```

`make check` chặn khi wiki/ontology sai, code sinh ra lệch, contract lệch hoặc phá tương thích,
module vượt ranh giới (modular-monolith).

## Cách hoạt động

```
scripts/apply.py     ghép lớp: core → stack → archetype → capability → deploy (starter rồi team)
                     - "+<file>/NN-part" ghép file theo phần (AGENTS.md, .pre-commit-config.yaml, wiki/index.md)
                     - mk/*.mk thêm target vào make check; "[var=value]/" là file có điều kiện
                     - không ghi đè, chạy lại an toàn, --adopt cho repo cũ
scripts/doctor.py    chấm điểm theo checklists/top-tier.toml (theo level, archetype, capability, deploy)
scripts/hook_*.py    hooks Claude Code
presets/ archetypes/ capabilities/ deploy/   mỗi thư mục: preset.toml + starter/ + team/
```

Chỉ cần Python 3.11+ cho plugin. Dùng trực tiếp:

```bash
python3 scripts/apply.py --target ../shop --preset fastapi --archetype service-api \
  --deploy container --level team --var "project_name=Shop" --var "description=Orders API" \
  --var owner=my-org --var license=Proprietary --var marketplace=my-org/repo-standards --dry-run
python3 scripts/doctor.py --target ../shop --remote
```

**Windows**: dùng WSL2, Git Bash + `choco install make`, hoặc dev container (level team).

## Tùy biến cho đội của bạn

- **Tiêu chuẩn**: `checklists/top-tier.toml`. **Mức tự chủ của agent**: `governance/autonomy.yaml`
  trong từng repo (thay đổi file này luôn cần người).
- **Thêm stack/archetype/capability/deploy**: tạo thư mục với `preset.toml` (`extends`, `stacks`,
  `when`, `capabilities`, `install`/`verify` — lệnh có thể bắt đầu bằng `[lang=ts]`), `starter/`, `team/`.
- Phát hành: `python3 tools/bump_version.py minor`.
