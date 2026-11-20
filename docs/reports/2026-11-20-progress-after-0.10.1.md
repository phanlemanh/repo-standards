# Tổng kết sau 0.10.1

Ngày 2026-11-20. Phạm vi: từ `main` tại `bc31175` (commit gộp RS7, cuối phạm vi của bản trước) đến
`main` tại `b2cb544` (commit gộp bản `0.10.1`). Kế hoạch được chấm theo
[thiết kế tổng quan ba kho](../three-repo-overview-design.md), mục 7 và các bước A đến F ở cuối mục 8.
Bản trước: [tổng kết sau RS7](2026-11-18-progress-after-rs7.md). Mục 8 ghi việc làm sau phạm vi
này, tới `main` tại `c1dbe05`.

## 1. Tóm tắt

- Từ bản trước: 8 PR đã gộp (36 đến 43), 12 commit, 17 tệp đổi, thêm 714 dòng, bỏ 36 dòng.
- **Hai bản phát hành:** `0.10.0` (RS7 và ba bản sửa) và `0.10.1` (một bản sửa đường nâng cấp). Cả
  hai có tag, có bản phát hành trên GitHub, và CI trên `main` xanh ở commit gộp.
- **Bước E: RS7 xong**, đã phát hành và đã chạy trên kho thử. RS5a vẫn chờ design-assembly.
- **Ba trong năm việc «chủ kho quyết» của bản trước đã xong:** thẻ phần cuối `AGENTS.md` đã làm
  (PR 40), `0.10.0` đã phát hành sau thẻ, và `onehub-inventory` đã lên `0.9.0`. Còn mở: câu nói quá
  trong `55-autonomy.md`, và Phát hiện 5.
- **`main` xanh lại và xanh suốt:** lần đỏ ở `bc31175` qua ở lượt chạy lại; từ đó không lượt nào
  trên `main` đỏ. Nguyên nhân lần đỏ đó vẫn chưa tìm ra.
- **Một lỗi mới, tìm ra và sửa trong cùng ngày:** nâng kho thử từ tag `0.10.0` thì cả tệp `AGENTS.md`
  nằm giữa dấu xung đột. Gốc là nhãn phiên bản của các bản dựng nằm giữa hai tag (mục 3). `0.10.1`
  sửa trường hợp đó; phần còn lại ghi là lỗ hổng đã biết.
- **Sau phạm vi (mục 8):** kho thử đã lên `0.10.1` (PR 21 đã gộp). Các mối nối với design-assembly
  và delivery-loop đã được rà trên cả hai phía; hai lỗi ở phía kho này đã sửa (PR 44, đã gộp, chưa
  phát hành).

## 2. Đã thực hiện

### Kế hoạch tới nay

| Bước | Gói  | Mục tiêu                                                       | Trạng thái                                     |
| ---- | ---- | -------------------------------------------------------------- | ---------------------------------------------- |
| A    | RS1  | Tường thật: quét bí mật, «Release», ô khuôn commit, ruleset    | Xong, phát hành ở 0.6.0                        |
| A    | RS9  | Kho giữ luật tên tiếng Anh                                     | Xong                                           |
| B    | RS2a | `wiki/log.md` gộp kiểu hợp                                     | Xong, phát hành ở 0.6.0                        |
| B    | RS10 | Thước luồng lặp lại được                                       | Một phần: in khoảng nửa số dòng của mục 2      |
| C    | RS8  | Bản sửa của mẫu tới được tệp đã sửa tại chỗ; `doctor` báo lệch | Xong ở 0.7.0; thêm một bản sửa ở 0.10.1        |
| D    | RS2b | Sổ thành mảnh; PR không mang tệp dẫn xuất                      | Xong, phát hành ở 0.8.0, đã đo trên kho thử    |
| D    | RS3  | CI xếp tầng, một ô tổng luôn chạy                              | Xong, phát hành ở 0.9.0, đã đo trên kho thử    |
| E    | RS7  | Mỗi luật của `AGENTS.md` có phép kiểm hoặc ghi «giữ bằng lời»  | **Xong, phát hành ở 0.10.0, đã chạy ở kho thử** |
| E    | RS5a | Tường cho biên thiết kế                                        | Chưa thiết kế; chờ DA3 nêu đường dẫn           |
| F    | RS4  | Bản đồ phạm vi                                                 | Hoãn: chưa có bên đọc                          |
| F    | RS5b | Khe uỷ quyền trong `governance/`                               | Hoãn tới khi delivery-loop đọc được            |
| —    | RS6  | Nguyên tắc 1, 2 và 5 vào `setup-principles.md`, kèm bài kiểm   | Chưa làm                                       |

