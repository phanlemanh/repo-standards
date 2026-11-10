# Tầng design trên khung `react-vite`: kế hoạch thực hiện đợt 1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repo dựng từ khung `react-vite` có sẵn sàn design ngay commit đầu tiên, qua một tầng quyết định mới và capability `design`, và bảng chấm chứng minh sàn đó chặn được lỗi thật.

**Architecture:** Dùng lại cơ chế có sẵn của `apply.py`: `capabilities/`, `[var=value]/`, `+file/`, `mk/*.mk`. Tầng `design` ghi lựa chọn vào blueprint; `blueprint.py` đổi thành `--with design` và các `--var`. Một công cụ duy nhất trong repo sinh ra (`tools/design_guards.mjs`) phục vụ cả `make check` lẫn bảng chấm.

**Tech Stack:** Python 3.11+ thư viện chuẩn và bash 3.2 cho plugin; TypeScript, React 19, Tailwind 4, shadcn 4.23, `@shadcn/lint` 0.2.5, Playwright trong repo sinh ra.

**Spec:** `docs/superpowers/specs/2026-11-09-design-layer-design.md`. Đọc spec trước khi làm. Mục 5 và 6 của spec là phạm vi; đợt 2 và 3 không nằm trong kế hoạch này.

**Bản dựng thử:** `/private/tmp/claude-501/-Users-manhphan--claude-spares-spare-YpjQSi/d77357d7-345f-446b-8a65-6630ccfda80f/scratchpad/plugin-copy/capabilities/design`. Thư mục tạm, có thể đã mất; nếu còn thì dùng để đối chiếu, mọi giá trị bắt buộc đã chép vào kế hoạch.

## Global Constraints

- Script plugin chỉ dùng thư viện chuẩn Python 3.11+. `apply.py` là đường duy nhất tạo tệp từ preset.
- `tests/run.sh` chạy được trên bash 3.2, không mạng, không dùng `sed -i`. Mỗi `SKILL.md` dưới 500 dòng.
- Mọi thứ trong `plugins/repo-setup/` viết tiếng Anh: `tests/run.sh` chặn tiếng Việt trong plugin.
- Ghim đúng: `shadcn@4.23.0`, `@shadcn/lint@0.2.5`.
- Không cài `sonner`. Linh kiện cài sẵn: button, input, label, table, card, badge, dialog, select, skeleton, empty, alert.
- Mọi tệp trong capability phải đã qua Prettier với cấu hình của khung.
- Không có `.mcp.json` trong capability. Không viết plugin ESLint riêng.
- Làm trên nhánh `feat/design-layer`, không commit thẳng vào `main`. Không dùng `--no-verify`. Commit kết thúc bằng `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Chạy phép đo tốn tiền API và đẩy repo thử lên GitHub đều phải hỏi người trước (Task 8).

## Review Focus

Mỗi dòng có bài kiểm ở task được ghi.

- Cổng 4173 đang bận vì một bản preview khác đang chạy: `make ui-floor` phải đỏ, không được kiểm nhầm bản cũ. Task 6.
- Tên dự án có dấu tiếng Việt, dấu ngoặc kép hay gạch chéo ngược đi qua các template mới: tệp sinh ra vẫn hợp lệ. Task 3.
- Blueprint chọn `design` nhưng stack không có giao diện: dừng ở bước kiểm với lời báo rõ, không dựng dở. Task 2.
- Màu thương hiệu dạng `#FFF`, chữ hoa, hoặc YAML không có ngoặc kép: mã 3 ký tự và khoá rỗng bị từ chối, chữ hoa được nhận. Task 2.
- Áp lại sau khi đã cài và định dạng: không xung đột, `src/index.css` đã sửa tay được giữ, `make check` vẫn xanh. Task 5 và 6.

---

## Sơ đồ tệp

| Tệp | Trách nhiệm |
|---|---|
| `plugins/repo-setup/skills/new/references/layers.toml`, `layers/design.md` | Khai tầng, câu hỏi, nhãn phương án |
| `plugins/repo-setup/scripts/blueprint.py` | Kiểm lựa chọn design và màu; ánh xạ sang tham số `apply.py` |
| `plugins/repo-setup/scripts/apply.py` | Biến dẫn xuất của design |
| `plugins/repo-setup/scripts/doctor.py`, `checklists/top-tier.toml` | Lọc theo khung; bốn mục chấm |
| `plugins/repo-setup/capabilities/design/` | Toàn bộ phần sinh ra |
| `tests/run.sh`, `tests/e2e.sh`, `tests/fixtures/blueprints/` | Kiểm thử |
| `tests/scenarios/design-bank.md` | Phép đo tác dụng, khoá trước khi dựng |

---

### Task 1: Khoá phép đo

Làm trước mọi thứ để lịch sử git chứng minh phép đo không chỉnh theo kết quả.

