# Mỗi tệp một người ghi: sổ thành mảnh, tệp tổng hợp thành vật dẫn xuất (RS2b)

Ngày 2026-11-17. Gói RS2b, bước D của [thiết kế tổng quan ba kho](../../three-repo-overview-design.md).
Trạng thái: chủ kho đã đồng ý phần mục đích, năm sổ và cơ chế trong buổi thảo luận cùng ngày; bản
viết này được chủ kho duyệt ngày 2026-11-17. Bản đi cùng: [CI xếp tầng (RS3)](2026-11-17-tiered-ci-design.md).

## 1. Ý định

Ở `onehub-inventory`, cặp PR nào cũng chạm chung ít nhất một tệp (435 trên 435), vì vòng nào cũng
ghi vào cùng vài tệp sổ. Hệ quả: lối gộp nhanh của delivery-loop (`dieu-phoi/scripts/gop.mjs`) không
bao giờ mở, vì nó chỉ mở khi hai PR không chạm chung tệp; PR nào gộp sau cũng phải gộp ngược nhánh
chính, bằng chứng thành cũ, ghim lại, chờ thêm một vòng CI.

RS2a (`wiki/log.md merge=union`) chỉ gỡ xung đột khi gộp ở máy. Nút gộp, «Update branch» và tự gộp
của GitHub không theo luật đó, và hai PR vẫn «cùng chạm một tệp». RS2b gỡ tận gốc: **một PR chỉ
chạm tệp của riêng nó**.

Xong là: hai PR, mỗi PR thêm một dòng log, một thuật ngữ, một trang wiki, một thực thể, không chạm
chung tệp nào thuộc năm sổ dưới đây; trên GitHub cả hai gộp được theo thứ tự bất kỳ mà không xung
đột.

## 2. Mục tiêu, không làm, phản mục tiêu

Mục tiêu:

- Sổ ghi tay thành mảnh: mỗi mục một tệp, tên tệp là khoá của mục.
- Tệp tổng hợp ở đường dẫn cũ thành vật dẫn xuất: máy vẽ lại, nằm ngoài git, PR không mang.
- Một cơ chế dùng chung với DA1 của design-assembly: một đích `make derived`, mỗi lớp nối việc vẽ
  của mình vào.
- Kho đã cài đi qua được bằng đường nâng cấp RS8, không đỏ vì nâng cấp.

Không làm:

- Không sửa delivery-loop, design-assembly hay `onehub-inventory`. Phần của kho khác chỉ là lời đề
  nghị.
- Không đụng `LO-TRINH.html`, `PRODUCT-MAP.md`, `_acceptance/config.yaml` (DL1), các sổ trong
  `design/` (DA1).
- Không làm cơ chế đẩy tệp tổng hợp lên nhánh chính sau gộp (lý do ở mục 4).

Phản mục tiêu, tức là xong mà vẫn hỏng:

- Một dòng log hay một thuật ngữ **mất lặng lẽ**: ai đó (thường là tác tử theo thói cũ) sửa tệp
  tổng hợp, lần vẽ sau đè mất, không ai biết.
- Kho cũ **đỏ ngay sau khi nâng cấp** mà không ai làm gì sai.
- Tác tử ở worktree mới **không có `wiki/index.md`** để đọc, trong khi `AGENTS.md` bảo đọc nó trước
  tiên.
- Thêm một chỗ người phải xuất hiện, một hộp hỏi, hay một luật `ask`.

## 3. Hiện trạng

