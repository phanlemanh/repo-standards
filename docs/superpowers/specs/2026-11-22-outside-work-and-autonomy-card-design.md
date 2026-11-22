# Việc ngoài kho và bảng tự chủ: máy làm, người đưa khoá và quyết

Ngày 2026-11-22. Trạng thái: chủ kho duyệt bản viết này ngày 2026-11-22. Trong buổi thảo luận ngày 21 và 22/11 chủ kho
đã chốt bốn điều: (1) hướng B ở mục 4, một sổ việc ngoài kho và một lệnh, không dựng lớp riêng cho từng
nền tảng; (2) lúc dựng kho không hỏi gì về mức tự chủ, có một bảng để thấy và một cách đổi dễ; (3) thay
đổi ở tệp luật do máy soạn, chủ kho duyệt; (4) ở kho một chủ, luật nhánh không đòi code owner duyệt, và
việc chủ kho bấm gộp là duyệt (5.3). Mọi điểm khác trong trang này là đề xuất của người viết, và
được ghi là «đề xuất». Chưa có gì được dựng.

## 1. Ý định

Ngày 21/11, chủ kho bảo một phiên Claude đưa `onehub-inventory` lên bản thật. Câu trả lời đầu chia 14
việc ngoài kho thành bốn lượt ngồi, gần như tất cả do chủ kho làm. Khi chủ kho hỏi lại, cùng phiên đó
trả lời rằng nó làm được gần hết, chủ kho chỉ còn tạo năm khoá và dán chúng vào Terminal.

Câu trả lời đầu không sai so với thứ phiên đó đọc được. Rà kit và kho đó cho thấy bốn gốc:

- **Tài liệu giao việc cho người.** Sổ tay vận hành của kho đó viết «việc ngoài kho do chủ kho làm theo
  danh sách»; cả 14 việc ở dạng «vào trang nào, bấm gì». Không việc nào có lệnh, kể cả việc tạo hai môi
  trường GitHub mà `tools/github_setup.py` của kit làm được.
- **Kit dồn việc ngoài kho xuống cuối và coi nó là một khối.** `skills/new/SKILL.md` kết thúc bước dựng
  bằng «dừng và hỏi cho mọi thứ ngoài thư mục». Chỉ GitHub có công cụ, và chỉ ở bậc `team`. Nơi chạy
  ứng dụng ngoài `container` mang nhãn `manual`: chỉ ghi lại, không dựng, không chấm.
- **Không chỗ nào tách phần bí mật khỏi phần còn lại.** Một việc dính khoá thì cả việc thành của người.
- **Một lớp chặn biến «người quyết» thành «người làm».** `.claude/settings.json` sinh ra chặn agent sửa
  `.github/workflows/**` và `governance/**`, nên với tệp CI người phải tự tay dán nội dung.

Ngoài ra, mức tự chủ của agent đang đặt ở năm chỗ (quyền trong phiên, chính sách gộp, check bằng chứng,
agent trên GitHub, một câu trong `deploy.yml`), không có chỗ nào cho người dùng thấy chúng cùng lúc.

Chủ kho nêu điều mình muốn ngày 22/11: người dùng, mới hay chuyên nghiệp, không biết trước mình cần gì;
kit phải tự đặt mức ít gọi người nhất, cách đặt đơn giản nhất; khi họ muốn đổi thì đổi được dễ và nhìn
thấy được.

Xong là:

- một kho bậc `team` vừa dựng xong có một lệnh in ra ba danh sách: việc ngoài kho đã đủ, việc máy sẽ
  áp, và việc chỉ người làm được; danh sách thứ ba chỉ gồm khoá phải nhập, điều phải quyết, và việc
  làm một lần mà không máy nào làm thay được (cài GitHub App);
- không giá trị khoá nào đi qua cuộc trò chuyện, dòng lệnh hay nhật ký;
- một lệnh vẽ bảng «bạn được gọi khi nào», từ trạng thái thật, ở cả hai bậc;
- đổi mức tự chủ là một PR do máy soạn, có bảng trước và sau, chủ kho duyệt.

