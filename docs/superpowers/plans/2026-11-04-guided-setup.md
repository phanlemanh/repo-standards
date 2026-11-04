# Dựng repo có dẫn dắt theo tầng và phần AI: kế hoạch thực hiện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Biến `setup-new` thành luồng 9 tầng dùng được cho cả người mới và người chuyên nghiệp, thêm capability `ai` ba nấc và `github-agents`, ghi quyết định vào blueprint.

**Architecture:** Dùng lại cơ chế có sẵn của `apply.py`: lớp theo level, `capabilities/`, `[var=value]/`, `+file/`. Logic blueprint nằm trong `scripts/blueprint.py`; hội thoại nằm trong skill và `references/`. Code mẫu AI dùng lại `validate`, `plain`, `redact_output` của capability `mcp`, giống cách `http_actions.py` đang làm.

**Tech Stack:** Python 3.11+ thư viện chuẩn cho script plugin; bash 3.2 cho test; template Python (uv, Ruff, mypy, pytest) và TypeScript (vitest, tsc); SDK `anthropic` và `@anthropic-ai/sdk`.

**Spec:** `docs/superpowers/specs/2026-11-04-guided-setup-design.md`. Đọc spec trước khi làm.

## Global Constraints

- Script plugin chỉ dùng thư viện chuẩn Python 3.11+.
- `apply.py` là đường duy nhất tạo tệp từ preset; không ghi đè, chạy lại an toàn.
- `make check` không cần `ANTHROPIC_API_KEY` và không gọi API thật.
- Không test nào gọi API thật. `make eval` không nằm trong `make check` hay CI mặc định.
- Model mặc định `claude-opus-5-5`, đổi qua `CLAUDE_MODEL`. Đặt `effort` tường minh. Không dùng `temperature`, không ép `tool_choice`, không gửi cấu hình thinking.
- Cú pháp SDK lấy từ tài liệu hiện hành hoặc skill `claude-api`, không viết theo trí nhớ. Mypy strict và `tsc` phải qua trên code đó.
- `tests/run.sh` chạy được trên bash 3.2, không dùng `sed -i`. Mỗi `SKILL.md` dưới 500 dòng.
- Không dùng `--no-verify`, không nới hook secret. Commit kết thúc bằng dòng `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Làm trên nhánh `feat/guided-setup`, không commit thẳng vào `main`.
- Ngôn ngữ theo mục 5.8 của spec: mọi thứ trong `plugins/repo-setup/` viết tiếng Anh, kể cả test mẫu, chuỗi mẫu, tệp tầng và tên tệp. Chỉ dữ liệu test trong `tests/` và tài liệu trong `docs/superpowers/` được dùng tiếng Việt.

**Lệch khỏi mặc định của skill `claude-api`, có chủ ý:** mẫu không bật `fallbacks` beta. Khi `stop_reason` là `refusal`, code mẫu ném `LLMRefused` để ứng dụng tự quyết. Lý do: giữ mẫu tối giản và không phụ thuộc beta ngoài Tool Runner.

## Review Focus

- Tên dự án có dấu tiếng Việt (`Quán Cà Phê Đông`): slug phải là `quan-ca-phe-dong`, không phải `qu-n-c-ph-ng`. Test ở Task 8.
- `--with github-agents` ở level `starter`: báo lỗi rõ thay vì không sinh gì mà vẫn im lặng. Test ở Task 1.
- Repo `team` cũ có `pr-pipeline.yml` nhưng manifest không có capability: `apply.py` không xoá, `github_setup.py` vẫn giữ check `gate`, `doctor` không báo lỗi. Test ở Task 1 và 2.
- Trong nấc `agent`, handler ném lỗi, model gửi input sai hoặc hết trần lượt: agent trả kết quả lỗi cho model hoặc dừng rõ ràng, không làm sập tiến trình. Test ở Task 6.
- Blueprint còn tầng `pending` hoặc `needs_review`, hoặc chưa `approved` mà chạy thật: `apply.py` từ chối và không tạo tệp nào. Test ở Task 7.

---

## Sơ đồ tệp

| Tệp | Trách nhiệm |
|---|---|
| `plugins/repo-setup/capabilities/github-agents/` | Workflow agent, mẫu Intent, mục SDLC agent |
| `plugins/repo-setup/capabilities/ai/` | Ba nấc AI, eval, `mk/ai.mk`, mục `AGENTS.md` |
| `plugins/repo-setup/scripts/blueprint.py` | Đọc, kiểm tra blueprint; ánh xạ sang tham số `apply.py`; tính tầng phụ thuộc |
| `plugins/repo-setup/skills/setup-new/SKILL.md` | Luồng chính, gọn |
| `plugins/repo-setup/skills/setup-new/references/layers.toml` | Danh sách 9 tầng và phụ thuộc, nguồn duy nhất |
| `plugins/repo-setup/skills/setup-new/references/layers/<id>.md` | Câu hỏi, phương án, nhãn của từng tầng |
| `plugins/repo-setup/skills/setup-new/references/critic.md` | Đề bài subagent phản biện |
| `plugins/repo-setup/skills/setup-new/references/tour.md` | Khung tệp tour |
| `tests/scenarios/guided-setup.md` | Kịch bản chạy thật với Claude Code |

ID tầng dùng thống nhất: `context`, `repo`, `architecture`, `ai`, `stack`, `domain`, `quality`, `delivery`, `governance`.

---

### Task 1: Capability `github-agents`

**Files:**
- Create: `plugins/repo-setup/capabilities/github-agents/preset.toml`
- Move (`git mv`) vào `capabilities/github-agents/team/dot.github/workflows/`: `agent-implement.yml`, `agent-mention.yml`, `agent-ci-fix.yml`, `agent-maintenance.yml`, `pr-pipeline.yml`
- Move vào `capabilities/github-agents/team/dot.github/ISSUE_TEMPLATE/`: `intent.yml`
- Move vào `capabilities/github-agents/team/+AGENTS.md/`: `60-ai-native-sdlc.md`
- Create: `plugins/repo-setup/presets/_core/team/+AGENTS.md/55-autonomy.md`
- Modify: `plugins/repo-setup/scripts/apply.py` (`check_combination`), `plugins/repo-setup/checklists/top-tier.toml:378-393`, `tests/run.sh`, `tests/e2e.sh`

**Interfaces:**
- Produces: capability tên `github-agents`, bật bằng `--with github-agents`. Khoá `requires_level = "team"` trong `preset.toml` của capability, được `check_combination(preset, archetype, deploy, caps, level)` kiểm tra.

- [ ] **Step 1: Viết test đỏ trong `tests/run.sh` (mục mới)**

```bash
# team không kèm agent: không có workflow agent, doctor vẫn chỉ thiếu lockfile
n="$TMP/team-no-agents"; mkdir -p "$n" && git -C "$n" init -q -b main
python3 "$S/apply.py" --target "$n" --preset python --level team --var project_name=N --var description=x --var owner=acme >/dev/null
[ ! -e "$n/.github/workflows/pr-pipeline.yml" ] || miss "team without agents got pr-pipeline.yml"
[ ! -e "$n/.github/ISSUE_TEMPLATE/intent.yml" ] || miss "team without agents got intent.yml"
[ -e "$n/governance/autonomy.yaml" ] || miss "team lost the autonomy policy"
git -C "$n" add -A
failed=$(python3 "$S/doctor.py" --target "$n" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = lockfile ] || miss "team without agents: doctor failures: $failed"
# team kèm agent
y="$TMP/team-agents"; mkdir -p "$y" && git -C "$y" init -q -b main
python3 "$S/apply.py" --target "$y" --preset python --level team --with github-agents --var project_name=Y --var description=x --var owner=acme >/dev/null
[ -e "$y/.github/workflows/pr-pipeline.yml" ] || miss "github-agents did not add pr-pipeline.yml"
rm "$y/.github/workflows/agent-implement.yml"; mv "$y/.github/workflows/pr-pipeline.yml" "$TMP/pipeline.bak"; git -C "$y" add -A
failed=$(python3 "$S/doctor.py" --target "$y" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
case ",$failed," in *,agent_workflows,*) ;; *) miss "doctor did not notice missing agent workflows: $failed" ;; esac
# starter không nhận capability chỉ dành cho team
if python3 "$S/apply.py" --target "$TMP/bad-agents" --preset python --level starter --with github-agents --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "github-agents accepted at starter"; fi
# repo team cũ: có workflow agent, manifest không có capability
o2="$TMP/old-team"; mkdir -p "$o2/.github/workflows" && git -C "$o2" init -q -b main
printf 'name: PR pipeline\n' > "$o2/.github/workflows/pr-pipeline.yml"
python3 "$S/apply.py" --target "$o2" --preset python --level team --var project_name=O --var description=x --var owner=a >/dev/null
[ -e "$o2/.github/workflows/pr-pipeline.yml" ] || miss "apply removed an existing pr-pipeline.yml"
```

Cập nhật các test đang giả định SDLC có sẵn ở `team`: mục 13 và mục 21 thêm `--with github-agents` cho những repo được kiểm tra phần agent; `grep "## AI-native SDLC"` chỉ áp dụng cho repo đó.

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep FAIL`
Expected: có `team without agents got pr-pipeline.yml`.

