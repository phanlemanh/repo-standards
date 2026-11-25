# Sẵn sàng phát hành 0.10.5: kiểm trước khi gắn thẻ

Ngày 2026-11-25 (UTC), viết cho bản phát hành `repo-setup` 0.10.5. Kiểm `main` tại `b0e296d` (gộp PR 89),
phiên bản `0.10.5.dev0`, bản phát hành trước là `0.10.4`. Phiên này không chạy `bump_version.py`, không tạo
nhánh `release/0.10.5` hay thẻ, không đẩy gì, không ghi vào `design-ci-probe` hay `onehub-inventory` thật.

## 1. Kết luận

**Chưa phát hành ngay. Phát hành được sau một PR nhỏ.**

**Cập nhật cùng ngày:** chủ kho duyệt PR đó («Làm PR sửa»). PR mang báo cáo này cũng mang bản sửa L1 và
ba dòng CHANGELOG cho K1 đến K3. L2 chưa sửa: chủ kho chưa chọn hướng; CHANGELOG ghi nó là chỗ còn hở.
Khi PR này gộp và CI xanh, các điều kiện ở dưới đã đủ; quyết định phát hành vẫn là của chủ kho.

- Phía máy xanh hết: `tests/run.sh`, `tests/e2e.sh` cho cả 17 tổ hợp cùng hai ca nâng cấp, và lượt «Test plugin»
  trên `main` (5 job, gồm `e2e`).
- Hai lượt thử nâng trên bản sao đều tới được `make check` xanh. Cả hai đều cần chủ kho làm tay, và một việc
  tay trong số đó không có trong CHANGELOG: sau một lượt nâng sạch (thoát 0, không tệp nào bị đánh dấu), kho
  Node ở bậc `team` vẫn đỏ ở `prettier --check` cho tới khi chạy `make format` (lỗi L1, mục 5).
- CHANGELOG có ba khoảng trống (mục 6). Một câu đã sai từ khi 5.2 và 5.3 vào `main`.
- Không lỗi nào làm một thay đổi sai đi qua: L1 làm đỏ, không làm xanh sai. Vì vậy đây không phải lý do
  chặn vì an toàn. Lý do chờ là mọi lượt nâng thật đều sẽ gặp L1, còn CHANGELOG chưa nói gì về nó.

Đề xuất trước khi gắn thẻ, gói vào một PR:

1. Sửa L1 (định dạng sẵn bảng trong mẫu `autonomy-change/SKILL.md`, và viết khoá plugin của
   `settings.json` theo dạng prettier viết), có bài đỏ trước. Hoặc, nếu chủ kho muốn phát hành ngay: thêm một
   dòng vào mục «What breaks on upgrade» nói phải chạy `make format` sau khi nâng.
2. Ghi ba khoảng trống CHANGELOG (mục 6) thành dòng mới, không sửa lời của PR khác.
3. L2 (link `docs/START-HERE.md` hỏng) để vào `### Known gaps` của bản phát hành, hoặc sửa cùng PR.

## 2. Bước 1: `main` và CI

| Lượt | Commit | Kết quả |
| --- | --- | --- |
| «Test plugin» 45604783055 | `b0e296d` (PR 89) | Xanh: `offline` (macOS, Ubuntu), `validate`, `e2e`, `check`. 28 phút 33 giây |
| Ba lượt trước trên `main` | PR 91, 90, 88 | Xanh |

## 3. Bước 2: bộ kiểm

### `tests/run.sh`

Xanh: «All tests passed», thoát 0. Có các mục mới của đợt này: 55 (lời sinh ra), 56 (`wiki_lint` với tệp chưa vẽ).

### `tests/e2e.sh`, từng tổ hợp

Chạy mỗi tổ hợp một lần riêng (`PRESETS=<tổ hợp>`), để một tổ hợp đỏ không che các tổ hợp sau. Hai ca nâng
cấp chạy riêng (`PRESETS=python UPGRADE=1`).