Bước A đến E đã xong, trừ RS5a (chờ kho khác) và phần còn thiếu của RS10. Bước F hoãn có chủ đích.

### Từ bản trước

| PR  | Commit gộp | Việc                                                                                              |
| --- | ---------- | ------------------------------------------------------------------------------------------------- |
| 36  | `d50674b`  | Bản tổng kết sau RS7                                                                              |
| 37  | `45521b8`  | `conventional-commits` chấm theo hook commit-msg của chính kho, không gọi một hook theo tên        |
| 38  | `7b0e6d3`  | README ghi git 2.38 trở lên (`sdlc_metrics.py` dùng `git merge-tree --write-tree`)                |
| 39  | `cc6390c`  | Tài liệu trỏ tới delivery-loop, kho kế nhiệm Acceptance Gate Kit                                  |
| 40  | `eaea3af`  | Luật riêng ở cuối `AGENTS.md` gộp được với mục «What holds these rules», không còn dấu xung đột    |
| 41  | `614514d`  | Phát hành `0.10.0`                                                                                |
| 42  | `f134e6a`  | Đường nâng cấp thử mẫu của plugin đang chạy trước, nên tệp do bản dựng giữa hai tag ghi tìm được gốc |
| 43  | `b2cb544`  | Phát hành `0.10.1`                                                                                |

**PR 37** đến từ `onehub-inventory`: sau khi lên `0.9.0`, ô `conventional-commits` đỏ ở mọi PR, vì kho
đó thay hook `conventional-pre-commit` bằng hook riêng. Ô nay chạy cả tầng commit-msg, nên hook nào
`git commit` chạy ở kho đó thì hook đó chấm. Kho có hook mà không hook nào từ chối thông điệp nào vẫn
đỏ, vì một ô xanh mà không chấm gì thì không phải tường.

**PR 40** là thẻ mà bản trước chờ chủ kho bấm. Khi gộp cả tệp cần dấu xung đột, tệp được gộp làm hai
phần, tách ở tiêu đề của mục: phần trước và chính mục đó. Mục của plugin luôn ở cuối, nên thứ tự là
một luật chứ không phải một phán đoán, và không cần ai gỡ tay. Lượt soát độc lập so cách gộp cũ và
mới trên 6.000 ca ngẫu nhiên: 309 ca từ `marked` thành `merged`, không ca nào mất dòng, không ca nào
có tiêu đề hai lần, không ca nào sạch trước đó bị đổi kết quả.

**PR 42**, xem mục 3.

### Kho thử (`design-ci-probe`)

| PR  | Việc                                                                                              | Trạng thái           |
| --- | ------------------------------------------------------------------------------------------------- | -------------------- |
| 20  | Nâng lên `main` tại `eaea3af` (RS7 và PR 40), với một mục riêng ở cuối `AGENTS.md` để thử đúng ca | Đã gộp, cả 8 ô xanh  |
| 21  | Nâng lên tag `0.10.1`                                                                             | Đã gộp, cả 8 ô xanh  |

PR 20 gộp sạch: `AGENTS.md` xếp `merged`, không có dấu, mục riêng giữ nguyên chỗ, mục của plugin ở
cuối. Đối chứng: cùng cây đó chạy bằng bản trước PR 40 (`cc6390c`) thì thoát mã 1 và `AGENTS.md`
có một chỗ đánh dấu.

PR 21 chỉ đổi `.repo-setup.json`: ba tệp đã sửa tại chỗ xếp `edited` vì mẫu không đổi, 97 tệp không
đổi, mọi tệp nay ghi `0.10.1`. `make check` xanh ở máy, gồm 13 bài đơn vị và 18 bài trình duyệt.

## 3. Phát hiện: nhãn phiên bản của bản dựng giữa hai tag

- **Thấy ở đâu:** nâng kho thử từ tag `0.10.0` thì toàn bộ `AGENTS.md` nằm giữa dấu xung đột (nhãn
  «no matching base») và lượt chạy thoát mã 1, dù mẫu của tệp đó không đổi.