- [ ] **Step 3: Chuyển tệp và tạo capability**

`preset.toml`: `description`, `when` (dùng khi muốn agent tự nhận việc từ issue và mở PR; cần GitHub App và secret; lớp này chưa từng chạy với Claude thật), `requires_level = "team"`. `55-autonomy.md` giữ các quy tắc áp dụng cả khi không có agent trên GitHub: tier lấy từ `governance/autonomy.yaml`, kiểm tier trước khi bắt đầu, không sửa `.github/workflows/` và `governance/`, không xoá hay làm yếu test.

- [ ] **Step 4: Sửa `check_combination` và checklist**

`check_combination` thêm tham số `level: str`; capability có `requires_level` mà `LEVELS.index(level)` thấp hơn thì `raise ValueError(f"{name} needs level {required}")`. Cập nhật lời gọi trong `main`. Trong `top-tier.toml`, `agent_workflows` và `intent_template` thêm `capabilities = ["github-agents"]`.

- [ ] **Step 5: Thêm tổ hợp vào `tests/e2e.sh`**

Thêm `python:none:none:github-agents` và giữ một tổ hợp không có capability này.

Đồng thời cho `e2e.sh` chạy được trên máy có `core.hooksPath` toàn cục, không tắt hook đó: khi `git config core.hooksPath` có giá trị thì bỏ qua các lệnh chứa `pre-commit install` và kiểm commit-msg bằng `pre-commit run --hook-stage commit-msg --commit-msg-filename <tệp>`; commit cuối vẫn đi qua hook toàn cục. Khi `pre-commit` không có trên `PATH` thì dùng `uvx pre-commit`.

- [ ] **Step 6: Chạy và xác nhận xanh**

Run: `bash tests/run.sh | tail -1`
Expected: `All tests passed.`

- [ ] **Step 7: Commit**

```bash
git add -A plugins/repo-setup tests
git commit -m "feat!: move GitHub agent workflows into the github-agents capability"
```

---

### Task 2: `github_setup.py` và `sdlc-github-setup` theo việc bật agent

**Files:**
- Modify: `plugins/repo-setup/presets/_core/team/tools/github_setup.py:27-39,67-175`, `plugins/repo-setup/skills/sdlc-github-setup/SKILL.md`, `tests/run.sh`

**Interfaces:**
- Consumes: tệp `.github/workflows/pr-pipeline.yml` từ Task 1.
- Produces: `plan(repo: str, branch: str, reviewer: str, marketplace: str, agents: bool) -> list[dict]`; `has_agents(root: Path) -> bool`.

- [ ] **Step 1: Viết test đỏ trong `tests/run.sh`**

