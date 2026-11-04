# Thiết kế: dựng repo có dẫn dắt theo tầng và phần AI trong sản phẩm

Ngày: 2026-11-04. Trạng thái: chờ duyệt. Áp dụng cho plugin `repo-setup`, mốc `f99cc0e`.

Tài liệu liên quan: [báo cáo đối chiếu best practices](https://claude.ai/artifact/C2fVTN89B7DzcMF7RVeKPi), [giả lập buổi setup đầu tiên](https://claude.ai/artifact/LwkYJtKbwhUsPcrqBM5Sa9).

## 1. Ý định

Plugin đang coi người dùng là người chưa biết gì: Claude tự chọn mọi thứ, hỏi tối đa hai vòng, không ra ngoài preset. Điều đó hợp với người mới, nhưng người chuyên nghiệp đã có sẵn một phần lựa chọn thì không được giúp làm rõ, tìm khoảng trống hay phản biện.

Chủ repo muốn một công cụ dùng được cho cả hai nhóm: thấy bức tranh toàn cảnh trước, đi qua từng tầng quyết định, mỗi tầng có 2–3 đề xuất kèm lý do để điều chỉnh, rồi quá trình setup tự chạy. Ngoài ra, plugin chưa có đường nào để dựng sản phẩm có LLM hoặc agent bên trong, trong khi đó là khoảng trống lớn nhất so với cách làm hiện nay.

## 2. Mục tiêu

- Người mới vẫn đi hết luồng mà không phải hiểu các lựa chọn kỹ thuật, và cuối buổi có tài liệu giải thích bằng ngôn ngữ của họ.
- Người chuyên nghiệp đưa được lựa chọn sẵn có vào, được hỏi đúng chỗ thiếu hoặc mâu thuẫn, và được phản biện độc lập.
- Mọi quyết định được ghi lại cùng lý do và phương án bị loại, và phiên bị ngắt thì làm tiếp được.
- Sau tổng duyệt, phần dựng repo tự chạy, chỉ dừng ở việc chạm ra bên ngoài.
- Dựng được sản phẩm có AI ở ba nấc: gọi LLM một lần, workflow do code điều khiển, một agent.

### Không làm trong đợt này

- Preset monorepo, cơ sở dữ liệu, stack mới (Go, Rust, Java), web full-stack, hướng sự kiện. Các phương án này vẫn được đề xuất, kèm nhãn "ghi quyết định, làm tay".
- Managed Agents, Agent SDK, RAG, MCP từ xa, OpenTelemetry, A2A, orchestrator-workers: đề xuất và ghi quyết định, chưa sinh code.
- Các sửa đổi CI từ báo cáo đối chiếu (`allowed_bots`, job `review`, lỗ `.gate/`, ghim plugin). Chúng làm ở đợt riêng.
- Preset cho từng framework agent.

### Điều làm thiết kế này thất bại dù vẫn chạy được

- Đề xuất một phương án rồi plugin không làm được mà không nói trước.
- Người mới bị hỏi nhiều hơn hiện tại.
- Phản biện chỉ là hình thức, luôn đồng ý với đề xuất ban đầu.
- Tầng không có lựa chọn thật vẫn dừng lại để hỏi.
- Sản phẩm AI mẫu gọi API tốn tiền trong `make check`, hoặc `make check` cần API key mới xanh.
- Điểm `doctor` hoặc tài liệu tour hứa cứng hơn thực tế.

## 3. Ràng buộc

- Script của plugin chỉ dùng thư viện chuẩn Python 3.11+.
- `apply.py` vẫn là đường duy nhất tạo tệp từ preset; không ghi đè, chạy lại an toàn.
- Skill dưới 500 dòng; chi tiết để ở `references/` theo khuyến nghị [progressive disclosure](https://code.claude.com/docs/en/skills#add-supporting-files).
- CI hiện tại (offline trên Ubuntu và macOS, e2e, validate) phải tiếp tục xanh; `tests/run.sh` chạy được trên bash 3.2.
- Code mẫu gọi Claude phải dùng SDK chính thức (`anthropic`, `@anthropic-ai/sdk`) và lấy cú pháp từ tài liệu hiện hành, không viết theo trí nhớ.
- `make check` phải chạy không cần mạng tới API và không cần `ANTHROPIC_API_KEY`.

## 4. Các quyết định đã chốt

**Của chủ repo:**
- Một công cụ cho cả người mới và người chuyên nghiệp.
- Có bức tranh toàn cảnh; đi theo tầng; mỗi tầng 2–3 đề xuất kèm lý do, cho điều chỉnh; hỗ trợ làm rõ, tìm khoảng trống, phản biện; tự động hoá setup.
- Vòng lặp Framing, Phân tích, Hoàn thiện, Đề xuất.
- Phần AI trong sản phẩm làm ngay ở đợt 1.
- Tách workflow agent trên GitHub thành tuỳ chọn riêng ở level `team`, về cấu trúc chứ không chỉ đổi lời dẫn.
- Chuẩn hoá ngôn ngữ theo mục 5.8.

**Giả định chờ chủ repo xác nhận:** phương án ngoài khả năng tự động vẫn được đề xuất, kèm nhãn rõ ràng (câu hỏi này chưa được trả lời trực tiếp).

**Quyết định của người viết (có thể sửa):**
- Mở rộng `setup-new`, không tạo skill thứ hai.
- AI là một **capability** `ai`, không phải archetype. Lý do: `--archetype` chỉ nhận một giá trị, trong khi `service-api` hay `modular-monolith` đều có thể có AI. Đề xuất `ai-app` trước đó đổi theo hướng này.
- Nấc agent mặc định dùng **Tool Runner** của SDK thường, không dùng Agent SDK như đề xuất trước đó. Lý do: agent sản phẩm thường chỉ cần các tool do ontology định nghĩa, không cần Bash và quyền đọc ghi tệp; Agent SDK hợp với agent làm việc trên tệp và mã. Agent SDK vẫn là một phương án trong tầng 4, nhãn "ghi quyết định, làm tay".
- Bản ghi quyết định là `setup-blueprint.yaml` ở gốc repo đích.
- Việc tách workflow agent dùng một capability `github-agents`, xem mục 8.1.

## 5. Luồng

### 5.1 Bức tranh toàn cảnh

Sau khi chạy `detect.py`, Claude hiện danh sách 9 tầng với trạng thái từng tầng (đã có sẵn, chờ quyết định, không cần quyết định) và mời dán những gì đã nghĩ, dưới dạng tự do hoặc tệp.

| # | Tầng | Quyết định chính | Khả năng đợt 1 |
|---|---|---|---|
| 1 | Bối cảnh | Mục tiêu, đội, ràng buộc, tuân thủ, thời hạn | Ghi quyết định, là đầu vào cho các tầng sau |
| 2 | Chiến lược repo | Một repo, monorepo, nhiều repo; nhánh; phát hành; license | Một repo và license tự động; nhánh, phát hành dùng quy ước sẵn có, muốn khác thì ghi quyết định, làm tay; monorepo và nhiều repo ghi quyết định, làm tay |
| 3 | Kiến trúc | `service-api`, `modular-monolith`, không dùng | Tự động |
| 4 | AI trong sản phẩm | Không dùng, gọi một lần, workflow, agent; nơi chạy agent | Xem mục 6 |
| 5 | Stack và công cụ | Ngôn ngữ, framework | 5 stack tự động; ngoài ra ghi quyết định |
| 6 | Miền và dữ liệu | Ontology, PII, action, role; cơ sở dữ liệu | Ontology tự động; cơ sở dữ liệu ghi quyết định |
| 7 | Chất lượng và bảo mật | Ngưỡng coverage, quét bảo mật, level | Tự động theo level, ngưỡng cố định như hiện tại; muốn ngưỡng khác thì ghi quyết định, làm tay |
| 8 | CI/CD và triển khai | CI, container, môi trường | Tự động cho `container`; khác ghi quyết định |
| 9 | Agent làm dev và quản trị | Tier, MCP, hook, ai duyệt, có bật agent trên GitHub không | Bật hay tắt agent trên GitHub: tự động. Còn lại tự động một phần: dùng chính sách mẫu; đổi tier hay người duyệt là việc của người vì `governance/` bị chặn với agent; kèm cảnh báo lớp CI chưa chạy với Claude thật |

Tầng 4 đứng trước tầng 5 vì nó ảnh hưởng tới stack. Hiển thị một danh sách cho người mới phải ngắn, không kèm thuật ngữ.

### 5.2 Ba độ sâu

Cùng một logic, chỉ khác số lần dừng. Đổi được ở từng tầng bất kỳ lúc nào.

- **Giao cho Claude.** Chọn phương án đề xuất cho mọi tầng, chỉ dừng ở tổng duyệt. Mặc định khi người dùng không nêu lựa chọn kỹ thuật nào. Level mặc định là `starter`.
- **Duyệt từng tầng.** Dừng ở mỗi tầng có lựa chọn thật.
- **Đã có bản thiết kế.** Điền trước từ nội dung được dán, gắn nguồn "người dùng nêu"; chỉ hỏi chỗ thiếu hoặc mâu thuẫn. Vẫn qua phản biện ở tổng duyệt.

### 5.3 Vòng lặp mỗi tầng

1. **Framing.** Một câu tầng này quyết định gì, ràng buộc nào từ các tầng trước.
2. **Phân tích.** 2–3 phương án. Mỗi phương án có lý do, đánh đổi, trường hợp nó sai, và nhãn mức tự động. Phương án đề xuất đứng đầu. Lựa chọn người dùng đã nêu luôn được đưa vào danh sách, kể cả khi Claude không đề xuất nó.
3. **Hoàn thiện.** Người dùng chọn, sửa, hoặc hỏi sâu hơn. Claude nêu khoảng trống của lựa chọn đó, như quyết định kéo theo chưa được nói tới.
4. **Đề xuất.** Chốt, ghi vào blueprint, báo tầng nào bị ảnh hưởng.

Quy tắc:
- Tầng chỉ có một đáp án hợp lý thì nói một dòng rồi đi tiếp, không hỏi.
- Dùng `AskUserQuestion` khi có; không có thì hỏi trong một tin nhắn ngắn. Công cụ này giới hạn 4 lựa chọn, nên 2–3 phương án là vừa.
- Không có phương án nào được nêu nếu thiếu nhãn.

**Ba nhãn mức tự động:**

| Nhãn | Nghĩa |
|---|---|
| Tự động | `apply.py` làm được, có kiểm chứng |
| Tự động một phần | Làm được phần lõi, còn bước tay được liệt kê |
| Ghi quyết định, làm tay | Plugin chỉ ghi quyết định và hướng dẫn; `doctor` không chấm phần này |

### 5.4 Khi đổi tầng trên

Mỗi tầng khai báo tầng phụ thuộc trong `references/layers/`. Đổi quyết định ở tầng trên thì các tầng phụ thuộc đã chốt được đánh dấu `needs_review`, và Claude đi lại đúng các tầng đó.

### 5.5 Tổng duyệt và phản biện

Sau tầng cuối:
1. Claude gọi một subagent chỉ đọc, chỉ nhận blueprint và bối cảnh, không nhận lý luận của phiên chính. Nó báo mâu thuẫn giữa các tầng, khoảng trống, và rủi ro lớn nhất. Không có subagent thì Claude tự đọc lại theo cùng tiêu chí và nói rõ đây là tự kiểm tra.
2. Hiện bản tóm tắt theo tầng, kết quả phản biện, và kết quả `apply.py --dry-run`.
3. Người dùng duyệt.

Với người mới, kết quả phản biện chỉ hiện những gì cần họ quyết định.

### 5.6 Tự động hoá sau duyệt

`apply.py` theo blueprint, cài đặt, thay ontology mẫu nếu người dùng đã mô tả miền, chạy `next_commands.verify`, `doctor`, tạo ghi chép quyết định, tạo tệp tour, đề nghị một commit. Tự sửa định dạng; lỗi khác thử tối đa 2 lần rồi báo đúng lỗi. Việc chạm ra ngoài (tạo repo GitHub, push, GitHub App, secret, chi phí API) luôn hỏi riêng.

### 5.7 Tệp tour

`docs/START-HERE.md` trong repo đích, nội dung viết theo `docs_language`, sinh theo đúng những gì vừa dựng. Nội dung theo bản nháp trong giả lập: hiện trạng, ba lệnh, trong repo có gì, việc tự động, điều nên biết về an toàn, chưa làm, việc tiếp theo. Với người chuyên nghiệp, thêm mục tóm tắt quyết định, trỏ tới blueprint.

### 5.8 Quy tắc ngôn ngữ

| Lớp | Thành phần | Ngôn ngữ |
|---|---|---|
| Code và máy đọc | Tên biến, hàm, tệp, thư mục; comment; test; log; commit, nhánh, tiêu đề PR; `CHANGELOG`; tên entity, action, role; heading bắt buộc của wiki | Luôn tiếng Anh |
| Chỉ dẫn cho AI | Thân skill, agent, `AGENTS.md`, `CLAUDE.md`, mô tả tool | Tiếng Anh; `description` của skill có thể thêm từ khoá tiếng Việt |
| Hội thoại | Câu hỏi, đề xuất, nhãn phương án, giải thích của Claude | `conversation_language` |
| Tài liệu cho người đọc | Tệp tour, nội dung wiki, spec, mô tả PR | `docs_language` |
| Giao diện sản phẩm | Chuỗi người dùng cuối thấy | Theo sản phẩm, ngoài quy tắc này |

- Thuật ngữ kỹ thuật giữ nguyên (`repo`, `commit`, `CI`, `hook`), giải thích ở lần đầu khi nói với người mới.
- Thuật ngữ nghiệp vụ: tên trong code tiếng Anh; `ontology/glossary.md` có thêm cột tên hiển thị theo `docs_language`. Từ không dịch được thì viết không dấu và giải thích trong glossary.
- Ngôn ngữ code không cấu hình được. Hai biến mặc định `en` khi không có thông tin; `setup-new` lấy từ ngôn ngữ người dùng đang nói và ghi vào blueprint.
- Tệp tầng lưu khoá `automated`, `partial`, `manual`; Claude dịch nhãn khi nói chuyện.
- `AGENTS.md` sinh ra có mục `## Language` nêu quy tắc này và giá trị hai biến; `doctor` kiểm tra mục đó tồn tại.
- Repo này: `README.md` và `plugins/repo-setup/README.md` tiếng Anh, thêm `README.vi.md`. Tài liệu trong `docs/superpowers/` để tiếng Việt, vì `docs_language` của repo này là `vi`.
- Chưa kiểm chứng: skill mô tả bằng tiếng Anh có được kích hoạt tốt khi người dùng nói tiếng Việt không. Đo bằng `claude plugin eval` khi chủ repo đồng ý.

## 6. Tầng AI và capability `ai`

### 6.1 Câu hỏi mở đầu

Tầng 4 luôn bắt đầu bằng: có thật sự cần agent không? Dùng bốn tiêu chí: độ phức tạp, giá trị, năng lực của model, chi phí khi sai và khả năng khôi phục. Một tiêu chí không đạt thì đề xuất nấc đơn giản hơn. Phương án "không dùng AI" luôn có mặt.

### 6.2 Ba nấc tự động

Biến `ai_tier` chọn nấc, dùng cơ chế `[var=value]/` có sẵn. Nấc sau bao gồm nấc trước.

| Nấc | Dùng khi | Sinh ra |
|---|---|---|
| `call` | Phân loại, tóm tắt, trích xuất | Một client, một lần gọi có structured output, xử lý `stop_reason` gồm `refusal` |
| `workflow` | Nhiều bước do code điều khiển | Chuỗi hai bước, có kiểm tra giữa các bước |
| `agent` | Bài toán mở, cần model tự quyết bước đi | Vòng lặp Tool Runner, tool lấy từ ontology, trần lượt và trần chi phí, cổng xác nhận |

**Nơi chạy agent, đề xuất ở tầng 4:**

| Phương án | Hợp khi | Nhãn |
|---|---|---|
| Tool Runner (mặc định) | Tool do mình định nghĩa, tự host | Tự động |
| Vòng lặp tự viết | Cần kiểm soát từng bước, không muốn phụ thuộc beta | Ghi quyết định, làm tay |
| Agent SDK | Agent làm việc trên tệp và mã | Ghi quyết định, làm tay |
| Managed Agents | Chạy dài, cần sandbox do Anthropic host. Đang beta, không có ZDR và HIPAA | Ghi quyết định, làm tay |

`AskUserQuestion` giới hạn 4 lựa chọn, nên bảng này vừa đủ.

### 6.3 Nối với ontology

Nấc `agent` lấy tool từ `ACTIONS` đã sinh, dùng lại `can()`, kiểm tra đầu vào và `redactPII` của capability `mcp`, không chép logic. Action `forbidden` không xuất hiện.

**Nguồn tool trong repo vừa dựng.** Capability kèm một ontology mẫu trung tính: một entity, hai action (một `allowed`, một `confirm`) và handler chạy được, để `make check` và e2e kiểm tra được bằng máy. Người mới dùng "Giao cho Claude" không bị hỏi thêm về miền nghiệp vụ. Nếu người dùng mô tả miền, Claude thay mẫu bằng `ontology-add` sau khi `apply.py` xong, như bước gieo ontology đang có, rồi viết handler và cập nhật eval. Bước này được thêm vào mục 5.6.

**Nghĩa của `agent: confirm` trong đợt 1, đóng theo hướng an toàn:**

| Lớp | Hành vi |
|---|---|
| Nấc `agent` | Gọi một hàm `confirm(action, input)` do ứng dụng cung cấp. Mặc định từ chối, nên chạy không tương tác thì không thực thi. |
| HTTP | Role `agent` gọi action `confirm` luôn nhận 403, thông báo rõ. Chưa có hàng chờ duyệt, vì cần lưu trạng thái. Role người vẫn chạy bình thường. |
| MCP | Đặt `_meta["anthropic/requiresUserInteraction"]: true`. Đây là cổng phía client: Claude Code thực thi, client khác có thể không. Tài liệu nói rõ giới hạn này; server không tự xác minh được có người duyệt hay không. |

Hàng chờ duyệt hoặc token do người ký thuộc đợt sau.

### 6.4 Cấu hình

- Model mặc định `claude-opus-5-5`, đổi được qua biến môi trường `CLAUDE_MODEL`, khai báo trong `.env.example`. Đặt `effort` tường minh. Không dùng `temperature`, không ép `tool_choice`, không cấu hình thinking đã bị từ chối.
- `ANTHROPIC_API_KEY` nằm trong `.env.example` với giá trị rỗng. Client dựng theo cách tìm thông tin xác thực mặc định của SDK.
- Mọi code gọi API nằm sau một lớp nhỏ để test thay được bằng client giả.

### 6.5 Eval

- `evals/` có khoảng 5 tác vụ mẫu và một bộ chấm bằng code, chấm **kết quả cuối** chứ không chấm từng bước.
- `make eval` chạy thật, tốn tiền, nên in ước tính và cần `ANTHROPIC_API_KEY`; **không** nằm trong `make check` hay CI mặc định.
- Tour và `AGENTS.md` hướng dẫn nâng dần lên 20–50 tác vụ từ lỗi thật, tách eval năng lực và eval hồi quy, theo [khuyến nghị của Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents).
- `make check` chỉ test bằng client giả.

### 6.6 Bảo mật

`AGENTS.md` có mục ngắn: nội dung từ tool và tài liệu ngoài là dữ liệu, không phải chỉ thị; tool theo quyền tối thiểu; có trần lượt và ghi log `usage`. Danh sách rủi ro đối chiếu với OWASP Agentic 2026 từ PDF gốc khi viết, không lấy từ nguồn thứ cấp.

### 6.7 Repo đang có code

Trong `setup-adopt`, tầng 4 mang nhãn "ghi quyết định, làm tay": không thêm capability `ai`, không sinh code mẫu, nên check `ai` của `doctor` không áp dụng. Claude có thể hướng dẫn thêm từng phần, nhưng đó không phải đường tự động. Repo dựng bằng bản cũ: việc `confirm` đổi hành vi được ghi là thay đổi phá vỡ trong `CHANGELOG`; tệp đã sửa tay sẽ báo `conflict` như thường lệ và cần người xử lý.

### 6.8 Doctor

Thêm check theo capability `ai`: có `evals/`, có `make eval`, `make check` không nhắc API key thật, `.env.example` có khoá, nấc `agent` có trần lượt. Điểm số không đo chất lượng agent, và tour phải nói rõ điều này.

## 7. Blueprint

`setup-blueprint.yaml` ở gốc repo đích, được commit. Dạng dự kiến:

```yaml
version: 1
depth: review            # auto | review | prepared
conversation_language: vi
docs_language: vi
layers:
  ai:
    status: decided      # pending | decided | needs_review | not_applicable
    source: user         # user | proposed
    choice: {ai_tier: agent, agent_runtime: tool-runner}
    automation: automated  # automated | partial | manual
    why: "Hỏi đáp có nhiều bước không biết trước"
    rejected:
      - {option: workflow, why: "Không liệt kê trước được các bước"}
    manual_steps: []
```

- `apply.py --from-blueprint <file>` đọc phần `automated` và `partial`, ánh xạ thành `--preset`, `--level`, `--archetype`, `--deploy`, `--with`, `--var`. Có thể kèm `--dry-run`.
- Giá trị không hợp lệ thì báo lỗi, không đoán.
- Phiên mới gặp blueprint chưa xong thì làm tiếp từ tầng dở.
- Blueprint là **bản ghi của buổi setup**, không phải trạng thái mong muốn sống cùng repo. Có thêm trường cấp cao `status: designing | approved | applied` và `applied_at` để làm tiếp khi lỗi xảy ra sau tổng duyệt. Sau `applied`, đổi kiến trúc hay hạ nấc AI là việc tay, vì `apply.py` chỉ cộng thêm và không xoá tệp. `.repo-setup.json` vẫn là nguồn sự thật về những gì đã áp dụng.
- Mỗi tầng `decided` có phương án bị loại sinh một ghi chép trong `wiki/decisions/`, trừ người mới dùng "Giao cho Claude": gộp thành một ghi chép.
- `doctor` so blueprint với `.repo-setup.json`, báo lệch là cảnh báo, và liệt kê `manual_steps` chưa xong là việc cần làm, không trừ điểm.

## 8. Các sửa đổi đã giả lập

- `README.md` đúng tên `phanlemanh/repo-standards`, nêu điều kiện cần.
- `setup-new` kiểm tra Python 3.11+ trước khi hỏi, chạy được cả khi `python3` quá cũ, có hướng dẫn dễ hiểu.
- Nói rõ điểm `doctor` đo gì và không đo gì.
- Bảng tra của `setup-explain` có thêm các tệp hay gặp như `pyproject.toml`, `.coveragerc`, `.gitleaks.toml`; sửa câu hứa quá mức về `pii: true` và `.mcp.json`.

### 8.1 Tách agent trên GitHub

Level `team` nay chỉ gồm phần làm việc nhóm. Agent trên GitHub là capability `github-agents` với lớp `team/`, bật bằng `--with github-agents`. Cơ chế capability, lớp theo level và bộ lọc `capabilities` của `doctor` đã có sẵn, nên không cần biến hay level mới.

| Phần | Vị trí sau khi tách |
|---|---|
| `agent-implement.yml`, `agent-mention.yml`, `agent-ci-fix.yml`, `agent-maintenance.yml`, `pr-pipeline.yml` | Chuyển sang `capabilities/github-agents/team/` |
| Mẫu issue `intent.yml`, các mục SDLC agent trong `AGENTS.md` | Chuyển theo capability |
| `ci.yml`, `pr-title.yml`, `release.yml`, `deploy.yml`, pre-commit, quét bảo mật, CODEOWNERS | Giữ ở `team` |
| `governance/autonomy.yaml`, `tools/autonomy.py`, hook `PreToolUse` | Giữ ở `team`, vì Claude Code chạy local vẫn cần cổng này |

Hệ quả cần làm cùng:
- Check `agent_workflows` và `intent_template` chỉ áp dụng khi bật capability.
- `github_setup.py` chỉ yêu cầu check `gate` và tạo nhãn agent khi repo có `pr-pipeline.yml`; nếu không thì required check chỉ còn `check`.
- `sdlc-github-setup` chia hai phần: làm việc nhóm, và agent trên GitHub cần App và secret. Phần sau nêu rõ lớp CI chưa chạy với Claude thật, và phương án này mặc định là không bật.
- Đây là thay đổi phá vỡ của level `team`, ghi vào `CHANGELOG`. Repo cũ có workflow agent trong manifest được tự giữ capability này khi chạy lại `apply.py`, kèm một ghi chú, để không mất mục SDLC trong `AGENTS.md`.
- Capability này không sửa các lỗi CI trong báo cáo đối chiếu. Chúng vẫn thuộc đợt riêng, nhưng nay chỉ ảnh hưởng tới người chủ động bật.

## 9. Tệp bị ảnh hưởng

| Tệp | Thay đổi |
|---|---|
| `plugins/repo-setup/skills/setup-new/SKILL.md` | Viết lại thành luồng theo tầng, giữ dưới 500 dòng |
| `plugins/repo-setup/skills/setup-new/references/layers/*.md` | Mới: mỗi tầng một tệp gồm câu hỏi, phương án, nhãn, phụ thuộc |
| `plugins/repo-setup/skills/setup-new/references/critic.md` | Mới: đề bài cho subagent phản biện |
| `plugins/repo-setup/skills/setup-new/references/tour.md` | Mới: khung tệp tour |
| `plugins/repo-setup/skills/setup-adopt/SKILL.md` | Dùng chung các tầng, không đưa mẫu vào repo đang có code |
| `plugins/repo-setup/skills/setup-explain/SKILL.md` | Bổ sung và sửa bảng tra |
| `plugins/repo-setup/scripts/apply.py` | `--from-blueprint` |
| `plugins/repo-setup/scripts/doctor.py`, `checklists/top-tier.toml` | Check `ai`, đối chiếu blueprint |
| `plugins/repo-setup/capabilities/ai/` | Mới: `preset.toml`, `starter/` cho `lang=ts`, `lang=python`, `[ai_tier=...]/` |
| `plugins/repo-setup/capabilities/mcp/`, `archetypes/service-api/` | Thực thi `agent: confirm` |
| `plugins/repo-setup/capabilities/github-agents/` | Mới: nhận các workflow và fragment chuyển từ `presets/_core/team/` |
| `plugins/repo-setup/presets/_core/team/` | Bỏ các phần đã chuyển; giữ phần làm việc nhóm |
| `plugins/repo-setup/presets/_core/team/tools/github_setup.py` | Yêu cầu check và nhãn theo việc bật agent |
| `plugins/repo-setup/skills/sdlc-github-setup/SKILL.md`, `CHANGELOG.md` | Chia hai phần; ghi thay đổi phá vỡ |
| `README.md`, `README.vi.md`, `plugins/repo-setup/README.md` | Tiếng Anh, thêm bản tiếng Việt, cập nhật nội dung |
| `presets/_core/starter/+AGENTS.md/`, `ontology/glossary.md.tmpl` | Mục `## Language`, cột tên hiển thị |
| `tests/run.sh`, `tests/e2e.sh` | Test mới, thêm tổ hợp `ai` |

## 10. Tiêu chí nghiệm thu

**Máy kiểm tra được:**
- `tests/run.sh` xanh trên Ubuntu và macOS, có test: blueprint hợp lệ và không hợp lệ, ánh xạ blueprint thành tham số `apply.py`, `needs_review`, cả ba `ai_tier`, `make check` không cần `ANTHROPIC_API_KEY`, không có tệp nào gọi API trong test.
- `tests/e2e.sh` xanh với `python`, `ts-node`, `fastapi`, `ts-api` kèm `--with ai` ở các nấc đã chọn.
- Nấc `agent`: action `forbidden` không thành tool; action `confirm` bị từ chối khi chạy không tương tác; có test cho PII.
- `claude plugin validate` xanh cho marketplace và cho `plugins/repo-setup`. Mọi `SKILL.md` dưới 500 dòng.
- Không có ký tự tiếng Việt trong `plugins/repo-setup/`, và mọi đường dẫn trong đó là ASCII. `AGENTS.md` sinh ra có mục `## Language` đúng giá trị hai biến.
- Level `team` không kèm `github-agents`: không có `agent-*.yml`, `pr-pipeline.yml`, và `doctor` đạt 100. Kèm `github-agents`: có đủ các tệp, và thiếu một tệp thì `doctor` báo. E2e có cả hai tổ hợp.

**Phải có phiên Claude Code thật:**
- Ba kịch bản theo giả lập: người mới dùng "Giao cho Claude", người chuyên nghiệp duyệt từng tầng, người chuyên nghiệp dán bản thiết kế có một mâu thuẫn cố ý. Phản biện phải bắt được mâu thuẫn đó.
- Có thể đo kích hoạt và hành vi skill bằng `claude plugin eval`, chạy thủ công vì tốn tiền.
- Một lần gọi thật qua `make eval` ở mỗi nấc.

**Cần người thật:** một người mới và một người chuyên nghiệp thử, ghi lại chỗ vấp. Chủ repo tự quyết định lúc nào làm.

## 11. Để người hiện thực quyết định

- Nội dung sample cụ thể của từng nấc, miễn là giải được một bài toán nhỏ theo miền của dự án.
- Cấu trúc tệp bên trong `capabilities/ai/`.
- Cú pháp SDK cụ thể, lấy từ tài liệu hiện hành.
- Cách đọc YAML của blueprint bằng thư viện chuẩn, có thể dùng bộ đọc trong `repo_ontology.py`.
- Cách chia commit và thứ tự làm.

## 12. Đợt sau

Preset monorepo, cơ sở dữ liệu, stack mới; sinh code cho Agent SDK và Managed Agents; RAG; MCP từ xa có xác thực; OpenTelemetry; orchestrator-workers; A2A. Mỗi mục làm khi có nhu cầu thật, và đổi nhãn từ "ghi quyết định" sang "tự động" khi có kiểm chứng.
