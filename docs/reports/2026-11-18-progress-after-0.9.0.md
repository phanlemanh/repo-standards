# Tổng kết sau 0.9.0

Ngày 2026-11-18. Phạm vi: từ `main` tại `1d84368` (commit gộp RS3, cuối phạm vi của bản trước) đến
`main` tại `5205c16` (commit gộp bản `0.9.0`). Kế hoạch được chấm theo
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và các bước A đến F ở cuối mục 8. Bản trước: [tổng kết sau 0.8.0 và RS3](2026-11-18-progress-after-rs3.md).

## 1. Tóm tắt

- Từ bản trước: 3 PR đã gộp (30, 31, 32), 6 commit, 5 tệp đổi, thêm 249 dòng, bỏ 12 dòng. Trên kho
  thử `design-ci-probe`: 2 PR (16 gộp, 17 đóng không gộp).
- **Bước D xong hẳn.** RS2b phát hành ở `0.8.0`, RS3 phát hành ở `0.9.0`, và cả hai đã đo trên kho
  thử. Bốn bước A, B, C, D đã phát hành; chỉ còn nửa sau của RS10 ở bước B.
- **Sáu phép thử của RS3 trên kho thử đều đạt**, chạy trước khi phát hành, theo đề xuất của bản
  trước.
- **RS3 có tác dụng ngay trên kho này:** PR chỉ đổi tài liệu chạy `e2e` trong 4 đến 13 giây, so với
  24 đến 29 phút trước RS3.
- Bản `0.9.0` đã phát hành: tag `repo-setup-v0.9.0` trên `5205c16`, bản phát hành trên GitHub.
- Hai phiên con đã xong được lưu trữ; ba worktree và bốn nhánh cục bộ đã gộp được dọn.
- Bộ kiểm nhanh trên `5205c16` qua hết, 58 mục.

## 2. Đã làm

| PR  | Commit gộp | Việc                                                                                                         |
| --- | ---------- | ------------------------------------------------------------------------------------------------------------ |
| 30  | `7e8a1b5`  | Bản tổng kết sau `0.8.0` và RS3                                                                              |
| 31  | `cd5bc1b`  | Ghi sáu phép thử của RS3 vào thiết kế tổng quan và vào mục RS3 của CHANGELOG                                 |
| 32  | `5205c16`  | Phát hành `0.9.0`: «Verified», «Known gaps», nâng số bản; tag `repo-setup-v0.9.0`, bản phát hành trên GitHub |

**Kho thử `design-ci-probe`:**

- **PR 16:** nâng từ tag `repo-setup-v0.8.0` (sổ đã tách) lên `main` của kho này tại `7e8a1b5`. Không
  tệp nào bị đánh dấu; `make check` xanh. Đây là lần đầu `quick`, `heavy` và `check` chạy trên GitHub,
  và cả ba xanh.
- **PR 17**, sáu phép thử ở mục 8 của thiết kế RS3, mỗi phép thử một commit:

| Phép thử                                    | `quick` | `heavy`                                            | `check`      |
| ------------------------------------------- | ------- | -------------------------------------------------- | ------------ |
| 1. Lỗi kiểu, `quick` cố ý đỏ                | đỏ      | bỏ qua                                             | đỏ           |
| 2. Sửa lỗi, cây vẫn khác `main`             | xanh    | chạy thật, 1 phút 43 giây; ghi lượt xanh, lưu khoá | xanh         |
| 3. Commit chỉ đổi `docs/`                   | xanh    | xanh sau 6 giây, nêu lượt và commit của phép thử 2 | xanh         |
| 4. Commit đổi mã                            | xanh    | chạy lại thật, 1 phút 55 giây                      | xanh         |
| 5. Huỷ tay lúc `make check-heavy` đang chạy | xanh    | huỷ                                                | đỏ           |
| 6. Bản nháp, rồi chuyển sang sẵn sàng       | xanh    | bỏ qua, rồi chạy thật khi sẵn sàng                 | đỏ, rồi xanh |

Lời của `check` nói rõ từng trường hợp: tầng trước chưa qua, bị huỷ, hay PR là bản nháp, «chưa tới
lượt». Ở phép thử 6, một đầu nhánh có hai lượt `check`, một đỏ một xanh. GitHub tính lượt mới nhất,
nên ô bắt buộc `check` của kho thử không chặn PR.

**Dọn:**

