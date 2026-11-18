# Mỗi luật khai thứ giữ nó: máy, hay lời (RS7)

Ngày 2026-11-18. Gói RS7, bước E của [thiết kế tổng quan ba kho](../../three-repo-overview-design.md).
Trạng thái: trong buổi thảo luận cùng ngày, chủ kho đã chốt năm điều: nhãn có nguồn trong plugin và
một dạng ngắn trong `AGENTS.md` sinh ra; «máy giữ» chỉ hợp lệ khi có bài kiểm chứng minh; cách B ở
mục 4; «máy giữ» gồm cả máy bắt được mà không đỏ (5.1); kho cài bằng `--adopt` không nhận mục tổng
(5.4). Hai điều sau do một người đọc độc lập nêu ra khi soát bản nháp. Bản viết này được chủ kho
duyệt ngày 2026-11-18. Chưa có gì được dựng.

## 1. Ý định

`AGENTS.md` mà plugin sinh ra viết mọi luật cùng một giọng. Người đọc không phân biệt được luật có
máy chặn với luật chỉ là câu chữ (gốc rễ 4 của thiết kế tổng quan). Ba hậu quả:

- **Tin nhầm.** Luật «tên tệp tiếng Anh» đứng cạnh luật Conventional Commits như nhau, nhưng ở
  `onehub-inventory` khoảng 59 trên 62 thư mục vòng mang tên tiếng Việt. Luật bằng lời hỏng trong
  im lặng.
- **Không có số.** Nguyên tắc «bậc thang thay người» đòi đẩy luật lên bậc cao hơn, nhưng chưa có
  danh sách nào để đẩy.
- **Cửa vào không có ma sát.** Thêm một luật chỉ tốn một câu; không ai phải trả lời «cái gì giữ nó».

RS7 không làm luật nào được giữ tốt hơn. Nó làm cho việc luật nào đang không có máy giữ thành thứ
nhìn thấy và đếm được, ở hai nơi: trong nguồn plugin (cho người giữ plugin) và trong `AGENTS.md`
sinh ra (cho máy làm việc trong kho được cài).

Xong là:

- mọi mục danh sách trong 12 mảnh `+AGENTS.md/` mang đúng một nhãn;
- bài kiểm của kho này đỏ khi ai thêm một mục không có nhãn, hoặc ghi «máy giữ» mà không trỏ được
  tới một bài kiểm chứng minh;
- `AGENTS.md` sinh ra có một mục cuối nêu các máy đang giữ luật ở đúng kho đó, và nói một lần rằng
  đừng trông vào máy nào cho các luật còn lại;
- một lệnh in ra số luật theo từng loại.

## 2. Mục tiêu, không làm, phản mục tiêu

**Mục tiêu**

- Mỗi luật khai loại một lần, ở một chỗ, cạnh chính câu luật.
- Nhãn «máy giữ» có bằng chứng: một bài đã có trong bộ kiểm của kho này phạm luật và thấy máy
  phản ứng.
- Loại hiện ra theo kho được cài: máy không có mặt thì luật không được nêu là máy giữ.
- Kho đã cài bị đụng ít nhất khi nâng cấp, và đường nâng cấp của RS8 vẫn dựng lại được bản gốc.

**Không làm**

- Không viết bài kiểm chứng minh mới. Luật chưa có bài thì ghi «lời»; nâng nó lên là việc về sau,
  từng luật một.
- Không sinh mục tổng cho kho cài bằng `--adopt` (5.4), và không sửa cách RS8 dựng lại bản gốc,
  ngoài việc truyền cờ `adopt`.
- Không đẩy luật nào lên bậc thang, không bỏ luật nào.
- Không dựng tường cho tên tệp (đã chốt ở thiết kế tổng quan, mục 7). Luật tên tệp ghi «lời».
- Không xếp loại cho luật ở tệp khác (`CONTRIBUTING.md`, `.claude/rules/`, các skill).
- Không thêm phép kiểm nào vào kho được cài, không đổi `doctor`.
- Không đặt ngưỡng cho số luật bằng lời.