```bash
steps() { ( cd "$1" && python3 -B -c "
import json,sys; sys.path.insert(0,'tools')
import github_setup as g
print(json.dumps(g.plan('o/r','main','@a','m',agents=$2)))" ); }
s=$(steps "$n" False)
echo "$s" | python3 -c "import json,sys; d=json.load(sys.stdin); w=[x['what'] for x in d]; r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check'],c; assert not any('label' in a for a in w),w; assert not any('approve' in a for a in w),w; assert not any('REPO_SETUP_MARKETPLACE' in a for a in w),w" || miss "github_setup without agents"
s=$(steps "$n" True)
echo "$s" | python3 -c "import json,sys; d=json.load(sys.stdin); r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check','gate'],c" || miss "github_setup with agents"
( cd "$o2" && python3 -B -c "import sys; sys.path.insert(0,'tools'); import github_setup as g, pathlib; assert g.has_agents(pathlib.Path('.'))" ) || miss "old team repo not detected as having agents"
```

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep 'github_setup'`
Expected: có `github_setup without agents`.

- [ ] **Step 3: Hiện thực**

`has_agents` kiểm tra tồn tại `.github/workflows/pr-pipeline.yml`, không đọc manifest, để repo cũ vẫn đúng. Không có agent thì `plan` bỏ nhãn, bỏ bước cho Actions duyệt PR, bỏ biến marketplace, required check chỉ còn `check`; vẫn giữ merge squash, môi trường và ruleset. Phần cuối chỉ nhắc secret agent khi có agent.

- [ ] **Step 4: Chia đôi `sdlc-github-setup/SKILL.md`**

Phần 1 làm việc nhóm, luôn áp dụng. Phần 2 agent trên GitHub: chỉ khi repo có `github-agents`, nêu cần GitHub App và một secret, có chi phí API, và lớp CI này chưa chạy với Claude thật.

- [ ] **Step 5: Chạy xanh và commit**

Run: `bash tests/run.sh | tail -1`
Expected: `All tests passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: configure GitHub according to whether agents are enabled"
```

---

### Task 3: Capability `ai`, nấc `call`

**Files:**
- Create: `plugins/repo-setup/capabilities/ai/preset.toml`, `starter/+AGENTS.md/46-ai.md`, `starter/+dot.env.example/40-ai.example`
- Create (Python): `starter/[lang=python]/src/{{package_name}}/llm.py`, `.../feedback.py`, `starter/[lang=python]/tests/test_llm.py.tmpl`, `starter/[lang=python]/evals/tasks.json`, `starter/[lang=python]/evals/run.py`, `starter/[lang=python]/mk/ai.mk`
- Create (TS): `starter/[lang=ts]/src/ai/llm.ts`, `src/ai/feedback.ts`, `tests/llm.test.ts`, `evals/tasks.json`, `evals/run.ts`, `mk/ai.mk`
- Move: `presets/_core/starter/dot.env.example` thành `presets/_core/starter/+dot.env.example/00-core.example`
- Modify: `plugins/repo-setup/scripts/apply.py` (`derive_vars`), `plugins/repo-setup/checklists/top-tier.toml`, `tests/run.sh`, `tests/e2e.sh`

**Interfaces:**
- Produces, Python (`llm.py`): `class LLMRefused(Exception)`; `def model_name() -> str` (đọc `CLAUDE_MODEL`, mặc định `claude-opus-5-5`); `def make_client() -> anthropic.Anthropic`.
- Produces, Python (`feedback.py`): `class Feedback(BaseModel)` với `label: Literal["positive","negative","neutral"]`; `def classify_feedback(text: str, client: LLMClient) -> Feedback`, trong đó `LLMClient` là `Protocol` chỉ khai đúng phần SDK được dùng để test thay được.
- Produces, TS (`src/ai/llm.ts`, `feedback.ts`): `LLMRefused`, `modelName()`, `makeClient()`, `classifyFeedback(text, client)`.
- Produces: biến `ai_tier` (`call|workflow|agent`, mặc định `call`), biến dẫn xuất `ai_workflow` (`yes` khi tier là `workflow` hoặc `agent`), `ai_agent` (`yes` khi tier là `agent`). `make eval` là target trong `mk/ai.mk`.

- [ ] **Step 1: Viết test đỏ trong `tests/run.sh`**

```bash
for stack in python ts-node; do
  a="$TMP/ai-$stack"; mkdir -p "$a" && git -C "$a" init -q -b main
  python3 "$S/apply.py" --target "$a" --preset "$stack" --with ai --var project_name=Ai --var description=x --var owner=acme >/dev/null || miss "ai: apply failed on $stack"
  grep -q '^CLAUDE_MODEL=' "$a/.env.example" && grep -q '^ANTHROPIC_API_KEY=$' "$a/.env.example" && grep -q '^APP_ENV=' "$a/.env.example" || miss "ai: .env.example on $stack"
  [ -f "$a/evals/tasks.json" ] && grep -q '^eval:' "$a/mk/ai.mk" || miss "ai: eval parts on $stack"
  if grep -qE '^CHECK_TARGETS.*eval' "$a/mk/ai.mk"; then miss "ai: eval joined make check on $stack"; fi
  [ "$(python3 -c "import json;print(len(json.load(open('$a/evals/tasks.json'))))")" -ge 5 ] || miss "ai: fewer than 5 eval tasks on $stack"
done
if python3 "$S/apply.py" --target "$TMP/bad-tier" --preset python --with ai --var ai_tier=magic --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "bad ai_tier accepted"; fi
```

Trong `test_llm.py.tmpl` và `llm.test.ts`, dùng client giả:

```python
def test_classify_returns_label() -> None:
    assert classify_feedback("great", FakeClient(label="positive")).label == "positive"

def test_refusal_raises() -> None:
    with pytest.raises(LLMRefused):
        classify_feedback("x", FakeClient(stop_reason="refusal"))

def test_model_name_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CLAUDE_MODEL", raising=False)
    assert model_name() == "claude-opus-5-5"
    monkeypatch.setenv("CLAUDE_MODEL", "claude-sonnet-5-5")
    assert model_name() == "claude-sonnet-5-5"
```

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep 'ai:'`
Expected: `ai: apply failed on python`.

- [ ] **Step 3: Hiện thực engine**

`derive_vars` thêm `ai_tier`, kiểm tra thuộc tập cho phép, thêm hai biến dẫn xuất. Chuyển `.env.example` sang dạng ghép `+dot.env.example/`; test cũ về `.env.example` phải vẫn qua.

- [ ] **Step 4: Viết template**

`preset.toml`: `stacks = ["ts-node", "python"]`, `sample` gồm mọi code mẫu và evals, `install` `[lang=python] uv add anthropic` và `[lang=ts] npm install @anthropic-ai/sdk`. `classify_feedback` dùng structured output theo tài liệu hiện hành, có `effort: "low"`, kiểm `stop_reason` trước khi đọc nội dung. `evals/run` cần `ANTHROPIC_API_KEY`, thiếu thì in hướng dẫn và thoát mã 2 mà không gọi mạng; có thì in số tác vụ và model trước khi chạy, chấm bằng so sánh nhãn với kết quả cuối, in tỉ lệ đạt và tổng `usage`. `mk/ai.mk` chỉ thêm target `eval`, không đụng `CHECK_TARGETS`; lệnh là `uv run python evals/run.py` ở Python và `npx tsx evals/run.ts` ở TS. `46-ai.md` theo mục 6.5 và 6.6 của spec; danh sách rủi ro đối chiếu PDF gốc của OWASP Agentic 2026 lúc viết.

- [ ] **Step 5: Thêm check doctor**

`top-tier.toml` thêm với `capabilities = ["ai"]`: `ai_evals` (có `evals/tasks.json`), `ai_eval_target` (`mk/ai.mk` khớp `^eval:`), `ai_env_example` (`.env.example` khớp `ANTHROPIC_API_KEY`). Việc `make check` không cần khoá được kiểm ở e2e (Step 6), không phải ở `doctor`.

- [ ] **Step 6: Thêm e2e và kiểm tra `make check` không cần khoá**