| Sổ | Hôm nay | Ai ghi | Ai đọc |
| --- | --- | --- | --- |
| `wiki/log.md` | Một danh sách, mới nhất ở trên; `merge=union` từ RS2a | `AGENTS.md` (`10-guide.md.tmpl`: «append one line»), skill `ontology-add`, `wiki-ingest`, `wiki-health`, `adopt`; lời dặn trong `agent-ci-fix.yml`; ví dụ trong skill `github` | `wiki-ingest` (ngày của lần ingest trước), người |
| `wiki/index.md` | Ráp lúc cài từ `wiki/+index.md/*`, sau đó sửa tay | `ontology-add`, `wiki-ingest` («link new pages»), `sdlc_metrics.py` (`link_in_index`, thêm dòng báo cáo tuần) | `AGENTS.md` («đọc trước tiên»), `wiki_lint.py` (trang không có liên kết từ mục lục thì cảnh báo), skill `wiki-query`, `wiki-health` |
| `ontology/glossary.md` | Một bảng bốn cột, căn cột; thêm một thuật ngữ dài là định dạng lại cả bảng (21 đến 27 dòng mỗi lần ở `onehub-inventory`) | `ontology-add` | `wiki_lint.py` (thực thể phải có trong glossary), `AGENTS.md`, `review-change`, `wiki-query` |
| `src/generated/ontology.ts`, `src/<pkg>/ontology_types.py` | Sinh bằng `make gen`, commit; `make ontology` đỏ khi tệp cũ | `make gen` | Mã sản phẩm, `typecheck`, `test`, `build` |
| `ontology/labels.yaml`, `src/generated/labels.ts`, `display.ts` | Của riêng `onehub-inventory` (`tools/design_codegen.py`, `design/language.md`), không do plugin sinh | Kho đó | Kho đó |

delivery-loop không ghi tệp nào trong năm sổ (tìm cả nhánh `chuyen-nha` ngày 2026-11-17). Mọi bên
ghi đều là mẫu của kho này, nên đổi được hết từ đây.

DA1 ở design-assembly đã dựng và gộp (nhánh chính tại `93daea4`, quyết định 0049 đến 0053): mảnh là
nguồn; tệp ở đường dẫn cũ nằm ngoài git; `derived.mjs` vẽ mọi vật dẫn xuất trước bên đọc; `make test`
chờ `design-derived` khi `test` là một bước của cổng; vật dẫn xuất nằm trong git thì cổng đỏ; mỗi
kho tự bật; bộ đọc nhận hình dạng cũ mãi mãi. Chỗ hở họ còn ghi: bài kiểm chạy thẳng bằng trình
chạy, không qua `make`, thì không có tệp (`derived-files-not-written-for-a-runner-alone`), và kit
nghiệm thu tụt bậc ở worktree mới.

## 4. Các cách đã cân

| Cách | Gỡ được gì | Vướng | Chọn |
| --- | --- | --- | --- |
| **A. Mảnh là nguồn; tệp cũ là vật dẫn xuất ngoài git; một đích `make derived` dùng chung** | Mỗi PR chỉ chạm mảnh của nó; GitHub và lối gộp nhanh đều thấy hai PR không chung tệp | Tệp tổng hợp vắng trên GitHub và ở bản chép mới cho tới khi được vẽ; bên đọc không qua `make` phải có móc | **Chọn**: cùng hướng DA1, chủ kho đã chọn hướng này cho DA1 và bảo kho này theo |
| B. Giữ một tệp, nhờ luật gộp (`merge=union`, trình gộp riêng như `PRODUCT-MAP.md merge=generated-file`) | Xung đột khi gộp ở máy | GitHub không chạy luật gộp; lối gộp nhanh vẫn đóng vì cùng tệp | Không: đó là RS2a, đã biết giới hạn |
| C. Mảnh là nguồn, tệp tổng hợp vẫn commit, một việc tự động vẽ lại trên nhánh chính sau mỗi lần gộp | Tệp vẫn hiện trên GitHub | Cần một bên được đẩy thẳng lên nhánh chính; ruleset của RS1 chặn điều đó, và mở ra là mở một lỗ cho tường. Tệp tổng hợp vẫn bị PR chạm nếu PR tự vẽ | Không. Nếu sau này cần, hình dạng mảnh không phải đổi |
| D. Bỏ hẳn tệp tổng hợp, bên đọc đọc thư mục mảnh | Không còn vật dẫn xuất | Hơn hai chục chỗ đọc đường dẫn cũ ở kho dùng (đếm ở DA1 cho sổ màn; ở đây là skill, `wiki_lint`, `AGENTS.md`, kit) | Không: giữ đường dẫn cũ để bên đọc không phải đổi |

Trong cách A, phần riêng của kho này (máy chọn, chủ kho đồng ý phần nguyên tắc):

