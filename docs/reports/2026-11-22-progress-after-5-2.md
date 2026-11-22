# Tổng kết sau phần 5.2

Ngày 2026-11-22. Phạm vi: từ `main` tại `9f30d08` (commit gộp PR 68, bản tổng kết trước) đến `main`
tại `4f70ee7` (commit gộp PR 79). Bản trước: [tổng kết sau 0.10.3](2026-11-21-progress-after-0.10.3.md).
Bàn giao giữa chừng: [bàn giao ngày 22/11](2026-11-22-handoff.md).

## 1. Tóm tắt

- **Từ bản trước:** gộp 10 PR (từ 70 đến 79), gồm 33 commit không phải commit gộp. Có 67 tệp thay đổi,
  thêm 5.910 dòng, bỏ 106 dòng. Còn một PR mở là PR 80.
- **Thiết kế ngày 22/11 đã dựng đủ ba phần:**
  - sổ việc ngoài kho (5.1, PR 76);
  - máy soạn, người duyệt (5.3, PR 77);
  - bảng tự chủ (5.2, PR 79).
- **Có một bản phát hành là `0.10.4`** (PR 72). `main` hiện mang `0.10.5.dev0`. Dưới `## Unreleased`
  có ba thay đổi chưa phát hành, ứng với 5.1, 5.3 và 5.2.
- **Lượt soát cả nhánh 5.2 bắt được hai lỗi nghiêm trọng trước khi gộp.** Cả hai cùng một kiểu: thứ
  chưa ai kiểm lại hiện ra như đã xong. Cả hai đã sửa, có bài đỏ trước.
- **Chủ kho quyết thêm một điều:** «nói đúng sự thật». Ngoài năng lực `github-agents`, không tệp nào
  còn nói PR hạng `low` «tự gộp» nữa (mục 3).
- **CI trên `main` xanh ở bảy lượt gần nhất.** Lượt cho commit gộp PR 79 đang chạy lúc viết.
- **Chưa thử gì trên GitHub thật hay trên bản sao của hai kho dùng.** Đây là việc còn lại trước khi phát
  hành `0.10.5`.

## 2. Đã thực hiện

### Thiết kế ngày 22/11

| Phần | Nội dung | Trạng thái |
| --- | --- | --- |
| 5.1 | Sổ việc ngoài kho: `tools/outside.py` (`status`, `apply`, `secrets`), `governance/outside.toml`, `ops/outside.toml`, `github_setup.py --check`, luật 11 | Đã gộp, PR 76 (`5cfe226`) |
| 5.3 | Bỏ hai dòng chặn sửa ở bậc `team`, kỹ năng `autonomy-change`, kho một chủ không đòi code owner duyệt | Đã gộp, PR 77 (`04b6d47`) |
| 5.2 | Bảng tự chủ: `make autonomy` cho biết «bạn được gọi khi nào», từ trạng thái thật, ở cả hai bậc | Đã gộp, PR 79 (`4f70ee7`) |

Bảng tự chủ trả lời bốn câu: khi nào gọi người, người làm gì, vì sao, và công tắc nào để bớt bị gọi.

- **Ở bậc `starter`:** bảng đọc các dòng chặn trong `.claude/settings.json`, tệp CI và
  `ontology/actions.yaml`.
- **Ở bậc `team`:** bảng đọc thêm chính sách gộp qua `autonomy.card_row` và sổ việc ngoài kho qua
  `outside.py status --json`. Cả hai nguồn đều có khoá `card`, nên bảng chép đúng chữ của nguồn, không
  tự viết lại.
- **Luật mới trong `AGENTS.md`, ở cả hai bậc:** khi giao việc cho người, nêu dòng của bảng gây ra lần
  gọi đó, kèm công tắc của dòng ấy. Luật này chỉ đổi lời của một lần gọi đã có sẵn; nó không thêm điểm
  dừng nào.