Mở rộng định dạng spec của `tests/e2e.sh` thành `stack:arch:deploy:caps:tier`, thêm `--var ai_tier=$tier` khi có. Thêm `python:none:none:ai:call`, `ts-node:none:none:ai:call`. Sau `verify`, với tổ hợp có `ai`:

```bash
env -u ANTHROPIC_API_KEY make check >/dev/null || { echo "FAIL: make check needs an API key"; exit 1; }
if env -u ANTHROPIC_API_KEY make eval >/dev/null 2>&1; then echo "FAIL: make eval ran without a key"; exit 1; fi
```

- [ ] **Step 7: Chạy xanh và commit**

Run: `bash tests/run.sh | tail -1 && PRESETS="python:none:none:ai:call ts-node:none:none:ai:call" SKIP=gitleaks bash tests/e2e.sh | tail -1`
Expected: `All tests passed.` và `E2E passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: add ai capability with the single-call tier"
```

---

### Task 4: Nấc `workflow`

**Files:**
- Create: `plugins/repo-setup/capabilities/ai/starter/[lang=python]/[ai_workflow=yes]/src/{{package_name}}/triage.py`, `.../tests/test_triage.py.tmpl`
- Create: `plugins/repo-setup/capabilities/ai/starter/[lang=ts]/[ai_workflow=yes]/src/ai/triage.ts`, `.../tests/triage.test.ts`
- Modify: `tests/run.sh`, `tests/e2e.sh`

**Interfaces:**
- Consumes: `classify_feedback`, `LLMClient`, `LLMRefused` từ Task 3.
- Produces: `class Triage` (`label`, `reply: str | None`); `def triage(text: str, client: LLMClient) -> Triage`. TS: `triage(text, client)`.

- [ ] **Step 1: Viết test đỏ trong template**

```python
def test_negative_gets_a_reply() -> None:
    assert triage("awful", FakeClient(label="negative", reply="Sorry")).reply == "Sorry"

def test_positive_skips_the_second_call() -> None:
    client = FakeClient(label="positive", reply="must not be used")
    assert triage("great", client).reply is None
    assert client.calls == 1
```

Trong `tests/run.sh`: repo `--var ai_tier=call` không có `triage.py`; repo `--var ai_tier=workflow` và `agent` có.

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep triage`
Expected: báo thiếu `triage.py` ở tier `workflow`.

- [ ] **Step 3: Viết `triage`**

Bước 1 gọi `classify_feedback`; cổng do code quyết định: chỉ `negative` mới sang bước 2 soạn phản hồi. Code điều khiển luồng, không phải model.

- [ ] **Step 4: Chạy e2e và commit**

Run: `PRESETS="python:none:none:ai:workflow ts-node:none:none:ai:workflow" SKIP=gitleaks bash tests/e2e.sh | tail -1`
Expected: `E2E passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: add the workflow tier to the ai capability"
```

---

### Task 5: Thực thi `agent: confirm` ở MCP và HTTP

**Files:**
- Modify: `plugins/repo-setup/capabilities/mcp/starter/[lang=python]/src/{{package_name}}/mcp_server.py.tmpl`, `[lang=ts]/src/mcp/server.ts.tmpl`, `+AGENTS.md/45-mcp.md`, `[lang=python]/tests/test_mcp.py.tmpl`, `[lang=ts]/tests/mcp.test.ts`
- Modify: `plugins/repo-setup/archetypes/service-api/starter/[lang=python]/src/{{package_name}}/http_actions.py`, `[lang=ts]/src/http/actions.ts`
- Test: `plugins/repo-setup/archetypes/service-api/starter/[lang=python]/tests/test_api.py.tmpl`, `[lang=ts]/tests/app.test.ts`. Các test này truyền action giả qua tham số `actions` của `build_router` / `registerActionRoutes`, nên độc lập với miền thật. `tests/fixtures/coffee-impl/` hiện không được script nào dùng, nên không đặt test ở đó.

**Interfaces:**
- Produces: tool MCP của action `confirm` có `_meta["anthropic/requiresUserInteraction"] = true` (JSON boolean); action khác không có khoá này. HTTP: role đúng bằng `agent` gọi action `confirm` nhận 403 với thông báo nêu cần người xác nhận; role khác không đổi.

- [ ] **Step 1: Viết test đỏ**

Trong test MCP: tool `confirm` có khoá `_meta` bằng `True`, tool `allowed` thì không; đoạn kiểm mô tả "human confirmation" vẫn giữ. Trong test HTTP:

```python
def test_agent_cannot_run_confirm_action() -> None:
    r = client.post("/v1/actions/echo-confirm", json={"text": "hi"}, headers=AGENT_KEY)
    assert r.status_code == 403
    assert "confirm" in r.json()["detail"]

def test_human_role_runs_confirm_action() -> None:
    r = client.post("/v1/actions/echo-confirm", json={"text": "hi"}, headers=STAFF_KEY)
    assert r.status_code == 200
```

Làm tương tự trong `app.test.ts`.

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `PRESETS="fastapi:service-api:container" SKIP=gitleaks bash tests/e2e.sh 2>&1 | tail -5`
Expected: test mới thất bại ở HTTP.

- [ ] **Step 3: Hiện thực**

HTTP: thêm kiểm tra ngay sau `can()`. MCP: đặt `_meta` khi dựng danh sách tool, theo đúng tên trường của SDK đang dùng. Sửa `45-mcp.md`: nhãn chỉ có tác dụng ở client hỗ trợ, Claude Code có thực thi, server không xác minh được có người duyệt hay không.

- [ ] **Step 4: Chạy xanh và commit**

Run: `PRESETS="fastapi:service-api:container ts-api:service-api:container ts-node:modular-monolith:none:mcp" SKIP=gitleaks bash tests/e2e.sh | tail -1`
Expected: `E2E passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "fix!: enforce agent: confirm in MCP and HTTP"
```

---

### Task 6: Nấc `agent`

**Files:**
- Create dưới `plugins/repo-setup/capabilities/ai/starter/[ai_agent=yes]/`: `ontology/actions.yaml`, `ontology/roles.yaml`, `ontology/entities/Note.yaml`
- Create: `[lang=python]/[ai_agent=yes]/src/{{package_name}}/agent.py`, `.../actions.py`, `.../tests/test_agent.py.tmpl`, `.../evals/agent_tasks.json`
- Create: `[lang=ts]/[ai_agent=yes]/src/ai/agent.ts`, `src/actions/index.ts`, `tests/agent.test.ts`, `evals/agent_tasks.json`
- Modify: `plugins/repo-setup/scripts/apply.py` (`capabilities_for`, hoặc nơi gộp caps trong `main`), `tests/run.sh`, `tests/e2e.sh`

**Interfaces:**
- Consumes: `agent_actions`, `validate`, `plain`, `redact_output`, `HANDLERS` từ capability `mcp`; `model_name`, `make_client` từ Task 3.
- Produces, Python: `ConfirmFn = Callable[[str, dict[str, Any]], bool]`; `def deny_all(action: str, data: dict[str, Any]) -> bool` luôn `False`; `MAX_ITERATIONS = 10`; `def agent_tools(handlers, ctx, confirm: ConfirmFn = deny_all) -> list[...]`; `def run_agent(prompt: str, client, confirm: ConfirmFn = deny_all) -> str`. TS cùng tên theo camelCase.
- Produces: `ontology` mẫu gồm entity `Note` (`id`, `text`, `author` có `pii: true`), action `searchNotes` (`kind: query`, `agent: allowed`), `deleteNote` (`kind: delete`, `agent: confirm`), `purgeNotes` (`agent: forbidden`, không có role `agent`); role `agent`, `staff`.
- Produces: `ai_tier=agent` tự thêm capability `mcp`, đứng trước `ai` trong thứ tự lớp.

- [ ] **Step 1: Viết test đỏ trong `test_agent.py.tmpl` (và bản TS tương ứng)**

```python
def test_forbidden_action_is_not_a_tool() -> None:
    assert "purgeNotes" not in tool_names(agent_tools(HANDLERS, CTX))

