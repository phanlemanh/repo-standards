# Thiết kế: tường thật (đợt 1)

Ngày: 2026-11-16. Trạng thái: đã dựng trên nhánh `claude/thiet-ke-tong-quan-ba-kho` cùng ngày, chờ chủ
kho xem; ba lựa chọn ở mục 6 dựng theo đề nghị của máy. Áp dụng cho plugin
`repo-setup`. Đây là gói RS1 của [thiết kế tổng quan](../../three-repo-overview-design.md); nguyên tắc
phải giữ xem [nguyên tắc của setup](../../setup-principles.md).

## 1. Ý định

Trên `onehub-inventory` có bốn ô mang tên một bức tường mà không giữ gì:

- `secret-scan` quét 0 byte và luôn xanh;
- «Release» đỏ sau mọi lần gộp (6 trên 6), nên màu đỏ trên nhánh chính mất nghĩa;
- ô tên PR kiểm một thứ không commit nào dùng, vì kho gộp bằng merge commit;
- ruleset chỉ bắt buộc 3 trên 9 ô, và `secret-scan` không nằm trong đó.

Cả bốn đều đi ra từ mẫu của plugin này. Gốc chung: chưa ô nào từng được thấy đỏ. Luật của đợt này:
**mỗi bức tường phải có một bài kiểm chiều đỏ**, tức một lần cố tình làm sai và thấy nó chặn.

## 2. Bốn thay đổi

### 2.1 Quét bí mật quét được

Hiện nay job chạy `pre-commit run gitleaks --all-files`. Móc `gitleaks` gọi
`gitleaks git --pre-commit --staged`: nó chỉ đọc phần đã stage, mà CI không stage gì.

Sửa:

- Mảnh `20-gitleaks.yaml` thêm một móc thứ hai cho CI, cùng kho móc và cùng phiên bản:

  ```yaml
  - id: gitleaks
    alias: gitleaks-history
    name: Detect hardcoded secrets in every commit of this branch
    entry: gitleaks git --redact --verbose --log-opts=HEAD
    stages: [manual]
  ```

- `security.yml` của ba preset gọi
  `pre-commit run gitleaks-history --hook-stage manual --all-files`.

Vì sao cách này: phiên bản gitleaks vẫn ghim ở một chỗ; `.gitleaks.toml` vẫn được đọc; không thêm
action của bên thứ ba. `--log-opts=HEAD` giới hạn vào lịch sử của chính nhánh đang kiểm.

Đã thử ngày 2026-11-16 trên một repo sinh từ preset `ts-node` mức team, gitleaks 8.30.1:

| Tình huống                                        | Lệnh cũ | Lệnh mới |
| ------------------------------------------------- | ------- | -------- |
| Repo sạch                                         | Xanh    | Xanh     |
| Token giả đã commit                               | Xanh    | Đỏ       |
| Tệp chứa token bị xoá ở commit sau                | Xanh    | Đỏ       |
| Token nằm ở nhánh khác, nhánh đang kiểm sạch      | Xanh    | Xanh     |

Dòng cuối là lý do có `--log-opts=HEAD`: không có nó, một nhánh rò sẽ làm đỏ mọi PR khác.

Hệ quả cần biết: bí mật đã vào lịch sử thì ô đỏ cho tới khi khoá được đổi và dấu vân tay của nó được
ghi vào `.gitleaksignore`. Đó là chỗ người quyết, đúng luật «người xuất hiện ở bí mật».

### 2.2 «Release» không đỏ khi chưa có khoá

Hiện nay `release.yml` dùng `secrets.RELEASE_PLEASE_TOKEN || github.token`. Khi chưa có khoá, nó lùi
về token của Actions, mà GitHub không cho Actions tạo pull request. `github_setup.py` chủ động tắt
quyền đó, vì nó cũng là quyền duyệt pull request. Kết quả: đỏ sau mọi lần gộp.

Sửa:

- Bỏ phần lùi về `github.token`.
- Bước release-please chỉ chạy khi có khoá. Chưa có thì job ghi một dòng vào phần tóm tắt
  («Releases are off: add the RELEASE_PLEASE_TOKEN secret») và kết thúc xanh.
