# Nguyên tắc của setup: người quyết, máy kiểm

Ngày: 2026-11-16. Trạng thái: chủ kho nêu tiêu chí và cho sửa cùng ngày. Luật 8 đến 10 thêm ngày
2026-11-20, lấy từ nguyên tắc 1, 2 và 5 của [thiết kế tổng quan ba kho](three-repo-overview-design.md),
mục 4 (gói RS6). Luật 11 thêm ngày 2026-11-22, theo [thiết kế việc ngoài kho](superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md)
chủ kho duyệt cùng ngày. Trang này nói thứ repo-setup sinh ra phải giữ điều gì. Việc nào ở kho nào xem [ranh giới ba kho](three-repo-boundaries.md).

## Ý định

Repo Standards sinh ra để vòng làm tính năng (delivery-loop, trước đây là Acceptance Gate Kit) chạy cùng
Claude Code hiệu quả hơn: ít lần người xuất hiện hơn, thời gian ngắn hơn, ít token hơn, mà vẫn tin
được. Người đứng ở biên.

## Phép thử

Một thành phần của setup **đúng** khi nó giúp không cần người mà máy vẫn làm đúng. Nó **sai** khi
kéo người vào để tăng độ tin cậy.

Ở mỗi chỗ có người, hỏi: người ở đây **quyết** hay **kiểm**?

- Quyết: ý định, đổi luật chơi, đưa ra production. Máy không thay được. Giữ.
- Kiểm: đọc lại để bắt lỗi. Máy làm rẻ hơn và kỹ hơn. Thay bằng máy. Chưa thay được thì ghi nó
  vào mục «Chỗ còn hở», không coi nó là thiết kế.

## Mười một luật

1. **Setup không dùng người làm người kiểm.** Độ tin cậy do máy tạo ra: check bắt buộc, luật nạp
   từ nhánh gốc, bằng chứng kiểm lại trước khi gộp.
2. **Người rời đi khi có bằng chứng máy thế chỗ, không rời trước.** Muốn mã sản phẩm tự gộp thì
   phải nêu tên check chứng minh nó.
3. **Chỉ một nơi quyết khi nào cần người: vòng làm việc.** Setup không thêm điểm dừng của riêng
   mình: không luật `ask`, không câu «xin duyệt trước khi làm», hạng của thay đổi không phải lý do
   dừng.
4. **Lớp chặn thì im lặng, và nằm ở nơi máy không tự gỡ được.** Ruleset, check bắt buộc, luật nạp
   từ nhánh gốc. Không chặn theo mẫu lệnh Bash: lách được, và làm máy đứng lại chờ người.
5. **Hạng high chỉ dành cho việc đổi luật chơi.** Không đoán rủi ro theo tên đường dẫn. Việc nới
   rào do máy phát hiện (bỏ test, nới `agent:`), lúc đó người mới quyết.
6. **Không trả token hai lần cho một phán xét.** Thay đổi đã có bằng chứng thì không chạy thêm
   agent review.
7. **Mỗi lớp trả lời một câu.** Máy được làm gì trong phiên: Claude Code. Việc đã đúng chưa: vòng
   làm việc. Cái gì vào nhánh chính: GitHub. Không lớp nào trả lời lại câu của lớp khác.
8. **Một phép kiểm, một chỗ.** Mỗi câu hỏi có đúng một chỗ trả lời. Phần của setup: tầng nhẹ trả lời
   «luật chơi có bị lách không» ở mọi lần đẩy; tầng nặng trả lời «có làm vỡ phần còn lại trên máy
   sạch không» khi PR rời bản nháp, và chỉ chạy lại khi đầu vào của nó đổi; một ô tổng `check` đứng
   cho cả hai, nên tầng bị bỏ qua không thành xanh. Câu «hàng có đúng hợp đồng của nó không» là của
   vòng làm việc, ở Máy: setup không trả lời lại.
9. **Mỗi tệp một người ghi.** Một vòng chỉ ghi vào chỗ của riêng nó: sổ chung thành mảnh, mỗi mục một
   tệp. Tệp tổng hợp là vật dẫn xuất: máy vẽ lại từ các mảnh, PR không mang nó. Sổ còn ở dạng một
   tệp thì gộp kiểu hợp, để hai nhánh cùng thêm một dòng không xung đột.