**Phản mục tiêu**

- Một nhãn «máy giữ» mà không máy nào phản ứng khi luật bị phạm, hoặc nêu tên một máy kho đó không
  có. Đó là «tường trên danh nghĩa» ở dạng chữ, đúng thứ RS1 vừa gỡ.
- Một lần nâng cấp dừng lại vì bản gốc của `AGENTS.md` không dựng lại được.
- Một câu trong `AGENTS.md` khiến máy hiểu luật bằng lời là «không bắt buộc».
- Thêm một lần người phải xuất hiện, hay một câu bảo máy dừng lại.

## 3. Hiện trạng

- `apply.py` (`build_plan`, quanh dòng 369) nối các tệp trong thư mục `+AGENTS.md/` theo tên, qua
  mọi lớp được cài; mảnh cùng tên ở lớp sau thay mảnh lớp trước. Nội dung mảnh được chép nguyên,
  chỉ tệp `.tmpl` được thay `{{biến}}`.
- 12 mảnh có 102 mục danh sách. Bản sinh thử đầy đủ (ts-api, hạng team, service-api, container,
  mcp, ai, github-agents) dài 171 dòng với 59 mục; bản starter của ts-node dài 73 dòng với 33 mục.
- Các mảnh trộn luật, sự kiện, quy trình và bản đồ thư mục. Không có ranh giới máy đọc được giữa
  luật và phần còn lại.
- Luật và phép kiểm có khi nằm ở hai lớp khác nhau. Luật Conventional Commits và «không commit bí
  mật» nằm ở `_core/starter`; ô kiểm commit (`pr-title.yml`, móc `commit-msg`) và quét bí mật
  (`security.yml`, gitleaks) chỉ có ở lớp team. Kho hạng starter nhận luật mà không có máy giữ.
- Vài luật đã tự nêu phép kiểm trong câu chữ («`make check` fails otherwise (`tools/boundaries.py`)»),
  phần lớn thì không.
- Một mục có khi chứa nhiều luật do nhiều thứ giữ. Ví dụ ở `60-ai-native-sdlc.md`: «Never push to
  the default branch, merge a medium/high PR, approve your own work, or edit `.github/workflows/`».
- `AGENTS.md` ở `onehub-inventory` đã bị sửa tại chỗ; nâng cấp gộp ba chiều theo dòng (RS8).

## 4. Các cách đã cân

| Cách | Nhãn nằm ở | `AGENTS.md` sinh ra | Đánh đổi |
| --- | --- | --- | --- |
| A | Cạnh từng mục trong mảnh | In sau từng luật («Held by …», «Kept by word») | Loại nằm ngay tại luật. Mọi dòng luật đổi khi nâng cấp; tốn token nhất; «Kept by word» lặp vài chục lần, dễ bị đọc thành «không bắt buộc» |
| **B** | Cạnh từng mục trong mảnh | Dòng luật giữ nguyên; thêm một mục tổng ở cuối | Thêm luật và khai loại là một lần sửa. Nâng cấp chỉ thêm một mục. Loại nằm xa luật; `apply.py` thêm một bước ghép có logic |
| C | Một tệp sổ cạnh mỗi mảnh, khớp theo đoạn chữ | Như B | Mảnh giữ là markdown thuần, sổ đếm được ngay. Thêm luật phải sửa hai tệp; phép khớp gãy khi ai sửa câu |

Chủ kho chọn **B**: một chỗ sửa, kho đã cài bị đụng ít nhất, và phần «lời» được nói một lần bằng
một câu giao trách nhiệm.

Hai cách bị loại sớm:

- **Mặc định là «lời», chỉ khai luật máy giữ.** Rẻ nhất, nhưng thêm luật bằng lời vẫn không tốn gì
  và không đếm được: mất hai trên ba lợi ích ở mục 1.
