# Tổng kết trước khi phát hành 0.6.0

Ngày 2026-11-17. Phạm vi: từ tag `repo-setup-v0.5.0` (2026-11-11) đến `main` tại `9c32c39`.
Kế hoạch được chấm theo [thiết kế tổng quan ba kho](../three-repo-overview-design.md), các bước A
đến F.

## 1. Tóm tắt

- 10 PR đã gộp (8 đến 17), 79 commit, 115 tệp đổi, thêm 8.091 dòng, bỏ 262 dòng.
- Thứ tự Repo Standards: bước A (RS1, RS9) và bước B (RS2a, RS10) đã xong và đã chạy trên GitHub
  thật. Bước C (RS8) chưa thiết kế.
- Bộ kiểm nhanh trên `main` hôm nay qua hết: 55 mục, 557 phép kiểm `miss` (ở 0.5.0 là 207), 2.210
  dòng (ở 0.5.0 là 908).
- Cần làm trước khi phát hành: bỏ một đoạn CHANGELOG bị chép trùng, sửa hai câu «chưa chạy trên
  GitHub» đã cũ, rồi nâng số bản. Chi tiết ở mục 6.

## 2. Đã làm

| PR  | Nội dung                                                                      | Gói / bước       |
| --- | ----------------------------------------------------------------------------- | ---------------- |
| 8   | Tầng thiết kế và năng lực `design` cho `react-vite`                           | Trước kế hoạch   |
| 9   | Mỗi thực thể trả lời đủ tạo, truy vấn, sửa, xoá                               | Trước kế hoạch   |
| 10  | Kho nào trả lời câu hỏi UX nào (chỉ tài liệu)                                 | Trước kế hoạch   |
| 11  | Phạm vi «của tôi», quan hệ và thuộc tính tự trả lời                           | Trước kế hoạch   |
| 12  | Chọn cách gộp (`--merge-method merge`); mặc định vẫn squash                   | Trước kế hoạch   |
| 13  | «Người quyết, máy kiểm»: nguyên tắc, mục 43 của bộ kiểm, bỏ duyệt vì lệ       | Nền của kế hoạch |
| 14  | Tường thật (RS1) và thiết kế tổng quan ba kho; đổi tên bốn tài liệu (RS9)     | Bước A           |
| 15  | `wiki/log.md` gộp kiểu hợp (RS2a); thước luồng trong `sdlc_metrics.py` (RS10) | Bước B           |
| 16  | Ghi kết quả chạy thật ở kho thử `design-ci-probe`                             | Kiểm chứng A, B  |
| 17  | Phần tiếp của RS1: `codeql` xanh được; ô khuôn commit chặn gộp                | Bước A           |

Sáu bức tường trước đây đứng tên mà không giữ gì, nay đều giữ, và mỗi bức có bài kiểm làm nó đỏ.
Bốn bức thấy khi thiết kế RS1: quét bí mật quét 0 byte; «Release» đỏ sau mỗi lần gộp; ô tên PR
dựa vào squash; ruleset không bắt buộc `secret-scan`. Hai bức chỉ lộ ra khi chạy thật: `codeql`
không bao giờ xanh trên kho riêng tư, và ô khuôn commit không bắt buộc ở đâu cả.

## 3. Kiểm chứng