## 2. Mục tiêu, không phải mục tiêu, điều làm hỏng

**Mục tiêu**

- Với việc ngoài kho, người chỉ làm ba loại việc: tạo khoá ở trang dịch vụ, nhập khoá vào một lệnh hỏi
  ẩn, và quyết (duyệt bản thật, dữ liệu thật, chấp nhận rủi ro). Thêm một ngoại lệ đã có trong nguyên
  tắc của setup: việc làm một lần mà không máy nào làm thay được, như cài GitHub App.
- Việc của người gom vào một lượt, là một danh sách do máy tính ra.
- Kit không cần biết từng nền tảng. Kho sản phẩm tự khai nền tảng của mình.
- Lúc dựng không thêm câu hỏi nào. Mức tự chủ mặc định là mức thấp nhất mà máy đã chứng minh được.

**Không phải mục tiêu**

- Không tự tạo khoá ở trang dịch vụ thay người.
- Không đặt chế độ quyền của Claude Code cho người dùng.
- Không đóng chỗ hở «kho một chủ: agent dùng chung danh tính với chủ kho». Trang này chỉ ghi rõ nó.

**Điều làm hỏng, dù chạy được**

- Thêm một lần người xuất hiện so với hôm nay, hay một hộp hỏi mới lúc dựng.
- Một dòng «đã đủ» khi máy không kiểm được. Không biết thì ghi không biết.
- Bảng tự chủ thành một tệp phải giữ bằng tay, lệch khỏi trạng thái thật.
- Công cụ thành cửa để máy chạy lệnh tuỳ ý ở dịch vụ ngoài mà không ai duyệt loại lệnh đó.

## 3. Ràng buộc

- [Nguyên tắc của setup](../../setup-principles.md): người quyết, máy kiểm; setup không thêm điểm dừng
  của riêng mình; lớp chặn nằm ở nơi máy không tự gỡ được; luật chưa có máy giữ thì ghi «giữ bằng lời».
- Công cụ sinh ra chỉ dùng thư viện chuẩn của Python 3.11 trở lên, như các công cụ hiện có.
- Mã, mẫu, tên tệp, đầu ra của công cụ bằng tiếng Anh. Tài liệu trong `docs/` bằng tiếng Việt.
- Kho đã cài kit nhận thay đổi qua phép gộp ba chiều. Đổi một dòng nằm cạnh dòng kho hay sửa tay thì
  kho đó nhận dấu xung đột (bài học của 0.10.3 và 0.10.4).
- Phần chạm GitHub thật chỉ thử được ở kho thử `design-ci-probe`, và cần chủ kho cho phép từng lần.

## 4. Các hướng đã cân

| Hướng | Là gì | Đánh đổi |
| --- | --- | --- |
| A. Chỉ thêm luật | Một câu trong `AGENTS.md` sinh ra: việc ngoài kho máy làm | Rẻ nhất. Luật chỉ giữ bằng lời; phiên sau vẫn phải tự phân loại từng việc |
| **B. Sổ việc ngoài kho và một lệnh** | Kho kê từng việc ngoài kho thành dữ liệu; một công cụ kiểm, áp, hỏi khoá | Kit không cần biết nền tảng. Kho sản phẩm phải khai nền tảng của mình |
| C. Lớp riêng cho từng nền tảng | Kit sinh lệnh cho Vercel, Supabase, v.v. | Tự động nhất cho đúng nền tảng đó. Kit phải theo API từng dịch vụ; mới có một kho dùng |

Chủ kho chọn B, kèm luật của A trỏ vào công cụ. C để tới khi có kho thứ hai dùng cùng nền tảng.

## 5. Thiết kế

Ba phần, dựng theo thứ tự 5.1, 5.3, 5.2 (đề xuất). Phần 5.1 tự đứng được với các việc GitHub kit gieo
sẵn. Phần 5.3 mở cho máy soạn loại việc của nền tảng riêng. Phần 5.2 đọc cả hai. Mỗi phần một PR.

### 5.1 Sổ việc ngoài kho (bậc `team`)

**Hai tệp, hai mức quyết.** Đề xuất tách «loại việc» khỏi «từng việc»:

- `governance/outside.toml`: các **loại việc** máy được làm ngoài kho. Mỗi loại là một mẫu lệnh. Tệp
  nằm trong `governance/`, nên đổi nó là đổi luật chơi: một người quyết, một lần cho mỗi loại.
- `ops/outside.toml`: **từng việc**, là dữ liệu trỏ vào một loại. Thêm một biến môi trường là thêm một
  dòng ở đây, đi như mã sản phẩm, không gọi chủ kho.

```toml
# governance/outside.toml
[recipe.github-variable]
where = "github"
kind = "setting"
check = ["gh", "variable", "get", "{name}", "--env", "{env}"]
expect = "{value}"
apply = ["gh", "variable", "set", "{name}", "--env", "{env}", "--body", "{value}"]

[recipe.github-secret]
where = "github"
kind = "secret"
check = ["gh", "secret", "list", "--env", "{env}", "--json", "name", "--jq", ".[].name"]
expect_line = "{name}"
store = ["gh", "secret", "set", "{name}", "--env", "{env}"]
```

```toml
# ops/outside.toml
[[item]]
recipe = "github-variable"
name = "APP_URL"
env = "staging"
value = "https://staging.example.com"

[[item]]
recipe = "github-secret"
name = "RELEASE_PLEASE_TOKEN"
source = "person"
how = "GitHub > Settings > Developer settings > Fine-grained tokens: contents and pull requests, write"

[[item]]
decision = "approve-production"
when = "each deploy to production"
```

Điều các khoá trên phải giữ:

- Bốn loại: `setting` (máy kiểm và áp), `secret` (máy kiểm theo tên; giá trị do người nhập hoặc máy
  sinh), `decision` (chỉ kê ra, không có lệnh), và `action` (việc người làm một lần, như cài GitHub
  App). Một `action` có `check` thì máy kiểm. Không kiểm được thì dòng đó nhận một khoá `done` ghi ngày
  người báo đã làm; `status` tính nó là xong và in rõ «ghi bằng tay, không kiểm».
- Lệnh là danh sách đối số, không qua shell. Chỗ trống chỉ lấy từ các khoá của chính dòng đó; một chỗ
  trống không có khoá tương ứng thì công cụ từ chối cả dòng.
- `check` trả lời «đã đủ chưa». Chạy không được, hay không so được, là **không biết**, không bao giờ là
  đã đủ. `check` của một khoá không bao giờ đọc giá trị.
- Loại không có `apply` là loại máy chỉ kiểm.
- `source = "person"`: người nhập. `source = "generated"`: máy sinh giá trị ngẫu nhiên và cất, không ai
  thấy. Một dòng có thể cất cùng một giá trị ở nhiều nơi.
- Máy chỉ sinh một khoá `generated` khi nó thiếu ở **mọi** nơi cất. Có ở nơi này, thiếu ở nơi kia thì
  máy dừng và đưa dòng đó vào danh sách của người: sinh lại là xoay một khoá đang dùng, người quyết.
- Loại việc đổi chính các bức tường (luật nhánh, cách gộp, môi trường: thứ `tools/github_setup.py` ghi)
  không có `apply`. `status` nói nó lệch hay không; áp nó vẫn cần một lần đồng ý của người như nay.

**Một công cụ: `tools/outside.py`, và `make outside`.**

| Lệnh | Ai chạy | Làm gì |
| --- | --- | --- |
| `status` (mặc định) | máy hoặc người | Chạy mọi `check`. In ba danh sách: đã đủ, máy sẽ áp, của người. Có `--json` |
| `status --draft` | máy | In các lệnh mà bản trong cây làm việc **sẽ** chạy, không chạy lệnh nào |
| `apply` | máy | Áp các `setting` chưa đủ, sinh và cất các khoá `generated` còn thiếu. Không đụng khoá `person` |
| `secrets` | người, ở Terminal | Hỏi ẩn từng khoá `person` còn thiếu, đưa giá trị vào lệnh `store` qua đầu vào chuẩn |

- `secrets` từ chối chạy khi đầu vào không phải một Terminal thật. Vì thế máy không chạy thay được, và
  giá trị không đi qua cuộc trò chuyện.