**Files:**
- Create: `tests/scenarios/design-bank.md`

**Interfaces:**
- Produces: bốn mô tả màn và bảng đếm, Task 8 dùng nguyên văn.

- [ ] **Step 1: Tạo nhánh `feat/design-layer` từ `main`, đưa spec và kế hoạch này vào commit đầu**

- [ ] **Step 2: Viết `tests/scenarios/design-bank.md`, tiếng Việt, cùng kiểu với `guided-setup.md`**

Bắt buộc có:
- Bốn mô tả viết sẵn, mỗi mô tả 3 đến 5 câu về một ứng dụng quản lý đơn hàng giả định: danh sách có lọc, biểu mẫu tạo mới, trang chi tiết, luồng xác nhận xoá. Không nhắc tới trạng thái hay linh kiện nào.
- Nền thử: repo sinh bằng `--preset react-vite --level starter --with design`.
- Nền đối chứng: đúng nền thử, rồi xoá `.claude/rules/ui.md`, `.claude/skills/ui/`, `design/`, `tools/design_guards.mjs`, `mk/design.mk`, `tests/e2e/`, `src/example/`, đoạn design trong `AGENTS.md`, khối luật giao diện trong `eslint.config.js`, và đổi `src/App.tsx` về trang một tiêu đề.
- Mỗi màn dựng ba lần bằng tác tử mới trên mỗi nền, tổng 24 lần.
- Bảng đếm cho từng lần: trạng thái thiếu so với sáu trạng thái của `design/behaviors.md` (do một tác tử chấm khác chấm trên bản đang chạy), lỗi rào còn lại khi tác tử báo xong (chạy bộ rào của nền thử trên cả hai nền), số vòng sửa, token.
- Đọc nhật ký ít nhất một lần chạy mỗi màn.
- Ngưỡng đạt, chép nguyên từ spec: số trạng thái thiếu giảm ít nhất một nửa, lỗi còn lại bằng 0, token tăng không quá 30%.

- [ ] **Step 3: Commit** với thông điệp `docs: lock the design measurement before building`.

---

### Task 2: Tầng quyết định

**Files:**
- Modify: `plugins/repo-setup/skills/new/references/layers.toml`
- Create: `plugins/repo-setup/skills/new/references/layers/design.md`, `tests/fixtures/blueprints/design.yaml`
- Modify: `plugins/repo-setup/scripts/blueprint.py`, `plugins/repo-setup/skills/new/SKILL.md:55-56`
- Modify: `tests/fixtures/blueprints/{ok,ok-designing,bad-value}.yaml` (và `pending.yaml` nếu cần), `tests/run.sh`

**Interfaces:**
- Produces, trong `blueprint.py`:
  - `contrast_ratio(a: str, b: str) -> float`, nhận `#rrggbb` không phân biệt hoa thường.
  - `readable_on(colour: str) -> str`, trả `"#ffffff"` hoặc `"#0a0a0a"`, chọn cái tương phản cao hơn.
  - `brand_errors(colour: object) -> list[str]`, rỗng nếu hợp lệ.
  - Tham số `apply.py` sinh từ blueprint: `--with design`, `--var design_surface=`, `--var brand_primary=`, `--var locale=`, `--var currency=`.

- [ ] **Step 1: Viết test trong `tests/run.sh`, ngay sau mục 26**

Thêm `design` vào danh sách tầng ghi cứng ở mục 26 (dòng `for l in context repo ...`). Thêm mục mới dùng `miss`:

```bash
# 26b. design layer: choices, colours, mapping to apply.py
python3 "$bp" check "$B/design.yaml" >/dev/null || miss "design.yaml should be valid"
args=$(python3 -c "
import sys; sys.path.insert(0, '$S'); import blueprint
from pathlib import Path
print(' '.join(blueprint.to_apply_args(blueprint.load(Path('$B/design.yaml')))))")
for w in "--with design" "design_surface=tool" "brand_primary=#0246ff" "locale=vi-VN" "currency=VND"; do
  case "$args" in *"$w"*) ;; *) miss "blueprint args lack: $w" ;; esac
done
python3 - "$S" <<'PY' || miss "colour rules"
import sys; sys.path.insert(0, sys.argv[1]); import blueprint as b
assert round(b.contrast_ratio("#0246ff", "#ffffff"), 2) == 6.32
assert b.readable_on("#0246ff") == "#ffffff" and b.readable_on("#ffba00") == "#0a0a0a"
assert b.brand_errors("#0246FF") == []
for bad in ("#ffba00", "#FFF", "blue", None, ""):
    assert b.brand_errors(bad), bad
PY
bad_design() { python3 - "$B/design.yaml" "$TMP/dv.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
  if python3 "$bp" check "$TMP/dv.yaml" >/dev/null 2>&1; then miss "design: accepted $3"; fi
}
bad_design 'surface: tool' 'surface: magazine' "an unknown surface"
bad_design 'base: shadcn' 'base: bootstrap' "an unbuilt base marked automated"
bad_design 'preset: react-vite' 'preset: python' "a stack without a screen"
bad_design 'brand_primary: "#0246ff"' 'brand_primary: #0246ff' "an unquoted colour"
grep -E 'needs_review' "$SK/SKILL.md" | grep -q 'not_applicable' || miss "needs_review ignores not_applicable layers"
```