| Tổ hợp | Lượt 1 | Lượt 2 | Thời gian (lượt xanh) |
| --- | --- | --- | --- |
| `claude-plugin` | xanh | | 19s |
| `fastapi` | xanh | | 27s |
| `python` | xanh | | 12s |
| `ts-api` | xanh | | 43s |
| `ts-node` | xanh | xanh | 23s |
| `react-vite:none:none:design` | xanh | | 833s |
| `react-vite:none:none:design::content` | đỏ (npm) | xanh | 896s |
| `ts-api:service-api:container:github-agents` | đỏ (npm) | xanh | 27s |
| `fastapi:service-api:container` | xanh | | 18s |
| `ts-node:modular-monolith:none:mcp` | đỏ (npm) | xanh | 16s |
| `python:modular-monolith:none:mcp` | xanh | | 14s |
| `python:none:none:github-agents` | xanh | | 10s |
| `python:none:none:ai:call` | xanh | | 26s |
| `ts-node:none:none:ai:workflow` | đỏ (npm) | xanh | 19s |
| `python:none:none:ai:agent` | xanh | | 23s |
| `ts-node:none:none:ai:agent` | đỏ (npm) | xanh | 20s |
| `fastapi:service-api:none:ai:agent` | xanh | | 25s |
| Nâng `python` từ `0.10.4` | xanh | xanh | |
| Nâng `ts-node` từ `0.7.0` | đỏ (npm) | xanh | 48s (cả hai ca) |

**Vì sao lượt 1 đỏ:** `vitest` 5.1.2 được phát hành lên npm đúng lúc lượt chạy đang diễn ra:
`@vitest/coverage-v8` 5.1.2 lúc 11:50:54 UTC, `vitest` 5.1.2 lúc 11:52:10 UTC. Bản coverage mới đòi đúng
`vitest` 5.1.2. Trong vài phút đó, bước cài `npm install --save-dev @vitest/coverage-v8` làm npm 11.19.0 sập
trong arborist (`TypeError: Cannot read properties of null (reading 'children')`, tại `place-dep.js:300`).
Sau đó là `ETARGET` vì `@vitest/spy@5.1.2` chưa có. Mọi tổ hợp Node chạy sau 11:51 đều đỏ ở cùng bước đó.
Chạy lại khi registry đã đủ bản thì cả sáu xanh. Không phải lỗi của kho này.

**E2E không chạy design-assembly.** `tests/e2e.sh` chỉ gọi `apply.py`. Bước gọi `/design-assembly:adopt
--starter` nằm trong kỹ năng `new`, nên e2e không phủ được chỗ nối mà PR 90 đọc lại ở 0.59.0. Để phủ, tôi
chạy thêm một lượt tay (mục 3.1).

### 3.1. Chỗ nối với design-assembly thật

Bản sao `~/dev/design-assembly` tại `origin/main` `4f9160f`, plugin **0.62.0** (mẫu dữ liệu đọc ở 0.59.0).
Một kho `react-vite` có `design`, bậc `team`, dựng và cài như e2e, rồi
`node plugins/design-assembly/scripts/adopt.mjs --target <kho> --starter --json`.

| Bước | Kết quả |
| --- | --- |
| `make check` trước khi gọi | xanh |
| `adopt --starter` | thoát 1: sổ đã đặt, còn câu chờ người. Đúng nghĩa «not a failure» trong `seam.json` |
| Tệp plugin ghi | đủ 7 sổ «From birth», `design/tool-stamp.json`, `mk/design-assembly.mk`, `tools/design-assembly/`, và `tests/e2e/floating-parts.spec.ts` (tệp mới của 0.57.0 mà 51g giữ) |
| Câu chờ người | `font-licence`, `conformance-level`, `source-color`, `product-type`: đều là câu của plugin, không có câu nào do setup thêm |
| `make check` sau khi gọi | xanh. Cổng `design-assembly`: 32 quyết định, 38 phép kiểm; 18 bài trình duyệt qua |
| `doctor --json` | 100; `design_ledgers`: `missing` rỗng, `stamp` `0.62.0` |

Chỗ nối đứng vững ở 0.62.0, ba bản sau bản mẫu dữ liệu đã đọc.

