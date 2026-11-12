# Thiết kế: tầng design cho repo mới

Ngày: 2026-11-09, kiểm lại và duyệt 2026-11-10. Trạng thái: đã duyệt. Áp dụng cho plugin `repo-setup`, mốc `defb398`.

Tài liệu liên quan: [thiết kế setup theo tầng](2026-11-04-guided-setup-design.md), `onehub-inventory/docs/design-standard-proposal.md`, `onehub-quy-hang/docs/plan/ma-tran-kiem-ke-design-claude-code.md`.

## 1. Ý định

Một repo dựng bằng `repo-setup` hôm nay không có gì nói về giao diện. Bảng chấm cho 100/100 mà không hề hỏi màn hình được làm thế nào. Khung web duy nhất chỉ có một trang demo, và AI sẽ chép trang đó.

Số đo ở Quỹ hàng cho thấy điều cần giải quyết: mỗi màn AI tự đoán 17 đến 22 quyết định, khoảng 70% lẽ ra hệ thống phải trả lời sẵn. Trong 21 điểm quyết định, ba tác tử làm giống nhau ở 16 điểm vì cùng chép màn gần nhất, và 6 trong 16 điểm đó là chép cả lỗi.

Setup không dựng hệ design. Setup **chốt những gì cần chốt một lần, đặt rào để AI không phải đoán, và để lại một màn mẫu đúng để AI chép**. Phần còn lại mọc theo màn thật.

## 2. Mục tiêu

- Sàn design là mặc định cho mọi repo có giao diện, không phải một tuỳ chọn. Người setup chỉ chọn những gì chỉ người mới biết: nền linh kiện, kiểu sản phẩm, nhận diện.
- Bước quyết định có tối đa ba câu hỏi, và người giao hết cho Claude không phải trả lời câu nào.
- Ngay commit đầu tiên, lỗi giao diện phổ biến làm cổng kiểm tra đỏ, kèm lời chỉ cách sửa.
- Màn đầu tiên của repo đủ các trạng thái và có bài kiểm, thay trang demo.
- Bảng chấm chứng minh rào có chặn thật, bằng cách đưa lỗi vào và đòi thấy đỏ.
- Repo không có giao diện không thấy thêm gì.

### Không làm trong đợt này

- Tệp token riêng, Storybook, kho linh kiện dùng chung, cổng tra cứu tự viết, so ảnh tự động. Mỗi thứ có điều kiện mở ở mục 8.
- Áp vào repo đã có code (`adopt`). Xem mục 9.
- Khoá hiển thị trong ontology (`display`). Xem đợt 3 ở mục 7.
- Chấm thẩm mỹ và vòng design của từng tính năng. Đó là việc của kit nghiệm thu.
- Giao diện không phải màn hình (dòng lệnh, email, câu trả lời của AI). Chúng chỉ dùng lại giọng văn, từ vựng và định dạng, không có linh kiện. API và công cụ cho AI đã có chuẩn riêng từ ontology.
- Ứng dụng di động. Nguyên tắc vẫn đúng, nhưng bộ rào hiện tại chỉ dành cho web.

## 3. Căn cứ đã kiểm

Dựng thật hai lần trong thư mục tạm, với ESLint 10.14, TypeScript 6, Vite 8, Tailwind 4.3, shadcn 4.23, `@shadcn/lint` 0.2.5, Playwright 1.65. Lần đầu lắp tay từ khung `react-vite`. Lần hai làm capability `design` trên bản sao của plugin, sinh repo bằng đúng `apply.py`, cài theo đúng danh sách lệnh, ở cả hai cấp.