def test_confirm_denied_by_default_does_not_run() -> None:
    result = call_tool("deleteNote", {"id": "n1"}, confirm=deny_all)
    assert "not confirmed" in result
    assert note_exists("n1")

def test_confirm_approved_runs() -> None:
    call_tool("deleteNote", {"id": "n1"}, confirm=lambda a, d: True)
    assert not note_exists("n1")

def test_pii_is_redacted_in_tool_output() -> None:
    assert "alice" not in call_tool("searchNotes", {"query": "x"}, confirm=deny_all)

def test_invalid_input_returns_an_error_to_the_model() -> None:
    assert "invalid input" in call_tool("searchNotes", {"nope": 1}, confirm=deny_all)

def test_handler_exception_returns_an_error_to_the_model() -> None:
    assert "boom" in call_tool_with(BrokenHandlers(), "searchNotes", {"query": "x"})

def test_runner_is_bounded() -> None:
    assert FakeClient().last_kwargs_after(run_agent)["max_iterations"] == MAX_ITERATIONS
```

Trong `tests/run.sh`:

```bash
g2="$TMP/ai-agent"; mkdir -p "$g2" && git -C "$g2" init -q -b main
python3 "$S/apply.py" --target "$g2" --preset python --with ai --var ai_tier=agent --var project_name=G --var description=x --var owner=acme >/dev/null
python3 -c "import json;d=json.load(open('$g2/.repo-setup.json'));assert 'mcp' in d['capabilities'],d['capabilities']" || miss "agent tier did not bring mcp"
( cd "$g2" && python3 tools/wiki_lint.py >/dev/null ) || miss "agent tier sample ontology fails wiki-lint"
c2="$TMP/ai-call"; mkdir -p "$c2"; python3 "$S/apply.py" --target "$c2" --preset python --with ai --var project_name=C --var description=x --var owner=a >/dev/null
[ ! -e "$c2/ontology/actions.yaml" ] || miss "call tier got the sample ontology"
```

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep 'agent tier'`
Expected: `agent tier did not bring mcp`.

- [ ] **Step 3: Sửa `apply.py`**

Khi `ai` có trong caps và `ai_tier == "agent"`, thêm `mcp` ngay trước `ai`. Phải chạy sau khi có `variables`, trước `check_combination`. Thứ tự này khiến `actions.py` mẫu của `ai` thắng bản rỗng của `mcp`. Lưu caps đã bổ sung vào manifest.

- [ ] **Step 4: Viết ontology mẫu, handler và agent**

Handler dùng danh sách trong bộ nhớ. Tool Runner dùng tool JSON Schema từ `ActionSpec.input_schema` (`betaTool()` ở TS, dạng tương ứng ở Python theo tài liệu SDK). Thân mỗi tool: gọi `validate`; nếu `spec.agent == "confirm"` thì gọi `confirm`, từ chối thì trả chuỗi có `not confirmed`; gọi handler trong `try`, lỗi thì trả chuỗi lỗi; trả `redact_output(spec, plain(result))` dạng JSON. Runner đặt `max_iterations=MAX_ITERATIONS`, `max_tokens=16000`, `effort` tường minh; ghi log tổng `usage` qua `logging`, không ghi nội dung.

Thêm check doctor `ai_agent_bounded`: tệp `src/**/agent.py` hoặc `src/ai/agent.ts` khớp `MAX_ITERATIONS`. Check có khoá mới `vars = { ai_tier = "agent" }`; `applies()` trong `doctor.py` so khoá này với `vars` trong `.repo-setup.json`. Test: `sed` xoá hằng số trong repo tier `agent` thì `doctor` báo `ai_agent_bounded`; repo tier `call` không có check này.

- [ ] **Step 5: Eval cho agent**

`evals/agent_tasks.json` có ít nhất 3 tác vụ; chấm **trạng thái cuối** của kho ghi chú. Có một tác vụ yêu cầu xoá: với `deny_all`, ghi chú phải còn nguyên.

- [ ] **Step 6: Chạy e2e và commit**