### Từ bản trước

| PR | Việc |
| --- | --- |
| 70 | Kho đã có sẵn nhận đúng cách gộp nó đang dùng, không bị ép squash |
| 72 | Phát hành `0.10.4` |
| 74 | `main` mang `0.10.5.dev0` |
| 75 | Trang roadmap của feature loop không còn là đầu vào của tầng nặng (sửa #71) |
| 76 | Phần 5.1: sổ việc ngoài kho, một lệnh cho mọi việc ngoài kho |
| 77 | Phần 5.3: máy soạn thay đổi luật, người duyệt |
| 78 | Bàn giao cho phiên sau, sau 5.1 và 5.3 |
| 79 | Phần 5.2: bảng tự chủ; kèm các bản sửa từ lượt soát cuối và phần đổi chữ «tự gộp» |
| 80 | **Đang mở, CI xanh:** bộ kiểm phải thất bại khi dừng giữa chừng dưới bash 3.2 |

### Cách dựng 5.2

- Năm task, mỗi task có bài đỏ trước rồi mới dựng, rồi một lượt soát riêng cho task đó. Task 4 và Task
  5 bị trả về sửa một lần.
- Lượt soát cả nhánh chạy trên model mạnh nhất. Nó tìm ra hai lỗi nghiêm trọng và hai lỗi quan trọng,
  sửa trong một lượt, rồi soát lại một lần: cả bảy điểm đều đã sửa.
- `tests/e2e.sh` giờ có thêm bước chạy `make autonomy` trong kho cài thật.

### Kho khác

Không có thay đổi từ lúc bàn giao.

| Kho | Trạng thái |
| --- | --- |
| `design-ci-probe` | Ở `0.10.3`. Đây là kho thử cho mọi lần chạy trên GitHub thật |
| `onehub-inventory` | Ở `0.10.3`, đang chuẩn bị đưa lên bản thật. Ví dụ gốc của thiết kế 22/11 |
| `delivery-loop`, `design-assembly` | Không có vòng kit nào trước ngày 02/12 |

## 3. Phát hiện

1. **«Không biết» đã hai lần hiện thành «đã xong» hay «tắt».** Lượt soát task và lượt soát cả nhánh
   cùng chỉ ra kiểu lỗi này:
   - Một dòng của sổ được ghi tay (`done = "..."`) bị đếm vào «N rows in place», dưới tiêu đề «máy tự
     làm».
   - Dòng `DEPLOY_ENABLED` bị từ chối lại hiện là «off: add a row». Còn `value = "false"` lại hiện là
     «deploys to staging».

   Cách sửa: bảng đọc cả bảy danh sách của sổ và đọc chính giá trị của dòng. Giá trị lấy từ bộ đọc của
   sổ, không dựng thêm bộ đọc TOML thứ hai. Bài học cho các công cụ sau: không thấy trong `ok` không có
   nghĩa là «không».
2. **Câu «PR `low` tự gộp» sai ở mọi kho không có `github-agents`.** Câu này có từ trước 5.2 và nằm ở
   bảy chỗ:
   - chú thích của chính sách;
   - hai mẫu PR;
   - nhãn `risk:low`;
   - README;
   - kỹ năng `github`;
   - tour.

   Bảng tự chủ làm lộ nó, vì bảng khẳng định đó là «việc máy làm». Chủ kho quyết «nói đúng sự thật» và
   sửa ngay trong PR 79. Bài 54k chặn câu này quay lại.
3. **Máy dựng có `PYTHONDONTWRITEBYTECODE=1`, nên che mất một lỗi chỉ hiện trên CI Ubuntu.** Chính bài
   test để lại `__pycache__` rồi đổ lỗi cho bảng. Từ nay, nên chạy bộ kiểm thêm một lần với
   `env -u PYTHONDONTWRITEBYTECODE` trước khi mở PR có công cụ Python mới.
4. **Bash 3.2 trên macOS từng làm bộ kiểm thoát 0 dù một tệp không đọc được** (PR 80). Máy dựng ở đây
   dùng bash 5.3, nên các lượt chạy của 5.2 là trọn vẹn. Nhưng ai chạy bằng `/bin/bash` của macOS thì có
   thể đã thấy «All tests passed» mà không đúng. PR 80 sửa việc này và chờ chủ kho gộp.
5. **Một ghi chú trong CHANGELOG đúng về chữ nhưng sai về ý.** Câu «không tệp nào anh đã sửa bị ghi đè»
   che mất hai điều: gộp ba chiều có thể để lại dấu xung đột, và kho adopt bị `skipped`. Lượt soát đối
   chiếu từng câu với `apply.py`, rồi viết lại cho đúng.

## 4. Kiểm chứng

| Lượt | Kết quả |
| --- | --- |
| `bash tests/run.sh` tại `18ffe18` | Xanh, cả khi bỏ `PYTHONDONTWRITEBYTECODE` |
| `tests/e2e.sh` cho `python` và `python:none:none:github-agents` | Xanh, có `make autonomy` trong kho thật |
| CI của PR 79 tại `18ffe18` | `check`, `e2e` (22 phút), `offline` trên macOS và Ubuntu, `validate`: xanh hết |
| Cây của commit gộp `4f70ee7` | Đầu PR được ghim bằng `--match-head-commit` |

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 18` trên `main` của chính kho này. Cửa sổ bắt đầu ngày
2026-11-04, như bản trước.

| Dòng | Bây giờ | Bản trước |
| --- | --- | --- |
| PR đã gộp | 76 | 67 |
| Trung vị thời gian từ mở đến gộp | 0,6 giờ | 0,7 giờ |
| Lâu nhất từ mở đến gộp | 14,9 giờ | 14,9 giờ |
| Gộp nhánh chính vào nhánh PR | 15 lần trên 77 PR, 5 lần xung đột khi phát lại | 15 lần trên 67 PR, 5 lần xung đột |
| Phút máy CI | 4.539,8 phút trong 181 lượt | 4.015,5 phút trong 161 lượt |
| Phút máy mỗi PR đã gộp | 59,7 | 59,9 |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 78 | 5 trên 69 |
| Revert | 0 | 0 |

- **Không có lượt đỏ mới trên `main`, và không có lần gộp ngược nào mới.** Chín PR mới đều đi thẳng.
- **Tỷ lệ đỏ trên nhánh chính là 6%, vẫn trên ngưỡng 1/20.** Con số giảm dần vì cả năm lượt đỏ đều cũ.
- **28 PR được gộp khi ô bắt buộc `check` chưa xanh ở đầu cuối cùng.** Công cụ đo không nói vì sao;
  báo cáo này chưa tra từng PR. Hai số «đến xanh» và «từ xanh» không tính các PR này.

## 6. Còn lại

### Chủ kho quyết

1. **Gộp PR 80:** bộ kiểm phải thất bại dưới bash 3.2 khi dừng giữa chừng. CI xanh.
2. **Kho một chủ có bật `github-agents`.** Agent trên GitHub có thể gộp một PR hạng `medium` hay `high`
   khi các check xanh. Một cách đóng: giữ yêu cầu code owner duyệt, và cho vai admin một dòng
   `bypass_actors`. Chưa dựng.
3. **Có cần một lần đồng ý cho danh sách máy áp ở chặng 7 không?** Bản dựng hiện không hỏi.
4. **Nâng cấp các kho thật.** Mỗi kho cần chủ kho cho phép riêng, và chỉ từ một thẻ phát hành.

### Trước bản phát hành 0.10.5

- Chạy `tests/e2e.sh` cho mọi tổ hợp. Các phiên dựng 5.1, 5.3 và 5.2 chỉ chạy `python` và
  `python:none:none:github-agents`; CI của từng PR chạy e2e của nó.
- Thử nâng cấp trên **bản sao** của `design-ci-probe` và `onehub-inventory` (mục 7 của thiết kế). Cần
  xem bốn điểm:
  - hai dòng chặn sửa ở `settings.json`;
  - mục mới `50-autonomy-card` của `AGENTS.md`, chỗ dễ có dấu xung đột;
  - kho một chủ đổi luật nhánh;
  - nhãn `risk:low` đổi mô tả.
- Trên GitHub thật, ở `design-ci-probe` khi chủ kho cho phép, chạy thử:
  - các loại lệnh của sổ ngoài kho;
  - `gh secret set` với khoá của môi trường;
  - `github_setup.py --apply` ở kho một chủ;
  - `make autonomy` có `gh` thật.
- Phát hành theo quy trình cũ: nhánh `release/0.10.5`, rồi `bump_version.py patch`, `### Verified` và
  `### Known gaps`, thẻ và `gh release create --verify-tag`, rồi một PR `bump_version.py dev`.

### Lỗi nhỏ để lại

Phần 5.2, theo lượt soát cuối, đều không sai sự thật:

- step summary có thể kết thúc bằng `..`;
- dòng ghi tay vẫn nằm dưới tiêu đề «The machine does alone»;
- mục Review Focus của kế hoạch còn câu cũ;
- lời «not known» của dòng deploy hơi rộng;
- bảng chữ rộng 122 cột;
- một số bài kiểm còn mỏng: `--keys`, step summary, tệp hỏng, 54f.

Phần 5.1 và 5.3: bảy điểm của 5.1 và hai điểm của 5.3 ghi ở
[bàn giao](2026-11-22-handoff.md), mục 3, vẫn còn nguyên.

### Issue đang mở

- [#73](https://github.com/phanlemanh/repo-standards/issues/73): luật «tầng nặng xanh trước chữ ký».
  Phần của kit đã xong ở PR 75. Phần còn lại là một câu ở delivery-loop; chưa bên nào nhận.
- [#69](https://github.com/phanlemanh/repo-standards/issues/69): `doctor` báo `ontology_wiki_valid` hỏng
  khi có tệp dẫn xuất chưa vẽ.

### Vệ sinh

- Đã dọn worktree và nhánh `feat/autonomy-card` (cả ở máy và trên GitHub).
- Còn hai worktree cũ:
  - `rs-consolidated-plan-2f7ac9`, nhánh `feat/merge-method-in-policy`, đã gộp;
  - `rule-kinds-design-1c073a`, nhánh `claude/machine-drafts-rule-changes-b5675c`, đã gộp.
- Có khoảng 30 nhánh ở máy và khoảng 45 nhánh trên GitHub. Nhiều nhánh đã gộp.
- Tệp chưa theo dõi `docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`: không commit, không xoá.

## 7. Đề xuất hạng mục tiếp tục

1. **Gộp PR 80** trước tiên, vì nó làm bộ kiểm trung thực trên macOS.
2. **Chuẩn bị `0.10.5`:** chạy e2e đủ tổ hợp, rồi thử nâng cấp trên bản sao hai kho, rồi chạy thử trên
   `design-ci-probe`, rồi phát hành. Ba phần của thiết kế 22/11 nên ra cùng một bản, vì cả ba cùng đổi
   `AGENTS.md` và cùng nói về chỗ người xuất hiện.
3. **Đưa `onehub-inventory` lên `0.10.5`** khi chủ kho cho phép. Kho này là ví dụ gốc của thiết kế,
   nên đây là lần đầu bảng tự chủ chạy trên trạng thái thật của một kho dùng.
4. **Quyết chỗ hở của kho một chủ có `github-agents`** trước khi bật `github-agents` ở bất kỳ kho một chủ
   nào.
5. **Dọn nhánh và worktree đã gộp,** khi chủ kho muốn.