- **Mục lục wiki không cần mảnh mới.** Mỗi trang wiki đã là một mảnh: phần đầu có `type` và `title`.
  Mục lục vẽ từ chính các trang, cộng một tệp nhỏ viết tay cho phần mở đầu.
- **Tên mảnh log bắt đầu bằng ngày**, nên trên GitHub thư mục mảnh đọc được như một cuốn log dù tệp
  tổng hợp vắng.
- **Bên ghi đi qua một lệnh** thay vì sửa tệp: lệnh tự biết kho đang ở hình dạng nào (mục 5.4). Đây
  là thứ giữ cho kho cũ không đỏ khi tác tử theo lời dặn mới.

## 5. Thiết kế

### 5.1 Cơ chế chung: `make derived`

Một tệp mới của lõi, `presets/_core/starter/mk/derived.mk`, theo cùng khuôn với `CHECK_TARGETS`:

- `DERIVED_TARGETS`: các đích vẽ. Lớp nào có vật dẫn xuất thì `+=` vào đây. Lõi thêm `wiki-derived`
  (log, mục lục, glossary) và `gen` (mã sinh từ ontology).
- `DERIVED_FILES`: đường dẫn của mọi vật dẫn xuất mà lớp đó giữ ngoài git, để phép kiểm ở dưới biết
  mà soi.
- `derived`: chạy mọi `DERIVED_TARGETS`. Im lặng khi không có gì đổi; khi viết thì nói đã viết tệp
  nào.
- Thứ tự: `derived` chờ `upgrade` (dấu xung đột của RS8 phải được thấy trước); mọi bước của
  `CHECK_TARGETS`, cùng `build`, `dev` và `test`, chờ `derived`. Cách nối thứ tự (điều kiện thứ tự
  của make, hay đặt ở `Makefile` của từng preset) là việc của người dựng, với một điều bắt buộc:
  `make check` trên bản chép sạch, chưa có vật dẫn xuất nào, phải xanh.
- Phép kiểm `derived-untracked`, thêm vào `CHECK_TARGETS`: một đường dẫn trong `DERIVED_FILES` mà
  đang nằm trong git, trong khi sổ của nó đã ở hình dạng mảnh, thì đỏ và nêu tên tệp cùng lệnh sửa
  (`git rm --cached <tệp>`). Sổ còn ở hình dạng một tệp thì phép kiểm bỏ qua sổ đó.

Lời đề nghị gửi design-assembly (chờ kho đó quyết): `mk/design-assembly.mk` nối `design-derived` vào
`DERIVED_TARGETS` và khai tệp của nó trong `DERIVED_FILES`. Khi đó một lệnh vẽ mọi vật dẫn xuất của
một kho, và móc lúc mở phiên ở mục 5.6 vá luôn chỗ hở «kit tụt bậc ở worktree mới» của họ. Chưa
nối thì hai bên vẫn chạy độc lập như hôm nay.

`onehub-inventory` dùng cùng khuôn cho `labels.ts` và `display.ts` ở bước chạy trên kho đó: một dòng
`DERIVED_TARGETS += design-gen` trong một tệp `mk/` của chính nó. Tách `ontology/labels.yaml` thành
mảnh là việc của kho đó, không nằm trong gói này.

### 5.2 Bốn sổ của lõi

| Sổ | Nguồn | Tên mảnh | Tệp ở đường dẫn cũ |
| --- | --- | --- | --- |
| Log | `wiki/log/` | `YYYY-MM-DD-NN-<slug>.md`; `NN` giữ thứ tự trong ngày (một ngày có tới 20 dòng ở `onehub-inventory`); một dòng nội dung, có thể kèm liên kết | `wiki/log.md`: đầu trang như hôm nay, rồi mỗi mảnh một dòng, mới nhất ở trên |
| Mục lục | Các trang `wiki/**/*.md` có `type` và `title`; phần mở đầu viết tay ở `wiki/index.head.md` | Không có mảnh mới | `wiki/index.md`: phần mở đầu, rồi mỗi loại trang một mục theo thứ tự trong `ontology/page-types.yaml`, mỗi trang một dòng `- [title](path) — summary` |
| Glossary | `ontology/glossary/` | `<Term>.md`, tên là tên mã của thuật ngữ; phần đầu có `display` và `not_confused_with`, thân là định nghĩa một câu | `ontology/glossary.md`: bảng bốn cột như hôm nay |
| Mã sinh từ ontology | `ontology/` | Không đổi | `src/generated/ontology.ts` (ts-node, react-vite, ts-api), `src/<pkg>/ontology_types.py` (python, fastapi): ngoài git |