| Câu hỏi | Kết quả |
|---|---|
| Linter có sẵn chạy trên ESLint 10 không | Chạy được, không cần sửa gì |
| Chặn được bao nhiêu trong bộ lỗi mẫu | 22 trên 23. Mọi lỗi đã lọt ở `onehub-inventory` (kích thước tự đặt, style nội tuyến, ghi đè kiểu Button) đều bị chặn |
| Dòng hợp lệ có bị chặn nhầm không | Không, 2 trên 2 qua |
| Lỗi nói được cách sửa không | Có, ví dụ chỉ đúng các variant của Button và nơi thêm variant mới |
| Thang khoảng cách có thật sự đóng không | **Không.** Tailwind 4 chấp nhận mọi bội của 0,25, nên `p-3.25` và `h-37` lọt, và chính linter gợi ý `p-3.25` khi gặp `p-[13px]`. Thêm một luật thang số: chặn 5 trên 5, các giá trị đúng thang vẫn qua. Luật phải phủ cả `ps-`, `me-` và dấu `!`, đã thử: 5 trên 5 |
| Control trần, tự định dạng số và ngày | Chặn bằng luật sẵn có của ESLint, không cần viết plugin |
| Cài nền linh kiện không cần người bấm | Được, cả khởi tạo và thêm linh kiện |
| Linh kiện cài về có qua kiểu chặt của khung không | 11 trên 12. `sonner` lỗi với `exactOptionalPropertyTypes` |
| Tra kho linh kiện không cần máy chủ | Được, bằng lệnh `search`, `view`, `docs` của shadcn |
| Kiểm trình duyệt trong cổng chung | Toàn bộ `make check` 6 giây trên máy đã có trình duyệt |
| Kiểm trình duyệt có bắt lỗi thật không | Bỏ tiêu đề: đỏ. Chữ tương phản kém: đỏ. Chữ trùng hẳn màu nền: **xanh**, vì công cụ xếp 1:1 vào nhóm "chưa kết luận" |
| Đưa lỗi vào linter để bảng chấm dùng | Khoảng 1 giây, không ghi tệp nào |
| Toàn bộ capability sinh bằng `apply.py` từ thư mục trống | Cả `starter` và `team` qua `make check` ngay lần đầu và qua `pre-commit`: 12 lỗi mẫu bị bắt, 5 trạng thái ở 2 khổ màn hình qua kiểm trình duyệt, bảng chấm hiện tại 100 điểm ở cả hai cấp |
| Gỡ một luật, gỡ bước trình duyệt, hoặc để bước đó không thể làm đỏ (`-` hay `\|\| true`) | Bài kiểm rào đỏ, chỉ đúng chỗ. `make -n` một mình không thấy hai cách sau, nên phải đọc cả tệp `mk` |
| Quên nạp CSS | Bản đầu của bài trình duyệt vẫn **xanh** trên trang không có kiểu. Đã thêm phép kiểm CSS đã nạp, giờ đỏ |
| Linh kiện mặc định có qua kiểm truy cập không | **Không hẳn.** Mô tả trong Alert kiểu lỗi đạt 4,49:1, thiếu 0,01. Hạ độ sáng `--destructive` xuống 0,55 thì qua |
| Khối có sẵn của shadcn có qua rào không | **Không.** 4 khối mẫu chính thức gây 106 lỗi ghi đè kiểu trên 11 tệp. Thang số chỉ chặn 1 lần, tức không quá chặt |
| Cấp `team` khi tính cả linh kiện nhà cung cấp | Độ phủ 50%, dưới ngưỡng 80%. Loại thư mục đó thì 100% |
| Font mặc định có tiếng Việt không | Có, Geist kèm bộ chữ tiếng Việt |
| Bảng chấm có nhận ra repo giao diện bỏ qua tầng này không | Thêm một mục trên bản sao plugin: khung React không có tầng design trượt mục đó, có tầng thì 100 điểm, khung API không bị ảnh hưởng |

**Chưa kiểm:** chạy trên CI thật, khung Next.js, luồng đi qua tầng quyết định và blueprint, và câu hỏi lớn nhất là AI có làm màn tốt hơn không (mục 10). Màn mẫu trong lần dựng thử mới ở mức tối thiểu. Số hiệu quả của `@shadcn/lint` do nhà sản xuất công bố.

## 4. Quyết định thiết kế