- [ ] **Step 2: Chạy `bash tests/run.sh`, kỳ vọng `miss` báo `layer file missing: design` và các dòng trên**

- [ ] **Step 3: Khai tầng trong `layers.toml`** ngay sau `domain`, `depends_on = ["context", "stack"]`.

- [ ] **Step 4: Viết `layers/design.md`** theo đúng khung của `layers/stack.md` (Framing, Depends on, Only one sensible answer when, Options, Recommendation, Recording). Nội dung lấy từ mục 5 spec, tiếng Anh:
- Only one sensible answer: stack không có giao diện, một dòng `not_applicable`.
- Options table ba dòng với nhãn `automated`, `manual`, `manual`. Không có dòng "skip".
- Ghi rõ: ai cố ý không muốn sàn thì ghi `automation: manual` kèm `why`, và bảng chấm sẽ trừ điểm.
- Recommendation: `shadcn`, `surface` suy từ mô tả ở `context`, giữ nhận diện mặc định.
- Choice keys: `base`, `surface`, `brand_primary` (luôn có ngoặc kép), `locale`, `currency`. Máy tự điền `locale` và `currency` từ `conversation_language` (`vi` thành `vi-VN`, `VND`; khác thì `en-US`, `USD`) và hiển thị ở tổng duyệt. Đổi font ghi vào `manual_steps`.

- [ ] **Step 5: Sửa `blueprint.py`**

Hằng số: `DESIGN_BASES = {"shadcn", "company", "other"}`, `DESIGN_SURFACES = {"tool", "content"}`, `DESIGN_STACKS = {"react-vite"}`, `BRAND_MIN_CONTRAST = 4.5`.

`brand_errors`: từ chối giá trị không phải chuỗi `^#[0-9a-fA-F]{6}$` (lời báo nhắc đặt trong ngoặc kép), từ chối khi `contrast_ratio(colour, "#ffffff") < 4.5` và đề xuất sắc đậm hơn.

`_design_errors(layer, bp)`, gọi trong `errors()` cạnh `_ai_errors`: khi `status == "decided"` và `automation` khác `manual`: `base` phải là `shadcn`, `surface` phải thuộc tập, preset ở tầng `stack` phải thuộc `DESIGN_STACKS`. Nếu khoá `brand_primary` có mặt thì chạy `brand_errors` (khoá có mặt mà `None` là lỗi). `locale` khớp `^[a-z]{2}-[A-Z]{2}$`, `currency` khớp `^[A-Z]{3}$`, nếu có.

`expected_setup`: có `base` trong `c["design"]` thì thêm `"design"` vào `caps`. `to_apply_args`: truyền `design_surface` từ `surface`, và `brand_primary`, `locale`, `currency` nếu có.

- [ ] **Step 6: Sửa `SKILL.md`** bước 4 ý 4: đánh dấu `needs_review` cho tầng `decided` hoặc `not_applicable` trong danh sách.

- [ ] **Step 7: Thêm tầng vào fixture.** `ok.yaml` và các fixture khác: `design: {status: not_applicable}` cho đúng để các kỳ vọng cũ giữ nguyên. Tạo `design.yaml`: như `ok.yaml` nhưng `stack.choice.preset: react-vite`, `ai: not_applicable`, tầng `design` decided, automated, `choice` viết dạng khối, mỗi khoá một dòng, để phép thử màu không ngoặc kép đi đúng nhánh đọc ra `None`: `base: shadcn`, `surface: tool`, `brand_primary: "#0246ff"`, `locale: vi-VN`, `currency: VND`.

- [ ] **Step 8: Chạy `bash tests/run.sh`, kỳ vọng `All tests passed.`** (`design_guards` chưa có nên mục capability chưa được chạm).

- [ ] **Step 9: Commit** `feat(new): add the design decision layer`.

---

### Task 3: Capability `design`

**Files:**
- Create: `plugins/repo-setup/capabilities/design/` như dưới đây
- Modify: `plugins/repo-setup/scripts/apply.py` (`derive_vars`), `tests/run.sh`