Run: `PRESETS="python:none:none:ai:agent ts-node:none:none:ai:agent fastapi:service-api:none:ai:agent" SKIP=gitleaks bash tests/e2e.sh | tail -1`
Expected: `E2E passed.` Nếu tổ hợp `fastapi` lộ xung đột giữa handler mẫu và `service-api`, sửa ở đây, không bỏ tổ hợp.

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: add the agent tier built on ontology actions"
```

---

### Task 7: Blueprint

**Files:**
- Create: `plugins/repo-setup/scripts/blueprint.py`, `plugins/repo-setup/skills/setup-new/references/layers.toml`, `tests/fixtures/blueprints/ok.yaml`, `pending.yaml`, `bad-value.yaml`
- Modify: `plugins/repo-setup/scripts/apply.py`, `plugins/repo-setup/scripts/doctor.py`, `tests/run.sh`

**Interfaces:**
- Produces trong `blueprint.py`:
  - `LAYERS: tuple[str, ...]`, đọc từ `layers.toml`
  - `load(path: Path) -> dict[str, Any]`, dùng `load_yaml_file` của `presets/_core/starter/tools/repo_ontology.py` theo cùng cách `hook_pretool_gate.py` nạp code từ plugin
  - `errors(bp: dict) -> list[str]`: thiếu tầng lạ, `status` hoặc `automation` sai, tầng `decided` không có `why`
  - `blocking(bp: dict) -> list[str]`: các tầng `pending` hoặc `needs_review`
  - `to_apply_args(bp: dict) -> list[str]`: ánh xạ theo bảng dưới, bỏ qua tầng `automation: manual`
  - `dependents(layer: str) -> list[str]`: bắc cầu theo `depends_on`
  - `manual_steps(bp: dict) -> list[str]`
- CLI: `blueprint.py check FILE` (in lỗi, thoát 1), `blueprint.py dependents LAYER`.
- `apply.py --from-blueprint FILE`. `doctor.py` thêm `report["blueprint_drift"]: list[str]`, `report["manual_steps"]: list[str]`, không ảnh hưởng điểm.

| Tầng | Khoá `choice` | Tham số |
|---|---|---|
| `context` | `project_name`, `description`, `owner` | `--var k=v` |
| (cấp cao nhất) | `conversation_language`, `docs_language` | `--var k=v` |
| `repo` | `license` | `--var license=v` |
| `architecture` | `archetype` | `--archetype v` |
| `ai` | `ai_tier` (`none` thì bỏ qua) | `--with ai --var ai_tier=v` |
| `stack` | `preset` | `--preset v` |
| `quality` | `level` | `--level v` |
| `delivery` | `deploy` | `--deploy v` |
| `governance` | `capabilities` (danh sách), `marketplace` | `--with`, `--var marketplace=v` |

`depends_on` trong `layers.toml`: `repo` và `architecture` theo `context`; `ai` theo `architecture`; `stack` theo `architecture`, `ai`; `domain` theo `architecture`, `ai`; `quality` theo `repo`; `delivery` theo `architecture`, `stack`; `governance` theo `ai`, `quality`.

- [ ] **Step 1: Viết test đỏ trong `tests/run.sh`**

```bash
B="$ROOT/tests/fixtures/blueprints"
bp="$S/blueprint.py"
python3 "$bp" check "$B/ok.yaml" >/dev/null || miss "blueprint: ok rejected"
if python3 "$bp" check "$B/bad-value.yaml" >/dev/null 2>&1; then miss "blueprint: bad value accepted"; fi
deps=$(python3 "$bp" dependents ai)
case " $deps " in *stack*domain*|*domain*stack*) ;; *) miss "blueprint: dependents of ai: $deps" ;; esac
x="$TMP/bp-ok"; mkdir -p "$x" && git -C "$x" init -q -b main
python3 "$S/apply.py" --target "$x" --from-blueprint "$B/ok.yaml" --json | json 'd["preset"]+"/"+d["level"]+"/"+",".join(d["capabilities"])' | grep -q '^python/starter/ai$' || miss "blueprint: wrong mapping"
y2="$TMP/bp-pending"; mkdir -p "$y2"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/pending.yaml" >/dev/null 2>&1; then miss "blueprint: pending applied"; fi
[ -z "$(ls -A "$y2")" ] || miss "blueprint: pending wrote files"
python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" --dry-run >/dev/null || miss "blueprint: designing dry-run refused"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" >/dev/null 2>&1; then miss "blueprint: designing applied"; fi
cp "$B/ok.yaml" "$x/setup-blueprint.yaml"; git -C "$x" add -A
python3 "$S/doctor.py" --target "$x" --json | json 'd["blueprint_drift"]' | grep -q '^\[\]$' || miss "blueprint: false drift"
python3 - "$x/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["archetype"]="service-api"; json.dump(d,open(p,"w"))
PY
python3 "$S/doctor.py" --target "$x" --json | json 'len(d["blueprint_drift"])' | grep -qv '^0$' || miss "blueprint: drift not reported"
```

Thêm `ok-designing.yaml` (giống `ok.yaml`, `status: designing`).

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep 'blueprint:' | head -3`
Expected: có `blueprint: ok rejected`.

- [ ] **Step 3: Viết `layers.toml` và `blueprint.py`**

- [ ] **Step 4: Nối vào `apply.py`**

`--from-blueprint` không dùng chung với các cờ preset khác. Thứ tự: `errors` có thì báo và thoát 2; `blocking` có thì từ chối; không phải `--dry-run` mà `status` khác `approved` và `applied` thì từ chối. Sau đó ánh xạ qua `to_apply_args` và chạy luồng hiện có. Việc cập nhật `status: applied` do skill làm; `apply.py` không ghi vào blueprint.

- [ ] **Step 5: Nối vào `doctor.py`**

Có `setup-blueprint.yaml` thì so `to_apply_args` với `.repo-setup.json` về preset, level, archetype, deploy, capabilities. Với `capabilities`, coi tập trong manifest là bao hàm tập blueprint, vì `ai_tier=agent` thêm `mcp`. Text report có mục cảnh báo và việc tay. Blueprint hỏng là một dòng cảnh báo, không làm `doctor` sập.

- [ ] **Step 6: Chạy xanh và commit**

Run: `bash tests/run.sh | tail -1`
Expected: `All tests passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: record setup decisions in a blueprint"
```

---

### Task 8: Luồng theo tầng trong skill

**Files:**
- Rewrite: `plugins/repo-setup/skills/setup-new/SKILL.md`
- Create: `plugins/repo-setup/skills/setup-new/references/layers/{context,repo,architecture,ai,stack,domain,quality,delivery,governance}.md`, `references/critic.md`, `references/tour.md`
- Create: `plugins/repo-setup/presets/_core/starter/+AGENTS.md/15-language.md.tmpl`
- Modify: `plugins/repo-setup/skills/setup-adopt/SKILL.md`, `plugins/repo-setup/skills/ontology-add/SKILL.md`, `plugins/repo-setup/presets/_core/starter/ontology/glossary.md.tmpl`, `plugins/repo-setup/checklists/top-tier.toml`, `tests/fixtures/coffee/glossary-rows.md`, `plugins/repo-setup/scripts/apply.py` (`derive_vars`, kiểm phiên bản Python), `doctor.py` và `detect.py` (kiểm phiên bản Python), `tests/run.sh`

**Interfaces:**
- Consumes: `layers.toml`, `blueprint.py`, `apply.py --from-blueprint`, `--list-options`.
- Produces: tệp tour `docs/START-HERE.md` ở repo đích, nội dung theo `docs_language`; blueprint `setup-blueprint.yaml`; biến `conversation_language`, `docs_language`, mặc định `en`.

- [ ] **Step 1: Viết test đỏ trong `tests/run.sh`**