| Quyết định | Lựa chọn | Lý do |
|---|---|---|
| Mặc định hay tuỳ chọn | Mặc định khi repo có giao diện. Không có phương án "bỏ qua" trong câu hỏi | Người setup thường chưa biết mình cần sàn này, nên hỏi cũng không có câu trả lời tốt. Repo làm thử cũng cần, vì màn đầu tiên sẽ bị chép tiếp |
| Gắn vào đâu | Tầng thứ mười `design`, sinh bằng capability `design` | Dùng đúng cơ chế sẵn có; repo không có giao diện đánh dấu `not_applicable` |
| Rào | Linter có sẵn cộng luật sẵn của ESLint | `onehub-inventory` phải tự viết và nuôi 10 luật; ở đây không viết luật nào cho ngày đầu |
| Kiểm trình duyệt | Nằm trong `make check` | Phép thử xoá tiêu đề cho thấy nằm ngoài cổng chung là không có tác dụng. Kit nghiệm thu và CI đều chạy `make check`, nên được phủ luôn |
| Nền linh kiện | Chụp sẵn cấu hình trong khung, chỉ dùng CLI để thêm linh kiện, ghim đúng phiên bản | Màu thương hiệu có trước khi cài; lần chạy lại không báo xung đột |
| Tra linh kiện | Luật `ui.md` trỏ tới lệnh của shadcn, không máy chủ MCP | Tránh đụng `.mcp.json` của capability `mcp`; thử nghiệm của Atlassian cho thấy CLI nhỉnh hơn MCP một chút |
| Danh mục linh kiện tự sinh | Không có ở ngày đầu | Kho của nhà cung cấp đã trả lời được; bản tự sinh ở `onehub-inventory` thiếu props và gán sai variant |
| Chứng minh rào hoạt động | Đưa lỗi mẫu qua đúng cấu hình thật, không xem tệp có tồn tại | Sổ quyết định ở `onehub-inventory` tăng từ 50% lên 75% khi chèn 40 dòng vô nghĩa |

## 5. Tầng quyết định

Tầng `design` đứng sau `domain`, phụ thuộc `context` và `stack`. Đổi stack thì tầng này phải xem lại. `SKILL.md` hiện chỉ đánh dấu các tầng `decided`, nên phải tính thêm `not_applicable`: đổi từ khung không giao diện sang có giao diện thì tầng này mới hiện ra.

Khung không có giao diện: một dòng, `not_applicable`, không hỏi.

Khung có giao diện, ba quyết định theo thứ tự:

| Câu hỏi | Mặc định khi giao cho Claude | Ghi vào |
|---|---|---|
| Nền linh kiện | shadcn | `choice.base` |
| Sản phẩm này chủ yếu là công cụ dày dữ liệu hay trang đọc cho khách | Suy từ mô tả ở tầng `context` | `choice.surface`: `tool` hoặc `content` |
| Nhận diện có khác mặc định không | Giữ mặc định | `choice.brand_primary` |

Nhãn phương án đúng quy ước sẵn có:

| Phương án | Vì sao | Đánh đổi | Sai khi | Nhãn |
|---|---|---|---|---|
| `shadcn` | Có sẵn linh kiện, tra cứu và linter đồng bộ | Phụ thuộc Tailwind | Công ty đã có hệ riêng | `automated` |
| Hệ của công ty | Một nguồn cho cả công ty | Phải trỏ rào và tra cứu sang hệ đó | Chưa có hệ dùng được thật | `manual` ở đợt 1 |
| Thư viện khác (MUI, Ant và tương tự) | Đội đã quen | Không có linter phù hợp, rào yếu đi nhiều | Không có lý do bắt buộc | `manual` |

Ai cố ý không muốn sàn này thì nói ra, và tầng được ghi `manual` kèm lý do. Khi đó capability không được bật và bảng chấm trừ điểm, nên lựa chọn đó luôn hiện ra. Dựng trực tiếp bằng `apply.py` không có `--with design` cũng bị trừ điểm như vậy.

Không có câu hỏi về kích cỡ chữ, khoảng cách, bo góc. Chúng giữ mặc định, vì `onehub-inventory` đã cho thấy bộ 207 token chỉ cần giữ lại 7 biến thương hiệu.

`surface` chọn màn mẫu và ghi một mật độ cố định cho kiểu màn. Không có công thức tính mật độ theo số cột.

Hai giá trị máy tự điền rồi hiển thị ở tổng duyệt: ngôn ngữ và đơn vị tiền của hàm định dạng, suy từ ngôn ngữ hội thoại (`vi` thành `vi-VN` và VND), ghi vào `choice.locale` và `choice.currency`, truyền thành biến ASCII cho `format.ts.tmpl` và `index.html.tmpl`. Khung hiện ghi cứng `lang="en"`. Đổi font là bước thủ công, ghi vào `manual_steps`, vì mỗi font là một gói cài khác nhau.