**Interfaces:**
- Consumes: `blueprint.readable_on`, `blueprint.brand_errors`.
- Produces, trong repo sinh ra: `ReferenceScreen({ state })` với `ScreenState = "ready" | "loading" | "empty" | "error" | "no-results"`; `LABELS` trong `src/lib/labels.ts`; `formatMoney(value: number): string`, `formatDate(value: Date): string` trong `src/lib/format.ts`; `ROUTES: string[]` trong `tests/e2e/routes.ts`; đích `make design-guards`, `make ui-floor`.

- [ ] **Step 1: Viết test trong `tests/run.sh`, mục mới**

```bash
# 27. design capability
for level in starter team; do
  d="$TMP/design-$level"; mkdir -p "$d"; git -C "$d" init -q -b main
  python3 "$S/apply.py" --target "$d" --preset react-vite --level "$level" --with design \
    --var 'project_name=Quán "Cà" \ Phê' --var description=x --var owner=acme \
    --var 'brand_primary=#0246ff' --var locale=vi-VN --var currency=VND --json >/dev/null \
    || miss "design: apply failed at $level"
  grep -q -- '--primary: #0246ff' "$d/src/index.css" || miss "design: brand block missing"
  [ "$(tail -6 "$d/src/index.css" | grep -c primary)" -ge 2 ] || miss "design: brand block must come last"
  grep -q 'lang="vi"' "$d/index.html" || miss "design: page language"
  grep -q '"vi-VN"' "$d/src/lib/format.ts" && grep -q '"VND"' "$d/src/lib/format.ts" || miss "design: locale"
  grep -q 'CHECK_TARGETS += design-guards ui-floor' "$d/mk/design.mk" || miss "design: not in the gate"
  [ -f "$d/.mcp.json" ] && miss "design: must not add .mcp.json"
  again=$(python3 "$S/apply.py" --target "$d" --json | json 'len(d["created"])+len(d["updated"])+len(d["conflict"])')
  [ "$again" -eq 0 ] || miss "design/$level: second run changed $again files"
done
grep -q 'src/components/ui' "$TMP/design-team/vitest.config.ts" || miss "design: team coverage counts vendor code"
d="$TMP/design-plain"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null || miss "design: no brand must work"
grep -q 'brand' "$d/src/index.css" && miss "design: brand block without a brand"
d="$TMP/design-content"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design --var design_surface=content \
  --var project_name=P --var description=x --var owner=a >/dev/null
grep -q 'TableRow' "$d/src/example/ReferenceScreen.tsx" && miss "design: content surface got the table screen"
grep -q 'text-base' "$d/design/behaviors.md" || miss "design: content surface lacks its density"
grep -q 'text-sm' "$TMP/design-plain/design/behaviors.md" || miss "design: tool surface lacks its density"
if python3 "$S/apply.py" --target "$TMP/design-py" --preset fastapi --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: stack without a screen accepted"; fi
if python3 "$S/apply.py" --target "$TMP/design-bad" --preset react-vite --with design --var 'brand_primary=red' \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: bad colour accepted"; fi
echo "ok  design capability (or misses reported above)"
```

- [ ] **Step 2: Chạy `bash tests/run.sh`, kỳ vọng `unknown capability 'design'` qua các `miss`**

- [ ] **Step 3: `derive_vars` trong `apply.py`**

Giá trị `brand_primary` khác rỗng mà `blueprint.brand_errors` báo lỗi thì `raise ValueError`. Thêm bằng `setdefault`: `design_brand` (`"yes"` hoặc `"no"`), `brand_primary_foreground` (`readable_on` hoặc `""`), `html_lang` (phần trước dấu `-` của `locale`, mặc định `en`).

- [ ] **Step 4: `preset.toml`**

```toml
description = "Design floor for a web front end: component base, machine guards, browser checks, reference screen"
stacks = ["react-vite"]
user_owned = ["src/index.css"]
sample = ["src/example/**"]

[vars]
brand_primary = ""
design_surface = "tool"
locale = "en-US"
currency = "USD"

[starter]
install = [
  "npm install @base-ui/react class-variance-authority cn lucide-react tw-animate-css @fontsource-variable/geist shadcn@4.23.0",
  "npm install --save-dev tailwindcss @tailwindcss/vite @shadcn/lint@0.2.5 @playwright/test @axe-core/playwright",
  "npx shadcn@4.23.0 add button input label table card badge dialog select skeleton empty alert -y --overwrite",
  "npx playwright install chromium",
  "make format",
]
```

`brand_primary` phải có mặc định vì `apply.py` render `.tmpl` trước khi xét điều kiện đường dẫn. `make format` phải khác chữ với `npm run format` vì danh sách lệnh bị khử trùng.

- [ ] **Step 5: Bản chụp nền linh kiện**

Trong thư mục tạm, từ khung `react-vite` có Tailwind: `npx shadcn@4.23.0 init --template vite --base base --preset nova -y --no-monorepo </dev/null`. Lấy `components.json` vào `starter/`, `src/lib/utils.ts` vào `starter/src/lib/`, `src/index.css` vào `starter/src/+index.css/10-base.css`. Trong khối `:root` đổi `--destructive` thành `oklch(0.55 0.245 27.325)`.