- **Nhận ra luật bằng từ khoá («never», «always», «must»).** Lọt mọi luật viết giọng khác («Keep
  PRs small»), cùng kiểu hỏng với phép kiểm tên tệp bằng từ điển.

## 5. Thiết kế

### 5.1 Đơn vị và ba nhãn

Đơn vị là **một mục danh sách** trong một mảnh `+AGENTS.md/`: gạch đầu dòng và mục đánh số, ở mọi
cấp lồng. Mỗi mục mang đúng một nhãn:

| Nhãn | Nghĩa | Điều kiện |
| --- | --- | --- |
| máy giữ | Một máy bắt được khi luật bị phạm | Nêu mã của một máy trong sổ ở 5.3 |
| lời | Là luật, chưa có máy nào được chứng minh là bắt được | Không |
| không phải luật | Danh sách lệnh, bản đồ thư mục, sự kiện, bước quy trình | Không |

«Bắt được» có ba kiểu, chủ kho chốt nghĩa rộng này:

| Kiểu | Máy làm gì | Ví dụ |
| --- | --- | --- |
| đỏ | Một phép kiểm thất bại | `make check`, `secret-scan` |
| từ chối | Hành động không chạy được | `can()` trả về sai cho `agent: forbidden` |
| nâng hạng | Cổng chuyển thay đổi cho một người quyết | Bỏ bài kiểm, nới `agent:`, sửa `governance/` |

Kiểu «nâng hạng» không thêm lần nào người xuất hiện: đó là hàng «máy thấy rào bị nới» đã có trong
bảng «Người xuất hiện ở đâu» của [nguyên tắc của setup](../../setup-principles.md).

Ba điều đi kèm:

- **Không có mặc định.** Mục nào cũng tự mang nhãn, kể cả mục «không phải luật». Mặc định theo đề
  mục sẽ cho một luật mới lọt vào mà không ai phải nghĩ.
- **Mục chỉ là «máy giữ» khi mọi điều nó đòi đều có máy giữ.** Mục chứa nhiều luật do nhiều thứ giữ
  thì tách thành nhiều mục, mỗi mục một nhãn. Tách là đổi hình thức câu chữ của khuôn, không đổi
  nội dung luật.
- **Không chắc thì là «lời».** Nhãn sai về phía «lời» chỉ làm con số xấu đi; sai về phía «máy giữ»
  là phản mục tiêu.

### 5.2 Nhãn trong mảnh nguồn

Nhãn là một chú thích HTML ở cuối mục, ví dụ:

```
- Commit messages follow Conventional Commits (`feat:`, …). <!-- kept: commit-format -->
- Keep changes small and focused; one concern per PR. <!-- kept: word -->
- `make setup` — install dependencies from the lockfile <!-- kept: none -->
```

`apply.py` gỡ mọi nhãn khi ghép, nên `AGENTS.md` sinh ra không còn chú thích nào. Cú pháp cụ thể do
người dựng chọn, miễn là: một mục một nhãn, nằm cùng mục với câu luật, và không còn dấu vết trong
tệp sinh ra.

### 5.3 Sổ máy giữ luật

Một tệp trong khuôn của plugin (cùng khổ với `preset.toml`) liệt kê các máy được phép đứng tên giữ
luật. Mỗi dòng có:

| Trường | Nội dung |
| --- | --- |
| mã | Tên ngắn mà nhãn ở 5.2 trỏ tới |
| bắt gì | Một cụm tiếng Anh ngắn, in trong mục tổng («a secret in a commit») |
| máy làm gì | Tên lệnh hoặc tên ô và phản ứng của nó, in trong mục tổng («`make check` goes red», «the gate raises the tier, and a person decides») |
| kiểu | đỏ, từ chối, hoặc nâng hạng (5.1) |
| có mặt khi | Đường dẫn trong kho được sinh mà máy sống ở đó |
| bài chứng minh | Có một bài trong bộ kiểm của kho này mang thẻ của mã này |