## 4. Bước 3: thử nâng trên bản sao

Cả hai kho đang ở **`0.10.3`**, không phải `0.10.4`, nên đây là lượt nâng `0.10.3` → `0.10.5.dev0`, bỏ qua
một bản.

- `onehub-inventory`: `git clone ~/dev/onehub-inventory`, commit `1ea13196`.
- `design-ci-probe`: không có bản ở máy (`~/dev/design-ci-probe` không tồn tại). Tôi clone từ GitHub
  (`gh repo clone phanlemanh/design-ci-probe`, chỉ đọc), commit `a4458ed3` (PR 22).

Mỗi kho: `npm ci`, `make check` lúc chưa nâng, `python3 <main>/plugins/repo-setup/scripts/apply.py --json`,
rồi `make check`.

### 4.1. `design-ci-probe` (`react-vite`, `design`, `team`)

`make check` lúc chưa nâng: chưa chạy riêng. Kho đã xanh trên CI ở PR 22.

| | Kết quả |
| --- | --- |
| Mã thoát | 0 |
| `created` (9) | `autonomy-change/SKILL.md`, `governance/outside.toml`, `mk/autonomy.mk`, `mk/outside.mk`, `ops/outside.toml`, `tools/autonomy_card.py`, `tools/github_check.py`, `tools/outside.py`, `tools/outside_ledger.py` |
| `updated` (9) | `.claude/settings.json`, `review-change/SKILL.md`, `pull_request_template.md`, `ci.yml`, `README.md`, `tools/autonomy.py`, `tools/ci_inputs.py`, `tools/github_setup.py`, `tools/wiki_lint.py` |
| `merged` (2) | `AGENTS.md`, `governance/autonomy.yaml` (gộp sạch) |
| `marked` | không có |
| `make check` ngay sau khi nâng | **đỏ** ở `lint`: prettier báo `.claude/settings.json` và `.claude/skills/autonomy-change/SKILL.md` (L1) |
| `make check` sau `make format` | xanh, gồm `ui-floor` (18 bài trình duyệt) |

Các điểm cần xem:

- **`.claude/settings.json` nhận hai thay đổi trong một lần:** cả hai đều vào. Hai dòng `Edit(...)` bị bỏ, hai
  khoá `extraKnownMarketplaces` và `enabledPlugins` của design-assembly được thêm. Tệp xếp `updated` vì kho
  chưa sửa nó. Nhưng hai khoá mới nằm mỗi khoá một dòng, prettier không nhận, nên `make check` đỏ (L1).
- **Mục `50-autonomy-card`:** mục `## The autonomy card` vào `AGENTS.md` sạch, đứng trước `## Autonomy tiers`.
  `make autonomy` in đủ thẻ và không ghi tệp nào.
- **Nhãn `risk:low`:** kho không bật `github-agents`, nên nhãn này không có ở đây. Lời mới của `low` vào sạch
  ở `AGENTS.md`, `governance/autonomy.yaml` và mẫu PR. Mô tả nhãn chỉ đổi khi chạy
  `github_setup.py --apply`, thuộc lượt thử trên GitHub thật.
- **Lời của PR 91:** README nhận dòng «Start here». Kho này không có `docs/START-HERE.md`, nên link hỏng (L2).
  Lời của lớp `delivery` và `context` chỉ nằm trong kỹ năng, không có tệp nào trong kho.
- **`wiki_lint.py` của PR 89:** `updated`; `make check` (bước `ontology`) xanh.

Chủ kho phải làm tay: chạy `make format` (hoặc `npm run format`) rồi commit. Không có xung đột nào.

### 4.2. `onehub-inventory` (`ts-node`, `modular-monolith`, `ai`, `team`)

`make check` lúc chưa nâng: xanh (tất cả 13 bước).