```bash
SK="$ROOT/plugins/repo-setup/skills/setup-new"
for l in context repo architecture ai stack domain quality delivery governance; do
  [ -f "$SK/references/layers/$l.md" ] || miss "layer file missing: $l"
  for w in "Framing" "automated" "Recommendation"; do grep -q "$w" "$SK/references/layers/$l.md" 2>/dev/null || miss "layer $l lacks: $w"; done
done
for f in "$ROOT"/plugins/repo-setup/skills/*/SKILL.md; do [ "$(wc -l < "$f")" -lt 500 ] || miss "too long: $f"; done
grep -q 'references/critic.md' "$SK/SKILL.md" && grep -q 'references/tour.md' "$SK/SKILL.md" && grep -q 'from-blueprint' "$SK/SKILL.md" || miss "setup-new does not use its references"
grep -qi 'really need an agent' "$SK/references/layers/ai.md" || miss "ai layer does not ask whether an agent is needed"
if grep -q 'make every technical choice for them' "$SK/SKILL.md"; then miss "setup-new still decides everything alone"; fi
v="$TMP/viet"; mkdir -p "$v"
slug=$(python3 "$S/apply.py" --target "$v" --preset python --var 'project_name=Quán Cà Phê Đông' --var description=x --var owner=a --dry-run --json | json '[c for c in d["created"] if c.startswith("src/")][0].split("/")[1]')
[ "$slug" = quan_ca_phe_dong ] || miss "Vietnamese project name gives package: $slug"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "Vietnamese text or non-ASCII path inside the plugin"
import pathlib, re, sys
vi = re.compile("[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]", re.I)
bad = []
for p in pathlib.Path(sys.argv[1]).rglob("*"):
    if p.is_file():
        if not str(p.relative_to(sys.argv[1])).isascii():
            bad.append(str(p))
        elif p.name != "README.md" and "__pycache__" not in p.parts and vi.search(p.read_text("utf-8", "ignore")):
            bad.append(str(p))
print(*bad, sep="\n")
sys.exit(1 if bad else 0)
PY
la="$TMP/lang"; mkdir -p "$la"
python3 "$S/apply.py" --target "$la" --preset python --var project_name=L --var description=x --var owner=a --var conversation_language=vi --var docs_language=en >/dev/null
grep -q '^## Language' "$la/AGENTS.md" && grep -q 'Conversation: vi' "$la/AGENTS.md" && grep -q 'Documents: en' "$la/AGENTS.md" || miss "AGENTS.md lacks the language rule"
grep -q 'Display name' "$la/ontology/glossary.md" || miss "glossary lacks a display name column"
git -C "$la" init -q -b main; git -C "$la" add -A
python3 "$S/doctor.py" --target "$la" --json | json '",".join(r["id"] for r in d["failed"])' | grep -q language_policy && miss "doctor rejects the language section"
old=/usr/bin/python3
if [ -x "$old" ] && ! "$old" -c 'import tomllib' 2>/dev/null; then
  msg=$("$old" "$S/apply.py" --list-presets 2>&1 || true)
  case "$msg" in *"Python 3.11"*) ;; *) miss "old Python: unfriendly error: $msg" ;; esac
fi
```

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep -E 'layer file|Vietnamese' | head -3`
Expected: `layer file missing: context` và lỗi slug.

- [ ] **Step 3: Sửa slug và thông báo Python**

Trong `derive_vars`, thêm `conversation_language` và `docs_language` mặc định `en`; bỏ dấu trước khi tạo `slug` và `package_name`: `unicodedata.normalize("NFKD", ...)`, bỏ dấu kết hợp, đổi `đ` thành `d`. Trong ba script, kiểm `sys.version_info < (3, 11)` trước `import tomllib`, in hướng dẫn bằng tiếng Anh có chữ `Python 3.11` rồi thoát 2. Thân script phải vẫn parse được trên 3.9.

Tạo `15-language.md.tmpl` theo mục 5.8 của spec, có hai dòng `Conversation: {{conversation_language}}` và `Documents: {{docs_language}}`. Thêm cột cuối `Display name` vào `glossary.md.tmpl` và `glossary-rows.md`; cập nhật `ontology-add`. Thêm check `language_policy` (`AGENTS.md` khớp `(?m)^## Language`) vào `top-tier.toml`, level `starter`, weight 1.

- [ ] **Step 4: Viết `references/layers/*.md`**

Viết bằng tiếng Anh. Mỗi tệp theo mục 5.3 của spec, gồm: Framing; khi nào coi là chỉ có một đáp án; các phương án kèm lý do, đánh đổi, trường hợp sai, khoá nhãn `automated` / `partial` / `manual` đúng bảng 5.1 của spec, kèm dòng `Recommendation`; cách ghi vào blueprint; và cách đề xuất mặc định cho độ sâu "Giao cho Claude". `ai.md` lấy bảng và bốn tiêu chí từ mục 6.1, 6.2 của spec.

- [ ] **Step 5: Viết `references/critic.md` và `references/tour.md`**

`critic.md`: đề bài cho subagent chỉ đọc, chỉ nhận `setup-blueprint.yaml` và mô tả bối cảnh; báo mâu thuẫn giữa các tầng, khoảng trống, rủi ro lớn nhất; nhắc rằng đồng ý mà không nêu lý do thì vô giá trị. `tour.md`: khung theo mục 5.7 của spec và bản nháp trong giả lập; bắt buộc có mục nói rõ điểm `doctor` đo gì và không đo gì.

- [ ] **Step 6: Viết lại `SKILL.md`**

Theo thứ tự: kiểm Python; `detect.py`; bức tranh toàn cảnh 9 tầng; chọn độ sâu; vòng lặp mỗi tầng; xử lý `needs_review` qua `blueprint.py dependents`; tổng duyệt với `critic.md` và `apply.py --from-blueprint --dry-run`; lấy `conversation_language` và `docs_language` ở bước đầu, nói chuyện và dịch nhãn theo chúng; chạy tự động theo mục 5.6; tạo ghi chép trong `wiki/decisions/` cho mỗi tầng `decided` có phương án bị loại, riêng "Giao cho Claude" gộp thành một ghi chép; cập nhật blueprint thành `applied`; tour; đề nghị commit. Giữ quy tắc: không ghi đè, không tự tạo repo GitHub, không push, việc chạm ra ngoài luôn hỏi. Mặc định không bật `github-agents`. Phiên mới gặp blueprint chưa xong thì làm tiếp.

- [ ] **Step 7: Sửa `setup-adopt`**

Dùng chung các tệp tầng. Tầng `ai` mang nhãn `manual`, không thêm capability `ai` (mục 6.7 của spec).

- [ ] **Step 8: Chạy xanh và commit**

Run: `bash tests/run.sh | tail -1`
Expected: `All tests passed.`