| Phép kiểm                                                 | Kết quả                                                                                                                                 |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main`                           | Qua: 55 mục                                                                                                                             |
| CI của PR 17 (`offline` Ubuntu, macOS, `validate`, `e2e`) | Qua; `e2e` phải chạy lại một lần vì npm gặp ECONNRESET                                                                                  |
| `bash tests/e2e.sh` ở máy, bản cuối của PR 17             | Qua                                                                                                                                     |
| Kho thử `design-ci-probe` (riêng tư, dựng từ 0.4.0)       | Quét bí mật đỏ đúng commit; commit sai khuôn bị chặn gộp; `codeql` tắt và xanh; «Release» xanh khi chưa có khoá; ruleset bắt buộc bốn ô |

Chưa kiểm được:

- Kho công khai sau khi nâng cấp: CodeQL còn phân tích không.
- Pipeline của `github-agents` trên GitHub (`gate`, tự gộp hạng thấp, tắt tự gộp khi PR lên hạng).
  Kho thử không cài phần này: nó chỉ có `ci`, `deploy`, `pr-title`, `release`, `security`.
- Đường nâng cấp với tệp đã sửa tại chỗ. Đây là RS8: hiện đường này bỏ sót bản sửa mà không báo.

## 4. Số đo luồng

Đo bằng chính `tools/sdlc_metrics.py --days 7` trên kho này. Cửa sổ 7 ngày gồm cả PR 5, 6 và 7,
gộp trước 0.5.0.

| Chỉ số                             | Giá trị                                      |
| ---------------------------------- | -------------------------------------------- |
| PR gộp                             | 13, không PR nào do agent mở                 |
| Thời gian mở đến gộp               | trung vị 1,6 h, dài nhất 14,9 h (PR 5)       |
| Gộp ngược nhánh chính vào nhánh PR | 2 lần, 1 lần xung đột khi phát lại           |
| Phút máy CI                        | 607 phút trong 30 lượt, 46,7 phút mỗi PR gộp |
| Đỏ trên nhánh chính                | 0 trên 12 lượt «Test plugin»                 |
| Revert                             | 0                                            |

Chỉ tính PR 8 đến 17: trung vị mở đến gộp khoảng 1,7 h. Ba PR lâu nhất là PR 9 (8,4 h), PR 17
(8,1 h) và PR 13 (5,6 h).

Cách đọc:

- Kho này chỉ có một người ghi và các phiên chạy nối tiếp, nên gần như không có xung đột. Thước
  luồng đáng đo nhất là ở `onehub-inventory` (mục 2 của thiết kế tổng quan: 93 trên 99 lần gộp
  ngược xung đột).
- 46,7 phút máy cho mỗi PR gộp phần lớn là `e2e`. Ở PR 17, lượt `e2e` xanh mất 23 phút, còn mỗi ô
  khác khoảng 1 phút. Đây là con số RS3 (CI xếp tầng) cần làm giảm.
- «Đỏ muộn» không đo được (`n/a`) vì kho này không có job `gate`. Lệnh ghi đúng là không đo, chứ
  không ghi 0.

## 5. Bài học

1. **Bộ kiểm với `gh` giả chứng minh được logic, không chứng minh được GitHub.** Trong một ngày,
   kho thử tìm ra năm điều mà hơn 500 phép kiểm ở máy không thấy: GitHub không theo `merge=union`;
   đường nâng cấp bỏ sót `src/index.css`; `codeql` đỏ mãi; ô khuôn commit không bắt buộc; môi
   trường `production` dựng không có người duyệt trên gói miễn phí. Nên coi một lượt chạy trên kho
   thử là một bước của mỗi lần phát hành, chứ không phải việc làm một lần.
2. **Mỗi bức tường phải đỏ được, và cũng phải xanh được.** Luật cũ chỉ đòi bài kiểm chiều đỏ. Một
   bức tường đỏ vô cớ (`codeql`, «Release» trước RS1) thì sẽ bị người ta bỏ qua hoặc tắt đi. Đó cũng
   là tường trên danh nghĩa, chỉ theo chiều ngược lại.
3. **Lỗi khó nhất nằm ở lúc không đọc được.** Lượt soát mã của PR 17 bắt được lỗi H1: không đọc
   được nhánh gốc thì các ô bắt buộc bị gỡ, hoặc lệnh dừng mà vẫn trả mã 0. PR 15 có cùng loại lỗi
   (danh sách lượt chạy bị cắt ở 1.000 thì báo thiếu). Cả hai giờ có bài kiểm. Luật «không đọc được
   thì nói không đọc được, không bao giờ coi là 0» nên thành mục kiểm cố định khi soát mã.
4. **Có thứ không máy nào giữ.** Đoạn «Fixes» của 0.5.0 bị chép lại vào `Unreleased` mà không phép
   kiểm nào đỏ. CHANGELOG hiện chỉ được giữ bằng lời.
5. **Ma sát của công cụ.** Hook chặn `--no-verify` bắt nhầm `head -n` trong lệnh có chữ «commit»;
   máy khởi động lại xoá thư mục tạm; mạng của máy chạy GitHub chập chờn một lần. Không cái nào làm
   hỏng kết quả, nhưng đều tốn một vòng.

## 6. Còn tồn

### Phải làm trước khi phát hành

1. Bỏ đoạn `### Fixes` cuối mục `Unreleased` trong `CHANGELOG.md` (dòng 281 đến 290). Đó là bản
   chép của mục Fixes ở 0.5.0.