**Hình dạng của một sổ** (máy chọn): sổ ở hình dạng một tệp khi tệp ở đường dẫn cũ đang nằm trong
git; ngược lại (tệp vắng, hoặc có mà git bỏ qua) là hình dạng mảnh. Kho cài mới, trước commit đầu
tiên, không có tệp cũ nào, nên ở hình dạng mảnh. Không dựa vào việc thư mục mảnh có hay không:
`apply.py` không có cách ghi một tệp chỉ ở lần cài đầu, nên khung của mẫu (`.gitkeep`, tệp `.head.md`)
cũng tới kho cũ khi nâng cấp, và phải vô hại ở đó. «Hai nguồn» nghĩa là tệp cũ còn trong git **và**
thư mục mảnh có ít nhất một mục (không tính `.gitkeep` và tệp `.head.md`).

**Phần không phải mục** của mỗi sổ (đoạn mở đầu, đoạn văn viết tay giữa chừng) nằm ở một tệp viết
tay cạnh sổ: `wiki/index.head.md`, `ontology/glossary.head.md`, `wiki/log.head.md`. Tệp tổng hợp là
phần đầu đó cộng các mục.

Luật chung cho cả bốn:

- **Tên tệp là khoá.** Hai mảnh trùng khoá không cùng tồn tại được, nên luật «không trùng» giữ bằng
  cấu trúc. Phép kiểm hình dạng đỏ khi khoá bên trong mảnh khác tên tệp, hoặc thiếu trường bắt buộc.
- **Vẽ ra luôn cùng một văn bản** từ cùng một tập mảnh, không phụ thuộc thứ tự đọc thư mục: log xếp
  theo tên tệp giảm dần, glossary và mục lục xếp theo khoá.
- **Mỗi tệp tổng hợp mở đầu bằng một dòng** nói nó được vẽ từ đâu và sửa ở đâu.
- **Sửa tay không mất lặng lẽ.** Lệnh vẽ nhớ băm của lần vẽ trước. Tệp tổng hợp khác bản đã vẽ thì
  lệnh đỏ, nêu những dòng thêm tay, và nói chuyển chúng vào mảnh bằng lệnh nào. Lệnh không đè lên
  bản sửa tay. Nơi giữ băm là việc của người dựng.
- **Bộ định dạng không đụng vật dẫn xuất**: Prettier và các bước lint bỏ qua các tệp trong
  `DERIVED_FILES`.
- Mục lục không còn cảnh báo «trang không có liên kết từ mục lục»: luật đó đổi thành «mỗi trang có
  `type` và `title`». Hai trường này giữ cho trang tự hiện ở mục lục.

### 5.3 Công cụ

Một công cụ mới của lõi, `tools/ledgers.py` (chỉ dùng thư viện chuẩn, như các công cụ khác của
plugin), với các lệnh:

- `draw`: vẽ log, mục lục, glossary cho những sổ đã ở hình dạng mảnh; `make wiki-derived` gọi nó.
- `check`: hình dạng mảnh; hai nguồn cùng lúc (tệp cũ còn trong git mà thư mục mảnh cũng có) thì đỏ.
- `add-log`, `add-term`: bên ghi gọi hai lệnh này thay vì sửa tệp (mục 5.4).
- `split <sổ>`: chuyển một sổ một tệp sang mảnh (mục 6). Bốn sổ: `log`, `index`, `glossary`, `gen`.
  Với `gen` không có mảnh: lệnh chỉ đưa tệp sinh ra khỏi git và thêm dòng `.gitignore`.