- **Vì sao:** PR 20 nâng kho thử từ `main` trước khi gắn tag, lúc `plugin.json` còn ghi `0.9.0`. Mọi
  commit giữa hai tag mang cùng số phiên bản của bản trước, nên manifest ghi `AGENTS.md` thuộc `0.9.0`
  với mã băm của một mẫu mà `0.9.0` không có. Đường tìm gốc chỉ đọc bản được ghi và các bản cũ hơn,
  không bản nào khớp, nên nó gộp hai chiều với gốc rỗng.
- **Đã sửa (PR 42, phát hành ở `0.10.1`):** mẫu của plugin đang chạy được thử trước, dựng theo lựa
  chọn cũ của kho; mã băm khớp thì đó là gốc. Bài 47n đỏ 7 chỗ trước khi sửa. Trên bản sao kho thử,
  bản sửa cho mã thoát 0 và `AGENTS.md` xếp `edited`.
- **Còn hở:** nếu mẫu của một tệp đổi thêm lần nữa giữa bản dựng đó và tag kế, tệp vẫn không có gốc.
  CHANGELOG ghi điều này và dặn: nâng từ tag.
- **Bài học cho quy trình:** kho thử từng được nâng từ `main` để thử trước khi gắn tag. Cách đó chính
  là thứ gây ra lỗi. Thử trước khi gắn tag vẫn nên làm, nhưng làm trên bản sao, và chỉ nâng kho thật
  từ tag. Một hướng gốc hơn ở mục 7.

## 4. Kiểm chứng

| Phép kiểm                                                  | Kết quả                                                                           |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------- |
| CI «Test plugin» trên `main` tại `bc31175`, lượt chạy lại   | Qua                                                                               |
| CI trên `main` tại 8 commit gộp sau đó, tới `b2cb544`       | Qua cả 5 ô ở mỗi commit; `e2e` trọn bộ, 20 đến 29 phút                            |
| CI trên PR 36 đến 43                                        | Qua cả 5 ô                                                                        |
| `bash tests/run.sh` trên đầu nhánh PR 40, 41, 42, 43, ở máy | Qua, «All tests passed.»                                                          |
| `e2e` tại `614514d`: ca nâng python xuất phát từ            | `repo-setup-v0.10.0` (tag đã có trước khi ca chạy)                                |
| `e2e` tại `b2cb544`: ca nâng python xuất phát từ            | `repo-setup-v0.10.0`: tag `0.10.1` được đẩy sau khi lượt này chạy xong            |
| Kho thử, PR 20: CI                                          | Qua cả 8 ô                                                                        |
| Kho thử, PR 21: `make check` ở máy; CI                      | Qua; CI qua cả 8 ô                                                                |

Chưa kiểm được:

- Ca nâng của `e2e` xuất phát từ `0.10.1`: lượt trên `main` tại `b2cb544` chạy trước khi có tag.
  Lượt tại `c1dbe05` (sau PR 44) đang chạy lúc viết; nó là lượt đầu tiên có tag `0.10.1`.
- `conventional-commits` mới trên `onehub-inventory`, nơi lỗi được tìm ra. Kho đó còn ở `0.9.0`, và
  ô này vẫn đỏ ở đó: lượt gần nhất (nhánh `chore/split-log-ledger`, 2026-11-19) báo «No hook with id
  `conventional-pre-commit` in stage `commit-msg`».
- Một lần chuyển từ starter lên team trên kho thật có luật riêng trong `AGENTS.md`.
- Còn từ trước: hai lượt cùng lưu một khoá đầu vào; một PR dùng lại khoá do nhánh chính lưu; pipeline
  `github-agents` trên GitHub; CodeQL trên kho công khai sau nâng cấp.

## 5. Số đo luồng

Đo bằng `tools/sdlc_metrics.py --days 16` trên chính kho này, cửa sổ từ 2026-11-04 (cùng ngày bắt đầu
với bản trước, nên hai cột so được với nhau).