- `github_setup.py` in một dòng khi kho có workflow release mà chưa có khoá. `doctor` báo hỏng
  cho đúng trường hợp đó, kèm cách sửa.

Không chọn: bật quyền cho Actions tạo pull request. Nó là cùng một công tắc với quyền duyệt, và bài
kiểm 43b đang cấm công tắc ấy.

Chưa thử trên GitHub thật: điều kiện theo sự có mặt của một secret.

### 2.3 Ô khuôn commit kiểm đúng thứ được dùng

Hiện nay `pr-title.yml` kiểm tên PR vì «PRs are squash-merged». Kho gộp bằng merge commit thì tên PR
không thành commit nào; skill `github` hiện bảo người tự sửa tệp này.

Sửa: workflow đọc cách gộp của kho lúc chạy, rồi kiểm thứ sẽ thật sự vào nhánh chính.

| Cách gộp đang bật     | Job                    | Kiểm gì                                                  |
| --------------------- | ---------------------- | -------------------------------------------------------- |
| Squash                | `conventional-title`   | Tên PR, như hiện nay                                     |
| Merge commit, rebase  | `conventional-commits` | Tiêu đề từng commit của PR, bằng móc commit-msg của kho  |

Job nào không áp dụng thì tự báo xanh kèm lý do, không bị bỏ qua. Câu bảo người sửa tay trong skill
`github` được gỡ.

Cả hai job chạy từ nhánh gốc và đọc pull request như dữ liệu: móc chấm commit lấy từ nhánh gốc,
không lấy từ pull request. Khi không đọc được cách gộp của kho thì tên PR vẫn được kiểm như cũ, còn
commit thì không.

Đã thử: móc `conventional-pre-commit` chấm được một thông điệp từ dòng lệnh, đúng cả hai chiều.

### 2.4 Ruleset bắt buộc đúng các ô kho khai

Hiện nay `github_setup.py` bắt buộc `check`, thêm `gate` khi có agent, thêm ô bằng chứng khi có. Có
hai lỗ:

1. `secret-scan` không bắt buộc.
2. Từ bản «người quyết, máy kiểm», ruleset đã có được cập nhật tại chỗ. Ô nào người thêm bằng tay,
   như `e2e` ở `onehub-inventory`, sẽ bị gỡ ở lần `--apply` kế tiếp mà không ai hay.

Sửa:

- `secret-scan` vào danh sách bắt buộc ở mức team, khi kho có một job mang đúng tên đó. Ô bắt
  buộc mà không job nào báo sẽ chặn mọi pull request.
- Khoá mới `required_checks` trong `governance/autonomy.yaml`: tên các ô của riêng kho.
  `github_setup.py` cộng chúng vào ruleset. Tên trùng với ô của setup thì bị từ chối, như
  `proof.check`.
- Trước khi cập nhật, `github_setup.py` so danh sách đang có với danh sách sắp đặt. Sắp gỡ một ô
  chưa khai thì nó in tên ô và dừng; muốn gỡ thật thì chạy kèm `--prune`. Lượt chạy thử in cùng
  lời cảnh báo đó, nên `doctor` không cần một phép so riêng.

Hai ô cố ý không bắt buộc:

- `dependency-audit` chấm thế giới chứ không chấm thay đổi: một lỗ hổng vừa công bố sẽ làm đỏ mọi
  PR không liên quan.
- `codeql`: kết quả nằm ở ô do ứng dụng của GitHub đăng; job này chỉ đỏ khi việc phân tích hỏng.

Cả hai vẫn chạy trên mọi PR, trên nhánh chính và theo lịch. Lệnh gộp của phiên điều phối vẫn đòi
mọi ô xanh, nên luật «gộp là phải xanh» không đổi.

Điều kiện của một ô bắt buộc: nó phải báo kết quả trên mọi pull request, kể cả của bot nâng thư
viện. Job bị bỏ qua thì GitHub tính là qua.