`starter/src/+index.css/[design_brand=yes]/90-brand.css.tmpl` chứa `:root` với `--primary: {{brand_primary}}`, `--primary-foreground: {{brand_primary_foreground}}`, `--ring: {{brand_primary}}`.

- [ ] **Step 6: Cấu hình thay thế của khung, trong `starter/`**

- `tsconfig.json`: của khung, thêm `"paths": { "@/*": ["./src/*"] }`, không có `baseUrl`.
- `vite.config.ts`: thêm `tailwindcss()`, `resolve.alias` `@` bằng `path.resolve(import.meta.dirname, "./src")`, `test.exclude: ["node_modules/**", "tests/e2e/**"]`.
- `index.html.tmpl`: của khung, `lang="{{html_lang}}"`.
- `src/main.tsx`: của khung, thêm `import "./index.css";` ở đầu.
- `playwright.config.ts`: `testDir: "tests/e2e"`, `outputDir: "coverage/e2e"`, `reporter: "list"`, `baseURL` và `webServer.url` là `http://127.0.0.1:4173`, `webServer.command` là `npm run build && npx vite preview --host 127.0.0.1 --port 4173`, `reuseExistingServer: false`.
- `team/vitest.config.ts`: của khung cấp team, thêm `"src/components/ui/**"` vào `coverage.exclude`.
- `eslint.config.js`: của khung, thêm `import { plugin as shadcn } from "@shadcn/lint"`, và các khối sau trước `prettier`:

```js
{
  files: ["src/**/*.{ts,tsx}"],
  ignores: ["src/components/ui/**", "src/lib/format.ts"],
  plugins: { shadcn },
  rules: {
    "shadcn/no-restyle": ["error", { allow: ["layout"] }],
    "shadcn/no-raw-colors": "error",
    "shadcn/no-arbitrary-values": "error",
    "shadcn/no-inline-styles": "error",
    "shadcn/no-unknown-classes": "error",
    "shadcn/require-static-classes": "error",
    "no-restricted-syntax": ["error",
      { selector: "JSXAttribute[name.name='className'] Literal[value=/(^|[\\s:])!?(h|w|size|min-h|min-w|max-h|max-w)-(?!(0|1|2|3|4|5|6|7|8|9|10|11|12|14|16|20|24|28|32|40|48|56|64|72|80|96)(!?(\\s|$)))[0-9.]+!?(\\s|$)/]",
        message: "Size is off the scale. Use a component size or a value from the size scale." },
      { selector: "JSXAttribute[name.name='className'] Literal[value=/(^|[\\s:])!?-?(p|px|py|pt|pb|pl|pr|ps|pe|m|mx|my|mt|mb|ml|mr|ms|me|gap|gap-x|gap-y|space-x|space-y)-(?!(0|0\\.5|1|1\\.5|2|3|4|5|6|8|10|12|16|20|24)(!?(\\s|$)))[0-9.]+!?(\\s|$)/]",
        message: "Spacing is off the scale. Use 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20 or 24." },
      { selector: "JSXOpeningElement[name.name=/^(button|input|select|textarea|table)$/]",
        message: "Use the component from @/components/ui instead of a raw control." },
      { selector: "CallExpression[callee.property.name=/^toLocale(Date|Time)?String$/]", message: "Format numbers and dates with @/lib/format." },
      { selector: "CallExpression[callee.object.name='Intl']", message: "Format numbers and dates with @/lib/format." },
      { selector: "NewExpression[callee.object.name='Intl']", message: "Format numbers and dates with @/lib/format." },
    ],
  },
},
{ files: ["tools/**/*.mjs"], languageOptions: { globals: globals.node } },
{ files: ["src/components/ui/**/*.tsx"], rules: { "react-refresh/only-export-components": "off" } },
```

- [ ] **Step 7: Màn mẫu và một nguồn chữ số, tiếng Anh**

- `src/lib/format.ts.tmpl`: hằng `LOCALE = "{{locale}}"`, `CURRENCY = "{{currency}}"`, hai hàm ở Interfaces.
- `src/lib/labels.ts`: `LABELS` là object `as const` chứa mọi chữ dùng chung và chữ của màn mẫu.
- `[design_surface=tool]/src/example/ReferenceScreen.tsx`: danh sách dùng `Table`. `[design_surface=content]/src/example/ReferenceScreen.tsx`: trang đọc dùng `Card`, không dùng `Table`. Cả hai cùng export, đủ năm trạng thái: `Skeleton` khi chờ, `Alert variant="destructive"` khi lỗi, `Empty` khi trống và không có kết quả. Một `main`, một `h1`. Mọi chữ lấy từ `LABELS`.
- `src/App.tsx`: đọc `?state=` từ URL, giá trị lạ thành `"ready"`.
- `tests/App.test.tsx`: `it.each` năm trạng thái, tiêu đề so với `LABELS`, không ghi cứng chữ để bước dịch không làm đỏ test.
- `tests/e2e/routes.ts`: `/` và bốn đường `/?state=...`.
- `tests/e2e/floor.spec.ts`: mỗi đường dẫn ở 1440 và 390 px. Lần lượt: biến `--primary` trên `documentElement` khác rỗng; đúng một `main`; đúng một `h1`; `scrollWidth - innerWidth <= 0`; `violations` của axe rỗng; `incomplete` không có node `any` nào có `data.messageKey === "equalRatio"`.