| Dòng                                | Bây giờ                               | Bản trước                             |
| ----------------------------------- | ------------------------------------- | ------------------------------------- |
| PR đã gộp                           | 43                                    | 35                                    |
| Trung vị từ mở đến gộp              | 0,7 giờ                               | 0,7 giờ                               |
| Lâu nhất từ mở đến gộp              | 14,9 giờ                              | 14,9 giờ                              |
| Gộp nhánh chính vào nhánh PR        | 7 trên 43 PR, 5 xung đột khi phát lại | 6 trên 35 PR, 4 xung đột khi phát lại |
| Phút máy CI                         | 2.445,8 trong 103 lượt                | 1.774,2 trong 82 lượt                 |
| Phút máy mỗi PR gộp                 | 56,9                                  | 50,7                                  |
| Đỏ trên nhánh chính («Test plugin») | 5 trên 46                             | 5 trên 38                             |
| Revert                              | 0                                     | 0                                     |

- Không lượt đỏ mới trên `main`: 8 lượt mới, cả 8 xanh.
- Phút máy mỗi PR tăng. 5 trong 8 PR mới đổi mã, mẫu hay số phiên bản của plugin (37, 40, 41, 42,
  43), nên `e2e` trên PR chạy trọn bộ. PR 36, 38 và 39 chỉ đổi tài liệu.
- Lần đẩy lên `main` sau mỗi lần gộp chạy `e2e` trọn bộ, cả khi PR chỉ đổi tài liệu: commit gộp
  PR 36 tốn 29 phút `e2e`. Cách dùng lại kết quả của RS3 (`HEAVY_NOT_INPUTS`) chỉ áp cho PR. Với
  một PR chỉ đổi tài liệu, phần lớn phút máy của nó nằm ở lượt trên `main` này.
- `CHANGELOG.md` nay đứng đầu danh sách tệp gây xung đột khi gộp ngược, với 3 lần.
- Từ RS3 (PR 29) đã có hơn 10 PR gộp, nên phép so «phút máy mỗi PR gộp» trước và sau RS3 làm được,
  nhưng chưa làm. Công cụ chưa tách số theo mốc.

## 6. Còn lại

### Chủ kho quyết

1. **Mối nối với hai kho kia (mục 8):** lưu cách gộp vào `governance/autonomy.yaml` hay giữ cờ
   `--merge-method`; và có gửi các đề xuất ở mục 8 sang design-assembly và delivery-loop không.
2. **Đưa `0.10.1` tới `onehub-inventory`.** Bản sửa `conventional-commits` được tìm ra ở đó mà kho đó
   chưa có; ô này đang đỏ ở mọi PR của kho đó. Đi kèm các quyết định còn lại của kế hoạch nâng: PR tách
   sổ thứ hai, PR 83 trước hay sau nó, design-assembly 0.7.2, ruleset, PR ở dạng bản nháp, ba luật
   ontology mới.
3. **Câu nói quá trong `55-autonomy.md`:** «the gate sees both and raises the tier» có ở cả kho không
   cài `github-agents`, nơi không có cổng nào thấy. Sửa câu này là đổi điều mọi kho được dặn.
4. **Số phiên bản của bản dựng giữa hai tag** (mục 3 và mục 7): một quyết định về cách đánh số.
5. Còn từ trước: Phát hiện 5 (môi trường `production` trên kho riêng tư gói miễn phí không có người
   duyệt); các mục ở mục 10 của thiết kế tổng quan.

### Theo kế hoạch

- **Bước E:** RS5a, khi DA3 đã nêu đường dẫn.
- **RS6:** đưa ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
- **RS10:** in nốt các dòng còn thiếu của mục 2, và tách số theo mốc để so trước và sau một gói.
- **Bước F:** RS4 và RS5b, khi delivery-loop chuyển nhà xong.
- **RS7 để lại:** luật viết trong đoạn văn hay bảng chưa bị đòi loại; kho cài bằng `--adopt` chưa nhận
  mục «What holds these rules»; text đặt ngay trước mục đó vẫn gặp mảnh mới thêm ở cuối luật.
- **RS3 để lại:** phép so phút máy sau 10 PR; hai trường hợp bộ nhớ đệm chưa thấy; `e2e` trọn bộ
  trên `main` sau một PR chỉ đổi tài liệu (mục 5). Bỏ lượt đó là đổi `test.yml`, tức đổi luật chơi
  của kho này, nên chủ kho quyết.
- **Bộ kiểm chập chờn:** lần đỏ ở `bc31175` chưa có nguyên nhân; nghi một ống `printf | grep`.
- **`CHANGELOG.md` là tệp nhiều PR cùng ghi**, nay là nguồn xung đột số một.
- `plugins/repo-setup/scripts/apply.py` dài 961 dòng, quá giới hạn 800 dòng.