- Giá trị khoá không bao giờ nằm trong đối số lệnh, đầu ra, hay tệp nào.
- Danh sách «của người» ghi cho mỗi dòng: tạo ở đâu (`how`), và vì sao máy không làm được.
- Mã thoát của `status`: 0 khi không còn gì phải làm, 1 khi còn, 2 khi gọi sai hay tệp sai.

**Cả hai tệp nạp từ nhánh gốc.** `status`, `apply` và `secrets` đọc `governance/outside.toml` và
`ops/outside.toml` của nhánh mặc định trên máy chủ, không đọc bản trong cây làm việc. Một loại việc
mới, hay một dòng mới, chỉ chạy được sau khi PR của nó đã gộp. Kho chưa có máy chủ thì đọc cây làm
việc và in ra điều đó. Lý do: `python3 tools/` nằm trong danh sách được phép của phiên, nên lệnh chạy
qua công cụ không hiện hộp xin quyền; thứ giữ thay cho hộp đó là «lệnh này đã qua một PR».

- Dòng có trong cây làm việc mà chưa có ở nhánh gốc: `status` kê nó là «chưa gộp, chưa áp».
- Soạn một loại việc mới: máy thử từng lệnh trực tiếp trong phiên, qua hộp xin quyền thường của Claude
  Code, rồi mới viết thành loại việc. `status --draft` cho xem lệnh sẽ chạy. Công cụ không chạy bản
  nháp.

**Kit gieo sẵn.**

- Các loại cho GitHub: biến, khoá, và một loại bọc `tools/github_setup.py` (chỉ kiểm, không `apply`).
- `tools/github_setup.py` có thêm `--check`: thoát 0 khi một lượt áp sẽ không đổi gì, 1 khi sẽ đổi, 2
  khi không đọc được trạng thái. Chỗ nào không so được thì tính là sẽ đổi.
- Các dòng: `RELEASE_PLEASE_TOKEN`; khoá agent và việc cài GitHub App (`action`) khi có lớp
  `github-agents`; quyết định `approve-production` khi kho chọn `--deploy container`.
- Kit không gieo `DEPLOY_ENABLED`. Mẫu `make deploy` mặc định thoát 1, nên bật sẵn là bật một lượt
  triển khai hỏng. Dòng đó do phiên thêm vào `ops/outside.toml` khi `make deploy` đã chạy được; trang
  hướng dẫn nói điều này.

**Chặng «ngoài kho» trong quy trình dựng.** Trong `skills/new/SKILL.md`, câu «dừng và hỏi cho mọi thứ
ngoài thư mục» được thay bằng một chặng cuối, chạy khi kho đã có máy chủ GitHub:

1. `status`, rồi nói bằng lời thường máy sẽ áp gì. Một lần đồng ý cho cả danh sách, như kỹ năng GitHub
   đang làm.
2. `apply`, rồi `status` lại.
3. Đưa danh sách «của người» một lần, kèm đúng một lệnh để chạy: `python3 tools/outside.py secrets`.
4. Người báo xong thì `status` lần cuối. Còn dòng nào không biết thì nói rõ.

Tạo kho GitHub và đẩy lần đầu vẫn hỏi một lần như nay: đó là việc hướng ra ngoài. `skills/github`
thành phần GitHub của cùng chặng này. `skills/adopt` chạy cùng chặng sau khi nhận kit.

Với lớp `delivery` mang nhãn `manual` (nền tảng kit không sinh): máy soạn các loại việc và các dòng
cho nền tảng đó, theo một trang hướng dẫn mới `skills/new/references/outside.md`. Các loại việc đi
theo 5.3: một PR, chủ kho duyệt. Trang hướng dẫn nói: ưu tiên lệnh dòng của chính dịch vụ, mỗi loại
phải có `check`, và phần bí mật tách thành dòng `secret` riêng.

**Luật.**