Mã sinh từ ontology giữ `tools/ontology_codegen.py`; chỉ đổi chỗ nó được gọi. Theo hình dạng: tệp
sinh ra còn trong git thì `make ontology` giữ `--check` (so với tệp đã commit) như hôm nay; đã ra
khỏi git thì `--check` thôi chạy, phép kiểm thay thế là `derived-untracked`, cộng việc chính
`typecheck` và `test` dùng tệp vừa sinh.

### 5.4 Bên ghi

| Bên ghi | Sau khi đổi |
| --- | --- |
| `AGENTS.md` (`10-guide.md.tmpl`) | «Thêm một dòng log: `make log m="…"`», thay cho «append one line to `wiki/log.md`». Thêm một câu: tệp tổng hợp do máy vẽ, sửa ở mảnh |
| Skill `ontology-add` | Thuật ngữ qua `add-term`; log qua `make log`; bỏ bước «link it from `wiki/index.md`» khi kho đã ở hình dạng mảnh |
| Skill `wiki-ingest`, `wiki-health` | Log qua `make log`; trang mới chỉ cần `type` và `title`; ngày của lần ingest trước đọc từ tên mảnh mới nhất |
| Skill `adopt`, ví dụ trong skill `github`, lời dặn trong `agent-ci-fix.yml` | Như trên |
| `sdlc_metrics.py` (`link_in_index`) | Không ghi vào mục lục khi kho đã ở hình dạng mảnh: trang báo cáo tuần có `type` nên tự hiện |

`make log` và `add-term` tự biết hình dạng: sổ còn là một tệp thì chúng ghi vào tệp đó như hôm nay;
đã là mảnh thì viết một mảnh mới. Nhờ vậy lời dặn mới đúng ở mọi kho, cũ hay mới, và một kho cũ
không chuyển sang trạng thái «hai nguồn» chỉ vì tác tử theo lời dặn mới. Skill còn nói «nếu
`wiki/index.md` còn trong git thì thêm liên kết ở đó» cho kho chưa tách.

### 5.5 Bên đọc không qua `make`

Vật dẫn xuất phải có trước mọi bên đọc. Ba đường, theo thứ tự hay gặp:

1. **CI**: mọi bước kiểm và dựng đi qua `make`, nên có tệp. Mẫu `ci.yml` của các preset đang gọi
   `npm run build` thẳng sau `make check`; tệp đã được vẽ ở bước trước, nhưng bước này nên đổi
   thành `make build` để không dựa vào thứ tự.
2. **Phiên Claude Code ở worktree mới**: móc lúc mở phiên (mục 5.6).
3. **Công cụ gọi thẳng trình chạy** (kit nghiệm thu chạy một tệp bài, IDE, `npm run dev`): preset
   Node thêm script `prepare` trong `package.json` gọi `make derived`, nên `npm ci` và `npm install`
   vẽ luôn. Preset Python không có móc tương ứng của `uv sync`; ở đó chỉ có đường 1 và 2, ghi là
   giới hạn. Khâu triển khai dựng từ git (ví dụ Vercel) đi qua `npm ci`, nên đi qua `prepare`; máy
   dựng của nền tảng đó có `make` và `python3` không là điều chưa thử.
4. **Lớp triển khai `container`**: ảnh gọn không có `make` hay `python3`, và `.dockerignore` loại
   `ontology/`. `prepare` vì thế không chạy được trong `Dockerfile`; mã sinh ra phải tới ảnh bằng
   đường khác (vẽ trước khi dựng ảnh và cho tệp vào bối cảnh dựng, hoặc một tầng dựng có
   `python3`). Chọn đường nào là việc của người dựng; bắt buộc: `e2e` của tổ hợp `container` dựng
   được ảnh từ bản chép sạch.

### 5.6 Móc lúc mở phiên

`settings.json.tmpl` thêm một móc `SessionStart`: `make -s derived`. Móc không bao giờ làm phiên
dừng hay hỏi: lỗi in ra để tác tử đọc, mã thoát luôn 0. Đây không phải điểm dừng của setup: không
`ask`, không deny, không câu «xin duyệt». Mục 43 của bộ kiểm phải vẫn xanh.

## 6. Kho đã cài: đường chuyển tiếp