### Vệ sinh

- 16 nhánh trên GitHub ngoài `main`, nhánh nào cũng đã gộp.
- Một worktree còn lại: `.claude/worktrees/rule-kinds-design-1c073a`, nay đứng ở nhánh
  `docs/point-to-delivery-loop` (đã gộp). Nhánh cục bộ đã gộp: `claude/nostalgic-poitras-9a0669`,
  `feat/rule-kinds`, `fix/shadcn-dev-dependency`. Không còn phiên con nào mở.
- Tệp kế hoạch nâng `onehub-inventory` vẫn chưa commit, nằm trong checkout chung.
- Kho thử: hai PR của dependabot (15, 19) còn mở; PR 2 và 3 là ca thử cố ý, để mở.

## 7. Đề xuất hạng mục tiếp tục

1. **Đọc lượt CI trên `main` tại `c1dbe05`.** Kho thử đã ở `0.10.1`. Lượt này là lượt đầu có ca
   nâng của `e2e` xuất phát từ `0.10.1`; xanh thì đường nâng từ bản mới nhất có chứng cứ ở cả hai nơi.
2. **Nâng `onehub-inventory` lên `0.10.1`.** Đây là nơi một ô bắt buộc đang đỏ ở mọi PR vì lỗi đã có
   bản sửa. Cũng là nơi cho số đo thật của bước D (548 phút máy mỗi PR gộp, 64% lượt chạy lúc PR chưa
   thể gộp). Nên làm cùng PR tách sổ thứ hai, theo thứ tự chủ kho chọn.
3. **Cho bản dựng giữa hai tag một số phiên bản riêng.** Ví dụ `main` ghi `0.10.2.dev0` ngay sau khi
   phát hành `0.10.1`, hoặc manifest ghi kèm commit của plugin. Khi đó tệp do bản dựng giữa hai tag ghi
   không còn mang tên một bản phát hành không chứa nó, và lỗ hổng còn lại ở mục 3 đóng hẳn. Đây là gói
   mới, chưa có trong kế hoạch, và đổi cách đánh số nên cần chủ kho quyết.
4. **RS6**, một gói nhỏ không chờ ai: ba nguyên tắc vào `setup-principles.md`, kèm bài kiểm.
5. **`CHANGELOG.md` thành mảnh**, để kho này tự áp luật «mỗi tệp một người ghi» mà nó dạy. Gói mới,
   chưa có trong kế hoạch.

## 8. Sau phạm vi: mối nối với design-assembly và delivery-loop

Làm ngày 2026-11-20, sau `b2cb544`. Hai PR đã gộp: PR 21 ở kho thử (lên tag `0.10.1`, commit gộp
`45a6eec`) và PR 44 ở kho này (commit gộp `c1dbe05`, nằm dưới `## Unreleased`).

Cách rà: đọc cả hai phía của từng mối nối, trên bản mới nhất của design-assembly (plugin 0.16.0),
delivery-loop (`8baa836`) và `onehub-inventory` (kho có cả ba), rồi chạy thử hai trường hợp ở phía
kho này. Không kho nào khác bị sửa.

**Kết luận.** Mỗi công cụ chạy được khi thiếu hai công cụ kia. Chỗ lệch nằm ở các mối nối ngầm: một
cái tên chung hay một quy ước không ghi ở đâu. Mối nối có tên rõ và có đường lui thì khớp.

| Mối nối                                       | Bên định nghĩa    | Đồng bộ                                                                  |
| --------------------------------------------- | ----------------- | ------------------------------------------------------------------------ |
| `-include mk/*.mk`, `CHECK_TARGETS`           | Kho này           | Khớp ở design-assembly 0.16.0; `onehub` còn bản 0.7.1, phải chèn chữ tạm |
| `tools/design-assembly/affected.mjs --json`   | design-assembly   | Khớp từng khoá; thiếu tệp hay trả lỗi thì chạy mọi bài                   |
| `DERIVED_TARGETS`, `DERIVED_FILES`            | Kho này           | Lệch: design-assembly không dùng, chỉ nối riêng vào `test`               |
| `ontology/`                                   | Kho này           | Khớp phần lớn; design-assembly đọc `status: planned`, kho này viết `later` |
| Ô CI tên `gate`                               | Cả hai            | Va tên; đã sửa phần của kho này (PR 44)                                  |
| Cách gộp PR                                   | Kho này           | Lệch: mặc định squash, delivery-loop cần merge commit; lựa chọn không lưu |
| Khuôn commit và tên PR                        | Kho này           | Lệch: delivery-loop tự ghi commit theo khuôn riêng                       |
| `.claude/settings.json`                       | Kho này           | Khớp: delivery-loop gộp theo khoá                                        |
| Khe `proof.check`, `_acceptance/**`           | Kho này           | Khớp; không nêu tên sản phẩm nào                                         |
| `.repo-setup.json` và manifest của bên kia    | Mỗi bên một tệp   | Không trùng tệp nào                                                      |