Bài chứng minh được nối bằng một thẻ chú thích đặt cạnh bài trong `tests/` (ví dụ
`# rule-check: commit-format`), không bằng số mục, vì số mục trôi. Bài mang thẻ phải phạm luật
trong một kho sinh thử và thấy máy phản ứng đúng kiểu đã khai: đỏ, từ chối, hoặc nâng hạng. Bài chỉ
soát rằng một dòng cấu hình có mặt thì không đủ. Ví dụ: dòng `deny` trong `.claude/settings.json`
chỉ có bài soát sự có mặt (mục 43g), nên tự nó không vào sổ; luật «không sửa `governance/`» vào sổ
nhờ cổng hạng.

Điểm xuất phát cho sổ, do tôi đọc bộ kiểm mà có. Người dựng kiểm lại từng dòng; dòng nào không có
bài chứng minh thật thì không vào sổ, và luật của nó ghi «lời».

| Máy | Kiểu | Lớp | Bài hiện có |
| --- | --- | --- | --- |
| Ranh giới mô-đun (`tools/boundaries.py` trong `make check`) | đỏ | modular-monolith | Mục 14, 14b |
| Hợp đồng API không vỡ (`api-compat`) | đỏ | service-api | Mục 15 |
| Mã sinh ra khớp `ontology/` (`make ontology`) | đỏ | `_core/starter` | Mục 11 |
| Khổ trang wiki (`tools/wiki_lint.py`) | đỏ | `_core/starter` | Mục 11 |
| Tệp dẫn xuất không nằm trong git (`derived-untracked`) | đỏ | `_core/starter` | Mục 48c |
| Khuôn commit (`conventional-title`, `conventional-commits`) | đỏ | team | Mục 44d |
| Quét bí mật (`secret-scan`) | đỏ | team của từng preset | Mục 44b |
| Cổng hạng: bỏ hay làm yếu bài kiểm, nới `agent:`, sửa `governance/` | nâng hạng | team | Mục 16, 17, 43d |
| `agent: forbidden` giữ ngay trong `can()` | từ chối | mcp | Mục 20 |
| Lint manifest của plugin (phiên bản, mô tả, nguồn) | đỏ | claude-plugin | Mục 35 |

Chưa thấy bài chứng minh, nên tạm coi là «lời» cho tới khi người dựng tìm ra: duyệt môi trường
`production`, ảnh chạy không phải root và `/health`, ẩn dữ liệu cá nhân, các luật của capability
`ai`, «skill `name` trùng tên thư mục», «không tự gộp PR hạng medium» (đã ghi là chỗ hở trong
[nguyên tắc của setup](../../setup-principles.md)).

### 5.4 Mục tổng trong `AGENTS.md` sinh ra

Sau khi ghép các mảnh, `apply.py` thêm một mục cuối tệp, tính cho đúng kho đang được cài:

1. Lấy các mục «máy giữ» trong những mảnh thật sự được ghép vào kho này.
2. Giữ lại những mã mà đường dẫn «có mặt khi» nằm trong các tệp mà khuôn sinh ra cho đúng các lựa
   chọn của kho (preset, hạng, archetype, deploy, capability).
3. In mỗi máy còn lại thành một dòng, rồi một câu cho phần còn lại.

**Ràng buộc từ RS8: mục tổng là hàm của khuôn và các lựa chọn, không nhìn trạng thái đĩa.** Khi nâng
cấp, `upgrade_base.py` dựng lại bản gốc của `AGENTS.md` bằng `planned_files` trên khuôn của bản
phát hành cũ, và chỉ nhận khi băm khớp. Mục tổng mà phụ thuộc đĩa thì bản gốc không dựng lại được,
tệp bị báo «không đọc được bản gốc» và lượt nâng cấp kết thúc với mã lỗi. Ba hệ quả bắt buộc:

- **Chữ nằm trong khuôn, không nằm trong mã.** Đề mục, câu mở, câu cuối và từng dòng đều đọc từ tệp
  của khuôn (sổ ở 5.3 và một tệp chữ đi kèm). Mã chỉ lắp. Nhờ đó mã của bản sau vẫn dựng lại đúng
  từng byte `AGENTS.md` của bản trước.
- **Khuôn không có sổ thì không có mục tổng và không gỡ gì.** Mọi bản phát hành tới 0.9.0 thuộc
  trường hợp này, nên bản gốc của chúng dựng lại y như hôm nay.
- **Kho cài bằng `--adopt` không nhận mục tổng** (chủ kho chốt). Ở chế độ đó, tệp nào kho đã có bản
  tương đương thì bị bỏ qua, nên mục tổng tính theo khuôn có thể nêu tên một máy kho không có. Cờ
  `adopt` đã nằm trong sổ cài (`.repo-setup.json`); nó được truyền vào bước ghép ở cả lượt chạy lẫn
  lượt dựng lại bản gốc. Đây là chỗ duy nhất RS7 chạm vào mã của RS8. Nhãn vẫn được gỡ khỏi các
  dòng như mọi kho khác.

Chữ đề xuất (tiếng Anh, vì khuôn viết bằng tiếng Anh), ở một kho hạng team có modular-monolith và
capability github-agents (dòng về cổng hạng chỉ hiện ở kho có `pr-pipeline.yml`, nơi duy nhất chạy
cổng trên một pull request; điều này tìm ra khi soát bản dựng):

```
## What holds these rules

A machine catches a miss of these:

- commit format: `conventional-title` or `conventional-commits` goes red (GitHub)
- a secret in a commit: `secret-scan` goes red (GitHub)
- module boundaries: `make check` goes red
- a deleted or weakened test, a looser `agent:` setting: the gate raises the tier, and a person decides

Nothing listed here covers the other rules in this file. Do not count on a machine to catch a
miss: keeping them is on you.
```

Hệ quả:

- Kho hạng starter không có ô kiểm commit, nên dòng «commit format» không hiện; luật đó rơi vào
  câu cuối. Lên hạng team thì dòng hiện ra ở lần chạy `apply.py` đó.
- Mục nói máy «đỏ», không nói «bị chặn gộp». Ô có bắt buộc hay không là việc của ruleset.
- Câu cuối không nói «không có máy nào». Nó nói «không gì nêu ở đây», vì có luật đã có cơ chế mà
  chưa có bài chứng minh (duyệt `production`, ảnh không chạy root). Luật kho tự thêm vào
  `AGENTS.md` cũng nằm trong câu đó một cách đúng: mục này không nêu chúng.
- Mục không chứa câu nào bảo máy dừng lại hay hỏi người.

Kho không có máy nào có mặt thì mục chỉ còn câu cuối, với một bản chữ riêng trong khuôn cho đúng
ngữ pháp.

### 5.5 Lệnh đếm

Một công cụ trong `plugins/repo-setup/scripts/` đọc các mảnh và sổ, rồi:

- báo lỗi, kèm tên mảnh và dòng, cho: mục thiếu nhãn, mục hai nhãn, mã không có trong sổ, dòng sổ
  thiếu trường, dòng sổ không có bài mang thẻ;
- in bảng đếm theo mảnh: máy giữ, lời, không phải luật.

Công cụ nhận một thư mục gốc khác (như `build_plan` đã nhận `root`) để bài kiểm chạy nó trên một
bản sao đã bị làm hỏng.

## 6. Bài kiểm

Một mục mới trong bộ kiểm nhanh (`tests/run.sh`, mục 50, tách tệp riêng như `tests/tiered_ci.sh`).

