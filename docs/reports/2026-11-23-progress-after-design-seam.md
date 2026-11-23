# Tổng kết sau mối nối với design-assembly

Ngày 2026-11-23. Phạm vi: từ `main` tại `4f70ee7` (commit gộp PR 79, điểm cuối của bản trước) đến `main`
tại `9ad1ed6` (commit gộp PR 84). Bản trước: [tổng kết sau phần 5.2](2026-11-22-progress-after-5-2.md).

## 1. Tóm tắt

- **Từ bản trước:** gộp 5 PR (từ 80 đến 84), gồm 6 commit không phải commit gộp. Có 23 tệp thay đổi,
  thêm 997 dòng, bỏ 32 dòng. Không còn PR nào mở.
- **Việc lớn nhất: setup gọi design-assembly** (PR 84). design-assembly đặt bộ sổ thiết kế lúc kho ra
  đời; setup chỉ gọi nó, và `doctor` chỉ xem sổ có mặt hay không. Đây là lát 3 của đề bài 0013 bên
  design-assembly. Sàn thiết kế vẫn ở kho này.
- **Thêm một chỗ «nói không đúng sự thật» đã sửa** (PR 83): `AGENTS.md` của kho bậc `starter` có lớp
  container từng hứa một lượt triển khai mà bậc đó không có.
- **Bộ kiểm trung thực hơn trên hai loại máy** (PR 80 và PR 82): bash 3.2 của macOS, và máy có ghi
  `__pycache__`.
- **Chưa có bản phát hành mới.** `main` vẫn mang `0.10.5.dev0`. Dưới `## Unreleased` có sáu mục.
- **CI trên `main` xanh ở 12 lượt gần nhất,** gồm lượt cho `9ad1ed6`.
- **Ba việc thử vẫn chưa làm:** hai plugin thật chạy cùng nhau, GitHub thật, và bản sao của hai kho
  dùng. Đây là việc còn lại trước khi phát hành `0.10.5`.
- **Đã dọn nhánh và worktree đã gộp** ở kho này và ở design-assembly (mục 6, «Vệ sinh»).

## 2. Đã thực hiện

### Mối nối với design-assembly (PR 84)

Lát 3 của đề bài 0013 bên design-assembly: tiêu chí 4, tiêu chí 5, và phần của kho này trong tiêu chí
7. Hợp đồng nằm ở [hợp đồng mối nối](../seam-contracts.md), mục 6 đến 8.

| Chỗ | Thay đổi |
| --- | --- |
| `/repo-setup:new`, bước 6 | Khi lớp `design` bật và plugin có trong phiên, gọi `/design-assembly:adopt --starter`, không kèm cờ nào khác. Mã thoát 0 và 1 đi tiếp; mã 2 thì nói một dòng rồi đi tiếp. Thiếu plugin thì nói một dòng, không dừng |
| `/repo-setup:new`, bước 8 | Mời đi tiếp với design-assembly, một lần: `adopt` khi kho dựng với màu thương hiệu, `new` ở các kho khác |
| `/repo-setup:adopt`, bước 4c | Gọi `audit` của plugin, rồi `adopt` không kèm `--starter` |
| `doctor.py` | Khối `design_ledgers`, không tính điểm: nêu sổ lúc ra đời còn thiếu, và dấu bản công cụ tụt so với plugin đang cài. Chỉ đọc tệp, qua mô-đun mới `scripts/design_ledgers.py` |
| `.claude/settings.json` sinh ra | Kho có sàn thiết kế biết marketplace `phanlemanh/design-assembly` và bật plugin |
| `tests/seams.sh` | Mục 51f đến 51k, dùng bản chép của plugin 0.35.0 ở `tests/fixtures/design-assembly/`. Không chạy plugin thật |

- **Chỗ người xuất hiện:** lời mời ở bước 8 là chỗ mới duy nhất. Chủ kho đã duyệt nó trong đề bài 0013
  (câu 2).