- [ ] **Step 8: Lớp nạp và câu trả lời đóng, tiếng Anh**

- `dot.claude/rules/ui.md`: frontmatter `paths: ["src/**/*.tsx"]`, tối đa 40 dòng: dùng linh kiện có sẵn, không sửa `src/components/ui`, chép cấu trúc từ `src/example`, thêm màn thì thêm vào `tests/e2e/routes.ts`.
- `dot.claude/skills/ui/SKILL.md`: tối đa 60 dòng: `npx shadcn@4.23.0 search`, `view`, `docs`, `add`; khối dựng sẵn chỉ đọc, không `add`.
- `+AGENTS.md/47-design.md`: năm dòng trỏ tới hai tệp trên và `design/behaviors.md`.
- `design/+behaviors.md/10-states.md`: một trang, sáu trạng thái (loading, empty, error, no results, saving, confirm delete), mỗi trạng thái một câu và tên linh kiện.
- `design/+behaviors.md/[design_surface=tool]/20-density.md` và `[design_surface=content]/20-density.md`: một mật độ cố định. `tool`: chữ `text-sm`, dòng bảng theo chiều cao mặc định của linh kiện. `content`: chữ `text-base`, nội dung rộng tối đa `max-w-2xl`. Không có công thức theo số cột.
- `design/terms.json`: `{ "forbidden": {} }`, khoá là từ cấm, giá trị là từ dùng thay.
- `mk/design.mk`:

```make
CHECK_TARGETS += design-guards ui-floor

.PHONY: design-guards ui-floor
design-guards: ## Prove the design guards still catch real violations
	node tools/design_guards.mjs

ui-floor: ## Browser checks: page structure, accessibility, no sideways scroll
	npx playwright install $(if $(CI),--with-deps) chromium
	npx playwright test
```

`tools/design_guards.mjs` tạo ở Task 4; trong task này để tệp tối thiểu `process.exit(0)` để áp dụng được.

- [ ] **Step 9: Chạy `bash tests/run.sh`, kỳ vọng `All tests passed.`**

- [ ] **Step 10: Commit** `feat(design): add the design capability for react-vite`.

---

### Task 4: Công cụ chống gỡ rào và bảng chấm

**Files:**
- Modify: `plugins/repo-setup/capabilities/design/starter/tools/design_guards.mjs`
- Modify: `plugins/repo-setup/scripts/doctor.py:283-292`, `plugins/repo-setup/checklists/top-tier.toml`, `tests/run.sh:57-58`

**Interfaces:**
- Produces: `node tools/design_guards.mjs [--only guards|gate|reference]`, thoát 0 hoặc 1, in từng vấn đề trên một dòng. Không có `--only` thì chạy tất cả. Trường lọc `presets` cho mục chấm.

- [ ] **Step 1: Viết test trong `tests/run.sh`**

Bước 6 đổi kỳ vọng: với `react-vite`, `failed` phải là `design_present,lockfile`; khung khác vẫn `lockfile`. Thêm vào mục 27:

```bash
d="$TMP/design-starter"; git -C "$d" add -A
failed=$(python3 "$S/doctor.py" --target "$d" --level starter --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = "design_guards_bite,lockfile" ] || miss "design doctor without install: $failed"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "design checks wired wrongly"
import sys, tomllib, pathlib
checks = {c["id"]: c for c in tomllib.loads((pathlib.Path(sys.argv[1]) / "checklists/top-tier.toml").read_text())["check"]}
for k, mode in (("design_guards_bite", "guards"), ("design_floor_in_gate", "gate"), ("design_reference", "reference")):
    assert checks[k]["type"] == "command" and checks[k]["capabilities"] == ["design"] and mode in checks[k]["command"], k
assert checks["design_present"]["presets"] == ["react-vite"] and checks["design_present"]["weight"] == 3
PY
```

- [ ] **Step 2: Chạy `bash tests/run.sh`, kỳ vọng các `miss` trên**

- [ ] **Step 3: `doctor.py`:** trong `applies`, `if "presets" in c and setup.get("preset") not in c["presets"]: return False`.