| Bài | Chiều xanh | Chiều đỏ |
| --- | --- | --- |
| Mọi mục có nhãn | Cây thật qua công cụ ở 5.5 | Bản sao thêm một gạch đầu dòng không nhãn: công cụ đỏ, nêu mảnh và dòng |
| «Máy giữ» trỏ được | Mọi mã có trong sổ, mọi dòng sổ có bài mang thẻ | Bản sao có mã lạ; bản sao gỡ thẻ khỏi bài: đều đỏ |
| Máy có mặt | Ở mỗi tổ hợp sinh thử (cài mới, không `--adopt`), mọi dòng trong mục tổng có tệp «có mặt khi» trên đĩa | Mục tổng nêu một máy mà kho không có: đỏ |
| Theo kho được cài | Starter: không có dòng khuôn commit và quét bí mật. Team: có cả hai | So chéo hai bản sinh thử |
| Kho `--adopt` | Không có đề mục «What holds these rules», không còn chú thích nhãn | — |
| Bản gốc dựng lại được | Một cây khuôn không có sổ cho `AGENTS.md` giống từng byte với phép nối mảnh hiện nay; một kho cài bằng bản này, sửa `AGENTS.md` tại chỗ rồi chạy lại, tìm được bản gốc | Kết quả «không đọc được bản gốc» cho `AGENTS.md`: đỏ |
| Không còn dấu vết | `AGENTS.md` của mọi tổ hợp cài mới không chứa chú thích nhãn, và có đề mục «What holds these rules» | — |
| Không thêm điểm dừng | Mục tổng qua các cụm cấm của mục 43g | — |

Bài kiểm in số đếm ở dòng «ok», để mỗi lượt chạy đều thấy con số.

## 7. Thước

Số luật theo loại, in bởi lệnh ở 5.5: tổng, và theo từng mảnh. Con số lúc dựng xong được ghi vào
`CHANGELOG.md` và vào dòng RS7 của thiết kế tổng quan, thay cho con số «6 máy giữ, 10 lời» vốn do
máy đọc và xếp. Vì «máy giữ» giờ đòi bài chứng minh, con số ban đầu có thể thấp hơn.

Không đặt ngưỡng. Hướng mong đợi: số «lời» không tăng mà không có lý do, và giảm khi một luật được
viết bài chứng minh hoặc được bỏ bằng cấu trúc.

## 8. Nâng cấp

- `AGENTS.md` của mọi kho cài mới nhận thêm một mục cuối ở lần nâng cấp, và vài mục bị tách dòng.
  Kho `--adopt` chỉ nhận phần tách dòng.
- Bản chưa sửa tại chỗ được cập nhật thẳng. Bản đã sửa đi qua phép gộp ba chiều của RS8. Hai
  trường hợp để lại dấu xung đột (`marked`), tìm ra khi dựng và có bài kiểm ghim lại: kho đã sửa
  đúng một dòng bị tách; hoặc kho đã thêm chữ của riêng mình vào tận cuối `AGENTS.md`, đúng chỗ mục
  tổng được thêm. Ở trường hợp sau cả hai phần đều còn giữa các dấu, không mất gì.
- Không có gì ngừng chạy. Ghi dưới `## Unreleased` của `CHANGELOG.md`, kèm con số ở mục 7.

## 9. Đối chiếu nguyên tắc của setup

| Câu hỏi | Trả lời |
| --- | --- |
| Có thêm lần nào người phải xuất hiện không? | Không |
| Có thêm hộp hỏi, luật `ask`, hay câu bảo máy dừng không? | Không; bài kiểm mục 6 soát mục tổng với các cụm cấm |
| Có phán xét nào bị trả token hai lần không? | Không; mục tổng thêm khoảng mười dòng vào mỗi phiên, chưa đo token |
| Rào mới có nằm ở chỗ máy tự gỡ được không? | RS7 không thêm rào ở kho được cài; rào của nó là bài kiểm của kho này |

## 10. Để lại cho người dựng

- Cú pháp nhãn, tên và khổ tệp sổ, tên công cụ đếm, tên tệp bài kiểm.
- Xếp loại từng mục trong 102 mục, theo ba điều ở 5.1, và tách các mục chứa nhiều luật.
- Kiểm lại từng dòng của bảng ở 5.3 với bài thật; đặt thẻ cạnh bài.
- Chữ của từng dòng «bắt gì» và «máy làm gì». Chữ của câu mở và câu cuối mục tổng giữ như 5.4, trừ
  khi chủ kho sửa.