| | Kết quả |
| --- | --- |
| Mã thoát | 1 |
| `created` (9) | như `design-ci-probe` |
| `updated` (5) | `review-change/SKILL.md`, `pull_request_template.md`, `tools/autonomy.py`, `tools/ci_inputs.py`, `tools/github_setup.py` |
| `merged` (1) | `README.md` |
| `marked` (4) | `.claude/settings.json`, `AGENTS.md`, `governance/autonomy.yaml`, `tools/wiki_lint.py` |
| `removed` (8) | mã mẫu kho đã xoá từ lâu; không tạo lại |
| `make check` ngay sau khi nâng | đỏ ở bước `upgrade`, nêu đúng 8 dòng dấu của 4 tệp |

Bốn chỗ đánh dấu. Mỗi chỗ là một chỗ hai bên cùng sửa thật, không chỗ nào là lỗi của bộ gộp:

| Tệp | Bên kho | Bên mẫu mới | Gỡ thế nào |
| --- | --- | --- | --- |
| `.claude/settings.json` | Kho tự thêm 5 dòng deny `Bash(...)` và một khối `ask` (6 luật `gh pr merge`/`gh release create`), ngay cạnh hai dòng `Edit` | Bỏ hai dòng `Edit` (5.3) | **Chủ kho quyết**, xem dưới |
| `AGENTS.md` | Kho thêm mục «Infrastructure standing permission» và khối Next.js giữa hai luật cũ | Hai luật mới của 5.3 và câu `low` mới | Giữ mục của kho, thay hai luật cũ bằng luật mới. Nhưng mục của kho có câu «Never… edit `.github/workflows/` or `governance/`», ngược với 5.3: **chủ kho quyết** |
| `governance/autonomy.yaml` | Chú thích tầng theo lời cũ của kho («agent reviewer approved») | Lời mới của `low` | Lấy bên mẫu |
| `tools/wiki_lint.py` | Kho tự thêm `check_decision_numbers` (hai trang quyết định không được trùng số) | PR 89 thêm `not_drawn` ở cùng chỗ | Giữ cả hai |

Gỡ theo hướng của plugin (bỏ hai dòng `Edit`), chạy `npm run format` (L1, ở đây chỉ còn `SKILL.md`), rồi
`make check`: **đỏ** ở `test`. `tests/permissions.test.ts` là bài riêng của kho: nó ghim danh sách deny từng
dòng, gồm cả hai dòng `Edit`, và 12 trong 47 bài hỏng. Gỡ theo hướng của kho (giữ hai dòng `Edit`, tức
`settings.json` giữ nguyên như trước khi nâng): **`make check` xanh** (13 bước). `wiki_lint.py` gộp cả hai
bên chạy đúng.

Các điểm cần xem:

- **`50-autonomy-card`:** mục thẻ vào sạch. Xung đột của `AGENTS.md` nằm ở luật tầng, không ở thẻ.
  `make autonomy` in đủ thẻ.
- **`risk:low`:** kho không bật `github-agents`. Chú thích tầng của `governance/autonomy.yaml` bị đánh dấu vì
  kho đã viết lời riêng.
- **Lời của PR 91:** README gộp sạch dòng «Start here» và link tới `docs/START-HERE.md`, tệp kho này có. Câu cũ
  của trang ấy («Điều gì tự chạy») giữ nguyên, đúng như CHANGELOG nói. Dòng mới bằng tiếng Anh trong một README
  tiếng Việt: bước 6.9 dịch chỉ chạy khi dựng mới, không chạy khi nâng.
- **`wiki_lint.py` của PR 89:** bị đánh dấu vì kho có hàm riêng ở cùng chỗ. Gộp cả hai thì chạy được.

Chủ kho phải làm tay:

1. Quyết 5.3 có áp vào kho này không. Kho đang giữ bằng ba chỗ rằng máy không sửa `.github/workflows/` và
   `governance/`: hai dòng deny, câu «Never… edit» trong mục quyền đứng, và `tests/permissions.test.ts`.
   Giữ thì lấy bên kho ở `settings.json`, và bỏ hai luật 5.3 mới khỏi `AGENTS.md`. Nhận 5.3 thì sửa cả ba chỗ
   cùng một PR.
