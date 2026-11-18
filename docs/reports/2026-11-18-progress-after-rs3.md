# Tổng kết sau 0.8.0 và RS3

Ngày 2026-11-18. Phạm vi: từ `main` tại `b6cfa81` (bản tổng kết trước) đến `main` tại `1d84368`
(commit gộp RS3). Kế hoạch được chấm theo [thiết kế tổng quan ba kho](../three-repo-overview-design.md),
mục 7 và các bước A đến F ở cuối mục 8. Bản trước:
[tổng kết trước khi phát hành 0.8.0](2026-11-18-progress-before-0.8.0.md).

## 1. Tóm tắt

- Từ bản trước: 5 PR đã gộp (25 đến 29), 23 commit, 32 tệp đổi, thêm 2.223 dòng, bỏ 112 dòng. Trên
  kho thử `design-ci-probe`: 4 PR (10 đến 13).
- **Bước D đã dựng xong.** RS2b phát hành ở `0.8.0` và đã đo trên kho thử: hai PR song song gộp nối
  nhau bằng nút của GitHub, không cần «Update branch», không chung tệp nào. RS3 đã gộp (PR 29), chưa
  phát hành, chưa đo trên kho thử.
- **Phép đo trên kho thử tìm ra một lỗi thật:** khi một kho Node nâng lên `0.8.0`, `package.json` bị
  đánh dấu. PR 28 đã sửa: `package.json` giờ gộp theo khoá. Bản sửa nằm ở `## Unreleased`.
- **`main` đỏ một lần, ngay sau khi gắn tag `0.8.0`.** Bài `e2e` nâng cấp từ «bản phát hành mới
  nhất», và từ lúc có tag thì bản đó đã ở dạng mảnh. PR 28 sửa luôn chỗ này; `main` xanh lại từ
  `7e6176c`.
- `## Unreleased` có một thay đổi phá vỡ (RS3, `feat(ci)!`), nên bản kế là `0.9.0`.
- Bộ kiểm nhanh trên `1d84368` qua hết, 58 mục. CI trên `main` tại `1d84368` đang chạy lúc viết.

## 2. Đã làm

| PR  | Commit gộp | Việc                                                                                                         |
| --- | ---------- | ------------------------------------------------------------------------------------------------------------ |
| 25  | `6a64ea5`  | Bản tổng kết trước khi phát hành `0.8.0`                                                                     |
| 26  | `6c33213`  | Phát hành `0.8.0`: «Verified», «Known gaps», nâng số bản; tag `repo-setup-v0.8.0`, bản phát hành trên GitHub |
| 28  | `7e6176c`  | `package.json` gộp theo khoá khi nâng cấp; `e2e` nhận ra bản phát hành đã có mảnh                            |
| 27  | `a786b22`  | Ghi kết quả đo RS2b trên kho thử vào mục 7 của thiết kế tổng quan                                            |
| 29  | `1d84368`  | RS3: CI xếp tầng                                                                                             |

**Kho thử `design-ci-probe`** (chủ kho cho phép ngày 2026-11-18):

| PR  | Việc                                                      | Kết quả                                                                                      |
| --- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| 10  | Nâng từ bản dựng thay `0.6.1` lên tag `repo-setup-v0.8.0` | 10 tệp cập nhật, 10 tệp mới, 3 tệp bị đánh dấu và gộp tay; `make check` xanh                 |
| 11  | `make split` bốn sổ, mỗi sổ một commit                    | Mỗi lần tách so khớp từng mục trước và sau                                                   |
| 12  | Nhánh A: một `make log`, một `add-term`, một trang wiki   | Gộp trước                                                                                    |
| 13  | Nhánh B, mở cùng lúc với A, từ cùng một gốc               | Sau khi A gộp, vẫn `MERGEABLE` dù đi sau nhánh chính 4 commit; gộp không cần «Update branch» |

**RS3** gồm:

- Ba ô trong `ci.yml` của mọi preset. `quick` chạy mọi lần đẩy. `heavy` chạy khi `quick` xanh và PR
  không phải bản nháp; khi đầu vào trùng một lượt đã xanh, nó xanh ngay và nêu lượt, commit được dùng
  lại. `check` luôn chạy, đỏ khi một tầng không xanh, và phân biệt «bản nháp, chưa tới lượt» với
  «hỏng».
- Ba lệnh mới: `ci_inputs.py` (khoá đầu vào), `ci_verdict.py` (luật của ô tổng), `ui_select.mjs` (bài
  trình duyệt chỉ chạy các màn bị chạm; có điều gì không chắc thì chạy trọn bộ). Mục 49 của bộ kiểm
  giữ phần này, ở tệp riêng `tests/tiered_ci.sh`.
- `test.yml` của chính kho này theo cùng khuôn: `e2e` chỉ chạy các tổ hợp mà thay đổi chạm tới
  (`tests/e2e_select.py`), và có ô tổng `check`.
- Một số đo trước khi dựng, [tầng nặng lặp lại một lượt xanh bao nhiêu](2026-11-18-heavy-reuse-measure.md):
  ở `onehub-inventory`, 12,4% số lượt lúc `gate` đỏ dùng lại được một lượt tầng nặng đã xanh, tức
  13,1% số phút tầng nặng. Con số không gần 0 nên đáng dựng, nhưng nhỏ hơn nhiều so với 64% số lượt
  chạy lúc `gate` đỏ, đúng như spec đoán.
- Mỗi việc có một bên soát độc lập, cuối cùng soát cả nhánh. Bốn lỗi thật được tìm ra và đã sửa
  trước khi gộp, trong đó có lỗi một lượt `heavy` đỏ bị ghi là xanh rồi được lượt sau dùng lại.

## 3. Đối chiếu kế hoạch

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                               |
| ---- | ---- | -------------------------------------------------------------- | -------------------------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                                  |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                                     |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                                  |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2                |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong, phát hành ở 0.7.0                                  |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | **Xong: phát hành ở 0.8.0, đã đo trên kho thử**          |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | **Đã gộp (PR 29)**; chưa phát hành; chưa đo trên kho thử |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | Chưa thiết kế                                            |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn                     |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                                    |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được                      |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm                                                 |

Bốn bước đầu đã dựng xong. A, B (trừ phần còn lại của RS10) và C đã phát hành. Bước D còn phát hành
RS3 và sáu phép thử của RS3 trên kho thử. Bước E là bước kế theo kế hoạch, và chưa có thiết kế.

## 4. Kiểm chứng

| Phép kiểm                                                           | Kết quả                                                                          |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main` tại `1d84368`, hôm nay              | Qua: 58 mục, «All tests passed.»                                                 |
| CI «Test plugin» trên `main` tại `6c33213` (gộp `0.8.0`)            | Đỏ ở `e2e`: «shape log is not one-file after the upgrade from repo-setup-v0.8.0» |
| CI «Test plugin» trên `main` tại `7e6176c` và `a786b22`             | Qua cả 4 ô                                                                       |
| PR 29: CI trên `78c2da9`                                            | Qua cả 5 ô, kể cả `check` mới; `e2e` đầy đủ 29 phút                              |
| CI «Test plugin» trên `main` tại `1d84368`                          | Đang chạy lúc viết: `validate`, hai ô `offline` đã xanh, `e2e` đang chạy         |
| Kho thử: `make check` sau nâng cấp và sau `split`, ở máy và trên CI | Xanh                                                                             |
| Kho thử: CI trên nhánh chính sau khi gộp PR 12 và 13                | «CI» xanh; «Security» đỏ ở `dependency-audit` (mục 6)                            |

Chưa kiểm được:

- Sáu phép thử của RS3 trên kho thử (mục 8 của thiết kế RS3). Chỉ ở đó mới kiểm được phạm vi bộ nhớ
  đệm, lần khôi phục trúng khoá và hai lượt ghi cùng khoá. Khuôn `ci.yml` mới của các preset chưa chạy
  trên GitHub lần nào.
- `claude-code-action` có chuyển nguyên `claude_args` hay không; pipeline `github-agents` trên
  GitHub; CodeQL trên kho công khai sau nâng cấp. Ba điều này còn từ `0.8.0` trở về trước.
- Bài `App.test.tsx` của tổ hợp `react-vite` có `design` từng đỏ hai lần trong `e2e` trên nhánh RS3,
  rồi xanh khi chạy riêng và xanh trong `e2e` đầy đủ sau khi gộp `main`. Chưa rõ nguyên nhân.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 14` trên chính kho này, cửa sổ từ 2026-11-04.