- Lưu trữ hai phiên con đã xong: phiên bước D (RS2b, RS3) và phiên sửa `package.json`.
- Gỡ ba worktree đã gộp (`github-setup-merge-style-a16ed8`, `ledger-fragments`, `tiered-ci`). Trước
  khi gỡ đã kiểm: chỉ còn bộ nhớ đệm, đầu nhánh đã nằm trong `main`.
- Xoá bốn nhánh cục bộ đã gộp. Checkout giờ chỉ có `main`.

## 3. Đối chiếu kế hoạch

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                      |
| ---- | ---- | -------------------------------------------------------------- | ----------------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                         |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                            |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                         |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2       |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong, phát hành ở 0.7.0                         |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | Xong, phát hành ở 0.8.0, đã đo trên kho thử     |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | **Xong, phát hành ở 0.9.0, đã đo trên kho thử** |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | Chưa thiết kế                                   |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn            |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                           |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được             |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm                                        |

Phần cấu trúc của kế hoạch, bốn bước A đến D, đã xong. Bước kế là E, và chưa có thiết kế. Bước F
chờ delivery-loop.

## 4. Kiểm chứng

| Phép kiểm                                                   | Kết quả                                                                                                                                              |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bash tests/run.sh` trên `main` tại `5205c16`, hôm nay      | Qua: 58 mục, «All tests passed.»                                                                                                                     |
| CI «Test plugin» trên `main` tại `7e8a1b5`                  | Qua cả 5 ô; `e2e` đủ tổ hợp, 30 phút                                                                                                                 |
| PR 30, 31, 32: CI                                           | Qua cả 5 ô                                                                                                                                           |
| CI «Test plugin» trên `main` tại `5205c16`, sau khi gắn tag | Qua cả 5 ô; `e2e` 27 phút 19 giây, gồm «upgrade-python-from-repo-setup-v0.9.0 (marked: [])» và «upgrade-ts-node-from-repo-setup-v0.7.0 (marked: [])» |
| Kho thử: PR 16 và sáu phép thử ở PR 17                      | Đạt cả sáu (mục 2)                                                                                                                                   |

Chưa kiểm được:

- Hai lượt cùng lưu một khoá đầu vào, và một PR dùng lại khoá do nhánh chính lưu.
- Phép so «phút máy mỗi PR gộp» của `sdlc_metrics.py` sau 10 PR gộp dưới RS3 (spec RS3, mục 8).
- Một lần nâng từ `0.9.0` lên bản sau.
- Còn từ trước: `claude-code-action` có chuyển nguyên `claude_args` hay không; pipeline
  `github-agents` trên GitHub; CodeQL trên kho công khai sau nâng cấp.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 14` trên chính kho này, cửa sổ từ 2026-11-04.

| Dòng                                | Bây giờ                               | Bản trước                             |
| ----------------------------------- | ------------------------------------- | ------------------------------------- |
| PR đã gộp                           | 32                                    | 29                                    |
| Trung vị từ mở đến gộp              | 0,8 giờ                               | 0,8 giờ                               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                              | 14,9 giờ                              |
| Gộp nhánh chính vào nhánh PR        | 5 trên 32 PR, 3 xung đột khi phát lại | 5 trên 29 PR, 3 xung đột khi phát lại |
| Phút máy CI                         | 1.602,3 trong 76 lượt                 | 1.457,2 trong 70 lượt                 |
| Phút máy mỗi PR gộp                 | 50,1                                  | 50,2                                  |
| Đỏ trên nhánh chính («Test plugin») | 4 trên 34                             | 4 trên 31                             |
| Revert                              | 0                                     | 0                                     |

Thước 14 ngày chưa thấy RS3, vì gần như mọi PR trong cửa sổ chạy trước RS3. Số đo theo từng PR thì
thấy rõ. Ô `e2e` trên PR của kho này:

| PR  | Đổi gì                    | Trước hay sau RS3 | `e2e`           |
| --- | ------------------------- | ----------------- | --------------- |
| 25  | Một tệp trong `docs/`     | Trước             | 24 phút 27 giây |
| 27  | Một tệp trong `docs/`     | Trước             | 28 phút 48 giây |
| 30  | Một tệp trong `docs/`     | Sau               | 13 giây         |
| 31  | `docs/` và `CHANGELOG.md` | Sau               | 4 giây          |
| 26  | PR phát hành `0.8.0`      | Trước             | 24 phút 9 giây  |
| 32  | PR phát hành `0.9.0`      | Sau               | 27 phút 4 giây  |