2. Gỡ ba tệp còn lại như bảng trên.
3. Chạy `npm run format` (L1).

Cùng ghi lại, không phải việc của bản này:

- Kho có luật `ask` riêng trong `settings.json`. Setup không sinh luật `ask` (luật 3 của nguyên tắc). Đó là
  quyết định của kho, chỉ ghi lại để chủ kho biết.
- `check_decision_numbers` mà kho tự thêm vào `wiki_lint.py` có thể đáng đưa về mẫu, để kho khác cũng có.

## 5. Lỗi tìm thấy

Không lỗi nào là sửa một dòng, nên lượt kiểm đầu không sửa. Sau đó chủ kho duyệt sửa L1 (mục 5.1).

### L1. Nâng sạch mà `make check` đỏ ở kho Node, cho tới khi chạy `make format` (đã sửa)

- **Ở đâu:** mọi kho preset `ts-node`, `ts-api` hay `react-vite` ở bậc `team` (tệp `autonomy-change/SKILL.md`),
  và thêm `.claude/settings.json` ở kho có sàn thiết kế.
- **Vì sao:** bảng Markdown trong mẫu `presets/_core/team/dot.claude/skills/autonomy-change/SKILL.md` chưa dàn
  cột như prettier dàn. Còn `plugin_settings()` trong `scripts/apply_plan.py` viết hai khoá plugin bằng
  `json.dumps` trên một dòng. `prettier --check` của bước `lint` từ chối cả hai.
- **Vì sao chưa bộ kiểm nào bắt:** kho mới dựng chạy `npm run format` trong các lệnh cài. `upgrade_case` của
  e2e cũng chạy các lệnh cài trước `make check`. Lượt nâng thật thì người ta chạy `apply.py` rồi `make check`:
  thoát 0 và không tệp nào bị đánh dấu, mà vẫn đỏ.
- **Tái hiện:**

  ```bash
  gh repo clone phanlemanh/design-ci-probe /tmp/dcp && cd /tmp/dcp && npm ci
  python3 <repo-standards>/plugins/repo-setup/scripts/apply.py --json   # exit_code 0, marked []
  make check   # lint: [warn] .claude/settings.json, .claude/skills/autonomy-change/SKILL.md
  make format && make check   # xanh
  ```

- **Hướng sửa:** dàn sẵn bảng trong mẫu và viết khoá plugin theo dạng prettier viết. Thêm một bài trong
  `tests/e2e.sh` chạy `make check` sau `apply.py` mà không chạy lệnh cài, hoặc nêu trong CHANGELOG rằng phải
  chạy `make format` sau khi nâng.

### 5.1. Bản sửa L1

Khi viết bài kiểm, prettier chỉ ra thêm hai chỗ cùng nguyên nhân, nên sửa luôn trong cùng PR:

- `settings.json` hỏng cả khi chỉ có `--var marketplace`, không cần sàn thiết kế: dạng một dòng có từ trước
  0.10.4.
- `AGENTS.md` của kho có `github-agents`: bảng chưa dàn cột (PR 77 có sửa một hàng của bảng này), và có hai
  dòng trống liền nhau sau mục «Work outside the repository». Dòng trống thừa đến từ một dấu
  `<!-- kept: word -->` đứng riêng một dòng trong `57-outside.md`: khi xoá dấu, dòng của nó ở lại.

Đã sửa:

| Chỗ | Sửa |
| --- | --- |
| `autonomy-change/SKILL.md`, `60-ai-native-sdlc.md` | Bảng dàn cột như prettier. Chỉ các dòng bảng đổi |
| `scripts/apply_plan.py` | `prettier_json`: object trên một dòng, có khoảng trắng trong ngoặc, khi vừa 100 cột; không vừa thì mỗi thành phần một dòng, thử lại từng tầng. Chỉ `plugins_enabled` (chưa bản phát hành nào dùng) theo dạng mới; `plugin_settings` giữ dạng một dòng mà bản đến 0.10.4 đọc, để lượt nâng vẫn tìm được gốc |
| `scripts/rule_kinds.py` | `finish` xoá cả dòng khi dòng đó chỉ có dấu. Không thẻ phát hành nào có dòng như vậy, nên gốc dựng lại của bản cũ không đổi |