- **Sàn chưa chuyển:** sàn thiết kế (`capabilities/design`), câu hỏi màu thương hiệu và loại bề mặt vẫn
  ở kho này, đúng như đề bài 0013 chốt (câu 5).
- **Ai dựng:** một phiên riêng do phiên điều phối của design-assembly mở. Phiên điều phối soát lại và
  bắt được một điểm sai trước khi gộp (mục 3, điểm 2).

### Các PR còn lại

| PR | Việc |
| --- | --- |
| 80 | Bộ kiểm thất bại khi dừng giữa chừng dưới bash 3.2 |
| 81 | Bản tổng kết sau phần 5.2 |
| 82 | Bài 54k chỉ đọc tệp chữ, không vấp `__pycache__` cũ |
| 83 | `AGENTS.md` bậc `starter` có lớp container không còn hứa lượt triển khai. Luật đó chuyển nguyên văn sang một mảnh ở bậc `team`. Mục 13b của `tests/run.sh` giữ việc này cho cả hai stack |
| 84 | Setup gọi design-assembly |

### Sáu mục chưa phát hành

Dưới `## Unreleased` của `CHANGELOG.md`, theo thứ tự thời gian:

1. Trang roadmap của feature loop không còn là đầu vào của tầng nặng (PR 75).
2. Sổ việc ngoài kho, phần 5.1 (PR 76).
3. Máy soạn thay đổi luật, người duyệt, phần 5.3 (PR 77).
4. Bảng tự chủ, phần 5.2 (PR 79).
5. Kho bậc `starter` có lớp container không còn bị hứa một lượt triển khai (PR 83).
6. Setup gọi design-assembly (PR 84).

Mục nào cũng có đoạn «What breaks on upgrade».

### Đối chiếu với kế hoạch

- **Thiết kế ngày 22/11** (5.1, 5.2, 5.3): đã dựng đủ từ bản trước. Không có thay đổi.
- **Trang ranh giới ba kho:** mục «lời gọi sang design-assembly» chuyển từ «sẽ làm» sang «đã làm». Mục
  «sàn thiết kế chuyển đi» vẫn chờ design-assembly sẵn sàng nhận.
- **Bảng gói việc RS** trong [thiết kế tổng quan](../three-repo-overview-design.md), mục 7: không dòng
  nào đổi trạng thái. RS5b (khe uỷ quyền) vẫn hoãn; RS4 và RS5a vẫn đóng, không dựng.
- **Phân loại luật** (`rule_kinds.py check`): 12 luật có máy giữ, 67 luật giữ bằng lời, 33 dòng không
  phải luật. Không đổi so với trước PR 83.

### Kho khác

Số đọc từ GitHub ngày 23/11. Bản sao của `onehub-inventory` ở máy này đã cũ (còn ghi `0.9.0`), nên không
dùng nó làm nguồn.

| Kho | Trạng thái |
| --- | --- |
| `design-ci-probe` | Ở `0.10.3`, không đổi từ ngày 21/11 |
| `onehub-inventory` | Ở `0.10.3`. `main` vừa gộp PR 109 (đổi tham chiếu kit lên `v3.1.0`). Đang mở PR 107 (design-assembly từ 0.7.1 lên 0.36.1, chỉ phần máy) và PR 110 (cổng nghiệm thu chạy trên delivery-loop `v3.1.0`) |
| `design-assembly` | Plugin ở `0.36.1`. Không có PR mở |
| `delivery-loop` | PR 21 (sổ của đợt chuyển nhà giai đoạn 2) còn mở; tiêu đề của nó ghi là nháp |

## 3. Phát hiện

