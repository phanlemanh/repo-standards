# Tổng kết sau RS7

Ngày 2026-11-18. Phạm vi: từ `main` tại `5205c16` (commit gộp bản `0.9.0`, cuối phạm vi của bản
trước) đến `main` tại `bc31175` (commit gộp RS7). Kế hoạch được chấm theo
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và các bước A đến F ở cuối mục 8. Bản trước: [tổng kết sau 0.9.0](2026-11-18-progress-after-0.9.0.md).

## 1. Tóm tắt

- Từ bản trước: 3 PR đã gộp (33, 34, 35), 13 commit, 36 tệp đổi, thêm 2.086 dòng, bỏ 117 dòng.
- **Bước E đã mở:** RS7 đã thiết kế, dựng và gộp (PR 35), chưa phát hành. RS5a vẫn chờ
  design-assembly.
- **Hai trong ba việc chờ chủ kho ở bản trước đã xong:** `main` của kho này có ruleset bắt buộc ô
  `check`, và `dependency-audit` xanh lại nhờ PR 34. Việc thứ ba, nâng `onehub-inventory`, đang làm.
- **Đang làm:** nâng `onehub-inventory` lên `0.9.0` (hai PR đã mở ở hai kho khác, chưa gộp), và một
  thẻ chờ chủ kho bấm để phần cuối `AGENTS.md` tự gộp khi nâng cấp.
- **`main` đang đỏ tại `bc31175`:** ô `offline` trên macOS thoát với mã 1, không in dòng lỗi nào. Cây
  của commit này trùng từng byte với đầu nhánh PR 35, nơi cả năm ô xanh, nên nhiều khả năng đây là bài
  chập chờn. Lượt chạy lại đang chạy lúc viết; chưa có kết quả.
- `## Unreleased` có hai mục, không mục nào phá vỡ: bản kế là `0.10.0`.

## 2. Đã thực hiện

### Kế hoạch tới nay

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                  |
| ---- | ---- | -------------------------------------------------------------- | ------------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                     |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                        |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                     |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2   |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong, phát hành ở 0.7.0                     |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | Xong, phát hành ở 0.8.0, đã đo trên kho thử |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | Xong, phát hành ở 0.9.0, đã đo trên kho thử |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | **Đã gộp (PR 35), chưa phát hành**          |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn        |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                       |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được         |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm                                    |

### Từ bản trước

| PR  | Commit gộp | Việc                                                                         |
| --- | ---------- | ---------------------------------------------------------------------------- |
| 33  | `eec54ae`  | Bản tổng kết sau `0.9.0`                                                     |
| 34  | `8706907`  | Mẫu `design` cài `shadcn` bằng `--save-dev`, nên `dependency-audit` xanh lại |
| 35  | `bc31175`  | RS7: mỗi luật trong `AGENTS.md` sinh ra nói thứ gì giữ nó                    |

**RS7** gồm:

- Mỗi mục danh sách trong 12 mảnh `+AGENTS.md/` của plugin mang một loại, `<!-- kept: <mã> -->`:
  `word` (giữ bằng lời), `none` (không phải luật), hay tên một máy có trong tệp mới
  `rule-checks.toml`. `apply.py` gỡ các nhãn này, nên kho cài không thấy chúng.
- `AGENTS.md` sinh ra kết thúc bằng mục mới «What holds these rules». Mục này kể các máy mà kho đó
  có, mỗi máy bắt gì và phản ứng thế nào, rồi nói một lần rằng các luật còn lại không có máy giữ.
- Một máy chỉ được nêu tên khi có bài kiểm của kho này, mang thẻ `# rule-check: <mã>`, phá luật đó
  trong một kho sinh ra và thấy máy phản ứng. Hôm nay có bảy máy đạt.
- Số đếm trên 108 mục: **13 luật máy giữ, 62 luật giữ bằng lời, 33 mục không phải luật.** Mục 50 của
  bộ kiểm (`tests/rule_kinds.sh`) đỏ khi một mục thiếu loại, nêu máy chưa đăng ký, hay nêu máy không
  có bài kiểm mang thẻ. Đây là điều kiện «xong» của bước E: bài kiểm đỏ khi thêm luật không có chủ.
- Sáu mục trộn một luật máy giữ với một luật bằng lời nay tách làm hai. Nội dung luật không đổi.

**Ruleset trên `main` của kho này** («protect main: PR + check», bật lúc 17:44 ngày 2026-11-18): mọi
thay đổi vào `main` phải qua PR; ô `check` là bắt buộc; không ai được vượt; cấm xoá nhánh và cấm đẩy
đè; không đòi nhánh phải cập nhật trước khi gộp (`strict: false`). Từ đây ô tổng của RS3 là tường
thật ở chính kho dạy nó.