Chủ kho đã chọn: nâng cấp qua RS8 chỉ mang công cụ và lời dặn mới; chưa tách sổ nào. Tách là một
lệnh, chạy trong một PR của chính kho đó.

1. **Nâng cấp không làm kho cũ đỏ.** Bộ đọc nhận cả hai hình dạng; `derived-untracked` bỏ qua sổ còn
   một tệp; `make log`, `add-term` ghi vào tệp cũ. Mẫu ngừng mang `wiki/log.md` một khối, nên lần
   nâng RS8 tiếp theo không còn ghi dấu `no matching base` vào sổ log. Mẫu cũng không tạo mảnh nào
   trong kho cũ, nên không có «hai nguồn». Dòng `.gitignore` mới không ảnh hưởng tệp đang nằm trong
   git.
2. **`doctor` báo sổ nào chưa tách**, kèm lệnh. Đó là thông báo, không trừ điểm: một kho cũ không bị
   hạ điểm vì chưa tách.
3. **`ledgers.py split <sổ>`**: in trước những gì sẽ viết; tách; vẽ lại tệp tổng hợp từ mảnh và so
   với tệp cũ. Phép so là **theo mục, không theo văn bản** (máy chọn): tập mục trước và sau phải
   bằng nhau, mỗi mục giữ nguyên chữ; thứ tự được phép đổi và lệnh in những chỗ đổi; phần không
   phải mục chuyển nguyên vào tệp `.head.md` của sổ. Mất hay thừa một mục thì dừng, không ghi gì.
   Lý do: ở `onehub-inventory` mục lục xếp theo thứ tự chèn, log có nhiều dòng một ngày, glossary có
   một đoạn văn viết tay giữa phần mở đầu và bảng; so cả văn bản thì lệnh dừng ở cả ba sổ. Khớp thì
   viết mảnh, `git rm --cached` tệp cũ, và tệp cũ thành vật dẫn xuất. Tệp `.head.md` mà mẫu đã ghi
   lúc nâng cấp, còn đúng như mẫu, thì `split` viết đè. Dòng ví dụ của mẫu glossary (`_Example:_`)
   không thành mảnh; lệnh nói đã bỏ nó. Riêng mục lục: phần mô tả sau dấu «—» của mỗi dòng trỏ tới
   một trang trong wiki chuyển vào khoá `summary` của trang đó; dòng không trỏ tới trang nào, cùng
   mọi đoạn văn, ở lại `wiki/index.head.md`.
4. **PR đang mở lúc chuyển** chạm tệp cũ một lần cuối: gộp ngược nhánh chính vào thì gặp một xung đột
   «xoá ở một bên, sửa ở bên kia». Cách gỡ là chạy `make log` lại trên nhánh. Ghi trong lời nhắc của
   `split`.

Kho cài mới bắt đầu luôn ở hình dạng mảnh: mẫu mang `wiki/index.head.md`, thư mục `wiki/log/` và
`ontology/glossary/` rỗng, các dòng `.gitignore`. Dòng log «Repository created» của mẫu bỏ đi: lịch
sử git đã ghi điều đó.

## 7. Bài kiểm

Mục 48 mới của `tests/run.sh`. Mỗi phép kiểm phải được thấy đỏ trên một bản bị đổi trước khi xanh.

| Phép kiểm | Thấy đỏ khi |
| --- | --- |
| Hai nhánh, mỗi nhánh thêm một dòng log, một thuật ngữ, một trang: không chung tệp nào; gộp theo hai thứ tự đều sạch | Ghi log vào tệp tổng hợp thay vì mảnh |
| `make check` xanh trên bản chép sạch chưa có vật dẫn xuất (ts-node, python, react-vite với `design`) | Bỏ điều kiện thứ tự của `derived` |
| Vật dẫn xuất nằm trong git thì đỏ, nêu tên tệp | `git add -f wiki/log.md` sau khi tách |
| Sửa tay tệp tổng hợp thì đỏ, nêu dòng | Thêm một dòng vào `wiki/log.md` đã vẽ |
| Vẽ hai lần ra cùng văn bản; thứ tự đọc thư mục không đổi kết quả | Đọc thư mục không xếp |
| `split` đi vòng không mất dòng; dừng khi mất | Bỏ một dòng khỏi mảnh trước khi so |
| Kho cài từ 0.6.0, nâng lên bản này: `make check` vẫn xanh, chưa sổ nào tách; `make log` ghi vào tệp cũ | Mẫu tạo mảnh trong kho cũ |
| Móc `SessionStart` có mặt, không `ask`, không deny dạng `Bash(`; mục 43 xanh | Thêm `ask` vào móc |
| Mảnh sai hình dạng (khoá khác tên tệp, thiếu `display`) thì đỏ | Đổi tên một mảnh |