«GitHub không trả lời» không được coi là «không có». Không đọc được danh sách ruleset thì
`github_setup.py` dừng, không tạo ruleset thứ hai. Không liệt kê được secret thì nó nói vậy, không
báo «thiếu khoá». Secret do tổ chức chia cho kho cũng được tính.

## 3. Bài kiểm

`tests/run.sh`, mục 44 «tường thật», không cần mạng:

- 44a. `security.yml` của ba preset gọi `gitleaks-history` với `--hook-stage manual`; mảnh móc không
  có `--staged` và có `--log-opts=HEAD`.
- 44b. Chiều đỏ: trên một repo sinh ra, chạy đúng lệnh của móc với một token giả đã commit và thấy
  đỏ; repo sạch thì xanh. Máy không có `gitleaks` thì bài này tự báo bỏ qua, có tên.
- 44c. `release.yml` không còn lùi về `github.token`; bước release có điều kiện theo khoá;
  `github_setup.py` và `doctor` báo khi thiếu khoá.
- 44d. `pr-title.yml` có hai job và mỗi job đọc cách gộp của kho.
- 44e. `plan()`: mức team bắt buộc `secret-scan`; `required_checks` của kho được cộng vào; tên
  trùng bị từ chối; hai tệp dry-run mẫu sinh lại.
- 44d chạy thật bước kiểm commit với `gh` và móc giả: commit sai khuôn thì đỏ và nêu tên commit,
  kho chỉ squash thì không chấm, không đọc được cách gộp thì có cảnh báo.
- 44f. `github_setup.py` không gỡ ô chưa khai khi thiếu `--prune`; có `--prune` thì nêu tên ô bị gỡ.
- 44g. Khi `gh` không trả lời: không tạo ruleset, không báo «thiếu» secret.
- 44h. Tên rỗng dưới `required_checks` bị từ chối; kho không có job `secret-scan` thì ô đó không
  bắt buộc và công cụ nói rõ.

`tests/e2e.sh`, cần mạng: chạy lệnh CI thật qua pre-commit với token cấy.

## 4. Gãy khi nâng cấp

- `secret-scan` có thể đỏ ngay lần đầu ở repo mà lịch sử đã có thứ giống bí mật.
- Sau `github_setup.py --apply`, `secret-scan` thành ô bắt buộc.
- Repo đã tự bật quyền cho Actions tạo pull request sẽ ngừng mở PR phát hành cho tới khi thêm
  `RELEASE_PLEASE_TOKEN`.
- Thêm ô mới `conventional-commits` trên mọi PR.
- `github_setup.py --apply` dừng thay vì gỡ một ô bắt buộc chưa khai.

## 5. Không dựng ở đợt này

- CI xếp tầng và chia song song: gói RS3.
- Bắt buộc cả chín ô: để ở mục 10 của thiết kế tổng quan.
- Sửa thẳng `onehub-inventory`: kho đó nhận thay đổi khi chạy lại phần setup.
- Quét rò ở nhánh khác, hay đổi công cụ quét.

## 6. Đã có người thứ hai đọc

Một agent đọc lại mã độc lập ngày 2026-11-16. Không có lỗi nghiêm trọng. Một lỗi mức cao (báo
«thiếu khoá» khi không liệt kê được secret) và năm lỗi mức trung đã sửa, mỗi lỗi kèm một bài kiểm ở
44d, 44g, 44h. Để lại, có chủ ý:

- Bí mật chỉ xuất hiện trong phần gỡ xung đột của một merge commit thì lệnh quét không thấy, vì
  merge commit không có diff riêng.
- Ba bài 44a, 44c và phần còn lại của 44d chỉ dò chữ trong tệp workflow; hành vi của chúng trên
  GitHub chưa được chạy.
- Bước kiểm commit gọi GitHub một lần cho mỗi commit, và GitHub chỉ trả tối đa 250 commit của một
  pull request.

## 7. Câu hỏi cho chủ kho

1. `secret-scan` bắt buộc, còn `dependency-audit` và `codeql` thì không: đúng chưa?
2. «Release»: bỏ phần lùi về token của Actions và đòi khoá riêng: đúng chưa?
3. Tên khoá `required_checks` trong `governance/autonomy.yaml`: dùng được chưa?