- Cách truyền cờ `adopt` vào bước ghép và vào lượt dựng lại bản gốc, miễn giữ ràng buộc ở 5.4.
- Cập nhật dòng RS7 và mục rủi ro «cách xếp 16 luật» trong thiết kế tổng quan.

## 11. Giới hạn đã biết

- **Luật viết trong đoạn văn hay trong bảng nằm ngoài tầm bài kiểm.** Bài chỉ thấy mục danh sách.
  Mảnh `55-autonomy.md` và `60-ai-native-sdlc.md` có luật ở dạng đó.
- **Nhãn «không phải luật» là phán xét của người viết.** Không máy nào soát được một câu có phải
  luật hay không; ai muốn giấu một luật bằng lời thì ghi nó là «không phải luật».
- **Thẻ nối bài với máy, không chứng minh bài phạm đúng luật đó.** Bài kiểm chỉ soát thẻ có tồn
  tại. Phần còn lại do người đọc PR giữ, tức là bằng lời.
- **«Có mặt» tính theo khuôn và lựa chọn, không theo đĩa hay GitHub.** Ô có trong workflow mà
  ruleset không bắt buộc thì vẫn được nêu; `doctor` là nơi trả lời câu đó. Kho xoá một máy sau khi
  cài thì dòng của nó vẫn ở lại trong mục tổng. Đây là giá của ràng buộc ở 5.4.
- **Kho `--adopt` chưa nhận được gì từ RS7** ngoài việc gỡ nhãn. Muốn có mục tổng đúng cho các kho
  đó thì phải ghi danh sách máy vào sổ cài và cho RS8 đọc nó: một gói việc khác.
- **Rủi ro «lời» bị đọc thành «không bắt buộc» chưa được đo.** Câu cuối mục tổng viết theo hướng
  giao trách nhiệm để giảm nó; chưa có phép thử nào so hành vi của máy trước và sau.
- **Sổ có thể thành nghi thức.** RS7 chỉ tạo ra con số; nếu không ai đẩy luật lên bậc thang thì
  tiêu chí «tin cậy» không dịch chuyển.

## Nguồn

- Thiết kế tổng quan ba kho: mục 3 (gốc rễ 4), mục 4 (nguyên tắc 5), mục 7 (dòng RS7, ghi chú «RS7
  không gồm tường cho tên tệp»), mục 8 (bước E), mục 9 (rủi ro «cách xếp 16 luật»).
- [Nguyên tắc của setup](../../setup-principles.md): bảy luật, năm câu hỏi trước khi gộp, «chỗ còn hở».
- `plugins/repo-setup/scripts/apply.py`, hàm ghép mảnh; 12 tệp trong các thư mục `+AGENTS.md/`.
- Hai kho sinh thử ngày 2026-11-18: ts-node hạng starter; ts-api hạng team với service-api,
  container, mcp, ai, github-agents. Số dòng và số mục đếm trên hai bản đó và trên 12 mảnh.
- `tests/run.sh`: các mục 11, 14, 15, 16, 17, 20, 35, 43d, 44b, 44d, 48c, đọc để lập bảng ở 5.3.
- `plugins/repo-setup/scripts/upgrade_base.py` và `planned_files` trong `apply.py`: cách bản gốc
  được dựng lại và so băm, đọc để lập ràng buộc ở 5.4.
- Lượt soát của một người đọc độc lập trong vai người dựng, ngày 2026-11-18: ba điểm, hai điểm
  chủ kho quyết.
- Chủ kho, buổi thảo luận ngày 2026-11-18: «cả hai»; «đồng ý theo đề xuất» cho mức bằng chứng;
  «chọn B»; «theo cả hai» cho nghĩa rộng của «máy giữ» và cho kho `--adopt`.