PR phát hành vẫn chạy trọn bộ, vì nó đổi `plugin.json` và `marketplace.json`, là đầu vào của tầng
nặng. Hai ô `offline`, khoảng 2 và 3 phút, vẫn chạy ở mọi PR: chúng là tầng nhẹ.

## 6. Bài học

- **Một phép thử phải giữ cây khác với nhánh chính khi cần đo «chạy thật».** Ở phép thử 2, nếu chỉ
  xoá lỗi để cây trùng `main`, `heavy` sẽ dùng lại khoá do `main` lưu, và phép thử 2 với phép thử 3
  thành một. Commit sửa giữ lại một thay đổi mã thật.
- **`if: always()` là thứ làm phép thử 5 đạt.** Khi cả lượt chạy bị huỷ, GitHub vẫn chạy job có
  `always()`, nên `check` tự báo đỏ. Nếu `check` bị bỏ qua, GitHub tính ô bắt buộc là đạt.
- **Thứ tự «thử rồi mới phát hành» đã đáng.** Lần `0.8.0` phát hành trước, và kho thử tìm ra lỗi
  `package.json` sau đó. Lần này sáu phép thử chạy trước. Không có `0.9.1` nào phải ra vì một điều
  kho thử tìm được.
- **Tag được đẩy trước khi ô `e2e` của nhánh chính bắt đầu.** Ca nâng cấp vì thế đọc được `0.9.0` làm
  bản mới nhất ngay trên lượt gộp của PR phát hành, không cần chạy lại.

## 7. Còn tồn

### Chủ kho quyết

1. **Có đặt ruleset bắt buộc ô `check` trên `main` của kho này không** (thiết kế RS3, mục 9). Ô
   `check` đã có và đã chạy trên mọi PR từ PR 29. Không có ruleset, nó chỉ để đọc: PR vẫn gộp được
   khi `e2e` chưa chạy. Đây là đổi luật của kho.
2. **`dependency-audit` đỏ trên mọi kho `react-vite` có `design`.** Mẫu đặt `shadcn` ở
   `dependencies`, trong khi ứng dụng mẫu chỉ đọc nó lúc dựng. Ba hướng: chuyển sang `devDependencies`
   (phải kiểm lại bản dựng), chờ bản vá, hay chấp nhận ô đỏ (ô này không bắt buộc).
3. **Cho phép chạy trên `onehub-inventory` với `0.9.0`:** nâng một lần, rồi `split` từng sổ, mỗi sổ
   một PR, rồi đo lại bằng `sdlc_metrics.py`. Đây là nơi RS2b và RS3 có số đo thật lớn nhất: 548 phút
   máy mỗi PR gộp, 64% số lượt chạy lúc PR chưa thể gộp.
4. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí không có người
   duyệt); các mục ở mục 10 của thiết kế tổng quan.

### Theo kế hoạch

- Thiết kế bước E: RS7 trước, RS5a khi DA3 đã nêu đường dẫn.
- RS6: đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- RS10: in nốt các dòng còn thiếu của mục 2.
- Đo lại «phút máy mỗi PR gộp» khi đã có 10 PR gộp dưới RS3.
- Những gì RS3 để lại: hai trường hợp bộ nhớ đệm chưa thấy (mục 4); vài ống `printf | grep` ở mục 49
  có thể chập chờn; điều kiện chạy ca nâng cấp trong `e2e_select.py` chưa lần theo `extends`.
- `plugins/repo-setup/scripts/apply.py` dài 930 dòng, quá giới hạn 800 dòng.

### Vệ sinh

- Mười nhánh đã gộp còn trên GitHub: bảy nhánh cũ, cộng `feat/ledger-fragments`, `feat/tiered-ci` và
  `fix/package-json-key-merge`.
- Trên kho thử còn các nhánh cục bộ của những lần đo trước, trong bản sao ở thư mục nháp.

## 8. Đề xuất bước kế

1. Quyết ruleset bắt buộc `check` trên `main` của kho này. Đây là bước rẻ nhất để ô tổng của RS3
   thành tường thật ở chính kho dạy nó.
2. Khi chủ kho cho phép: nâng `onehub-inventory` lên `0.9.0`, `split` từng sổ, rồi đo lại. Số trước
   và sau ở đó trả lời câu hỏi lớn nhất của bước D: có bớt chờ và bớt phút máy thật không.
3. Thiết kế RS7, mở đầu bước E.