Màu thương hiệu được kiểm ngay ở bước quyết định. Máy chọn màu chữ trên nền đó (trắng hoặc gần đen) theo độ tương phản cao hơn; việc này không phải phép kiểm vì cặp nào cũng được khoảng 4,5:1 trở lên. Phép kiểm thật là màu đó khi làm chữ và viền focus trên nền trắng: dưới 4,5:1 thì không nhận làm màu chính, đề xuất sắc đậm hơn. Ví dụ `#ffba00` chỉ đạt 1,71:1. Giá trị không phải `#rrggbb` hoặc không đạt ngưỡng làm `blueprint.py check` đỏ. Khoá có mặt mà rỗng cũng phải đỏ: trong YAML, `#0246ff` không có ngoặc kép là chú thích và đọc ra `None`, màu sẽ âm thầm mất.

## 6. Những gì được sinh ra

### Sáu phần

| Phần | Trong repo | Cái gì giữ nó |
|---|---|---|
| Rào máy | Khối luật trong cấu hình ESLint: sáu luật `@shadcn/lint`, thang khoảng cách, thang kích thước, control trần, tự định dạng số và ngày | `make check` và bài đưa lỗi vào |
| Kiểm trình duyệt | `tests/e2e/floor.spec.ts`: đúng một vùng chính, đúng một tiêu đề cấp một, không tràn ngang, không lỗi truy cập, ở 1440 và 390 px, trên từng đường dẫn trong danh sách | `make check` |
| Lớp nạp cho Claude Code | Một luật ngắn chỉ nạp khi đụng màn hình, gồm lệnh tra cứu linh kiện và danh sách bẫy hay gặp, cùng một đoạn trong `AGENTS.md`. Sau phép đo 2026-11-11, skill `ui` được gộp vào luật này | Giới hạn độ dài trong bài kiểm |
| Câu trả lời đóng | `design/behaviors.md`, một trang: mỗi trạng thái (chờ, trống, lỗi, không có kết quả, đang lưu, xác nhận xoá, xoá thất bại) một câu trả lời và linh kiện cụ thể | Màn mẫu thể hiện đủ, kiểm bằng test |
| Một nguồn cho chữ và số | Hàm định dạng tiền, số, ngày theo `locale` và `currency` đã chốt; từ điển nhãn dùng chung; danh sách từ cấm | Luật cấm tự định dạng; bài quét từ cấm |
| Màn mẫu | Thay trang demo, đủ trạng thái, chỉ dùng linh kiện có sẵn, có test đơn vị và kiểm trình duyệt cho từng trạng thái | `make check` |

Danh sách từ cấm rỗng lúc đầu. Nó chỉ có tác dụng từ khi có từ vựng nghiệp vụ, nên bước viết domain của `/repo-setup:new` phải điền vào.

Plugin chỉ chứa tiếng Anh, `tests/run.sh` chặn tiếng Việt trong plugin. Vì vậy chữ trên màn mẫu, từ điển nhãn và `design/behaviors.md` được sinh bằng tiếng Anh, rồi `/repo-setup:new` thêm một bước sau khi dựng để dịch sang `docs_language`, cùng chỗ với bước viết domain.

Linh kiện cài sẵn: button, input, label, table, card, badge, dialog, select, skeleton, empty, alert. Không cài `sonner` cho tới khi hết lỗi kiểu chặt.

Màn mẫu lấy trạng thái từ nguồn dữ liệu cạnh nó (`src/example/data.ts`): độ trễ thật, lỗi khi mất mạng, thêm và xoá thật trong bộ nhớ. Móc kiểm thử `?scenario=` là một dòng ở đầu mỗi yêu cầu và chỉ trả lời khi chạy test đơn vị (chế độ `test` của Vite) hoặc trong bản dựng riêng của bài trình duyệt (chế độ `floor`, ra `coverage/floor`, không đụng `dist/`). Ở hai chế độ đó móc trả lời mọi yêu cầu: câu trả lời `ready` khi không có kịch bản, nên test đơn vị và bài trình duyệt không bao giờ gọi tới máy chủ thật, kể cả khi người dựng đã nối API thật bên dưới dòng móc (đổi sau rà soát cuối 2026-11-11: trước đó yêu cầu thật đầu tiên làm đỏ bài đi qua danh sách màn, mà bài đó thuộc plugin). Bài đi qua danh sách chờ từng bước và từng trạng thái hiện ra, không chờ một độ trễ cố định. Bản `npm run build` cho người dùng không mang móc này: người ngoài không ép được trạng thái "không bao giờ tải" hay "lỗi" bằng đường dẫn.