- [ ] **Step 4: `top-tier.toml`:** bốn mục, `requires = "tools/design_guards.mjs"` cho ba mục `command`, `command = ["node", "tools/design_guards.mjs", "--only", "<mode>"]`, trọng số theo bảng ở mục 6 spec. `design_present`: `level = "starter"`, `presets = ["react-vite"]`, `any = [{ paths = ["tools/design_guards.mjs"] }]`, `fix` nhắc `apply.py --target . --with design`.

- [ ] **Step 5: `design_guards.mjs`**

`guards`, chỉ phần này `import("eslint")` động để hai chế độ kia chạy được khi chưa cài:
- `ESLint.lintText` với `filePath: "src/pages/guard-probe.tsx"`, mỗi dòng ghép sau `import { Button } from "@/components/ui/button";\nexport const a = `.
- Mười hai ca phải đỏ đúng luật: `bg-[#123456]`, `p-[13px]`, `h-[37px]` với `shadcn/no-arbitrary-values`; `text-red-500` với `no-raw-colors`; `style={{ padding: 13 }}` với `no-inline-styles`; `<Button className="rounded-none" />` với `no-restyle`; `rounded-huge` với `no-unknown-classes`; `p-3.25`, `h-37`, `<button />`, `<table />`, `{(1).toLocaleString()}` với `no-restricted-syntax`.
- Hai ca phải xanh: `<div className="mt-4 flex gap-2 bg-primary text-sm" />`, `<Button size="lg" className="mt-4 w-full" />`, bỏ qua `@typescript-eslint/no-unused-vars`.
- Duyệt `src` trừ `src/components/ui`: `eslint-disable` không có ` -- <lý do>` là lỗi; từ nào trong `design/terms.json` xuất hiện (không phân biệt hoa thường) là lỗi.

`gate`: `make -n check` phải có dòng đúng bằng `npx playwright test`; `mk/design.mk` phải có dòng đúng bằng tab cộng `npx playwright test`. Phải đọc tệp vì `make -n` bỏ dấu `-`.

`reference`: `design/behaviors.md` tồn tại; `tests/e2e/routes.ts` có ít nhất một chuỗi bắt đầu bằng `/`; `.claude/rules/ui.md` không quá 40 dòng; `.claude/skills/ui/SKILL.md` không quá 60 dòng.

- [ ] **Step 6: Chạy `bash tests/run.sh`, kỳ vọng `All tests passed.`** Kiểm chế độ `guards` thật ở Task 6.

- [ ] **Step 7: Commit** `feat(doctor): prove the design guards can fail`.

---

### Task 5: Áp lại không xung đột

Lỗi có sẵn: sau `npm run format`, bốn skill đổi và báo xung đột; `.repo-setup.json` được ghi lại chưa định dạng nên `prettier --check` đỏ.

**Files:**
- Modify: `plugins/repo-setup/presets/_core/starter/dot.claude/skills/{ontology-add,wiki-health,wiki-ingest,wiki-query}/SKILL.md`
- Modify: `plugins/repo-setup/presets/ts-node/starter/dot.prettierignore`, `tests/run.sh`

- [ ] **Step 1: Test trong `tests/run.sh`:** với `$TMP/ts-node-starter`, `grep -qxF '.repo-setup.json' .prettierignore`, nếu không thì `miss`.

- [ ] **Step 2: Chạy, kỳ vọng `miss`**

- [ ] **Step 3: Thêm `.repo-setup.json` vào `dot.prettierignore`.** Chạy Prettier bản của khung, cấu hình `.prettierrc.json` của khung, trên bốn tệp skill.

- [ ] **Step 4: Xác minh tay:** áp `ts-node` vào thư mục tạm, `npm install` theo danh sách, `npm run format`, áp lại `--json`: `conflict` rỗng, `prettier --check .` xanh.

- [ ] **Step 5: Commit** `fix(core): keep re-apply clean after formatting`.

---

### Task 6: Kiểm thử thật có mạng

**Files:**
- Modify: `tests/e2e.sh`

- [ ] **Step 1: Đổi danh sách**

Bỏ `react-vite` trần khỏi `ALL`, thêm vào `COMBOS`: `react-vite:none:none:design` và `react-vite:none:none:design::content`. Đọc thêm trường thứ sáu `surface`, có thì truyền `--var design_surface=$surface`.

- [ ] **Step 2: Thêm khối phá thử sau `doctor.py --min-score 100`, chỉ khi `cap` có `design`**