10. **Bậc thang thay người.** Mỗi việc đang dặn bằng lời rơi vào bậc cao nhất có thể: bỏ bằng cấu trúc,
    rồi luật trong mã, rồi uỷ quyền có biên, sau cùng mới là người quyết. Luật nào chưa có máy giữ
    thì ghi rõ là giữ bằng lời, không giả là đã có tường. Bậc uỷ quyền có biên chưa có trong setup
    (RS5b, chờ vòng làm việc đọc được).
11. **Việc ngoài kho: máy làm.** Người tạo khoá, nhập khoá và quyết. Cài đặt, biến và nơi chạy ứng dụng
    đi qua một công cụ; khoá chỉ nhập ở Terminal của người, không qua cuộc trò chuyện. Loại lệnh máy
    được chạy ngoài kho nằm trong `governance/` và nạp từ nhánh gốc, nên một lệnh chỉ chạy sau khi PR
    của nó đã gộp. Mã của chính công cụ thì chạy từ cây làm việc: xem «Chỗ còn hở».

## Người xuất hiện ở đâu

Danh sách đóng, tính trong phần repo-setup sinh ra. Các cổng của vòng làm việc thuộc về vòng đó.

| Khi nào | Người làm gì | Vai |
| --- | --- | --- |
| Pull request đổi luật chơi (hạng high) | Code owner duyệt | Quyết |
| Đưa ra production | Người duyệt môi trường `production` | Quyết |
| Đặt secret, cài GitHub App | Tự làm một lần | Quyết |
| Máy thấy rào bị nới: test bị bỏ, `agent:` nới ra | Gộp hoặc từ chối | Quyết |
| Chưa có bằng chứng máy (hạng medium mặc định) | Gộp | Kiểm: chỗ còn hở |

Ngoài bảng này, mỗi lần người bị gọi là một lỗi của setup. Sửa gốc của nó, không chấp nhận nó.

## Luật nằm ở đâu trong mã

| Luật | Nơi giữ | Bài kiểm (`tests/run.sh`, mục 43) |
| --- | --- | --- |
| 1 | `tools/github_setup.py`: ruleset không đòi approve nào; code owner chỉ ở file luật | 43b |
| 2 | `tools/autonomy.py`: `default: low` mà thiếu `proof.check` thì bị từ chối và tính là medium | 43c |
| 3 | `settings.json.tmpl` không có `ask`; `+AGENTS.md/55-autonomy.md` | 43g |
| 4 | `pr-pipeline.yml`: luật nạp từ nhánh gốc; job `gate` không checkout, đỏ khi không biết hạng; settings không có deny dạng `Bash(` | mục 30, 43f, 43g |
| 5 | `governance/autonomy.yaml.tmpl`: danh sách `high`; hai luật `*_raise_to`, so từng action với chính nó | 43a, 43d |
| 6 | `pr-pipeline.yml`: việc `review` bỏ qua khi chính sách có `proof.check` | 43f |
| 7 | Tự gộp theo hạng và check, không theo tên tác giả; chỉ tự gộp nhờ bằng chứng khi nhánh thật sự đòi check đó; pipeline không approve | 43f |
| 8 | `ci.yml` của mỗi preset: job `quick`, `heavy`, `check`; `tools/ci_inputs.py` (khoá đầu vào của tầng nặng), `tools/ci_verdict.py` (ô tổng) | 49a, 49d, 49e, 49f |
| 9 | `tools/ledgers.py` và `mk/derived.mk`: sổ thành mảnh, tệp vẽ ra không vào git; `.gitattributes`: `wiki/log.md merge=union` | 46a, 48c, 48f |
| 10 | `plugins/repo-setup/rule-checks.toml` và `scripts/rule_kinds.py`: mỗi luật của `AGENTS.md` sinh ra nêu máy giữ nó hoặc ghi «giữ bằng lời» | 50m, 50n |
| 11 | `tools/outside.py`: nạp `governance/outside.toml` và `ops/outside.toml` từ nhánh gốc; khoá chỉ đi qua đầu vào chuẩn của lệnh cất, từ một Terminal | 52b, 52c, 52d, 52e |

Đường dẫn tính từ `plugins/repo-setup/presets/_core/` và `capabilities/github-agents/`, trừ khi ghi
từ gốc kho. Mục 43k của bộ kiểm đỏ khi một luật không có hàng ở bảng này, hay một hàng nêu một mục
bộ kiểm không có.

## Hỏi trước khi gộp một thay đổi vào kho này