Bài kiểm, đỏ trước khi sửa và xanh sau:

- **Mục 57 của `tests/run.sh`** (`tests/prettier_shape.sh`): dựng năm tổ hợp Node (`ts-node` team và starter,
  `react-vite` có `design`, `ts-api` có `github-agents` và container, `react-vite` có `design` và
  `github-agents`), có marketplace dạng `owner/repo`, dạng URL git dài, và không có. Ngay sau `apply.py`:
  57a chạy `prettier --check` trên mọi tệp plugin viết, khi prettier có sẵn mà không phải đi mạng (CI
  `offline` không có, nên bỏ qua ở đó); 57b luôn chạy, kiểm các dạng prettier giữ (không hai dòng trống liền
  nhau, hàng bảng cùng độ rộng, object một dòng trong `settings.json` vừa 100 cột và có khoảng trắng trong
  ngoặc). Trước khi sửa: 57a đỏ ở cả năm tổ hợp, 57b đỏ ở đúng các tệp ấy.
- **`tests/e2e.sh`, `upgrade_case`:** ca nâng `ts-node` từ 0.7.0 chạy `prettier --check` của chính kho đó trên
  các tệp lượt nâng tạo, thay và gộp, trước bước cài. Trên cây chưa sửa: đỏ ở `autonomy-change/SKILL.md`.
  Trên cây đã sửa: xanh.

Sau bản sửa, một kho Node nâng lên không phải chạy gì thêm cho các tệp này. Kho có `github-agents` đã định
dạng bảng trong `AGENTS.md` có thể gặp dấu xung đột ở bảng đó, vì hàng `Spec` cũng đổi trong bản này.
CHANGELOG ghi điều đó.

### L2. README trỏ tới `docs/START-HERE.md` ở kho không có tệp ấy (chưa sửa)

- **Ở đâu:** mọi kho không dựng bằng `/repo-setup:new`. Gồm kho dựng bằng `/repo-setup:adopt`, kho chỉ chạy
  `apply.py`, và kho cũ chưa có trang tour, như `design-ci-probe`.
- **Vì sao:** PR 91 thêm dòng «Start here» vào mẫu `README.md.tmpl`, mà `docs/START-HERE.md` chỉ do kỹ năng
  `new` viết (`skills/new/references/tour.md`). `apply.py` không viết nó. Không phép kiểm nào đọc link của
  README.
- **Tái hiện:**

  ```bash
  mkdir /tmp/x && cd /tmp/x && git init -q -b main
  python3 <repo-standards>/plugins/repo-setup/scripts/apply.py --preset python --level starter \
    --var project_name=X --var description=Y --var owner=acme --json >/dev/null
  grep -n START-HERE README.md; ls docs/START-HERE.md   # link có, tệp không
  ```

- **Hướng sửa:** chủ kho chọn. Hoặc `adopt` cũng viết trang tour, hoặc dòng README chỉ có khi trang có, hoặc
  ghi vào `### Known gaps`. Cho tới khi chọn, CHANGELOG ghi nó là chỗ còn hở (K3).

## 6. Bước 4: CHANGELOG, mục `## Unreleased`

Các PR đã gộp từ `0.10.4` (`5305ab8`..`b0e296d`):