Một danh sách chung `src/screens.ts` ghi mỗi màn và các trạng thái của nó; ứng dụng, bài trình duyệt và test đơn vị đều đọc từ danh sách này. Đường dẫn có phần thay đổi (`/orders/:id`) khai thêm `visit`, một địa chỉ thật cho bài kiểm mở (`/orders/1`), và màn nhận các phần đó qua `params`. Repo thêm màn thật hay thêm trạng thái thì chỉ thêm một mục ở đó. `tests/App.test.tsx` chỉ đi qua danh sách này, không có gì riêng của màn mẫu; nó và `tests/e2e/routes.ts` thuộc plugin như `floor.spec.ts`, sửa tại chỗ thì mất điểm `design_guards_bite`. Hành vi riêng của màn mẫu (thử lại, thêm khi rỗng, huỷ xoá, mất mạng, móc tắt ở bản dựng thật) được kiểm trong `tests/e2e.sh` của plugin bằng `tests/fixtures/design/reference.test.tsx`, và cấp `team` không tính màn mẫu vào độ phủ.

Màn mẫu nằm ở `/example`, để màn thật đầu tiên lấy `/`. Địa chỉ không màn nào nhận, hay địa chỉ hỏng, thì hiện một trang báo không tồn tại kèm liên kết tới mọi màn đã đăng ký, không rơi về màn mẫu; bài trình duyệt kiểm cả trang này ở hai khổ. Luật "trạng thái đến từ điều kiện thật, không từ công tắc" ghi đủ ở cả `.claude/rules/ui.md` và `design/behaviors.md`: đây là luật đứng sau kết quả 0 / 18, nên trùng lặp là cố ý.

(Đổi sau phép đo lần ba 2026-11-11: 9 trên 12 tác tử vẫn sửa `tests/App.test.tsx` và tự đặt sáu tên trường khác nhau cho đường dẫn có tham số; 9 trên 12 bản để màn mẫu ở trang chủ; móc kiểm thử chạy cả trong bản phát hành.)

Luật cho phép thêm linh kiện từ kho, nhưng khối dựng sẵn (dashboard, login và tương tự) chỉ được đọc để tham khảo, không `add` thẳng vào repo.

### Điều chỉnh rút ra từ lần dựng thử

- Bỏ `baseUrl` trong `tsconfig`, chỉ dùng `paths`: TypeScript 6 báo lỗi với `baseUrl`.
- Tắt `react-refresh/only-export-components` riêng cho `src/components/ui`.
- Không áp rào giao diện cho `src/components/ui`, đó là mã nhà cung cấp.
- Ghim đúng phiên bản `shadcn` và `@shadcn/lint`, vì `@shadcn/lint` chưa tới 1.0.
- Bài trình duyệt coi nhóm "chưa kết luận" có lý do tương phản 1:1 là lỗi.
- Toàn bộ `no-restricted-syntax` phải nằm trong một khối: khối sau ghi đè khối trước, không cộng dồn. Khối đó áp cho cả `.ts` và `.tsx`, chỉ trừ `src/lib/format.ts`, và chặn `Intl.*` cả khi có và không có `new`.
- Capability phải mang theo `src/main.tsx` có dòng nạp CSS, và bài trình duyệt kiểm biến màu đã có giá trị.
- `src/index.css` ghép bằng cơ chế `+` với đoạn thương hiệu đứng cuối. Không tách tệp riêng: `@import` phải đứng đầu nên sẽ bị bộ biến mặc định đè mất.
- Khai `brand_primary = ""` trong `preset.toml`: `apply.py` render `.tmpl` trước khi xét điều kiện đường dẫn, thiếu biến là dừng.
- Lệnh `npm run format` bị gộp với lệnh cùng chữ của khung, nên chạy trước khi linh kiện được thêm. Capability kết thúc danh sách cài bằng `make format`.
- `vitest` loại `tests/e2e`; cấp `team` loại `src/components/ui` khỏi độ phủ.
- Công cụ trong `tools/` cần khai `globals.node`; `vite.config.ts` dùng `import.meta.dirname`.
- Mọi tệp trong capability phải đã qua Prettier, nếu không cổng đỏ ngay và lần áp lại báo xung đột.
- Hạ `--destructive` trong bản chụp cấu hình để Alert kiểu lỗi đạt ngưỡng.
- Lời báo của `shadcn/no-restyle` được thay qua tuỳ chọn `message` của luật: lời gốc bảo thêm biến thể trong `src/components/ui/table.tsx`, trái với luật không sửa `src/components/ui`. Lời mới bảo bọc chữ trong `span` và mang lớp ở đó.
- Playwright ghi kết quả vào thư mục đã được bỏ qua và không sinh báo cáo HTML, để khỏi sửa `.gitignore` của khung.
- Đích kiểm trình duyệt luôn gọi cài Chromium trước khi chạy (đã có thì mất nửa giây), để bản clone mới không đỏ vì thiếu trình duyệt. Thêm `--with-deps` khi có biến `CI`, nên không phải đụng `ci.yml`.

