# Tổng kết toàn bộ tiến độ, sau hai báo cáo UX

Ngày 2026-11-25. Phạm vi: toàn kho từ ngày 2026-11-04 (bản phát hành `0.4.0`) đến `main` tại `0b1e4e9`
(commit gộp PR 86), và chi tiết hơn cho đoạn từ `9ad1ed6`, điểm cuối của
[bản trước](2026-11-23-progress-after-design-seam.md).

## 1. Tóm tắt

- **Toàn cảnh:** 21 ngày, 84 PR đã gộp, 11 bản phát hành (`0.4.0` đến `0.10.4`), 0 revert. Bản mới nhất
  là `0.10.4` (ngày 21/11). `main` mang `0.10.5.dev0`, với sáu mục dưới `## Unreleased`.
- **Từ bản trước:** gộp 3 PR (85, 86, 87), cả ba chỉ thêm tài liệu: 3 tệp, thêm 835 dòng. Không đổi mã,
  template hay bài kiểm nào. Không còn PR nào mở.
- **Việc đã làm được nhiều nhất trong đoạn này là đo,** không phải dựng:
  - lượt thử tiêu chí 11 bên design-assembly đã qua: hai plugin thật chạy cùng nhau trên một kho trống;
  - một bản rà UX đọc lời của các skill (PR 86);
  - một lượt chạy thật với người mới do máy đóng vai (PR 87).
- **Hai báo cáo UX nói cùng một điều:** cuộc trò chuyện lúc setup đã nhẹ, còn kho người dùng nhận về
  thì nặng và nói một thứ tiếng riêng. Kho bậc `starter` có 71 tệp, 64% số dòng là công cụ của setup.
- **Mối nối với design-assembly đang tụt xa hơn:** bản chép trong bộ kiểm ghi `0.35.0`, còn plugin đã
  lên `0.58.0`. Tệp `host-strings.json` vẫn trùng từng byte, nên chỗ tụt chỉ nằm ở nghĩa của mã thoát 2.
- **Trước `0.10.5` còn ba việc thử:** e2e đủ tổ hợp, thử nâng cấp trên bản sao hai kho dùng, và GitHub
  thật. Chưa việc nào bắt đầu.
- **CI trên `main` xanh** ở 6 lượt gần nhất, gồm lượt cho `0b1e4e9`.

## 2. Đã thực hiện

### Toàn cảnh 21 ngày

Ngày là ngày phát hành trên GitHub; nội dung lấy từ các mục của `CHANGELOG.md`.

| Bản | Ngày | Nội dung chính |
| --- | --- | --- |
| `0.4.0` | 04/11 | Setup có hướng dẫn qua các lớp quyết định, lớp AI trong sản phẩm |
| `0.5.0` | 11/11 | Marketplace plugin |
| `0.6.0` | 16/11 | Preset TypeScript, lớp thiết kế, vòng đời thực thể, «người quyết, máy kiểm», tường thật, làm song song |
| `0.7.0` | 17/11 | Đường nâng cấp |
| `0.8.0` | 18/11 | Sổ mảnh (RS2b) |
| `0.9.0` | 18/11 | CI phân tầng (RS3) |
| `0.10.0` | 19/11 | Phân loại luật (RS7) |
| `0.10.1` đến `0.10.4` | 20/11 đến 21/11 | Bản vá từ các lần nâng cấp kho thật, đo luồng (RS10), cách gộp ghi trong `governance/autonomy.yaml` |
| Chưa phát hành | 22/11 đến nay | Sổ việc ngoài kho (5.1), bảng tự chủ (5.2), máy soạn thay đổi luật (5.3), mối nối với design-assembly, và hai bản sửa |

### Từ bản trước

| PR | Việc |
| --- | --- |
| 85 | Bản tổng kết sau mối nối với design-assembly |
| 86 | Rà UX các luồng của repo-setup, so với `0.3.0`: 15 phát hiện, 10 việc nhanh, 4 việc sâu |
| 87 | Mô phỏng một người mới đi qua `/repo-setup:new` bản `0.10.4`: hai lượt chạy thật, 6 phát hiện mới |

### Việc ngoài kho này đã xong

- **Lượt thử tiêu chí 11 của đề bài 0013** (design-assembly PR 100, đã gộp). Kho trống `library-loans` ra
  đời qua `/repo-setup:new` với cả hai plugin thật. Không ai gõ lệnh nào của design-assembly. Setup tự
  gọi `/design-assembly:adopt --starter` (mã thoát 1, bốn câu hỏi chờ), `status` báo đủ bảy sổ lúc ra
  đời, `make check` xanh. Chi phí 3,47 USD.