- `AGENTS.md` sinh ra, bậc `team`, thêm: việc ngoài kho đi qua `tools/outside.py`; khi phải gọi người,
  chỉ đưa danh sách «của người» mà công cụ in ra; không bao giờ nhận giá trị khoá trong cuộc trò
  chuyện. Nhãn theo [thiết kế nhãn luật](2026-11-18-rule-kinds-design.md): giữ bằng lời.
- `docs/setup-principles.md` thêm luật 11: «Việc ngoài kho: máy làm; người tạo khoá, nhập khoá và
  quyết.» Có hàng ở bảng «Luật nằm ở đâu trong mã» và một mục bài kiểm ở phần 43. Bảng «Người xuất
  hiện ở đâu» không thêm hàng: hàng «Đặt secret, cài GitHub App» đã có.

### 5.3 Máy soạn, người duyệt (bậc `team`)

Chủ kho đã chốt: thay đổi ở tệp luật do máy soạn thành PR, chủ kho duyệt.

- **Bỏ hai dòng chặn ở bậc `team`.** `Edit(./.github/workflows/**)` và `Edit(./governance/**)` rời khỏi
  `.claude/settings.json` sinh ra ở bậc `team`. Các dòng chặn đọc tệp bí mật giữ nguyên.
- **Bậc `starter` giữ hai dòng đó (đề xuất).** Bậc này không có luật nhánh hay code owner, nên không có
  bước duyệt nào mang được quyết định. Lên bậc `team` là đường để có «máy soạn, người duyệt».
- **Một mẫu, không hai bản sao.** Hai dòng đó có ở `starter` và không có ở `team` từ cùng một tệp mẫu.
- **Luật trong `AGENTS.md`** đổi từ «đừng sửa `.github/workflows/` hay `governance/`» thành: thay đổi ở
  đó đi trong một PR riêng, không kèm thứ khác; code owner quyết; không tự gộp. Phần «hạng high» vẫn do
  cổng tự chủ giữ; phần «PR riêng» và «không tự gộp» giữ bằng lời.
- **Kỹ năng đổi mức tự chủ**, sinh vào kho: `.claude/skills/autonomy-change/SKILL.md`. Người dùng nói
  bằng lời («cho máy tự gộp tài liệu»). Kỹ năng: tìm dòng của bảng tự chủ ứng với lời đó; sửa đúng một
  khoá trên một nhánh riêng; chạy phép kiểm chính sách sẵn có (nới rào mà thiếu bằng chứng máy thì bị
  từ chối, như `default: low` thiếu `proof.check`); in bảng trước và sau; mở PR; dừng.

**Kho một chủ: duyệt bằng cách nào.** Dữ kiện: luật nhánh kit ghi đòi code owner duyệt ở nơi
`CODEOWNERS` nêu tên. Ở kho một chủ, máy mở PR bằng danh tính của chính chủ kho, và GitHub không cho
tác giả tự duyệt. `onehub-inventory` đang chạy với phần đòi code owner duyệt đã tắt; PR đổi `ci.yml`
của kho đó do chủ kho tự gộp, không có lượt duyệt nào.

Chủ kho chốt ngày 2026-11-22: khi mọi người quyết ở hạng high chỉ là một tài khoản,
`tools/github_setup.py` ghi luật nhánh không đòi code owner duyệt và in ra lý do. Khi đó «duyệt» là
chủ kho tự bấm gộp, và câu «máy không tự gộp» giữ bằng lời. Điều này đúng cả khi kho bật lớp
`github-agents`: phiên Claude ở máy vẫn mở PR bằng danh tính chủ kho. Kho có từ hai người quyết trở
lên thì luật nhánh đòi code owner duyệt như nay.

### 5.2 Bảng tự chủ (cả hai bậc)

`make autonomy` chạy `tools/autonomy_card.py`, in một bảng tính từ trạng thái thật. Không tệp nào được
ghi vào git: bảng là vật dẫn xuất.

```text
Autonomy card                                              make autonomy

You are called when          You do        Why                      To be called less
1. A deploy to production    approve       always yours             -
2. The rules change          approve PR    always yours             -
3. Product code merges       merge         no machine proof yet     name a proof check
4. 3 secrets are missing     enter once    a machine cannot create  python3 tools/outside.py secrets
                                           them

The machine does, without calling you
- merges docs and tests
- deploys to staging
- GitHub settings, variables that are not secret
```