## 3. Đang thực hiện

- **Nâng `onehub-inventory` lên `0.9.0`.** Đã chạy thử trọn bản nâng trên một bản sao: 12 tệp bị đánh
  dấu đều gỡ được, bốn sổ tách xong không mất dòng nào, `make build` xanh. Kế hoạch 9 PR nằm ở
  `docs/superpowers/plans/2026-11-18-onehub-upgrade-0.9.0.md`; tệp này chưa commit. Hai PR đã mở,
  chưa PR nào gộp:
  - [phanlemanh/design-assembly#38](https://github.com/phanlemanh/design-assembly/pull/38), plugin
    design-assembly 0.7.2: luật `checks-in-gate` hiểu được `make check` hai tầng. Ô `check` xanh.
  - [phanlemanh/onehub-inventory#88](https://github.com/phanlemanh/onehub-inventory/pull/88): nâng từ
    0.4.0 lên 0.9.0, chỉ phần máy móc, giữ luật cũ. `quick`, `secret-scan`, `conventional-title`,
    `dependency-audit` và CodeQL xanh; `e2e` và `e2e-db` đang chạy; `gate` đỏ tới khi có chữ ký Gate 2. Hồ sơ nghiệm thu T3 đã qua Gate 1; phiên làm việc đó đang chờ chủ kho trả lời một câu về lời
    của tiêu chí AC-4.
- **Thẻ «Machine-kept tail of AGENTS.md merges by itself»**, chờ chủ kho bấm. RS7 thêm một mục vào
  cuối `AGENTS.md`; kho nào đã tự viết thêm ở cuối tệp sẽ nhận dấu xung đột khi nâng cấp. Thẻ để máy
  tự đặt mục đó ở cuối. PR 35 đã gộp nên thẻ đủ điều kiện chạy.
- **Lượt chạy lại CI của `main` tại `bc31175`** (mục 4).

## 4. Kiểm chứng

| Phép kiểm                                              | Kết quả                                                                                                                          |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main` tại `bc31175`, ở máy   | Qua, «All tests passed.», gồm mục 50 mới                                                                                         |
| PR 34 và PR 35: CI                                     | Qua cả 5 ô; `e2e` trọn bộ, 25 phút và 24 phút                                                                                    |
| PR 33 (chỉ tài liệu): CI                               | Qua cả 5 ô; `e2e` 8 giây                                                                                                         |
| CI «Test plugin» trên `main` tại `8706907` (gộp PR 34) | Qua                                                                                                                              |
| CI «Test plugin» trên `main` tại `bc31175` (gộp PR 35) | **Đỏ:** `offline (macos-latest)` thoát mã 1 sau mục «derived», không dòng `FAIL` nào; `e2e` bị bỏ qua; `check` đỏ. Đang chạy lại |

Về lần đỏ này: cây của `bc31175` và cây của đầu nhánh PR 35 (`34bd594`) là một (`219c619`), và ở đầu
nhánh đó ô macOS xanh. Bộ kiểm chạy ở máy macOS cũng xanh. Bản RS3 đã ghi rằng vài ống
`printf | grep` trong bộ kiểm có thể chập chờn; đây có thể là trường hợp đó, nhưng chưa xác nhận.

Chưa kiểm được:

- RS7 trên một kho thật: chưa nâng kho thử lên bản có RS7, nên hai trường hợp đánh dấu ghi trong
  CHANGELOG chưa được thấy ngoài bộ kiểm.
- `tests/e2e.sh` của RS7 chạy trước lần gộp `main` cuối và trước lượt sửa sau soát; lượt `e2e` trên
  PR 35 thì chạy trên đúng cây đã gộp và xanh.
- Còn từ trước: hai lượt cùng lưu một khoá đầu vào; một PR dùng lại khoá do nhánh chính lưu; pipeline
  `github-agents` trên GitHub; CodeQL trên kho công khai sau nâng cấp.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 14` trên chính kho này, cửa sổ từ 2026-11-04.

| Dòng                                | Bây giờ                               | Bản trước                             |
| ----------------------------------- | ------------------------------------- | ------------------------------------- |
| PR đã gộp                           | 35                                    | 32                                    |
| Trung vị từ mở đến gộp              | 0,7 giờ                               | 0,8 giờ                               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                              | 14,9 giờ                              |
| Gộp nhánh chính vào nhánh PR        | 6 trên 35 PR, 4 xung đột khi phát lại | 5 trên 32 PR, 3 xung đột khi phát lại |
| Phút máy CI                         | 1.774,2 trong 82 lượt                 | 1.602,3 trong 76 lượt                 |
| Phút máy mỗi PR gộp                 | 50,7                                  | 50,1                                  |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 38                             | 4 trên 34                             |
| Revert                              | 0                                     | 0                                     |

- Phút máy mỗi PR chưa giảm. Hai trong ba PR mới đổi mẫu của plugin, nên `e2e` chạy trọn bộ, đúng
  như RS3 định. Mới có 6 PR gộp dưới RS3; phép so sau 10 PR chưa làm được.
- Lần gộp ngược có xung đột mới là của PR 35, ở `CHANGELOG.md`, mục `## Unreleased`: PR 34 và PR 35
  cùng thêm vào đó. Đây là lần thứ hai `CHANGELOG.md` gây xung đột trong cửa sổ đo.

## 6. Còn lại

### Chủ kho quyết

1. **Bấm thẻ «Machine-kept tail of AGENTS.md merges by itself»** hay để hành vi hiện tại (đã ghi
   trong CHANGELOG).
2. **Câu nói quá trong `55-autonomy.md`:** «the gate sees both and raises the tier» có mặt cả ở kho
   không cài `github-agents`, nơi không có cổng nào thấy. Sửa câu đó là đổi điều mọi kho được dặn.
3. **`onehub-inventory`:** trả lời câu về AC-4, ký Gate 2 cho PR 88, gộp
   [phanlemanh/design-assembly#38](https://github.com/phanlemanh/design-assembly/pull/38), rồi bảy
   quyết định ở mục 8 của kế hoạch nâng (lúc tách sổ, ruleset, PR ở dạng bản nháp, thứ tự nhận ba
   luật ontology mới).
4. **Phát hành `0.10.0`**, và trước hay sau thẻ ở điểm 1.
5. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí không có người
   duyệt); các mục ở mục 10 của thiết kế tổng quan.

### Theo kế hoạch

- **Bước E:** RS5a, khi DA3 đã nêu đường dẫn.
- **RS6:** đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- **RS10:** in nốt các dòng còn thiếu của mục 2.
- **Bước F:** RS4 và RS5b, khi delivery-loop chuyển nhà xong.
- **RS7 để lại:** luật viết trong đoạn văn hay trong bảng không phải mục danh sách, nên chưa có gì
  đòi loại của chúng; kho cài bằng `--adopt` chưa nhận mục «What holds these rules».
- **RS3 để lại:** đo lại «phút máy mỗi PR gộp» sau 10 PR; hai trường hợp bộ nhớ đệm chưa thấy.
- **Bộ kiểm chập chờn:** tìm và sửa ống gây ra lần đỏ ở mục 4, nếu lượt chạy lại xác nhận.
- **`CHANGELOG.md` là tệp nhiều PR cùng ghi.** Kho này dạy luật «mỗi tệp một người ghi» (RS2b) mà
  chưa áp cho chính mục `## Unreleased` của mình.
- `plugins/repo-setup/scripts/apply.py` dài 960 dòng (bản trước 930), quá giới hạn 800 dòng.

### Vệ sinh

- Mười hai nhánh đã gộp còn trên GitHub.
- Một worktree đã gộp: `.claude/worktrees/rule-kinds-design-1c073a` (nhánh `feat/rule-kinds`), thuộc
  phiên RS7. Hai phiên con còn mở: phiên RS7 (đang giữ thẻ) và phiên nâng `onehub-inventory` (đang
  chờ chủ kho).
- Tệp kế hoạch nâng `onehub-inventory` chưa commit, nằm trong checkout chung.

## 7. Đề xuất hạng mục tiếp tục

1. **Đưa `main` về xanh.** Đọc kết quả lượt chạy lại. Xanh thì ghi nhận là chập chờn và sửa ống gây
   ra nó; đỏ lại thì đây là lỗi thật của RS7 trên macOS và phải sửa trước mọi việc khác.
2. **Bấm thẻ phần cuối `AGENTS.md`, rồi mới phát hành `0.10.0`.** Lý do như lần RS3: sửa trước khi
   phát hành thì không phải ghi một trường hợp «phải gỡ tay» vào bản ghi phát hành. Nên nâng kho thử
   lên bản có RS7 trước khi gắn tag.
3. **Đi tiếp `onehub-inventory`:** gộp design-assembly#38, ký Gate 2 cho PR 88, rồi tách sổ từng PR.
   Đây là nơi cho số đo thật của cả bước D: 548 phút máy mỗi PR gộp và 64% lượt chạy lúc PR chưa thể
   gộp. Lợi ích lớn nhất chỉ tới khi PR ở kho đó được mở ở dạng bản nháp.
4. **RS6**, một gói nhỏ không chờ ai: ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
5. **`CHANGELOG.md` thành mảnh**, nếu chủ kho muốn kho này tự áp luật mình dạy. Đây là gói mới,
   chưa có trong kế hoạch.