**Đã sửa ở kho này (PR 44).**

- `gate` chỉ là tên ô của setup khi kho có `pr-pipeline.yml`. Trước đó, kho không có pipeline agent
  mà khai `required_checks: [gate]` thì bị từ chối với câu «is required already», trong khi không gì
  bắt buộc ô đó. `onehub` đang để ô của delivery-loop mang tên này.
- Kho có tệp riêng nằm đúng chỗ một tệp `mk/` nối phép kiểm vào `make check`, mà không tệp nào của
  kho nối các phép kiểm đó, thì lượt cài thoát mã 1 và nêu tên chúng. Trước đó nó thoát mã 0: thử
  với `mk/design.mk` riêng và lớp `design` thì `design-guards` và `ui-floor` không bao giờ chạy.
- Mục 51 mới của bộ kiểm (`tests/seams.sh`) đỏ 15 chỗ trước khi sửa. Lượt soát độc lập nêu ba điểm
  mức vừa, đều đã sửa kèm bài kiểm đỏ trước.

**Còn lại ở kho này.**

- Cách gộp không được lưu: chạy `github_setup.py` mà quên `--merge-method merge` thì kho quay về
  squash. Lưu vào `governance/autonomy.yaml` là đổi luật chơi, nên chủ kho quyết.
- Không bài kiểm nào chạy mối nối thật: phía này thử `ui_select.mjs` với một `affected.mjs` giả.
  design-assembly còn nhận 16 phép kiểm sàn thiết kế của kho này bằng cách dò chuỗi, nên đổi một
  câu chữ ở đây là bên kia mất một phép kiểm mà không ai biết. Đề xuất: một trang hợp đồng mối nối
  (tên biến make, tên ô CI, dạng JSON của `affected`, các chuỗi dấu) kèm một mục bộ kiểm ghim chúng,
  và một ca `e2e` cài design-assembly thật.
- Còn hở sau PR 44: `Makefile` riêng của kho nằm chỗ `Makefile` của setup vẫn là xung đột thường;
  kho có pipeline agent và một ô khác tên `gate` vẫn có hai ô báo dưới một tên.

**Đề xuất gửi sang hai kho kia** (mỗi việc chờ chủ kho cho phép ở kho đó):

- design-assembly: thêm `DERIVED_TARGETS += design-derived`, để tầng nặng trên checkout sạch có tệp
  dẫn xuất mà không phải nối tay; đổi phép dò `ontology/glossary.md` sang thư mục mảnh; đóng giới
  hạn «chưa ai gọi affected», nay đã cũ.
- delivery-loop: đặt tên ô là `acceptance-gate` như sách hướng dẫn của nó; chỉ chờ ô bắt buộc thay
  vì mọi ô (nó đang chờ cả `e2e-db`); ghi một chỗ ánh xạ T1/T2/T3 với low/medium/high; sửa tài liệu
  ranh giới còn ghi kho này «luôn squash» và đo ở bản 0.5.0.
- Một chỗ ngược nguyên tắc bớt người: `t3_paths` của `onehub` gồm `tools/**`, `mk/**` và `Makefile`,
  nên mỗi lần nâng repo-setup đều cần hồ sơ có chữ ký người.
- Lệch với [trang ranh giới](../three-repo-boundaries.md): delivery-loop không đọc `ontology/` hay
  `wiki/`, và kế hoạch chuyển nhà của nó ghi là không bê hai sổ đó vào.

Chưa kiểm được: mối nối `affected` chạy thật trên một kho (chưa kho nào có đủ hai bên ở bản mới);
hai bản sửa của PR 44 trên `onehub-inventory`; trạng thái ruleset của `onehub`.