```bash
case ",$cap," in *,design,*)
  red() { if "${@:2}" >/dev/null 2>&1; then echo "FAIL: $1 stayed green"; exit 1; fi; }
  cp eslint.config.js "$TMP/e.bak"; grep -v 'shadcn/no-restyle' "$TMP/e.bak" > eslint.config.js
  red "removed rule" node tools/design_guards.mjs; cp "$TMP/e.bak" eslint.config.js
  cp mk/design.mk "$TMP/m.bak"; awk '{ if ($0 == "\tnpx playwright test") print "\t-npx playwright test"; else print }' "$TMP/m.bak" > mk/design.mk
  red "ignored browser step" node tools/design_guards.mjs --only gate; cp "$TMP/m.bak" mk/design.mk
  cp src/main.tsx "$TMP/s.bak"; grep -v 'index.css' "$TMP/s.bak" > src/main.tsx
  red "missing stylesheet" make ui-floor; cp "$TMP/s.bak" src/main.tsx
  f=src/example/ReferenceScreen.tsx; cp "$f" "$TMP/r.bak"; sed 's#<h1#<h2#; s#</h1>#</h2>#' "$TMP/r.bak" > "$f"
  red "missing heading" make ui-floor; cp "$TMP/r.bak" "$f"
  npx vite preview --host 127.0.0.1 --port 4173 >/dev/null 2>&1 & p=$!; sleep 2
  red "busy port" make ui-floor; kill "$p"; wait "$p" 2>/dev/null || true
  echo "/* kept */" >> src/index.css
  python3 "$S/apply.py" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d["conflict"], d["conflict"]; assert "src/index.css" in d["kept"]'
  grep -q 'kept' src/index.css || { echo "FAIL: index.css overwritten"; exit 1; }
  make check >/dev/null || { echo "FAIL: make check after re-apply"; exit 1; }
  git checkout -q -- src/index.css 2>/dev/null || true
  ;;
esac
```

- [ ] **Step 3: Chạy**

Run: `PRESETS="react-vite:none:none:design react-vite:none:none:design::content" bash tests/e2e.sh`
Expected: `E2E passed.`

- [ ] **Step 4: Chạy tiếp toàn bộ:** `bash tests/e2e.sh`, kỳ vọng `E2E passed.` Nếu Task 5 chưa đủ cho khung khác thì sửa ở Task 5.

- [ ] **Step 5: Commit** `test(e2e): break the design floor and require red`.

---

### Task 7: Luồng dựng và tài liệu

**Files:**
- Modify: `plugins/repo-setup/skills/new/SKILL.md`, `references/tour.md`, `references/layers/stack.md`, `plugins/repo-setup/README.md`, `README.md`, `README.vi.md`, `tests/scenarios/guided-setup.md`, `CHANGELOG.md`, `tests/run.sh`

- [ ] **Step 1: Test trong `tests/run.sh`, mục 26:** `SKILL.md` có `design/terms.json` và `docs_language` trong cùng bước dựng; `tour.md` có `src/example`; `plugins/repo-setup/README.md` có `ten layers`; `layers/stack.md` dòng `react-vite` nhắc `design`.

- [ ] **Step 2: Chạy, kỳ vọng `miss`**

- [ ] **Step 3: `SKILL.md` bước 6, ngay sau ý 3:** nếu có capability `design`, dịch chữ trong `src/lib/labels.ts`, `src/example/` và `design/behaviors.md` sang `docs_language`; khi viết domain thì ghi các từ đồng nghĩa cần tránh vào `design/terms.json`.

- [ ] **Step 4: Cập nhật:** `tour.md` mục 3 giới thiệu màn mẫu là thứ AI sẽ chép; bản đồ chín thành mười tầng ở README và kịch bản; `CHANGELOG.md` mục Unreleased báo tầng mới, và repo `react-vite` đã dựng sẽ trượt `design_present` cho tới khi bật capability.

- [ ] **Step 5: Chạy `bash tests/run.sh`, kỳ vọng `All tests passed.`**

- [ ] **Step 6: Commit** `docs: describe the design layer`.

---

### Task 8: Kiểm trên CI thật và đo tác dụng

Hai bước này ra ngoài máy hoặc tốn tiền. **Dừng và hỏi người trước mỗi bước.**

- [ ] **Step 1: Hỏi người repo GitHub nào được dùng để chạy thử CI.** Sau khi được đồng ý, đẩy một repo sinh từ `react-vite --with design --level team`, chạy workflow `CI`. Đạt khi job xanh và log có bước `npx playwright install --with-deps chromium`.

- [ ] **Step 2: Hỏi người cho phép chạy 24 lần theo `tests/scenarios/design-bank.md`.** Chạy đúng mô tả đã khoá ở Task 1, không sửa.

- [ ] **Step 3: Ghi kết quả vào `tests/scenarios/design-bank.md`:** bảng số, trích đoạn nhật ký đáng chú ý, đạt hay không theo ba ngưỡng.

- [ ] **Step 4: Không đạt thì dừng, báo người, sửa thiết kế trước khi phát hành.** Đạt thì commit `docs: record the design measurement`.