| PR | Việc | Có mục? | Mục nói gì xảy ra khi nâng? |
| --- | --- | --- | --- |
| 74 | Đổi số phiên bản sang dev | không cần | |
| 75 | `LO-TRINH.html` không là đầu vào tầng nặng | có | có |
| 76 | Sổ việc ngoài kho (5.1) | có | có («nothing»), nhưng có một câu đã sai (K1) |
| 77 | Máy soạn đổi luật, người quyết (5.3) | có | có |
| 78, 81, 85, 86, 87, 88 | Báo cáo trong `docs/` | không cần | |
| 79 | Thẻ tự chủ (5.2) | có | có |
| 80, 82 | Chỉ đổi `tests/` | không cần | |
| 83 | Kho `starter` có lớp container không nghe hứa triển khai | có | có |
| 84 | Gọi design-assembly | có | có |
| 89 | `wiki_lint` cảnh báo với tệp chưa vẽ (#69) | có | có |
| 90 | Đọc lại mẫu dữ liệu design-assembly ở 0.59.0 | không | Không cần: PR nêu lý do. `design_ledgers.py` chỉ đổi một chú thích |
| 91 | Năm câu sai trong tệp sinh ra | có | có, nhưng thiếu một ca (K3) |

Mọi PR đổi hành vi đều có mục, và mục nào cũng nói chuyện gì xảy ra khi nâng. Khoảng trống:

- **K1. Một câu đã sai.** Mục «Added: work outside the repository goes through one tool» có câu «Parts 5.3
  (the machine drafts rule changes, a person approves) and 5.2 (the autonomy card) of the design are not in
  this release». Cả hai đều đã vào `## Unreleased` (PR 77, 79). Hướng ghi: một dòng mới nói 5.2 và 5.3 cũng có
  trong bản này, không sửa câu của PR 76.
- **K2. Không mục nào nói phải chạy `make format` sau khi nâng** (L1). Mục 5.3 và mục design-assembly đều nói
  «A `settings.json` you never edited is replaced (`updated`)», làm người đọc nghĩ là xong. Ở kho Node, xong
  thật chỉ khi đã chạy định dạng.
- **K3. Mục của PR 91 chỉ nói về kho đã có `docs/START-HERE.md`** («keeps its old sentence»). Nó không nói kho
  chưa có trang ấy sẽ có một link hỏng (L2).

Ghi thêm, không phải khoảng trống: mục design-assembly nêu bản `0.35.0` và `0.36.0`. Câu đó vẫn đúng cho các
bản ấy. Plugin giờ ở `0.62.0`, và lượt thử ở mục 3.1 cho thấy chỗ nối vẫn đúng.

## 7. Đã làm và chưa làm

**Đã làm, chỉ trong scratchpad của phiên:** bản sao hai kho, bản sao design-assembly, các kho dựng thử.

**Sau khi chủ kho duyệt:** một PR mang báo cáo này, bản sửa L1 (mục 5.1) và ba dòng CHANGELOG cho K1 đến K3:
một mục «Fixed» trả lời K2, và một mục «Release notes» ghi lời đính chính K1 cùng chỗ còn hở K3. Không dòng
nào của PR khác bị sửa. `tests/run.sh` xanh trước khi commit. `tests/e2e.sh` chỉ chạy lại hai ca nâng
(`PRESETS=python UPGRADE=1`), không chạy lại 17 tổ hợp: CI của PR chạy phần còn lại.

**Một lệnh có ghi vào kho bên cạnh:** tôi đã chạy `git fetch origin` trong `~/dev/design-assembly` để đọc
phiên bản trên nhánh chính. Lệnh chỉ cập nhật nhánh theo dõi từ xa (`origin/main` vẫn ở `4f9160f`), không
đổi nhánh hay tệp nào. Lẽ ra phải hỏi trước. Mọi lần đọc sau đó đều chạy trên bản sao.

**Chưa làm (ngoài phạm vi phiên này):**

- Lượt thử trên GitHub thật ở `design-ci-probe`: luật nhánh của kho một chủ, mô tả nhãn `risk:low` sau
  `github_setup.py --apply`, các loại lệnh của sổ ngoài kho, `gh secret set` với khoá của môi trường.
- Chạy toàn bộ lệnh cài mà lượt nâng in ra. Tôi chỉ chạy bước định dạng: các bước
  `npm install --save-dev …` sẽ nâng mọi gói dev của kho lên bản mới nhất, việc chủ kho nên tự quyết.
- Sửa L2: chờ chủ kho chọn hướng.
- Thử nâng lại hai bản sao bằng cây đã sửa: bài 57 và ca e2e giữ cùng điều đó, nhưng chưa có lượt nâng
  lại trên bản sao.