1. **Bài kiểm nhanh dựng các lớp ở bậc `team`, nên bậc `starter` của một lớp có thể sai mà không ai
   thấy.** Câu «Releases deploy automatically to staging» nằm trong mảnh `starter` của lớp container,
   trong khi `deploy.yml`, `release.yml` và `mk/deploy.mk` chỉ có ở bậc `team`.
   - Người chỉ ra là lượt phản biện độc lập của một lần chạy thử `/repo-setup:new` trên bản 0.9.0. Lỗi
     vẫn còn trên `main` cho tới PR 83.
   - `tests/e2e.sh` không dựng kho nào ở bậc `starter`. Mục 13b là bài duy nhất giữ phía đó.
   - Lỗi này cùng kiểu với câu «PR `low` tự gộp» ở bản trước: một tệp sinh ra nói về thứ kho đó không
     có.
2. **Hợp đồng với design-assembly đổi trong lúc đang dựng.** Bản 0.35.0 từ chối `--starter` ở kho có
   màu thương hiệu (mã thoát 2). Bản 0.36.0 (quyết định 0087) đặt sổ ở cả kho đó. Commit đầu của PR 84
   viết «mã 2 nghĩa là màu thương hiệu»; phiên điều phối soát lại và báo sang, bản sửa `843bb84` vào
   trước khi gộp, có bài đỏ trước.
3. **Bản chép của plugin trong bộ kiểm đã tụt hai bản.** `tests/fixtures/design-assembly/seam.json`
   ghi `0.35.0`, đọc ngày 22/11. Plugin đang ở `0.36.1`. Không có gì báo khi plugin đi trước bản chép:
   các bài 51f đến 51k vẫn xanh với một hợp đồng cũ. `doctor` so dấu bản công cụ cho kho dùng, nhưng
   không có phép so nào cho bản chép này.
4. **Kho này không bật thứ nó bật cho kho khác.** `github_setup.py` đặt `delete_branch_on_merge=true`
   cho mọi kho nó dựng: `design-ci-probe`, `onehub-inventory` và `delivery-loop` đều đang bật. Kho này
   và `design-assembly` đang tắt, nên nhánh đã gộp cứ dồn lại: trước lượt dọn của phiên này, `design-assembly`
   có 38 nhánh đã gộp trên GitHub.
5. **Gỡ worktree xoá cả tệp bị `.gitignore` bỏ qua mà không báo.** Một worktree của `design-assembly`
   giữ nhật ký của một lần chạy thử nghiệm thu, không có ở nơi nào khác. Chủ kho quyết giữ worktree đó.
   Từ nay, trước khi gỡ worktree nên xem thêm `git status --ignored`.

## 4. Kiểm chứng

| Lượt | Kết quả |
| --- | --- |
| `bash tests/run.sh` tại `9ad1ed6` | Xanh: «All tests passed.», mã thoát 0 |
| Cùng lượt, bỏ `PYTHONDONTWRITEBYTECODE` | Xanh: «All tests passed.», mã thoát 0 |
| CI của PR 84 tại `5bbf10f` | `check`, `e2e`, `offline` trên macOS và Ubuntu, `validate`: xanh hết |
| CI trên `main` | 12 lượt «Test plugin» gần nhất đều xanh, gồm lượt cho `9ad1ed6` |
| `rule_kinds.py check` | 12, 67 và 33, như mục 2 |

Chưa kiểm:

- Hai plugin thật chạy cùng nhau. Đó là lượt thử của tiêu chí 11, bên design-assembly.
- Sau một lần cài thật, có đủ bảy sổ lúc ra đời hay không.
- `tests/e2e.sh` đủ tổ hợp ở máy này sau PR 84. Job `e2e` của CI thì xanh ở cả PR 83 và PR 84. Mô tả
  của PR 83 ghi một lượt chạy tay 17 tổ hợp ở bậc `team`; báo cáo này không chạy lại lượt đó.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 19` trên `main` của chính kho này. Cửa sổ bắt đầu ngày
2026-11-04, như các bản trước.

| Dòng | Bây giờ | Bản trước |
| --- | --- | --- |
| PR đã gộp | 81 | 76 |
| Trung vị thời gian từ mở đến gộp | 0,6 giờ | 0,6 giờ |
| Lâu nhất từ mở đến gộp | 14,9 giờ | 14,9 giờ |
| Gộp nhánh chính vào nhánh PR | 16 lần trên 81 PR, 5 lần xung đột khi phát lại | 15 lần trên 77 PR, 5 lần xung đột |
| Phút máy CI | 4.889,6 phút trong 192 lượt | 4.539,8 phút trong 181 lượt |
| Phút máy mỗi PR đã gộp | 60,4 | 59,7 |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 84 | 5 trên 78 |
| Revert | 0 | 0 |

- **Không có lượt đỏ mới trên `main`.** Tỷ lệ là 6%, vẫn trên ngưỡng 1/20, và vẫn giảm dần vì cả năm
  lượt đỏ đều cũ.
- **Có một lần gộp ngược mới,** ở PR 84, không xung đột. PR 83 gộp trước nó hơn nửa giờ và cả hai cùng
  thêm dòng vào `CHANGELOG.md`.
- **Năm PR mới đều gộp khi ô bắt buộc `check` đã xanh.** Số PR gộp lúc `check` chưa xanh ở đầu cuối
  cùng vẫn là 28, đều từ trước.

## 6. Còn lại

### Chủ kho quyết

1. **Kho một chủ có bật `github-agents`.** Agent trên GitHub có thể gộp một PR hạng `medium` hay `high`
   khi các check xanh. Một cách đóng: giữ yêu cầu code owner duyệt, và cho vai admin một dòng
   `bypass_actors`. Chưa dựng. Không đổi từ bản trước.
2. **Có cần một lần đồng ý cho danh sách máy áp ở chặng 7 không?** Bản dựng hiện không hỏi. Không đổi
   từ bản trước.
3. **Nâng cấp các kho thật.** Mỗi kho cần chủ kho cho phép riêng, và chỉ từ một thẻ phát hành.
4. **Hai phiên UX đang chờ.**
   - Phiên rà UX đã viết `docs/reports/2026-11-22-ux-audit.md` trong worktree của nó, chưa commit. Nó
     chờ chủ kho chọn dựng điểm nào.
   - Phiên tư vấn UX đã commit một bản thiết kế (`3f937e1`, «setup as a consultation») trên nhánh của
     nó, chưa đẩy, chưa có PR, chưa có kế hoạch dựng.
5. **Bật tự xoá nhánh sau khi gộp ở kho này** (mục 3, điểm 4). Đây là đổi cài đặt của kho trên GitHub.

### Trước bản phát hành 0.10.5

- **Lượt thử của tiêu chí 11:** `/repo-setup:new` và `/design-assembly:adopt --starter` thật, trên một
  kho trống. Bên design-assembly giữ lượt này.
- **Đọc lại bản chép của plugin ở `0.36.1`** rồi chạy lại 51f đến 51k. Cách làm ghi trong `seam.json`.
- **Chạy `tests/e2e.sh` cho mọi tổ hợp.**
- **Thử nâng cấp trên bản sao** của `design-ci-probe` và `onehub-inventory`. Bản này thêm một điểm cần
  xem: `design-ci-probe` vừa ở bậc `team` vừa có sàn thiết kế, nên `.claude/settings.json` của nó nhận
  hai thay đổi trong cùng một lần nâng (bỏ hai dòng chặn sửa của 5.3, và thêm hai khoá bật plugin).
  Các điểm cũ vẫn còn: mục `50-autonomy-card` của `AGENTS.md`, kho một chủ đổi luật nhánh, nhãn
  `risk:low` đổi mô tả.
- **Trên GitHub thật,** ở `design-ci-probe` khi chủ kho cho phép: các loại lệnh của sổ ngoài kho,
  `gh secret set` với khoá của môi trường, `github_setup.py --apply` ở kho một chủ, và `make autonomy`
  có `gh` thật.
- **Phát hành theo quy trình cũ:** nhánh `release/0.10.5`, rồi `bump_version.py patch`, `### Verified`
  và `### Known gaps`, thẻ và `gh release create --verify-tag`, rồi một PR `bump_version.py dev`.