- **Viết bằng hệ quả.** Cột đầu là «bạn được gọi khi nào». Thêm `--keys` thì mỗi dòng có tệp và khoá
  đứng sau nó, cho người chuyên nghiệp.
- **Mỗi dòng có lý do và công tắc.** Dòng «luôn là của bạn» không có công tắc.
- **Nguồn của từng dòng:** `governance/autonomy.yaml` (ai gộp, bằng chứng, rào bị nới, cập nhật thư
  viện); `tools/outside.py status --json` (khoá còn thiếu, quyết định, nơi máy chỉ kiểm);
  `.repo-setup.json` (các lớp đang bật); `ontology/` (số action phải hỏi trước hay bị cấm).
- **Không biết thì ghi không biết.** Không có mạng hay chưa đăng nhập `gh`: các dòng cần GitHub ghi
  `unknown` kèm lý do.
- **Bậc `starter`:** không có chính sách và không có sổ việc ngoài kho, nên bảng ngắn: ai gộp (bạn),
  CI chạy gì, và lên bậc `team` thì có thêm gì.
- **`--json`** để phiên Claude trình bày bảng bằng ngôn ngữ của người dùng. Công cụ in tiếng Anh.
- **Mỗi lần gọi người đều nêu dòng của bảng.** `tools/autonomy.py`, khi nói hạng của một thay đổi, in
  thêm dòng của bảng ứng với nó và công tắc. Danh sách «của người» của `tools/outside.py` cũng vậy.
  `AGENTS.md` thêm luật giữ bằng lời: khi dừng chờ người, nêu dòng của bảng gây ra.
- Trang `docs/START-HERE.md` trỏ tới lệnh, không chép bảng.

## 6. Bài kiểm

Mỗi mục là một hành vi phải có bài đỏ trước khi dựng.

- `outside.py status` với lệnh thay thế: ba danh sách đúng; `check` hỏng là không biết, không là đã đủ.
- `apply` chỉ chạy `setting` chưa đủ và khoá `generated` còn thiếu; không chạy `store` của khoá `person`.
- `secrets` từ chối khi không có Terminal; giá trị không có trong đối số, đầu ra, hay tệp.
- Chỗ trống không có khoá: từ chối cả dòng. Không lệnh nào qua shell.
- Loại việc đọc từ nhánh gốc: một loại chỉ có ở cây làm việc không chạy được.
- Mọi dòng kit gieo trỏ tới một loại có thật; mọi loại có `check`.
- `github_setup.py --check`: ba mã thoát. Loại việc bọc nó không có `apply`.
- `status --draft` in lệnh của cây làm việc và không chạy lệnh nào.
- Dòng chỉ có ở cây làm việc: `status` kê «chưa gộp», `apply` không áp.
- Khoá `generated` có ở một nơi, thiếu ở nơi khác: `apply` không sinh lại, dòng vào danh sách của người.
- `action` không có `check`: thiếu `done` thì còn việc; có `done` thì xong và mang chữ «không kiểm».
- Bảng tự chủ: với từng biến thể chính sách, đúng các dòng; không có `gh` thì `unknown`.
- Mẫu quyền: `team` không có hai dòng chặn sửa, `starter` có; cả hai giữ các dòng chặn đọc bí mật.
  Bài 43g đổi theo.
- Luật 11 có hàng và có mục bài kiểm (43k). Luật mới trong `AGENTS.md` có nhãn (50m, 50n).
- Nâng cấp: kho bậc `team` chưa sửa `settings.json` mất đúng hai dòng; kho đã sửa nhận dấu xung đột.

## 7. Gãy khi nâng cấp

- Kho bậc `team`: hai dòng chặn sửa rời `settings.json`. Từ đó agent sửa được tệp CI và chính sách;
  thứ giữ là hạng high và luật nhánh. Kho chưa chạy `tools/github_setup.py --apply` thì không có gì
  giữ ngoài câu chữ: ghi rõ điều này trong changelog.