- **Máy này đã lên `0.10.4`.** Nguồn marketplace trong `~/.claude/settings.json` ghim tag
  `repo-setup-v0.10.4`. Muốn lên bản sau phải đổi `ref`.

### Sáu mục chưa phát hành

Không đổi từ bản trước:

1. Trang roadmap của feature loop không còn là đầu vào của tầng nặng (PR 75).
2. Sổ việc ngoài kho, phần 5.1 (PR 76).
3. Máy soạn thay đổi luật, người duyệt, phần 5.3 (PR 77).
4. Bảng tự chủ, phần 5.2 (PR 79).
5. Kho bậc `starter` có lớp container không còn bị hứa một lượt triển khai (PR 83).
6. Setup gọi design-assembly (PR 84).

### Đối chiếu với kế hoạch

- **Bảng gói việc RS** ([thiết kế tổng quan](../three-repo-overview-design.md), mục 7): không dòng nào
  đổi. RS5b vẫn hoãn; RS4 và RS5a vẫn đóng, không dựng.
- **Phân loại luật** (`rule_kinds.py check`): 12 luật có máy giữ, 67 giữ bằng lời, 33 dòng không phải
  luật. Không đổi.
- **Các đề xuất của bản trước:**

| Đề xuất | Trạng thái |
| --- | --- |
| 1. Lượt thử tiêu chí 11 | **Xong** (design-assembly PR 100) |
| 1. Đọc lại bản chép của plugin | Chưa xong. Phiên làm việc này dừng giữa chừng, sửa ở `0.36.1`, chưa commit |
| 2. Chuẩn bị `0.10.5` | Chưa bắt đầu |
| 3. Đưa `onehub-inventory` lên `0.10.5` | Chờ `0.10.5` |
| 4. Chỗ hở của kho một chủ có `github-agents` | Chưa quyết |
| 5. Bài dựng lớp ở bậc `starter` | Chưa làm |
| 6. Hai phiên UX | Báo cáo rà UX **đã gộp** (PR 86). Bản thiết kế «setup as a consultation» vẫn chỉ ở máy |
| 6. Bật tự xoá nhánh | Chưa bật |

### Kho khác

Số đọc từ GitHub ngày 25/11.

| Kho | Trạng thái |
| --- | --- |
| `design-ci-probe` | Ở `0.10.3`, không đổi từ 21/11. Bốn PR cũ còn mở: hai PR thử nghiệm từ 16/11, hai PR Dependabot |
| `onehub-inventory` | Ở `0.10.3`. PR 107 (design-assembly lên `0.36.1`) và PR 110 (cổng nghiệm thu) **đã gộp**. PR 118 ghim kit delivery-loop lên `v3.1.1`. Đang mở PR 115: design-assembly lên `0.36.2` |
| `design-assembly` | Plugin ở **`0.58.0`**, 38 PR gộp từ ngày 23/11. Một PR mở (138, tài liệu) |
| `delivery-loop` | Bản mới nhất `v3.1.1` (23/11). PR 21 vẫn là nháp |

## 3. Phát hiện

1. **Bản chép của design-assembly tụt 23 bản phụ.** `tests/fixtures/design-assembly/seam.json` ghi
   `0.35.0`. Plugin đi từ `0.36.1` lên `0.58.0` chỉ trong hai ngày.
   - So từng byte, `host-strings.json` của bản chép và của `0.58.0` vẫn trùng nhau. Skill `adopt` vẫn
     có `adopt.mjs --target <repo> --starter`.
   - Chỗ sai đã biết vẫn là nghĩa của mã thoát 2. Bản chép ghi «màu thương hiệu», trong khi từ `0.36.0`
     kho có màu thương hiệu vẫn được đặt sổ.
   - Chưa đọc lại cột «From birth» của hợp đồng ở `0.58.0`.
   - Không có gì báo khi plugin đi trước bản chép, nên khoảng tụt này chỉ lộ ra khi có người tự đi xem.
