# Mô phỏng một người mới đi qua `/repo-setup:new` bản 0.10.4

Ngày: 2026-11-24. Trạng thái: báo cáo phát hiện, không sửa gì trong kho này. Chủ kho chọn việc nào làm.

Đây là lượt chạy thật mà mục R4 của [báo cáo UX audit](https://github.com/phanlemanh/repo-standards/pull/86)
(`docs/reports/2026-11-22-ux-audit.md`, nhánh `claude/ux-audit-b8f4ca`, chưa gộp) đề nghị. Audit đếm
điểm dừng từ lời của skill; báo cáo này đếm từ một phiên Claude Code thật, với một người mới do máy đóng
vai.

## Kết luận ngắn

1. **Cuộc trò chuyện lúc setup nhẹ hơn cả audit đếm.** Người mới «giao hết cho Claude» chỉ phải trả lời
   hai lần: duyệt kế hoạch và đồng ý commit. Không có câu hỏi tên dự án, không có câu hỏi đẩy lên
   GitHub. Từ câu đầu tiên đến một trang web chạy được trên máy là khoảng 7 phút và 3 tin nhắn.
2. **Sản phẩm làm được việc.** Trang mượn thiết bị chạy, bấm «Cho mượn» thì thẻ đổi sang «Đang mượn»
   và lịch sử ghi đúng. `make check` xanh trong 2 giây, `doctor` 100/100. Phiên con nói thật rằng nó
   chưa bấm thử trên trình duyệt, và còn đề xuất thẳng «Google Form có thể đã đủ».
3. **Chỗ đau nằm ở hai đầu, không ở giữa.** Đầu vào: một người mới hay hỏi «X là gì?» bị kéo qua bốn
   vòng từ mới (Python, máy chủ, container, volume) rồi duyệt trong lúc mệt. Đầu ra: kho nhận về có 71
   tệp, 64% số dòng (không tính lockfile) là công cụ của setup, và người mới không hiểu 16 từ trong
   README và `make help`. Họ nói sẽ chỉ dùng `make dev`.
4. **Lời dặn «web app nhỏ cho team» rơi ra ngoài sàn thiết kế.** Cả hai lượt chọn một stack có máy chủ
   (vì dữ liệu phải dùng chung), nên lớp `design` không áp dụng: giao diện viết tay, không có bài kiểm
   giao diện nào, mà `doctor` vẫn cho 100/100. Đây là phát hiện mới, audit không có.

## Cách làm

- **Bản được thử:** `repo-setup` 0.10.4, đúng bản người mới cài. Cây của tag `repo-setup-v0.10.4`
  (commit `f8e6a1a`) được giải nén vào scratchpad và nạp bằng `--plugin-dir`, nên kết quả không phụ
  thuộc `main` (`0.10.5.dev0`).
- **Phiên con sạch:** `claude -p --setting-sources project,local --strict-mcp-config --plugin-dir …`.
  Một lượt dò trước xác nhận phiên con chỉ thấy năm skill của `repo-setup`, không thấy hook,
  `CLAUDE.md` hay plugin nào khác của máy này. Mô hình của phiên con là Opus 5.5.
- **Nhiều lượt:** `--output-format stream-json`, rồi `--resume <session id>` cho mỗi câu trả lời. Mỗi
  lượt được tách thành ba tệp: toàn bộ luồng, phần người dùng nhìn thấy (chữ của Claude, cộng một dòng
  cho mỗi công cụ được gọi, như ô thu gọn trong giao diện), và danh sách công cụ.
- **Người mới:** chân dung viết ra trước lượt đầu và giữ nguyên (`persona.md`). Hà, điều phối vận
  hành ở một team 12 người, viết tiếng Việt, giỏi Excel, chưa gõ lệnh git bao giờ, chưa có tài khoản
  GitHub công việc, muốn thay Google Sheet ghi mượn thiết bị bằng một trang web nhỏ. Một tác tử con chỉ
  nhìn thấy những gì phiên con in ra đóng vai Hà và gõ từng câu trả lời; nó không đọc mã nguồn plugin
  hay tài liệu của kho này.
- **Hai lượt:** lượt 1 là Hà giao hết cho Claude. Lượt 2 là cùng Hà, nhưng dừng lại hỏi «X là gì?» ở
  từ đầu tiên không hiểu, mỗi tin nhắn một từ.
- **Vách ngăn:** `GH_CONFIG_DIR` trỏ vào một thư mục rỗng nên `gh` không đăng nhập được, không có
  remote nào, `GIT_TERMINAL_PROMPT=0`. Không tạo kho GitHub, không đẩy gì, không chạy
  `/repo-setup:github` hay `make eval`. Không đổi mã, template hay bài kiểm nào của kho này.
- **Quyền:** phiên con chạy ở `bypassPermissions` để đi hết luồng. Số lời xin quyền mà một người mới
  sẽ gặp ở chế độ mặc định được ước từ số lần gọi công cụ (mục «Điểm dừng»).

## Chi phí và thời gian

| Lượt | Tin nhắn của người | Thời gian phiên con | Chi phí |
| --- | --- | --- | --- |
| Dò cấu hình (2 lần) | — | 13 giây | $0,14 |
| Lượt 1: giao hết | 3 | 433 giây (130 + 283 + 20) | $5,14 |
| Lượt 2: hỏi từng từ | 6 | 546 giây (161 + 16 + 15 + 15 + 14 + 325) | $8,27 |
| **Tổng** | 9 | **16 phút 32 giây** | **$13,54** trên trần $40 |

Mỗi lần `--resume` tốn khoảng $1,1 đến $2,2 dù lượt chỉ dài 15 giây, vì phiên con nạp lại ngữ cảnh.
Mức dùng hằng tuần của tài khoản, đọc bằng `get_usage` như lượt thử tiêu chí 11: trước lượt chạy đầu
(21:35) là 50% cho mọi mô hình và 57% cho Fable; sau lượt chạy cuối (21:59) là 51% và 57%. Con số này
gồm cả phần của phiên điều phối và hai tác tử đóng vai.

## Lượt 1: Hà giao hết cho Claude

Câu mở đầu của Hà:

> /repo-setup:new mình muốn làm một trang web nhỏ cho team, để theo dõi ai đang mượn thiết bị chung
> (2 laptop, 3 máy ảnh, 1 máy chiếu), mượn khi nào, bao giờ trả. … Chưa cần đăng nhập đâu. Bạn chọn
> giúp mình nhé

Diễn biến:

1. **130 giây, 11 lần gọi công cụ, rồi duyệt kế hoạch.** Người dùng thấy sáu dòng «Claude ran a tool»
   rồi một câu: «Mình đang đọc cấu trúc công cụ thiết lập (các "layer" quyết định và preset có sẵn) để
   chọn giúp bạn». Sau đó là bảng mười lớp, lời phản biện độc lập, phần «KHÔNG tự động làm được», và
   một lựa chọn khác: «Với 6 thiết bị, chỉ dùng **Google Form + một Google Sheet được khoá chỉnh sửa**
   có thể đã đủ». Câu hỏi: «**Bạn muốn làm theo kế hoạch trên không?**»
2. Hà trả lời: «Ok bạn làm đi … Nhưng mình không có máy chủ hay Docker gì đâu nhé, mình chỉ muốn mở lên
   xem thử trên máy mình trước thôi.» Phiên con đổi lớp `delivery` sang chạy tại chỗ mà không hỏi lại.
3. **283 giây, 19 lần gọi công cụ.** `apply.py` dựng 61 tệp, cài thư viện, viết ontology Device và
   Loan, lưu trữ SQLite, API, trang web tiếng Việt, 13 bài kiểm, chạy thử server, `doctor`, bản ghi
   quyết định, `docs/START-HERE.md`. Kết thúc bằng: «**Bạn có muốn mình tạo một commit không?** Commit
   là một lần lưu toàn bộ trạng thái hiện tại vào lịch sử của repo, để sau này quay lại được.»
4. Hà: «Ok bạn tạo commit giúp mình đi.» **20 giây:** commit `4a2486b`, 71 tệp, kèm cách xử lý khi
   cổng 3000 bận.

Ngày đầu, làm đúng như người mới: `make dev`, mở `http://localhost:3000`, cho «Chị Lan» mượn Laptop 1
(ảnh ở `run1/day1/page-empty.jpg` và `page-after-loan.jpg`). Trang chạy đúng. Rồi đọc `README.md`, gõ
`make help`, `make check`.

Hà nói, khi được hỏi cảm nhận (trích nguyên văn):

> Mình thấy ổn, trang chạy được và bấm thử thấy đúng ý, vui lắm. Nhưng mấy thứ còn lại thì hơi ngợp.
> Mình không hiểu mấy từ này: lint, typecheck, CI, PR, build, ontology, wiki, glossary, lockfile,
> ledger, fragments, derived, conflict markers, tier, split, gen. Gần hết `make help` mình đọc không ra.
> Mình chỉ dùng `make dev` để mở trang, Ctrl+C để tắt. … Còn GitHub thì để sau, khi IT cấp tài khoản.

## Lượt 2: Hà hỏi «X là gì?»

Cùng câu mở đầu (khác vài chữ). Diễn biến:

1. **161 giây, 19 lần gọi công cụ.** Tám lần trong đó là đi tìm trường `owner`. Người dùng thấy:
   «Mình đang kiểm tra trường "owner" (chủ sở hữu) mà công cụ bắt buộc phải có.» Kế hoạch lần này chọn
   **Python + FastAPI**, không phải TypeScript + Fastify như lượt 1, với cùng một yêu cầu. Cuối bảng có
   thêm một mục «**Bạn cần xác nhận**: Dòng bản quyền trong LICENSE», ghi sẵn họ tên lấy từ `git config`.
2. «Python là gì vậy?» → giải thích tốt, kèm «Bạn có cần biết Python không? Không cần.»
3. «Máy chủ là gì vậy?» → giải thích bằng Google Sheet, rồi giới thiệu «container (gói ứng dụng chạy
   được ở mọi nơi)» và «cloud».
4. «Container là gì vậy?» → ví dụ thùng hàng trên tàu biển, rồi giới thiệu «volume».
5. «Volume là gì vậy?» → ví dụ két gửi đồ khách sạn, kèm «Bạn không cần hiểu hết các thuật ngữ này mới
   bắt đầu được».
6. Hà: «Mình thấy mệt rồi, từ nãy tới giờ toàn từ mới. Đọc đoạn trên xong thì mình hiểu là cứ ok. Ghi
   tên mình vào bản quyền nha. Ok» → **325 giây, 20 lần gọi công cụ**: dựng 57 tệp, 18 bài kiểm, dựng
   và chạy thử container Docker trên máy người dùng (kể cả khởi động lại để thử volume), `doctor`
   100/100, hướng dẫn tiếng Việt, rồi mời commit. Không chạy lượt commit này, vì lượt 1 đã đi qua.

Mỗi lời giải thích đều đúng và dễ hiểu, nhưng ba trong bốn từ đến từ lớp `delivery` (container), thứ
Hà chưa từng xin. Sau bốn vòng, Hà duyệt vì mệt, không phải vì hiểu.

## Điểm dừng, đếm từ phiên thật

| | Lượt 1 | Lượt 2 |
| --- | --- | --- |
| Phải trả lời | 2: duyệt kế hoạch, đồng ý commit | 3: duyệt kế hoạch, tên trong LICENSE, đồng ý commit |
| Tự hỏi «X là gì?» | 0 | 4 (Python, máy chủ, container, volume) |
| Phải chờ, chỉ thấy dòng công cụ thu gọn | 130 giây, 283 giây | 161 giây, 325 giây |
| Lỗi đỏ người dùng thấy | 1 lệnh `ls` của phiên con thoát 1 (vô hại) | 1 lệnh của phiên con sai đường dẫn tệp tạm (vô hại) |
| Lời xin quyền ở chế độ mặc định (ước) | tối đa 31: 26 Bash, 5 Write | tối đa 20: 19 Bash, 1 Write |

Lời nguyên văn ở các điểm dừng:

- «**Bạn muốn làm theo kế hoạch trên không?** Nếu đồng ý, mình sẽ tạo repo, viết chức năng và trang
  web, chạy kiểm tra, rồi viết file hướng dẫn `docs/START-HERE.md`.»
- «**Bạn có muốn mình tạo một commit không?** … Tên commit sẽ là `chore: set up repository
  (repo-setup ts-api/starter)`.»
- Lượt 2: «**Dòng bản quyền trong LICENSE:** hiện là `<họ tên trong git config>`. Nếu đây là tài sản của
  công ty, bạn cho mình tên công ty để ghi vào.»

Số lời xin quyền là trần trên: một số lệnh Bash chỉ đọc sẽ không bị hỏi. Đây là của Claude Code, không
phải của plugin, nhưng là thứ người mới gặp nhiều nhất nếu họ không tự bật chế độ khác. `settings.json`
của kho sinh ra chỉ có hiệu lực sau khi kho đã có.

## Từ người mới không hiểu

Gom từ hai lượt: những từ Hà nói thẳng là không hiểu, và những từ xuất hiện ở màn hình đầu ngày mà
không có lời giải thích.

- **Trong cuộc trò chuyện:** layer, preset, subagent, Fastify, TypeScript, SQLite, Proprietary,
  module, container, volume, cloud, `ts-api`, `starter`. Phiên con có giải thích repo, CI, Docker,
  commit, container ngay lần đầu, đúng như skill dặn, nhưng chữ ngoặc đơn không giữ được người đọc
  lướt.
- **Trong README và `make help`:** lint, typecheck, CI, PR, build, ontology, wiki, glossary, lockfile,
  ledger, fragments, derived, drawn, conflict markers, tier, split, gen.
- **Trong lúc chờ:** lượt 2 báo tiến độ bằng tiếng Anh («Installs done. Now reading the domain-writing
  procedure…», «Docker is running. Testing the container end to end…») dù cuộc trò chuyện là tiếng
  Việt.
- **Ở terminal:** `make dev` của lượt 1 in log JSON thô của Fastify
  (`{"level":30,"time":…,"msg":"Server listening at http://127.0.0.1:3000"}`).

## Kho lúc kết thúc

| Số đo | Lượt 1 (`ts-api`, starter) | Lượt 2 (`fastapi`, starter) |
| --- | --- | --- |
| Tệp do `apply.py` dựng | 61 | 57 |
| Tệp cuối cùng | 71, đã commit | 76, chưa commit |
| Dòng, không tính `package-lock.json` | 6.454 | — |
| Dòng trong `tools/` | 4.147 (64%), 11 tệp | 11 tệp |
| Dòng mã sản phẩm và bài kiểm (`src/`, `tests/`) | 679 | — |
| Dòng của `make help` | 22 | 24 |
| `make check` | xanh, 2 giây, 13 bài kiểm | xanh, 18 bài kiểm |
| `doctor` | 100/100 | 100/100 |
| Ngôn ngữ của `README.md` | tiếng Anh | tiếng Việt |
| `README.md` dẫn tới `docs/START-HERE.md` | không | không |

`docs/START-HERE.md` của cả hai lượt viết tốt, bằng tiếng Việt, có bảng «đường dẫn, là gì, bạn cần làm
gì», nói rõ điểm `doctor` đo gì và không đo gì, và kết thúc bằng hai việc đầu tiên nên nhờ Claude.

## So với các phát hiện của UX audit

Audit đo `main`; lượt này đo 0.10.4. Bốn phát hiện của audit nói về «việc ngoài kho» và thẻ tự chủ,
những thứ chưa có ở bậc starter của 0.10.4 (`presets/_core/starter/tools/` của tag không có
`autonomy_card.py`, `outside.py`).

| Phát hiện | Lượt này | Ghi chú |
| --- | --- | --- |
| F1. Starter không còn nhỏ | **Xác nhận** | 71 tệp, 64% số dòng là công cụ setup. Phiên con mô tả bậc là «đủ cho dự án nhỏ, nâng cấp được sau»; không ai nói về sức nặng. |
| F2. Nâng cấp không có cửa vào | Không chạm | Kho mới, không nâng cấp. |
| F3. `make outside` đỏ khi chưa có remote | Không chạm | Chưa có ở 0.10.4. |
| F4. Bước 7 cần bước 8 | Không chạm | 0.10.4 chưa có bước việc ngoài kho; commit được mời ở cuối, đúng thứ tự. |
| F5. `make help` phẳng | **Xác nhận** | 22 và 24 dòng, cột lệch ở `check-quick`, `derived-untracked`. Hà: «Gần hết `make help` mình đọc không ra». |
| F6. README không dẫn tới hướng dẫn | **Xác nhận** | Cả hai lượt. Mới: README lượt 1 giữ nguyên tiếng Anh của template trong khi `docs_language` là `vi`; lượt 2 thì dịch. |
| F7. Lời cũ không còn đúng | **Xác nhận, sống** | Cả hai `START-HERE.md` chép câu của `tour.md` «không có gì tự chạy» trong Claude Code, trong khi `.claude/settings.json` có hook `SessionStart` chạy `make derived`. Lượt 2 còn viết Claude «hỏi trước khi sửa», mà kho không có luật `ask` nào. |
| F8. `explain` không biết việc ngoài kho | Không chạm | Chưa có ở 0.10.4. |
| F9. Thẻ tự chủ mâu thuẫn | Không chạm | Chưa có ở 0.10.4. |
| F10. Skill `github` | Không chạm | Ngoài phạm vi. |
| F11. Thứ tiếng riêng | **Xác nhận** | ledger, fragments, derived, drawn, tier nằm trong danh sách Hà không hiểu. |
| F12 đến F15 | Không chạm | Người mới không đọc README của plugin, không chạy `doctor` trên kho cũ. |
| Số điểm dừng «bốn» | **Ngược lại, ít hơn** | Thực tế là hai. Câu hỏi tên không xảy ra vì người dùng đã mô tả dự án; câu hỏi đẩy không xảy ra vì không có remote. Nhưng có thêm thứ audit không đếm được: chờ 2 đến 5 phút mỗi lượt, và tối đa 31 lời xin quyền. |

## Phát hiện mới

**N1. «Web app nhỏ cho team» rơi ra ngoài sàn thiết kế.** Dữ liệu dùng chung cần máy chủ, nên cả hai
lượt chọn `ts-api` hoặc `fastapi`, và lớp `design` thành «không áp dụng: bộ khung giao diện tự động chỉ
có cho React». Giao diện viết tay, không có bài kiểm giao diện, `doctor` vẫn 100/100. Lượt 1 còn tự mâu
thuẫn: trước khi dựng nói «Điểm "sức khoẻ repo" sẽ bị trừ ở phần này», sau khi dựng nói «thực tế không bị
trừ». Đây có lẽ là yêu cầu hay gặp nhất của người mới.

**N2. Cùng một yêu cầu, hai kho khác nhau.** Stack (`ts-api` và `fastapi`), tên dự án (`device-loans` và
`equipment-tracker`), số tệp (61 và 57), ngôn ngữ README, có hay không có Docker. Với người giao hết cho
Claude, lựa chọn stack phụ thuộc vào lượt chạy.

**N3. Trường `owner` không có quy tắc khi chưa có remote.** `context.md` nói «lấy owner từ git remote»,
còn `apply_plan.py` bắt buộc trường đó. Lượt 2 mất tám lần gọi công cụ để tìm cách điền, rồi ghi họ tên
trong `git config` vào LICENSE và hỏi thêm một câu. Lượt 1 lấy phần trước `@` của email.

**N4. Mặc định của lớp `delivery` kéo theo từ vựng người mới không xin.** Lượt 1, Hà phải tự gạt đi
(«mình không có máy chủ hay Docker gì đâu»). Lượt 2, ba trong bốn câu «là gì?» đến từ đó, và phiên con
dựng, chạy thử container trên máy người dùng.

**N5. Chờ lâu và đổi ngôn ngữ giữa chừng.** Hai lượt dựng dài 283 và 325 giây, người dùng chỉ thấy các
dòng công cụ thu gọn. Lượt 2 báo tiến độ bằng tiếng Anh. Skill nói «talk in it» nhưng không nói về lời
báo tiến độ.

**N6. Những gì đang tốt.** Lựa chọn thật thà «Google Form có thể đã đủ»; lời phản biện độc lập tìm ra
rủi ro thật (không đăng nhập mà đưa lên Internet, hai người mượn cùng một máy, lệch ngày giờ); phiên con
đổi kế hoạch theo một câu của người dùng; nói thật «mình chưa mở trang trên trình duyệt để bấm thử»;
giải thích từ mới bằng ví dụ đời thường; `START-HERE.md` tốt; trang chạy đúng.

## Đề xuất

Theo nguyên tắc của kho, không đề xuất nào thêm một chỗ người xuất hiện.

| Việc | Phát hiện | Loại |
| --- | --- | --- |
| Lớp `delivery` khi giao hết cho Claude: mặc định «chạy trên máy bạn», container là bước sau | N4 | Chỉ sửa lời của lớp |
| Quy tắc cho `owner` khi chưa có remote, ghi trong `context.md` | N3 | Chỉ sửa lời của lớp |
| Skill nói rõ lời báo tiến độ cũng theo `conversation_language` | N5 | Chỉ sửa lời skill |
| Sửa câu «không có gì tự chạy» trong `tour.md` | F7 | Chỉ sửa lời (Q1 của audit) |
| README sinh ra dẫn tới `docs/START-HERE.md`, và được dịch theo `docs_language` | F6 | Đổi tệp sinh ra (Q5 của audit) |
| `make help` chia nhóm | F5 | Đổi tệp sinh ra (Q6 của audit) |
| Sàn thiết kế cho stack có máy chủ, hoặc một tổ hợp `react-vite` cộng API | N1 | Việc sâu, cần quyết định của chủ kho |
| Có nên cố định lựa chọn stack cho cùng một mô tả không | N2 | Câu hỏi cho chủ kho |

## Chỗ lượt này chưa phủ

- **Không có người thật.** Hà là một tác tử Sonnet đóng vai; câu trả lời hợp lý nhưng không thay được
  một người ngồi trước màn hình.
- **Không có thẻ câu hỏi.** Ở `-p` không có `AskUserQuestion`, nên mọi câu hỏi hiện bằng chữ. Trong ứng
  dụng, skill sẽ dùng thẻ bấm chọn.
- **Không đo lời xin quyền thật.** Phiên con chạy `bypassPermissions`; con số ở trên là ước.
- **Máy của người làm nghề.** Máy này có sẵn Node 26, Python 3.14, uv, Docker, `gh`. Một máy mới thật sẽ
  vướng ở bước cài, và lượt này không thấy được.
- **Chỉ bậc starter, chỉ macOS.** Không đi bậc team, không thử Windows, không chạy `/repo-setup:github`,
  không đẩy, không có remote.
- **Lượt 2 dừng trước commit.** Lượt 1 đã đi qua commit.
- **Mô hình của phiên con là Opus 5.5.** Người mới dùng mô hình khác có thể thấy khác.

## Bằng chứng

Tất cả nằm trong scratchpad của phiên này:
`/private/tmp/claude-501/-Users-manh-macmini-dev-repo-standards--claude-worktrees-newcomer-simulation-1c2e4b/c55c8aff-811b-4eac-9323-a5ece31575d8/scratchpad/`

- `persona.md`: chân dung người mới, viết trước lượt đầu.
- `bin/turn.py`: cách chạy một lượt của phiên con và tách đầu ra.
- `src/plugins/repo-setup/`: cây của tag `repo-setup-v0.10.4`.
- `run1/` và `run2/`: `msgs/NN.txt` (Hà gõ gì), `turns/NN.jsonl` (toàn bộ luồng), `turns/NN.visible.md`
  (người dùng thấy gì), `turns/NN.tools.txt` (công cụ và lỗi), `ledger.tsv` (thời gian, chi phí mỗi
  lượt), `day1/` (`make help`, `make check`, `make dev`, ảnh trang), `app/` (kho sinh ra).

Scratchpad có thể bị dọn. Một bản sao không gồm `app/` và `src/` nằm ở
`~/Library/Application Support/Claude/side-session-notes/local_14153f26-16c1-40d3-8ebc-9cb039038d69/newcomer-simulation/`.