- Luật trong `AGENTS.md` đổi lời; kho nhận tệp mới `tools/outside.py`, `tools/autonomy_card.py`,
  `governance/outside.toml`, `ops/outside.toml`, hai đích `make`, và kỹ năng `autonomy-change`.
- Kho một chủ: lượt `tools/github_setup.py --apply` kế tiếp tắt phần đòi code owner duyệt (5.3). Lượt
  chạy thử in ra thay đổi này trước. Từ đó câu «máy không tự gộp» ở kho ấy chỉ giữ bằng lời: ghi rõ
  điều này trong changelog và ở mục «Chỗ còn hở» của nguyên tắc setup.
- Dòng chú thích «must be done by a human» ở đầu `governance/autonomy.yaml.tmpl` đổi lời. Nó không
  nằm cạnh khoá nào kho hay sửa, nhưng phải thử nâng cấp trên bản sao của hai kho thật trước khi ra bản.

## 8. Không dựng ở bản này

- Loại việc cho Vercel, Supabase hay nền tảng nào khác do kit phát hành (hướng C).
- Khoá dẫn xuất (một chuỗi nối dựng từ mật khẩu): người dán cả chuỗi như một khoá.
- Gói mức đặt sẵn (thấp, vừa, cao), và một trang tương tác để bật tắt.
- Sổ việc ngoài kho ở bậc `starter`.
- Một check bắt buộc đỏ cho tới khi có người duyệt (chỗ hở đã ghi ở nguyên tắc của setup).
- Lịch xoay khoá và thử khôi phục.

## 9. Để người dựng quyết

- Chia mã thành tệp và hàm nào; tên các khoá TOML ngoài những khoá nêu ở 5.1.
- Dạng so khớp của `check` (`expect`, `expect_line`, hay dạng khác), miễn giữ ba điều ở 5.1.
- `github_setup.py --check` so được những cài đặt nào; chỗ không so được tính là sẽ đổi.
- Lời của đầu ra, số mục của bài kiểm, và cách một tệp mẫu sinh hai mẫu quyền.

## 10. Đã có người thứ hai đọc

Một người đọc độc lập soát bản nháp ngày 2026-11-22 và nêu sáu câu hỏi. Năm câu người viết tự chốt,
đã ghi vào các mục trên; đây là các lựa chọn để chủ kho soát khi đọc:

| Câu hỏi | Chốt | Ở đâu |
| --- | --- | --- |
| `apply` chạy lúc nào, ai đồng ý? Dòng ở nhánh chưa gộp có đổi được cài đặt thật không? | Chỉ áp thứ đã gộp vào nhánh gốc. Loại việc đổi các bức tường thì chỉ kiểm; áp vẫn cần người đồng ý | 5.1 |
| `status` đọc loại việc từ đâu? | Cũng từ nhánh gốc. Bản nháp chỉ được in ra, không chạy | 5.1 |
| `DEPLOY_ENABLED` gieo giá trị nào? | Không gieo | 5.1 |
| Khoá `generated` có ở nơi này, thiếu ở nơi kia? | Không sinh lại; người quyết | 5.1 |
| «Cài GitHub App» thuộc loại nào? | Loại thứ tư, `action`; không kiểm được thì ghi tay và nói rõ | 5.1 |

Câu thứ sáu là kho một chủ duyệt bằng cách nào. Người đọc bổ sung trường hợp kho một chủ có bật
`github-agents`, đã đưa vào 5.3. Chủ kho trả lời ngày 2026-11-22: đồng ý tắt phần đòi code owner duyệt
ở kho một chủ, và coi việc bấm gộp là duyệt.

## 11. Chưa kiểm

- Chưa thử gì trên GitHub thật. Hành vi luật nhánh ở kho một chủ lấy từ một kho (`onehub-inventory`).
- Chưa đọc mã của phiên đã soạn «lệnh dán khoá» cho `onehub-inventory`; thiết kế `secrets` ở đây độc lập.
- `gh secret set` nhận giá trị qua đầu vào chuẩn: lấy từ cách kỹ năng GitHub hiện dùng, chưa thử với
  khoá của môi trường.