```bash
git add -A plugins/repo-setup tests
git commit -m "feat: guide setup through decision layers"
```

---

### Task 9: Tài liệu, bảng tra và phát hành

**Files:**
- Create: `README.vi.md`
- Modify: `README.md`, `plugins/repo-setup/README.md`, `plugins/repo-setup/skills/setup-explain/SKILL.md`, `CHANGELOG.md`, `.github/workflows/test.yml`, `tests/run.sh`

**Interfaces:** không có interface mới.

- [ ] **Step 1: Viết test đỏ**

```bash
if grep -q 'your-org/repo-standards' "$ROOT/README.md"; then miss "README still says your-org"; fi
grep -q 'phanlemanh/repo-standards' "$ROOT/README.md" || miss "README lacks the real marketplace"
E="$ROOT/plugins/repo-setup/skills/setup-explain/SKILL.md"
for t in pyproject.toml .coveragerc .gitleaks.toml setup-blueprint.yaml evals/; do grep -q "$t" "$E" || miss "setup-explain lacks: $t"; done
if grep -q 'hidden from logs and from AI agents automatically' "$E"; then miss "setup-explain overclaims pii"; fi
[ -f "$ROOT/README.vi.md" ] || miss "README.vi.md missing"
grep -q 'README.vi.md' "$ROOT/README.md" || miss "README does not link the Vietnamese version"
if grep -qi 'real guardrails\|Rào chắn thật' "$ROOT/plugins/repo-setup/README.md"; then miss "plugin README overclaims guardrails"; fi
grep -q 'plugin validate plugins/repo-setup' "$ROOT/.github/workflows/test.yml" || miss "CI does not validate the plugin folder"
```

- [ ] **Step 2: Chạy và xác nhận đỏ**

Run: `bash tests/run.sh 2>&1 | grep -E 'README|setup-explain|validate' | head -3`
Expected: có `README still says your-org`.

- [ ] **Step 3: Sửa README và bảng tra**

Bỏ điều kiện `p.name != "README.md"` trong kiểm tra ngôn ngữ của `tests/run.sh` (thêm ở Task 8), vì README của plugin giờ đã là tiếng Anh. `README.md` viết tiếng Anh, tên repo thật, điều kiện cần có, link tới `README.vi.md`. `README.vi.md` là bản tiếng Việt cùng nội dung. `plugins/repo-setup/README.md` viết hoàn toàn bằng tiếng Anh: thêm luồng theo tầng, capability `ai`, `github-agents`, quy tắc ngôn ngữ; viết lại đoạn "Rào chắn thật" thành hai nhóm: cưỡng chế phía server (ruleset, CODEOWNERS, cổng PR) và rào theo lời gọi tool (deny rule, hook). `setup-explain`: thêm các tệp trong test; viết lại câu về `pii: true` (che ở kết quả trả về agent, ở trường cấp một; vẫn phải tự cẩn thận khi ghi log) và `.mcp.json`.

- [ ] **Step 4: Sửa CI và CHANGELOG**

`test.yml`: thêm `npx -y @anthropic-ai/claude-code plugin validate plugins/repo-setup`. `CHANGELOG.md` thêm mục `## Unreleased` gồm thay đổi phá vỡ: level `team` không còn kèm agent, kèm cách nâng cấp `--with github-agents`; `agent: confirm` đổi hành vi ở MCP và HTTP. Không tăng version; việc đó do chủ repo làm bằng `tools/bump_version.py`. Lưu ý `bump_version.py` chèn mục mới ngay sau tiêu đề, nên mục `Unreleased` sẽ cần gộp tay khi phát hành.

- [ ] **Step 5: Chạy toàn bộ và commit**

Run: `bash tests/run.sh | tail -1 && bash tests/e2e.sh | tail -1 && npx -y @anthropic-ai/claude-code plugin validate . && npx -y @anthropic-ai/claude-code plugin validate plugins/repo-setup`
Expected: `All tests passed.`, `E2E passed.`, và cả hai lần validate không báo lỗi. Nếu `validate plugins/repo-setup` lộ lỗi ở tệp có sẵn, sửa ở đây vì trước nay chưa từng được kiểm.

```bash
git add -A README.md CHANGELOG.md plugins/repo-setup .github tests
git commit -m "docs: describe guided setup and correct overstated guarantees"
```

---

### Task 10: Kịch bản chạy thật với Claude Code

Task này chỉ viết kịch bản. **Không chạy chúng khi chưa có chủ repo đồng ý**, vì tốn tiền API.

**Files:**
- Create: `tests/scenarios/guided-setup.md`, `tests/fixtures/blueprints/prepared-conflict.md`

**Interfaces:**
- Consumes: toàn bộ các task trước.

- [ ] **Step 1: Viết `prepared-conflict.md`**

Một bản thiết kế dán vào, có mâu thuẫn cố ý: `ai_tier: agent` nhưng `Không có người duyệt, chạy không tương tác` và cần action xoá dữ liệu. Ghi rõ mâu thuẫn phản biện phải bắt được: action `confirm` luôn bị từ chối khi không tương tác.

- [ ] **Step 2: Viết `guided-setup.md`**

Ba kịch bản theo mục 10 của spec, mỗi kịch bản gồm tin nhắn đầu vào, điều phải thấy, điều không được xảy ra:

| Kịch bản | Phải thấy | Không được xảy ra |
|---|---|---|
| Người mới, "Giao cho Claude" | Bức tranh 9 tầng ngắn; chỉ dừng ở tổng duyệt; `doctor` 100; có `docs/START-HERE.md` tiếng Việt | Hỏi chọn level; bật `github-agents` |
| Người chuyên nghiệp, duyệt từng tầng | 2–3 phương án có nhãn ở tầng có lựa chọn; bỏ qua tầng một đáp án; đổi `architecture` thì tầng phụ thuộc thành `needs_review` | Phương án thiếu nhãn |
| Người chuyên nghiệp, dán `prepared-conflict.md` | Giữ lựa chọn đã nêu; phản biện nêu đúng mâu thuẫn | Tự sửa lựa chọn của người dùng mà không hỏi |

Thêm mục một lần gọi thật qua `make eval` ở mỗi nấc, và ghi chỗ điền kết quả.

- [ ] **Step 3: Commit**

```bash
git add tests/scenarios tests/fixtures/blueprints/prepared-conflict.md
git commit -m "test: add live scenarios for guided setup"
```

- [ ] **Step 4: Báo cáo trạng thái**

Nêu rõ trong báo cáo cuối: kịch bản chưa chạy, nên tiêu chí "Phải có phiên Claude Code thật" và "Cần người thật" trong mục 10 của spec vẫn **chưa đạt**.