1. Thay đổi có thêm lần nào người phải xuất hiện không? Có thì người đó quyết hay kiểm?
2. Nếu là kiểm: máy nào làm thay được? Chưa có thì đã ghi vào «Chỗ còn hở» chưa?
3. Nó có thêm hộp hỏi, luật `ask`, hay một câu bảo máy dừng lại không?
4. Nó có làm một phán xét bị trả token hai lần không?
5. Rào mới có nằm ở chỗ máy tự gỡ được không?

Thêm một hàng vào bảng «Người xuất hiện ở đâu» là đổi nguyên tắc: chủ kho quyết.

## Số đo

- Số lần người xuất hiện mỗi pull request, tách theo lý do. Đích: thay đổi đã có bằng chứng là 0.
- Số hộp xin quyền mỗi đợt. Đích: 0.
- Token CI mỗi pull request.
- Đối trọng, để giữ chữ «vẫn tin được»: tỉ lệ đỏ khi kiểm chéo sau gộp, và tỉ lệ revert. Hai số
  này tăng thì sửa máy kiểm, không gọi người quay lại.

## Chỗ còn hở

- **Hạng medium mặc định.** Chưa nêu `proof.check` thì mã sản phẩm vẫn chờ một người gộp. Đó là
  người kiểm, giữ lại vì chưa có máy thế chỗ. Đóng lại bằng cách vòng làm việc báo một check
  bằng chứng trên mọi pull request, rồi nêu tên nó trong `governance/autonomy.yaml`.
- **Check bằng chứng phải chạy và báo trên mọi pull request**, kể cả pull request của bot nâng
  thư viện. Không báo thì pull request đó treo. Job bị bỏ qua thì GitHub tính là qua, nên check
  đó không được tự bỏ qua. Bên giữ check là vòng làm việc, theo luật «phép kiểm nối hai sổ đặt ở
  bên đọc».
- **Repo một chủ.** GitHub không cho tác giả tự duyệt pull request của mình, và không phân biệt
  người với agent dùng chung một danh tính. Pull request đổi luật do chính chủ mở chưa có đường
  gộp ngoài quyền quản trị. Chưa kiểm trên repo thật.
- **Hạng medium không có tường phía GitHub khi đường dẫn không có chủ.** Khi đã có bằng chứng,
  dòng `*` trong CODEOWNERS mất đi; một pull request lên medium vì bỏ một bài test thì pipeline
  không tự gộp, nhưng ai có quyền ghi, kể cả một agent chạy `gh pr merge`, vẫn gộp được khi các
  check xanh. Thứ giữ lại chỉ là câu «đừng tự gộp» trong `AGENTS.md`. Muốn đóng cần một check bắt
  buộc đỏ cho tới khi có người duyệt; chưa xây vì chưa thử được trên GitHub thật.
- **Quyền của bước tắt tự gộp chưa được thử.** Job `gate` cầm `contents: write` để tắt tự gộp cho
  pull request không còn low. Nếu GitHub vẫn từ chối, job đỏ và pull request đứng lại, không gộp
  sai.
- **`conftest.py` và các tệp cấu hình kiểm tra** vẫn ở hạng high. Tính năng Python chạm
  `conftest.py` khá thường. Chưa có máy phân biệt thêm fixture với tắt bài test.
- **Lớp agent trên GitHub chưa chạy với một phiên Claude thật.**
- **Luật 11 nạp dữ liệu từ nhánh gốc, còn mã thì chạy từ cây làm việc.** `tools/outside.py`,
  `tools/github_setup.py` và `tools/github_check.py` chạy bản trong cây làm việc, và hai công cụ sau
  đọc `governance/autonomy.yaml` của cây làm việc. Một nhánh sửa các tệp đó có thể đổi điều gì được
  tính là «đã đủ», và phiên chạy chúng không hiện hộp xin quyền (`Bash(python3 tools/:*)`). Hạng
  high của `tools/**` và `governance/**` giữ việc gộp, không giữ việc chạy trên nhánh: phần này giữ
  bằng lời.

## Nguồn

- Chủ kho, ngày 2026-11-16: «nếu việc setup giúp không cần người xuất hiện mà Claude Code vẫn
  hoạt động hiệu quả là đúng, còn nếu kéo con người vào để tăng sự tin cậy thì nó không phải là
  việc setup tốt».
- delivery-loop, `CLAUDE.md`: northstar «người về biên»; quyết định ngày 23/10 «đích là gộp được».
- delivery-loop, kế hoạch «hạt giống northstar từ đợt crm»: 12 trên 22 hồ sơ đã có chữ ký của
  người vẫn đỏ khi kiểm chéo sau gộp. Chữ ký không bắt được lỗi; bước kiểm chéo của máy bắt được.