`tests/e2e.sh`: các tổ hợp cài mới chạy `make check` trên một bản clone sạch; thêm một ca nâng từ
`repo-setup-v0.6.0` rồi chạy `split` cho cả bốn sổ. Thêm vào bảng trên: `split` trên một bản sao
của `onehub-inventory` (chỉ đọc kho thật) qua được cả bốn sổ, và trên mỗi sổ một ca bị đổi (bỏ một
mục) thì dừng.

## 8. Thước

- Trên kho thử `design-ci-probe`: mở hai PR song song, mỗi PR thêm một dòng log, một thuật ngữ, một
  trang. Gộp PR thứ nhất bằng nút của GitHub; PR thứ hai vẫn gộp được mà không «Update branch» và
  không xung đột. Đây là điều RS2a không làm được (phát hiện 1 của lần chạy ngày 16/11).
- Trên `onehub-inventory`, khi chủ kho cho chạy: `sdlc_metrics.py` trước và sau, cửa sổ bằng nhau.
  Dòng kỳ vọng dịch chuyển: số lần `wiki/log.md`, `wiki/index.md`, `ontology/glossary.md`,
  `src/generated/ontology.ts` có trong PR về 0; số cặp PR chạm chung tệp giảm. Mức giảm va chạm lớn
  chỉ tới khi DL1 và DA1 cùng chạy trên kho đó (mục 8 của thiết kế tổng quan).

## 9. Để lại cho người dựng

- Cách nối thứ tự trong make, nơi giữ băm của lần vẽ trước, cách đặt tên `slug` cho mảnh log.
- Định dạng phần đầu của mảnh glossary và mảnh log, miễn là đọc được bằng thư viện chuẩn.
- Thứ tự các mục trong mục lục khi `page-types.yaml` thiếu một loại trang có trong wiki.
- Cách `doctor` hiện thông báo «chưa tách».

## 10. Giới hạn đã biết

- Trên GitHub, tệp tổng hợp vắng; người xem thấy thư mục mảnh. Log và glossary vẫn đọc được theo tên
  tệp; mục lục thì không.
- PR không còn hiện thay đổi của mã sinh ra; thay đổi thật đã hiện ở `ontology/`.
- Preset Python: chạy `pytest` thẳng trên bản chép sạch, trước `make derived`, thì thiếu
  `ontology_types.py`.
- Máy dựng của nền tảng triển khai có `make` và `python3` không: chưa thử.
- Hai PR vẫn có thể chạm chung tệp sổ trong lúc kho chưa chạy `split`; lợi chỉ có sau khi tách.

## Nguồn

- design-assembly, nhánh chính tại `93daea4`: đề bài 0005, quyết định 0049 đến 0053, bản thử
  `docs/trials/ledgers-on-a-reference-copy.md` (đọc ngày 2026-11-17, không sửa).
- delivery-loop, nhánh `chuyen-nha`: tìm `wiki/log.md`, `wiki/index.md`, `glossary.md`,
  `labels.yaml`, `src/generated`; không tệp nào ghi vào chúng.
- `onehub-inventory`, nhánh chính `origin/main` tại `ea774a0f`: `Makefile`, `.gitattributes`,
  `tools/design_codegen.py`, số commit chạm từng sổ.
- Kho này: mẫu ở `plugins/repo-setup/presets/_core/`, `capabilities/github-agents/`; mục 46, 47 của
  `tests/run.sh`.
- Chủ kho, buổi thảo luận ngày 2026-11-17: «Đúng rồi» cho phần mục đích, năm sổ, cơ chế và đường
  chuyển tiếp.