### Chống rào bị gỡ

`tools/design_guards.mjs` là bài kiểm dùng chung cho `make check` và bảng chấm:

1. Đưa một tệp lỗi mẫu qua đúng cấu hình đang chạy bằng stdin. Mỗi dòng phải đỏ đúng luật đã khai.
2. Đưa vài dòng hợp lệ, phải xanh.
3. Xác nhận `make -n check` có bước kiểm trình duyệt, và trong `mk/design.mk` bước đó không bị `-` hay `|| true` làm mất khả năng đỏ.
4. Từ chối `eslint-disable` cho luật giao diện nếu không kèm lý do sau `--`.
5. Luật không vượt giới hạn độ dài.
6. Quét từ cấm trong `design/terms.json` trên toàn bộ `src`.
7. Có `design/behaviors.md`, và danh sách đường dẫn của bài trình duyệt có ít nhất một màn.

Bảng chấm thêm ba mục cho repo có capability `design`:

| Mục | Kiểu | Trọng số |
|---|---|---|
| `design_guards_bite`: rào đỏ khi có lỗi thật | `command` | 3 |
| `design_floor_in_gate`: kiểm trình duyệt nằm trong cổng | `command` | 3 |
| `design_reference`: có `design/behaviors.md` và đường dẫn cho bài trình duyệt | `command` | 1 |

Cả ba mục gọi cùng một công cụ. Kiểu `exists` không đủ vì danh sách điều kiện của nó là "một trong các", và `src/App.tsx` thì luôn tồn tại.

Thêm một mục cho repo dựng từ khung có giao diện, kể cả khi chưa bật capability:

| Mục | Kiểu | Trọng số |
|---|---|---|
| `design_present`: repo có giao diện thì có sàn design | `exists`, trỏ tới `tools/design_guards.mjs`, gắn `presets = ["react-vite"]` | 3 |

Nếu thiếu mục này, repo bỏ qua tầng design vẫn được 100 điểm, đúng vấn đề nêu ở mục 1. Mục này dựa vào tệp ghi nhận setup, nên repo không dựng bằng `repo-setup` chưa bị xét.

Bảng chấm không tính phần trăm quyết định đã xác định. Con số đó chưa đo được điều nó tuyên bố.

### Thay đổi trong plugin