| Dòng                                | Bây giờ                               | Bản trước             |
| ----------------------------------- | ------------------------------------- | --------------------- |
| PR đã gộp                           | 29                                    | 24                    |
| Trung vị từ mở đến gộp              | 0,8 giờ                               | 1,0 giờ               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                              | 14,9 giờ              |
| Gộp nhánh chính vào nhánh PR        | 5 trên 29 PR, 3 xung đột khi phát lại | 2 trên 24, 1 xung đột |
| Phút máy CI                         | 1.457,2 trong 70 lượt                 | 1.106,0 trong 58 lượt |
| Phút máy mỗi PR gộp                 | 50,2                                  | 46,1                  |
| Đỏ trên nhánh chính («Test plugin») | 4 trên 31                             | 3 trên 26             |
| Revert                              | 0                                     | 0                     |

- Phút máy mỗi PR tăng, vì mọi PR hôm nay đều chạy `e2e` trọn bộ, kể cả PR chỉ có tài liệu. RS3 của
  kho này có hiệu lực từ `1d84368`; số sau RS3 chỉ đo được ở bản tổng kết kế tiếp.
- Ba lần gộp ngược có xung đột: hai ở `docs/three-repo-overview-design.md`, một ở `CHANGELOG.md`.
  Hai tệp này do nhiều PR cùng ghi. Đây chính là loại tệp RS2b nhắm tới, nhưng RS2b mới chỉ áp cho
  kho dùng plugin, chưa áp cho chính kho này.
- Lần đỏ thứ tư trên nhánh chính là `6c33213` (mục 4).

## 6. Bài học

- **Một bài kiểm đọc «bản phát hành mới nhất» đổi nghĩa đúng lúc gắn tag.** Không dòng mã nào đổi mà
  `main` đỏ. PR 28 sửa bằng cách đọc hình dạng của bản phát hành (có `mk/derived.mk` hay không), và
  giữ một ca nâng cấp cố định từ tag `0.7.0`. Lần phát hành sau nên chạy lại `e2e` trên `main` ngay
  sau khi gắn tag, trước khi báo là xong.
- **Kho thử bắt được điều `e2e` không bắt được.** Ca nâng cấp của `e2e` chỉ chạy preset python, nên
  không chạm `package.json`. Kho thử có `npm install` thật, nên lộ ra hai thay đổi kề nhau thành xung
  đột. PR 28 thêm một ca nâng cấp Node vào `e2e`.
- **Thứ tự gộp tránh được một bản sửa trùng.** `e2e` của PR 27 đỏ cùng lỗi với `main`. Gộp PR 28
  trước rồi đưa `main` vào PR 27, thay vì vá trong PR 27, nên `tests/e2e.sh` chỉ có một bản sửa.

## 7. Còn tồn

### Chủ kho quyết