2. Sửa các câu đã cũ trong `CHANGELOG.md`:
   - «People decide, machines check» viết «None of this has run against a real GitHub repository
     yet». Ruleset không cần duyệt và chủ mã theo `CODEOWNERS` nay đã chạy trên kho thử. Phần
     `gate` và tự gộp thì vẫn chưa chạy.
   - Kiểm lại các câu «Not built» và «not yet run» khác cho khớp mục 3 ở trên.
3. Nâng `0.5.0` lên `0.6.0` trong `plugins/repo-setup/.claude-plugin/plugin.json` và
   `.claude-plugin/marketplace.json`, đổi `## Unreleased` thành `## 0.6.0 — <ngày>`, rồi gắn tag
   `repo-setup-v0.6.0`.

### Chủ kho quyết

- Phát hiện 5: môi trường `production` trên kho riêng tư gói miễn phí không có người duyệt. Có ba
  cách: chỉ chạy production khi một người tự bấm chạy; tắt job; hoặc ghi vào «Chỗ còn hở» của
  nguyên tắc.
- Thứ tự: **đã quyết (2026-11-17), phát hành 0.6.0 trước**, để bước kế không kẹt. Lượt kiểm
  trước phát hành (nâng cấp từ tag, pipeline `github-agents`, luật ontology trên mô hình thật)
  không chạy; những gì chưa chạy được ghi ở mục «Verified» và «Known gaps» của CHANGELOG.

### Theo kế hoạch

| Bước | Gói       | Trạng thái                                                                                          |
| ---- | --------- | --------------------------------------------------------------------------------------------------- |
| C    | RS8       | Chưa thiết kế; là điều kiện trước khi chạy trên `onehub-inventory`                                  |
| D    | RS2b, RS3 | Chưa thiết kế; RS2b theo hướng DA1 của design-assembly                                              |
| E    | RS7, RS5a | Chưa thiết kế; RS5a chờ DA3                                                                         |
| F    | RS4, RS5b | Hoãn tới khi delivery-loop đọc được                                                                 |
| —    | RS6       | Ô trạng thái ghi «Làm cùng RS9», nhưng RS9 xong rồi mà ba nguyên tắc chưa vào `setup-principles.md` |
| —    | RS10      | Mới in khoảng nửa số dòng của mục 2                                                                 |

### Vệ sinh

- Bảy nhánh cũ trên GitHub đã gộp: `claude/github-setup-merge-style-a16ed8`,
  `claude/plugin-marketplace-preset-7a7427`, `claude/relations-and-attributes-1dd820`,
  `feat/design-layer`, `feat/entity-lifecycle`, `fix/boundaries-alias-and-server-door`,
  `release/0.5.0`.
- Một worktree cũ: `.claude/worktrees/github-setup-merge-style-a16ed8`.
- `docs/three-repo-boundaries.md` dòng 102 vẫn ghi phần quan hệ và thuộc tính là «chờ chủ kho xem».
  Phần này đã gộp ở PR 11.

## 7. Đề xuất bước kế

1. Một PR phát hành: sửa ba mục «Phải làm trước khi phát hành», bỏ dòng cũ ở
   `three-repo-boundaries.md`, nâng bản lên 0.6.0.
2. Sau khi gắn tag: nâng kho thử từ bản đã gắn tag (không phải từ `main`). Đó là ca thử thật đầu
   tiên cho RS8, và là lần đầu thấy được «lệch mấy bản».
3. Thiết kế RS8 (bước C), rồi mới chạy trên `onehub-inventory`.