| Nơi | Thay đổi |
|---|---|
| `skills/new/references/layers.toml`, `layers/design.md` | Tầng mới, có đủ Framing, nhãn, khuyến nghị để `tests/run.sh` qua |
| `scripts/blueprint.py` | `expected_setup` thêm capability `design`; `to_apply_args` truyền các biến; kiểm `base`, `surface`, mã màu |
| `scripts/apply.py` | `derive_vars` tính `design_brand` và màu chữ trên nền thương hiệu |
| `capabilities/design/` | `preset.toml` với `stacks = ["react-vite"]`, `src/index.css` là `user_owned`, thư mục `starter/` và `team/` |
| `capabilities/design/starter/tools/patch_ui.mjs`, `make ui-patch` | Vá `table` của shadcn sau khi cài: vùng cuộn ngang nhận focus và bắt buộc `aria-label`. `preset.toml` chạy `make ui-patch` giữa `shadcn add` và `make format` |
| `capabilities/design/starter/src/screens.ts` | Danh sách màn chung: đường dẫn (có thể có phần thay đổi), `visit`, cách nạp màn, các trạng thái. `pick()` chọn đường dẫn cố định trước đường dẫn có phần thay đổi |
| `presets/ts-node/starter/Makefile`, `package.json.tmpl`; `presets/react-vite/starter/package.json.tmpl` | Bước kiểm chạy im, bước hỏng in đủ báo cáo, `make check` kết thúc bằng một dòng (dùng chung cho mọi khung TypeScript) |
| `presets/_core` | Định dạng bốn skill đang báo xung đột khi áp lại sau `npm run format`. Lỗi này có sẵn, không do tầng mới |
| `checklists/top-tier.toml` | Ba mục gắn `capabilities = ["design"]` và mục `design_present` |
| `scripts/doctor.py` | `applies` hiểu thêm trường lọc `presets` |
| `CHANGELOG.md` | Báo trước: repo `react-vite` đã dựng sẽ trượt `design_present` cho tới khi bật capability |
| `skills/new/SKILL.md`, `tour.md`, `README.md`, kịch bản | Mười tầng; `needs_review` tính cả `not_applicable`; bước dịch sau khi dựng; bước domain điền từ cấm; tour giới thiệu màn mẫu |
| `tests/` | Mục 10 |

Blueprint đang dở từ phiên bản cũ sẽ thấy tầng `design` ở trạng thái `pending` và được hỏi tiếp. Các fixture trong `tests/fixtures` phải khai thêm tầng này.

## 7. Thứ tự làm

**Đợt 1: tầng và capability trên `react-vite`.** Toàn bộ mục 5 và 6. Xong khi repo sinh từ khung này qua `make check`, và đo ở mục 10 đạt.

**Đợt 2: khung web có máy chủ.** Preset `nextjs`, capability `design` mở sang khung này, đường dẫn cho bài trình duyệt được quét từ thư mục route thay vì khai tay. Đây là phần thiếu thật: `react-vite` không giữ được bí mật phía máy chủ và không dùng được capability `ai`, còn `onehub-inventory` phải dựng Next.js bằng tay. Chưa dựng thử.

**Đợt 3: nghĩa dữ liệu quyết định cách hiển thị.** Khoá `display` trong ontology, sinh ra cách hiển thị từng trường và bắt buộc với trường được hiển thị. Đây là thế mạnh riêng mà công cụ khác không có, nhưng ở `onehub-inventory` hiện chỉ 14 trên 42 trường có khoá và chưa màn nào dùng. Chờ kết quả đo ở đó.

## 8. Chưa làm và điều kiện mở

| Thứ | Làm khi |
|---|---|
| Tệp token riêng | Có đồng bộ với Figma, hoặc repo thứ hai dùng chung nhận diện |
| Kho linh kiện chung, cổng tra cứu tự viết | Repo thứ hai cùng nền dùng thật |
| Storybook | Có người thiết kế cần duyệt, hoặc nhiều linh kiện tự viết |
| So ảnh tự động | Hành vi đã ổn định, có lý do cho số giờ giữ ảnh chuẩn |
| Danh mục linh kiện tự sinh | Có linh kiện tự viết, và bản sinh đúng tới từng linh kiện kèm props |
| Chế độ tối | Sản phẩm bật chế độ tối. Khi đó bài trình duyệt và màu thương hiệu phải kiểm cả nền tối |
| Cây thư mục Atomic | Không làm. Tầng linh kiện nên theo nguồn gốc (nhà cung cấp, công thức của sản phẩm, màn hình) |

## 9. Ranh giới

| Bên | Giữ |
|---|---|
| repo-standards | Bước quyết định, phần sinh ra, mục chấm, các khung |
| Kit nghiệm thu | Vòng design và chấm từng tính năng, tiếp quản từ sau màn mẫu đầu tiên |
| Từng repo | Giá trị nhận diện, công thức riêng của sản phẩm, từ vựng |

`adopt` chưa nằm trong đợt này vì `apply.py --adopt` bỏ qua cấu hình ESLint khi repo đã có một bản, tức là rào sẽ âm thầm không được gắn. Khi làm sẽ cần cơ chế ghép cấu hình. Trong lúc đó bài đưa lỗi vào vẫn báo đúng nếu ai đó bật capability bằng tay.