2. **Cuộc trò chuyện lúc setup nhẹ hơn bản rà UX đếm** (PR 87).
   - Người giao hết cho Claude chỉ trả lời hai lần, không phải bốn.
   - Bù lại phải chờ 2 đến 5 phút mỗi lượt, chỉ nhìn thấy các dòng công cụ thu gọn.
   - Ở chế độ quyền mặc định, ước tính có tới 31 lời xin quyền. Lời xin quyền thuộc về Claude Code chứ
     không phải plugin, nhưng là thứ người mới gặp nhiều nhất.
3. **Kho nhận về nặng, và một câu trong đó không đúng sự thật.**
   - Cả hai lượt chạy đều sinh ra `docs/START-HERE.md` có câu «không có gì tự chạy trong Claude Code».
     Câu này chép từ `tour.md` (F7). Thực tế `.claude/settings.json` của kho có hook `SessionStart`.
   - Đây là kiểu lỗi thứ ba trong hai tuần: một tệp sinh ra nói về thứ kho đó không có, hoặc bỏ qua thứ
     kho đó có.
4. **Yêu cầu hay gặp nhất của người mới rơi ra ngoài sàn thiết kế** (N1). «Web app nhỏ cho team» cần
   máy chủ, nên lớp `design` thành «không áp dụng». Kho có giao diện viết tay, không có bài kiểm giao
   diện, mà `doctor` vẫn cho 100/100.
5. **Cùng một yêu cầu cho ra hai kho khác nhau** (N2). Lượt 1 chọn TypeScript, lượt 2 chọn Python. Tên
   dự án, số tệp, có Docker hay không cũng khác.
6. **Sàn thiết kế chưa gắn quyết định vào bài kiểm.** Lượt thử tiêu chí 11 thấy
   `capabilities/design/starter/tests/e2e/floor.spec.ts` không có thẻ `decision:<id>` nào: thiếu cho
   một-main-một-h1, không cuộn ngang, và WCAG AA. Chủ kho đã để việc này sau.
7. **design-assembly thiếu `merge=union` cho `wiki/log.md`.** PR 100 bên đó xung đột ba lần, cả ba ở
   tệp này. Kho này đã có dòng đó cho `CHANGELOG.md`. Đây là việc của design-assembly.

## 4. Kiểm chứng

| Lượt | Kết quả |
| --- | --- |
| `bash tests/run.sh` tại `0b1e4e9`, có báo cáo này trong cây | Xanh: «All tests passed.», mã thoát 0 |
| CI của PR 86 và PR 87 | `check`, `e2e`, `offline` trên macOS và Ubuntu, `validate`: xanh hết |
| CI trên `main` | 6 lượt «Test plugin» gần nhất xanh, gồm `0b1e4e9` |
| `rule_kinds.py check` | 12, 67 và 33 |
| Số liệu của PR 87 | Bảng chi phí từng lượt cộng đúng 5,14 USD và 8,27 USD. Kho của lượt 1 có commit `4a2486b`, 71 tệp, `make check` qua. Câu của F7 có trong `tour.md` ở tag `0.10.4` |
| So `host-strings.json` | Bản chép trùng từng byte với `0.58.0` |

Chưa kiểm:

- `tests/e2e.sh` đủ tổ hợp ở máy này.
- Hợp đồng «From birth» ở `0.58.0`.
- Một người mới thật. Cả hai báo cáo UX đều dùng máy đóng vai.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 21`. Cửa sổ bắt đầu ngày 2026-11-04, như các bản trước.

| Dòng | Bây giờ | Bản trước |
| --- | --- | --- |
| PR đã gộp | 84 | 81 |
| Trung vị thời gian từ mở đến gộp | 0,6 giờ | 0,6 giờ |
| Lâu nhất từ mở đến gộp | 14,9 giờ | 14,9 giờ |
| Gộp nhánh chính vào nhánh PR | 16 lần trên 84 PR, 5 lần xung đột khi phát lại | 16 trên 81, 5 xung đột |
| Phút máy CI | 5.014,6 phút trong 198 lượt | 4.889,6 phút trong 192 lượt |
| Phút máy mỗi PR đã gộp | 59,7 | 60,4 |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 87 | 5 trên 84 |
| Revert | 0 | 0 |

- **Không có lượt đỏ mới trên `main`.** Tỷ lệ còn 6%, vẫn trên ngưỡng 1/20.
- **Không có lần gộp ngược mới.** Ba PR mới đều chỉ thêm một tệp ở `docs/reports/`.
- **`tests/run.sh` vẫn là tệp hay xung đột nhất:** 3 trên 5 lần xung đột. Còn quá ít ca để kết luận.
- **Ô bắt buộc `check`:** 28 PR gộp khi `check` chưa xanh ở đầu cuối cùng, đều từ trước. Ba PR mới đều
  gộp khi đủ năm check xanh, và được ghim vào đầu đã kiểm bằng `--match-head-commit`.

## 6. Còn lại

### Chủ kho quyết

1. **Chọn việc từ hai báo cáo UX.** Các việc chỉ sửa lời không thêm chỗ người xuất hiện. Các việc sâu
   cần quyết trước:
   - R1, cửa vào cho nâng cấp. Cả hai báo cáo cho là việc đáng làm nhất cho người đã có kho.
   - R2, giảm sức nặng nhìn thấy của bậc `starter`. Hướng «hoãn» chạm luật 9 «mỗi tệp một người ghi».
   - N1, sàn thiết kế cho stack có máy chủ, hoặc một tổ hợp `react-vite` cộng API.
   - N2, có nên cố định lựa chọn stack cho cùng một mô tả không.
2. **Bản thiết kế «setup as a consultation»** (`3f937e1`, 613 dòng, nhánh
   `claude/ux-expert-consult-1a7f3b`). Chỉ có ở máy này, chưa đẩy. Nó chạm cùng vùng với R2 và R3 của
   bản rà UX.
3. **Phiên đọc lại bản chép** (nhánh `claude/fixture-design-assembly-0-36-1-86c51d`): còn ba tệp sửa
   chưa commit, ở `0.36.1`. Hướng làm: làm lại ở bản plugin hiện tại, hoặc bỏ.
4. **Kho một chủ có `github-agents`.** Không đổi từ bản trước.
5. **Có cần một lần đồng ý cho danh sách máy áp ở chặng 7 không?** Không đổi từ bản trước.
6. **Bật tự xoá nhánh sau khi gộp** ở kho này. Đây là đổi cài đặt của kho trên GitHub.
7. **Nâng cấp các kho thật,** mỗi kho cần chủ kho cho phép riêng.

### Trước bản phát hành 0.10.5

- **Đọc lại bản chép của design-assembly** ở bản hiện tại, rồi chạy lại 51f đến 51k.
- **Sửa câu «không có gì tự chạy»** trong `tour.md` (F7, Q1). Câu này đang nằm trong mọi kho mới.
- **Chạy `tests/e2e.sh` cho mọi tổ hợp.**
- **Thử nâng cấp trên bản sao** của `design-ci-probe` và `onehub-inventory`. Các điểm cần xem vẫn như
  bản trước: `.claude/settings.json` của `design-ci-probe` nhận hai thay đổi cùng lúc, cùng với mục
  `50-autonomy-card` và nhãn `risk:low`.
- **Trên GitHub thật,** ở `design-ci-probe` khi chủ kho cho phép.
- **Phát hành theo quy trình cũ:** nhánh `release/0.10.5`, `bump_version.py patch`, thẻ, rồi
  `bump_version.py dev`.

### Việc nhanh từ hai báo cáo UX

Gom lại, bỏ trùng. Mỗi dòng là một PR nhỏ.

| Việc | Nguồn | Loại |
| --- | --- | --- |
| Sửa năm chỗ lời cũ, trước hết là câu «không có gì tự chạy» | F7, Q1 | Chỉ sửa lời |
| Đổi chỗ bước 7 và 8 của `new` | F4, Q2 | Chỉ sửa lời skill (chỉ có ở `main`) |
| `explain` biết việc ngoài kho, có bảng từ | F8, F11, Q3 | Chỉ sửa lời skill |
| Mô tả hai bậc bằng số thật | F1, Q4 | Chỉ sửa lời |
| README sinh ra dẫn tới `START-HERE.md`, và dịch theo `docs_language` | F6, Q5 | Đổi tệp sinh ra |
| `make help` chia nhóm | F5, Q6 | Đổi tệp sinh ra |
| Chưa có remote: nói bằng lời, `make outside` không in lỗi của make | F3, Q7 | Đổi hành vi, bài đỏ trước |
| Thẻ tự chủ: khối cho «anh vẫn bấm gộp» | F9, Q8 | Đổi hành vi, bài đỏ trước |
| `doctor` khuyên `adopt` cho kho đã có mã | F12, F13, Q9 | Đổi đầu ra |
| Mục «Upgrading» trong README | F2, Q10 | Chỉ sửa lời |
| Lớp `delivery`: mặc định «chạy trên máy bạn» khi giao hết cho Claude | N4 | Chỉ sửa lời của lớp |
| Quy tắc cho `owner` khi chưa có remote | N3 | Chỉ sửa lời của lớp |
| Lời báo tiến độ theo ngôn ngữ của cuộc trò chuyện | N5 | Chỉ sửa lời skill |

### Lỗi nhỏ để lại

- Thẻ `decision:<id>` trong bài kiểm của sàn thiết kế (mục 3, điểm 6). Chủ kho để sau.
- Hai điểm của PR 83 và các điểm của 5.1, 5.2, 5.3 ở [bản trước](2026-11-23-progress-after-design-seam.md),
  mục 6, vẫn còn nguyên.

### Issue đang mở

- [#73](https://github.com/phanlemanh/repo-standards/issues/73): luật «tầng nặng xanh trước chữ ký».
  Phần còn lại là một câu ở delivery-loop.
- [#69](https://github.com/phanlemanh/repo-standards/issues/69): `doctor` báo `ontology_wiki_valid` hỏng
  khi có tệp dẫn xuất chưa vẽ.

### Vệ sinh

Ở design-assembly, worktree, nhánh ở máy và nhánh trên GitHub của lượt thử tiêu chí 11 đã được xoá,
sau khi kiểm cả hai nhánh đều nằm trong `origin/main`.

Ở kho này còn sáu worktree ngoài thư mục chính:

| Worktree | Nhánh | Trạng thái |
| --- | --- | --- |
| `progress-after-design-seam` | `docs/progress-after-design-seam` | PR 85 đã gộp; nhánh còn ở máy và trên GitHub |
| `ux-audit-b8f4ca` | `claude/ux-audit-b8f4ca` | PR 86 đã gộp; nhánh còn ở máy và trên GitHub |
| `newcomer-simulation-1c2e4b` | `claude/newcomer-simulation-1c2e4b` | PR 87 đã gộp; nhánh còn ở máy và trên GitHub |
| `call-design-assembly-4e6e87` | `claude/fixture-design-assembly-0-36-1-86c51d` | Ba tệp sửa chưa commit (mục 6, «Chủ kho quyết», điểm 3). Nhánh `claude/call-design-assembly-4e6e87` của PR 84 (đã gộp) còn ở máy và trên GitHub |
| `ux-expert-consult-1a7f3b` | `claude/ux-expert-consult-1a7f3b` | Một commit chưa đẩy (điểm 2) |
| `progress-overall` | `docs/progress-overall-2026-11-25` | Báo cáo này |

Thư mục chính đứng ở `9ad1ed6`, sau `origin/main` ba commit gộp, và giữ tệp chưa theo dõi
`docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`: không commit, không xoá.

## 7. Đề xuất hạng mục tiếp tục

1. **Một PR sửa lời cho mọi kho mới, trước `0.10.5`:** câu «không có gì tự chạy» (F7), quy tắc `owner`
   (N3), mặc định của lớp `delivery` (N4), ngôn ngữ của lời báo tiến độ (N5), README dẫn tới
   `START-HERE.md` (F6). Đều chỉ đổi lời, không thêm chỗ người xuất hiện, và chạm thứ người mới thấy
   đầu tiên.
2. **Đọc lại bản chép của design-assembly ở bản hiện tại,** gọn trong một PR. `host-strings.json` không
   đổi, nên việc chính là sửa nghĩa của mã thoát 2 và đọc lại cột «From birth». Nên quyết luôn số phận
   phiên đang dở ở `0.36.1`.
3. **Chuẩn bị `0.10.5`:** e2e đủ tổ hợp, thử nâng cấp trên bản sao hai kho, chạy thử trên
   `design-ci-probe`, phát hành. Sáu mục chưa phát hành cùng hai việc trên nên ra cùng một bản.
4. **Quyết R1 (cửa vào cho nâng cấp) trước khi đưa `onehub-inventory` lên `0.10.5`.** Kho đó là người
   nâng cấp thật đầu tiên sẽ đi qua luồng mà cả hai báo cáo chê.
5. **Dọn ba worktree đã gộp và bốn nhánh của PR 84 đến 87,** ở máy và trên GitHub, khi chủ kho muốn.
6. **Bật tự xoá nhánh** ở kho này để việc dọn ở điểm 5 không phải lặp lại.