1. **Phát hành `0.9.0` trước hay chạy sáu phép thử của RS3 trên kho thử trước.** Đề xuất chạy thử
   trước. Lần `0.8.0`, kho thử tìm ra một lỗi chỉ sau khi đã phát hành. RS3 đổi khuôn CI của mọi
   preset và dùng bộ nhớ đệm của GitHub, là thứ chưa chạy lần nào. Cái giá: kho Node nâng lên `0.8.0`
   trong lúc chờ vẫn bị đánh dấu `package.json`. Kho thật duy nhất, `onehub-inventory`, chưa nâng lên
   `0.8.0`, nên cái giá đó hiện bằng 0.
2. **Cho phép chạy sáu phép thử của RS3 trên `design-ci-probe`.**
3. **Có đặt ruleset bắt buộc ô `check` trên `main` của kho này không** (thiết kế RS3, mục 9). Đây là
   đổi luật của kho. Có ô `check` mới từ PR 29, nhưng chưa có luật nào bắt buộc nó.
4. **`dependency-audit` đỏ trên mọi kho `react-vite` có `design`.** `npm audit --omit=dev` báo 8 lỗ
   hổng mức cao trong `shadcn` và các gói nó kéo theo. Mẫu đặt `shadcn` ở `dependencies`, nên
   `--omit=dev` không bỏ qua nó. Ứng dụng mẫu chỉ dùng `shadcn` lúc dựng, qua
   `@import "shadcn/tailwind.css"` trong `src/index.css`, mà Vite gộp vào bản dựng. Cần chọn: chuyển
   `shadcn` sang `devDependencies` (phải kiểm lại bản dựng), chờ bản vá của `shadcn`, hay chấp nhận ô
   đỏ (ô này không bắt buộc).
5. **Cho phép chạy trên `onehub-inventory`.** Đề xuất chờ `0.9.0`: nâng một lần, rồi `split` từng sổ,
   mỗi sổ một PR, rồi đo lại bằng `sdlc_metrics.py` để có số trước và sau.
6. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí không có người
   duyệt); các mục ở mục 10 của thiết kế tổng quan.

### Theo kế hoạch

- Thiết kế bước E: RS7 trước, RS5a khi DA3 đã nêu đường dẫn.
- RS6: đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- RS10: in nốt các dòng còn thiếu của mục 2.
- Những gì RS3 để lại: vài ống `printf | grep` ở mục 49 có thể chập chờn; điều kiện chạy ca nâng cấp
  trong `e2e_select.py` gắn với tên `python` và `fastapi`, chưa lần theo `extends`.
- `plugins/repo-setup/scripts/apply.py` dài 930 dòng, quá giới hạn 800 dòng.

### Vệ sinh

- Mười nhánh đã gộp còn trên GitHub: bảy nhánh cũ, cộng `feat/ledger-fragments`, `feat/tiered-ci` và
  `fix/package-json-key-merge`.
- Ba worktree đứng trên commit đã có trong `main`: `.claude/worktrees/ledger-fragments` (`7783041`),
  `.claude/worktrees/tiered-ci` (`78c2da9`) và `.claude/worktrees/github-setup-merge-style-a16ed8`, nay
  đang giữ nhánh `fix/package-json-key-merge` (`5c6e179`). Hai worktree đầu thuộc phiên bước D, worktree
  thứ ba thuộc phiên sửa `package.json`. Dọn được khi các phiên đó không còn việc.
- Trên kho thử còn bốn nhánh của lần đo nếu GitHub chưa tự xoá chúng khi gộp.

## 8. Đề xuất bước kế

1. Khi chủ kho cho phép: sáu phép thử của RS3 trên `design-ci-probe`, ghi kết quả vào thiết kế tổng
   quan như đã làm với RS2b.
2. Một PR phát hành `0.9.0`, với «Verified» và «Known gaps» theo khuôn của `0.8.0`, và chạy lại `e2e`
   trên `main` ngay sau khi gắn tag.
3. Thiết kế RS7, mở đầu bước E.
4. Khi chủ kho cho phép: nâng `onehub-inventory` lên `0.9.0`, `split` từng sổ, rồi đo lại.