## 10. Kiểm chứng

**Kiểm thử máy.**

- `tests/run.sh`, không mạng: thêm `design` vào danh sách tầng đang ghi cứng; áp `react-vite --with design` ở cả hai cấp, không còn placeholder, chạy lại không đổi gì; khung không có giao diện từ chối capability; `blueprint.py check` bắt mã màu sai và `surface` lạ. Bước kiểm bảng chấm cho từng khung đang chờ chỉ `lockfile` trượt, phải chờ thêm `design_present` với `react-vite` không bật capability.
- `tests/e2e.sh`, có mạng: khung `react-vite` phải bật capability vì bài này đòi 100 điểm; cài thật, `make check`, `npm run build`, chấm điểm; gỡ một luật rồi xác nhận bài kiểm đỏ; bỏ tiêu đề rồi xác nhận cổng đỏ.
- Chạy một lần trên GitHub Actions thật vì cài trình duyệt trên CI chưa được kiểm.

**Đo tác dụng, khoá trước khi dựng.** Rào đỏ chỉ chứng minh rào hoạt động, không chứng minh AI làm tốt hơn.

- Bốn màn cố định: danh sách có lọc, biểu mẫu tạo mới, trang chi tiết, luồng xác nhận xoá. Mô tả viết sẵn, giữ nguyên văn.
- Mỗi màn dựng ba lần bằng tác tử mới, trên hai nền: khung `react-vite` có shadcn nhưng không có capability, và khung có capability.
- Đếm: trạng thái thiếu so với `design/behaviors.md`, lỗi còn lại khi tác tử báo xong, số vòng sửa, token.
- Tổng 24 lần chạy, tốn tiền API, nên hỏi người trước khi chạy như với `make eval`.
- Đọc nhật ký ít nhất một lần chạy mỗi màn, vì những cải thiện đáng giá ở Atlassian là thứ không chỉ số nào bắt được.
- Đề xuất ngưỡng đạt: số trạng thái thiếu giảm ít nhất một nửa, lỗi còn lại bằng 0, token tăng không quá 30%. Không đạt thì sửa thiết kế trước khi phát hành.

## 11. Rủi ro

| Rủi ro | Xử lý |
|---|---|
| `@shadcn/lint` chưa tới 1.0, có thể đổi luật | Ghim phiên bản; bài đưa lỗi vào phát hiện ngay khi nâng cấp |
| Luật thang số bằng biểu thức chính quy chỉ đọc chuỗi tĩnh trong `className` | Lớp động đã bị `require-static-classes` chặn trên linh kiện; trên thẻ thường thì lọt, chấp nhận ở ngày đầu |
| Luật cấm ghi đè kiểu quá chặt với phần con như `CardTitle`, `CardContent`, làm AI sửa nhiều vòng | Bắt đầu chặt, theo dõi số vòng sửa khi đo; nới bằng `contracts` của linter cho đúng phần con |
| AI sửa thẳng `src/components/ui` để né rào | Thư mục đó nằm ngoài rào. Luật ngắn cấm sửa; kiểm khác biệt so với kho khi cần |
| Lời gợi ý của linter (`p-3.25`) mâu thuẫn với thang, thêm một vòng sửa | Theo dõi khi đo; nếu đáng kể thì gói `no-arbitrary-values` với thông báo riêng |
| Chromium làm CI chậm | Chỉ cài một trình duyệt, chấp nhận chi phí vì đây là phần hay bị bỏ nhất |
| Màn mẫu bị xoá hoặc cũ đi, AI chép màn khác | Mục chấm `design_reference`; danh sách đường dẫn của bài trình duyệt phải có ít nhất một màn |
| Kết quả phiên setup của `onehub-inventory` có thể đổi một số chi tiết | Đã đối chiếu ngày 2026-11-10. Phiên đó tự đi tới cùng hướng: dùng `@shadcn/lint`, bỏ gợi ý lệch thang của gói, rào phải đỏ được. Nó vẫn tự viết luật và kiểm trình duyệt chưa vào CI; bản thiết kế này giữ lựa chọn không viết luật và đưa kiểm trình duyệt vào cổng chung |