### Lỗi nhỏ để lại

- Từ PR 83, hai điểm ghi trong mô tả của nó:
  - ở bậc `team`, câu «Releases deploy automatically to staging» chỉ đúng khi biến `DEPLOY_ENABLED` là
    `true`, mà biến này không được gieo sẵn. `make autonomy` đã nói kho đang ở trạng thái nào;
  - `blueprint.py dependents quality` chỉ in `governance`, nên đổi bậc từ `starter` lên `team` không
    đánh dấu lớp delivery để xem lại.
- Các điểm của 5.2, 5.1 và 5.3 ở [bản trước](2026-11-22-progress-after-5-2.md), mục 6, vẫn còn nguyên.

### Issue đang mở

- [#73](https://github.com/phanlemanh/repo-standards/issues/73): luật «tầng nặng xanh trước chữ ký».
  Phần còn lại là một câu ở delivery-loop; chưa bên nào nhận.
- [#69](https://github.com/phanlemanh/repo-standards/issues/69): `doctor` báo `ontology_wiki_valid` hỏng
  khi có tệp dẫn xuất chưa vẽ.

### Vệ sinh

Đã dọn trong phiên này (ngày 22 và 23/11). Mỗi thứ đều được kiểm là đã gộp và không còn thay đổi chưa
commit. Ba phiên đã xong cũng đã được lưu trữ.

| Kho | Đã dọn |
| --- | --- |
| Kho này | 3 worktree, 31 nhánh ở máy, 9 nhánh trên GitHub |
| `design-assembly` | 8 worktree, 64 nhánh ở máy, 38 nhánh trên GitHub |

Còn lại ở kho này:

- Worktree `call-design-assembly-4e6e87`, cùng nhánh `claude/call-design-assembly-4e6e87` ở máy và trên
  GitHub. PR 84 của nó đã gộp.
- Hai worktree của hai phiên UX (mục «Chủ kho quyết», điểm 4).
- Tệp chưa theo dõi `docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`: không commit, không
  xoá.

Còn lại ở `design-assembly`: worktree `kit-trial-5-0` và nhánh của nó, giữ theo lời chủ kho (mục 3,
điểm 5).

## 7. Đề xuất hạng mục tiếp tục

1. **Chạy lượt thử của tiêu chí 11 trước mọi việc khác.** Mối nối mới chỉ được kiểm bằng bản chép của
   một bản plugin cũ. Nên đọc lại bản chép ở `0.36.1` trong cùng lượt đó.
2. **Chuẩn bị `0.10.5`:** e2e đủ tổ hợp, rồi thử nâng cấp trên bản sao hai kho, rồi chạy thử trên
   `design-ci-probe`, rồi phát hành. Sáu mục nên ra cùng một bản: bốn mục cùng đổi `AGENTS.md`, hai mục
   cùng đổi `.claude/settings.json`.
3. **Đưa `onehub-inventory` lên `0.10.5`** khi chủ kho cho phép, sau khi kho này và design-assembly đã
   xong phần của mình. Kho đó đang có PR 107 nâng design-assembly; hai lần nâng nên đi riêng.
4. **Quyết chỗ hở của kho một chủ có `github-agents`** trước khi bật `github-agents` ở bất kỳ kho một
   chủ nào.
5. **Thêm bài dựng lớp ở bậc `starter`** cho các lớp còn lại, như mục 13b đã làm cho lớp container (mục
   3, điểm 1). Việc này cần rà trước xem lớp nào có mảnh `starter` nói về thứ chỉ bậc `team` mới có.
6. **Quyết hai phiên UX** và **bật tự xoá nhánh**, khi chủ kho muốn.
