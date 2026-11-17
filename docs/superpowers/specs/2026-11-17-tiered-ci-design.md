# CI xếp tầng: tầng nặng chỉ chạy khi đầu vào của nó đổi, một ô tổng luôn chạy (RS3)

Ngày 2026-11-17. Gói RS3, bước D của [thiết kế tổng quan ba kho](../../three-repo-overview-design.md).
Trạng thái: chủ kho đã đồng ý phần mục đích và hình dạng trong buổi thảo luận cùng ngày, và cho gói
này sửa `.github/workflows/test.yml` của chính kho này. Cũng ngày đó, chủ kho chọn cách A ở mục 4
(chạy lại khi đầu vào đổi), sau khi người đọc bản nháp chỉ ra rằng chờ `gate` làm CI và vòng làm việc
chờ nhau. Bản viết này được chủ kho duyệt ngày 2026-11-17. Bản đi cùng:
[mỗi tệp một người ghi (RS2b)](2026-11-17-ledger-fragments-design.md).

## 1. Ý định

Phần lớn phút máy đổ vào lúc PR chưa thể gộp. Ở `onehub-inventory`, 64% số lượt chạy rơi vào lúc ô
`gate` đỏ, tức PR chưa thể gộp. Mỗi lượt như thế vẫn trả trọn `e2e` (trung vị 31 phút) và `e2e-db`
(30 phút), cộng lại 548 phút máy cho mỗi PR gộp. Ở kho này là 44,2 phút cho mỗi PR gộp, phần lớn là
`e2e` (khoảng 22 phút), chạy ở mọi lần đẩy, kể cả PR chỉ sửa tài liệu.

RS3 chia CI làm hai tầng. Tầng nhẹ chạy ở mọi lần đẩy. Tầng nặng chỉ chạy khi PR đã sẵn sàng, tức
là tầng nhẹ xanh, và khi đầu vào của nó đã đổi so với lần xanh trước. Một ô tổng luôn chạy giữ cho
tầng nặng không lọt khi bị bỏ qua: ô bị bỏ qua được tính là xanh, ở cả GitHub lẫn lệnh gộp của
delivery-loop.

Xong là:

- một lần đẩy không đổi đầu vào của tầng nặng (commit chữ ký, commit chỉ đổi hồ sơ hay tài liệu) thì
  không chạy lại tầng nặng, mà dùng lại kết quả xanh trước đó;
- tầng nặng bị bỏ qua thì ô tổng đỏ;
- ô trình duyệt chạy đúng các màn bị ảnh hưởng khi kho có lệnh của DA2;
- phút máy mỗi PR gộp ở kho này giảm, đo bằng `sdlc_metrics.py`.

## 2. Mục tiêu, không làm, phản mục tiêu

Mục tiêu:

- Khuôn CI của mọi preset có ba ô: tầng nhẹ, tầng nặng, ô tổng.
- Tầng nặng chờ tầng nhẹ, và chỉ chạy lại khi đầu vào của nó đổi so với lần xanh trước.
- Ô trình duyệt chọn bài theo `make design-affected` khi kho có lệnh đó.
- `test.yml` của kho này theo cùng khuôn, và chọn tổ hợp `e2e` theo tệp đổi.

Không làm:

- Không đổi việc `make check` chạy gì ở máy. Bớt phần chạy ở máy là DL3 của delivery-loop.
- Không sửa ô `gate` của kit nghiệm thu hay `ci.yml` của `onehub-inventory`. Kho đó nhận khuôn qua
  RS8 ở bước chạy trên kho đó.
- Không dùng hàng đợi gộp của GitHub (lý do ở mục 4).
- Không đổi ruleset của kho này: kho này chưa có ruleset nào (mục 9, câu 1).

Phản mục tiêu:

- Một PR gộp được mà tầng nặng chưa chạy trên đúng commit đó.
- Nhánh chính đỏ sau gộp nhiều hơn hôm nay (0 trên 29 lượt `CI` ở `onehub-inventory`).
- Một người phải bấm gì, gắn nhãn gì, hay chuyển PR khỏi bản nháp thì CI mới chạy.
- CI và vòng làm việc chờ nhau: CI chờ chữ ký, trong khi vòng chờ CI xanh rồi mới mời ký.
- Người phải ký lại vì tầng nặng chỉ chạy sau chữ ký rồi đỏ.
- Kho chưa có lệnh chọn màn bị bớt bài.

## 3. Hiện trạng

| Nơi | Hôm nay |
| --- | --- |
| Mẫu `ci.yml` (ts-node, react-vite kế thừa; python; claude-plugin) | Một job `check`: `make check`, rồi `npm run build` (Node) hay `make validate` (claude-plugin). `concurrency` huỷ lượt cũ của cùng nhánh |
| `make check` | Chạy `CHECK_TARGETS`. Capability `design` nối `ui-floor` (Playwright) vào đó, nên bài trình duyệt nằm trong `check` |
| `github_setup.py` | Bắt buộc `check`, `gate` (khi có github-agents), `secret-scan`, hai ô khuôn commit, các ô `governance/autonomy.yaml` khai, và ô bằng chứng `proof.check`. Không bỏ một ô bắt buộc cũ nếu không có `--prune` |
| `onehub-inventory` (`ci.yml` đã sửa tại chỗ) | Bốn job song song: `check` (3,4 phút), `e2e` (31), `e2e-db` (30), `gate` (kit nghiệm thu, đỏ tới khi có bằng chứng và chữ ký). Bắt buộc: `check`, `e2e`, `gate`. 0 trên 40 PR gần nhất là bản nháp |
| `test.yml` của kho này | `offline` (Ubuntu và macOS), `validate`, `e2e` (`tests/e2e.sh`, 12 tổ hợp cộng các preset lẻ, khoảng 22 phút), song song ở mọi lần đẩy và sau gộp. Không có ruleset: không ô nào bắt buộc. 3 trên 20 PR gộp gần nhất chỉ đổi tài liệu |
| design-assembly, DA2 (đã gộp, quyết định 0053) | `make design-affected --json` trả `all` (kèm lý do), `screens[]` (mã, đường dẫn, lý do, khổ màn) và `grep`: mẫu chọn bài có tên chứa đường dẫn màn. Bài không nêu màn nào là việc của bên chạy bài. Lệnh không bao giờ ghi |

## 4. Các cách đã cân

Câu cần trả lời là «PR sẵn sàng» nghĩa là gì, theo tín hiệu máy đọc được mà không cần người.

Một điều chặn cách đầu tiên được nghĩ tới. Ô `gate` của `onehub-inventory` đỏ cho tới khi có chữ ký.
Trong khi đó vòng làm việc của delivery-loop chờ CI xanh rồi mới mời ký («chờ CI xanh trước khi mời
ký chỉ là nhịp của vòng này», hợp đồng `phan-du-bo-cuc-moi-vong-ba`), và lệnh gộp đòi CI xanh trên
đúng đầu nhánh. Vòng chỉ mở PR khi hồ sơ đã `verified` (hợp đồng `ky-den-gop`, AC-10). Vì vậy phần
lớn 64% lượt chạy lúc `gate` đỏ là lượt sau khi chấm, trước và sau chữ ký, cộng các lần ghim lại.
Lượt trước khi mời ký cần tầng nặng thật; lượt của commit chữ ký thì không, vì nó chỉ đổi hồ sơ.

| Cách | Tín hiệu | Vướng | Chọn |
| --- | --- | --- | --- |
| **A. Tầng nặng chạy lại chỉ khi đầu vào của nó đổi** | Tầng nhẹ xanh; PR không phải bản nháp; khoá đầu vào khác mọi lần xanh trước đó của nhánh | Lượt trước khi mời ký vẫn trả tầng nặng một lần; lần đẩy chạy tầng nặng chậm thêm bằng thời gian tầng nhẹ | **Chọn** (chủ kho, 2026-11-17): nguyên tắc 3 của thiết kế tổng quan; không phụ thuộc kho nào |
| B. Tầng nặng chờ tầng nhẹ và một ô «sẵn sàng» như `gate` | Ô `gate` xanh | Hai bên chờ nhau: CI chờ chữ ký, vòng chờ CI. Nếu chữ ký có trước thì tầng nặng chỉ chạy sau đó, đỏ thì người ký lại. Muốn đúng phải tách phần trước chữ ký của `gate` thành ô riêng, việc của delivery-loop (DL3) | Không |
| C. Chỉ dựa vào bản nháp | PR chuyển khỏi bản nháp | 0 trên 40 PR của `onehub-inventory` là bản nháp; phải đổi cách delivery-loop mở PR | Không làm tín hiệu chính; giữ làm tín hiệu phụ, miễn phí |
| D. Nhãn «sẵn sàng» | Ai đó gắn nhãn | Một người hoặc một bên phải gắn; thêm một chỗ cần người | Không |
| E. Hàng đợi gộp của GitHub (`merge_group`) | Lúc PR vào hàng đợi | Không có cho kho riêng tư của tài khoản cá nhân; lệnh gộp của delivery-loop đã giữ việc xếp hàng | Không |

Với ô tổng, hai cách:

| Cách | Vướng | Chọn |
| --- | --- | --- |
| **Ô tổng giữ tên `check`**; tầng nhẹ đổi tên `quick`, tầng nặng là `heavy` | Tên `check` đổi nghĩa: từ «một job» thành «mọi tầng» | **Chọn**: tên ô bắt buộc không đổi, nên ruleset của mọi kho đã cài, `github_setup.py` và lệnh gộp không phải đổi gì |
| Ô tổng mang tên mới (`ci`) | Mọi kho đã cài phải chạy `github_setup.py --prune` để thôi bắt buộc `check`; quên thì PR treo chờ một ô không còn ai báo | Không |

## 5. Thiết kế cho khuôn của các preset

### 5.1 Hai tầng trong make

- `CHECK_TARGETS` giữ nghĩa «tầng nhẹ». Mọi tệp `mk/*.mk` đang `+=` vào đó vẫn ở tầng nhẹ, nên không
  tệp nào của kho dùng phải đổi.
- Biến mới `HEAVY_TARGETS`. Capability `design` chuyển `ui-floor` từ `CHECK_TARGETS` sang đây.
- `make check-quick`: chạy `CHECK_TARGETS`. `make check-heavy`: chạy `HEAVY_TARGETS`. `make check`:
  cả hai, như hôm nay. Ở máy không gì đổi.
- `HEAVY_TARGETS` rỗng thì `check-heavy` xanh và nói «no heavy checks».

### 5.2 Ba ô trong `ci.yml`

```text
quick ──▶ heavy ──▶ check (ô tổng, luôn chạy)
  │                   ▲
  └───────────────────┘
```

- **`quick`**: mọi lần đẩy. `make check-quick`, rồi bước dựng (`make build`, hay `make validate` ở
  claude-plugin).
- **`heavy`**, trên PR: chạy khi `quick` xanh và PR không phải bản nháp. Việc đầu tiên của nó là tính
  **khoá đầu vào**:
  - Khoá là băm của cây mã ở commit đó, trừ những đường dẫn đã khai là không phải đầu vào của tầng
    nặng.
  - Mặc định khuôn khai `docs/**`, `wiki/**`, `*.md` ở gốc, `_acceptance/**`.
  - Kho thêm hay bớt trong một danh sách ở đầu `ci.yml`. Đường dẫn không khai thì là đầu vào: không
    biết thì chạy.
  - Nếu một lượt `heavy` trước đó đã xanh với đúng khoá ấy, và kết quả đọc được từ nhánh này hay
    nhánh gốc, thì `heavy` xanh ngay, ghi vào tóm tắt «cùng đầu vào với lượt X ở commit Y», và không
    chạy bài nào.
  - Không thì nó chạy `make check-heavy`; xanh xong thì ghi lại khoá.
  - Nơi ghi khoá (bộ nhớ đệm của Actions, trạng thái commit, hay cách khác) là việc của người dựng.
    Điều bắt buộc: một PR không ghi được khoá cho nhánh gốc hay cho PR khác.
- **`heavy`**, sau gộp, trên nhánh chính: luôn chạy trọn bộ, không dùng lại khoá nào. Đó là lưới đỡ
  của nguyên tắc 4.
- **`heavy` luôn chạy tới cuối** khi điều kiện thoả, kể cả khi chọn không có bài nào hay dùng lại kết
  quả cũ. Khi đó nó xanh và ghi lý do. Vì vậy «bị bỏ qua» chỉ xảy ra khi tầng nhẹ đỏ hay PR là bản
  nháp, không bao giờ vì «không có gì để chạy».
- **`check`** (ô tổng): `if: always()`, chờ `quick` và `heavy`. Nó xanh chỉ khi cả hai có kết quả
  `success`. Bất kỳ kết quả nào khác của bất kỳ ô nào, kể cả `skipped` và `cancelled`, đều làm nó
  đỏ, kèm một dòng nói ô nào và vì sao.
  - PR là bản nháp: `check` đỏ. PR đó vốn chưa gộp được, nên không mất gì.
  - Lệnh gộp đòi mọi ô xanh, nên nó cũng bị chặn ở đây.
- **Ô `gate` của kit nghiệm thu** nằm ngoài khuôn và không dính vào `heavy`. Nó vẫn là ô riêng, chạy
  song song như hôm nay. Ở `onehub-inventory`, lượt trước khi mời ký chạy tầng nặng một lần. Commit
  chữ ký chỉ đổi `_acceptance/**`, nên dùng lại kết quả đó.
- `pull_request` thêm loại `ready_for_review`, để chuyển khỏi bản nháp là có lượt chạy mới.
- `concurrency` giữ nguyên: một lần đẩy mới huỷ lượt cũ của cùng nhánh.

### 5.3 Ô trình duyệt chọn bài

Việc này nằm ở `capabilities/design/starter/mk/design.mk`, chỗ kho này giữ lệnh chạy bài trình
duyệt:

- Trên PR, `ui-floor` gọi `node tools/design-assembly/affected.mjs --json` nếu kho có tệp đó
  (máy chọn). Không qua `make design-affected`, vì đích đó chỉ chuyển `FILES=` cho lệnh, không chuyển
  `--json`. Quyết định 0053 của design-assembly đặt lệnh này ở công cụ đã cài chính để CI của kho gọi
  được mà không cần plugin, nên gọi nó là «chỉ gọi design-assembly», đúng ranh giới. Lời đề nghị gửi
  kho đó: một biến `JSON=1` cho đích `make`, để sau này không phải biết đường dẫn.
  - Lệnh trả `all`: chạy trọn bộ, in lý do.
  - Lệnh trả danh sách màn: chạy các bài khớp `grep`, ở khổ màn của từng màn, cộng mọi bài không
    nêu màn nào.
  - Lệnh vắng, lỗi, hay trả thứ đọc không được: chạy trọn bộ. Không biết thì chạy hết.
- Trên nhánh chính và ở máy: luôn trọn bộ. Có một biến để buộc trọn bộ trên PR.
- Cách chạy «bài không nêu màn nào» với Playwright là việc của người dựng, với điều bắt buộc: không
  bài nào không nêu màn bị bỏ.

### 5.4 Bắt buộc trên GitHub

`github_setup.py` không đổi danh sách: `check` vẫn là ô bắt buộc, giờ là ô tổng. Sửa một điều: khi
một ô nằm sau ô tổng (`heavy`, hay `e2e` của một kho đã chuyển nó sang tầng nặng) đang là ô bắt
buộc, lệnh nói rằng ô đó có thể bị bỏ qua và bị tính là xanh, và chỉ `check` đứng thay được nó. Lệnh
không tự bỏ ô bắt buộc nào, đúng luật hiện có (`--prune`).

## 6. Thiết kế cho `test.yml` của kho này

Chủ kho đã cho đổi tệp này.

- **Tầng nhẹ**: `offline` (Ubuntu và macOS) và `validate`, như hôm nay.
- **Tầng nặng**: `e2e`, chờ `offline` và `validate`; trên PR chỉ khi không phải bản nháp; dùng lại
  kết quả theo khoá đầu vào như mục 5.2.
- **Chọn tổ hợp**: một lệnh mới, `tests/e2e_select.py`, đọc danh sách tệp đổi so với nhánh gốc và in
  giá trị cho biến `PRESETS` mà `tests/e2e.sh` đã nhận sẵn.

  | Tệp đổi | Tổ hợp chạy |
  | --- | --- |
  | Chỉ `docs/**`, tệp `*.md` ở gốc, `CHANGELOG.md` | Không tổ hợp nào: `e2e` xanh, ghi lý do |
  | `plugins/repo-setup/presets/<p>/**` | Mọi tổ hợp có preset `p`, hoặc preset kế thừa `p` (đọc `extends` trong `preset.toml`: đổi `ts-node` thì chạy cả `react-vite`) |
  | `plugins/repo-setup/capabilities/<c>/**` | Mọi tổ hợp có capability `c` |
  | Mọi thứ khác: `scripts/`, `presets/_core/`, `skills/`, `checklists/`, `tests/`, `.github/`, tệp lạ | Trọn bộ |

  Hai luật đứng trên bảng: tệp không xếp được thì trọn bộ; lệnh lỗi thì trọn bộ. Ca nâng cấp
  (`repo-setup-v0.6.0`) chạy khi chạy trọn bộ.
- **Sau gộp, trên nhánh chính**: `e2e` luôn trọn bộ.
- **Ô tổng `check`**, cùng luật với mục 5.2. Kho này chưa có ruleset, nên hôm nay ô tổng chỉ để
  đọc: không gì bắt nó là bắt buộc (mục 9, câu 1).

## 7. Bài kiểm

Mục 49 mới của `tests/run.sh`. Mỗi phép kiểm phải được thấy đỏ trên một bản bị đổi trước khi xanh.

| Phép kiểm | Thấy đỏ khi |
| --- | --- |
| Mẫu `ci.yml` của mọi preset có `quick`, `heavy`, `check`; `check` có `if: always()` và đỏ với mọi kết quả khác `success`, kể cả `skipped` | Bỏ `always()`; coi `skipped` là xanh |
| `heavy` trên PR chờ `quick` | `heavy` chạy khi `quick` đỏ |
| Khoá đầu vào: đổi một tệp `_acceptance/**` hay `docs/**` thì khoá giữ nguyên; đổi một tệp mã, tệp khoá thư viện hay một tệp không khai thì khoá đổi | Tính khoá trên cả cây; bỏ một tệp mã khỏi khoá |
| Trên nhánh chính, `heavy` không dùng lại khoá | Dùng lại khoá trên nhánh chính |
| `pull_request` có `ready_for_review` | Bỏ loại đó |
| `make check` vẫn chạy cả hai tầng; `check-quick` không chạy `ui-floor` | Để `ui-floor` trong `CHECK_TARGETS` |
| `ui-floor` chạy trọn bộ khi không có `design-affected`, khi lệnh trả `all`, khi lệnh lỗi | Thu hẹp khi lệnh lỗi |
| `e2e_select.py`: bảng ở mục 6, từng hàng; tệp lạ thì trọn bộ; kế thừa preset | Đổi `ts-node` mà không chạy `react-vite` |
| `test.yml` của kho này theo cùng luật ô tổng | Như hàng đầu |
| `github_setup.py` báo khi một ô sau ô tổng là ô bắt buộc | Bỏ lời báo |

Luật của ô tổng là biểu thức trên kết quả của các ô, nên kiểm được ở máy bằng cách đọc YAML và tính
biểu thức với từng tổ hợp kết quả. Chạy thật thì ở kho thử (mục 8).

## 8. Thước

- **Kho thử `design-ci-probe`**:
  - PR có `quick` cố ý đỏ: `heavy` bị bỏ qua, `check` đỏ.
  - Sửa cho `quick` xanh: `heavy` chạy, `check` xanh.
  - Đẩy thêm một commit chỉ đổi `_acceptance/` hay `docs/`: `heavy` xanh trong vài giây, nêu lượt cũ.
  - Đẩy một commit đổi mã: `heavy` chạy lại.
  - Huỷ tay `heavy` giữa chừng: `check` đỏ.
  - PR là bản nháp: không `heavy`. Chuyển khỏi bản nháp: có `heavy`.
- **Kho này**: `sdlc_metrics.py` trước và sau, cửa sổ bằng nhau, dòng «phút máy mỗi PR gộp» (hôm nay
  44,2).
- **`onehub-inventory`**, khi chủ kho cho chạy: phút máy mỗi PR gộp (hôm nay 548) và phần chạy lúc
  PR chưa thể gộp (hôm nay 64%). Kỳ vọng: commit chữ ký và commit chỉ đổi hồ sơ không còn trả
  `e2e` và `e2e-db`. Lượt trước khi mời ký vẫn trả, nên phần cắt được nhỏ hơn 64%. Trước khi dựng,
  đo một lần trên lịch sử thật bao nhiêu lượt trong phần đó có cây mã giống hệt lượt xanh trước nó
  (băm cây trừ các đường dẫn mặc định), để biết con số kỳ vọng. Lần đo này là bước đầu của kế hoạch.
- **Đối trọng, giữ chữ «vẫn tin được»**: tỉ lệ nhánh chính đỏ sau gộp và tỉ lệ đỏ muộn, đọc bằng
  cùng lệnh. Tăng thì sửa cách chọn bài, không gọi người quay lại.

## 9. Câu hỏi cho chủ kho

1. **Kho này chưa có ruleset trên `main`.** Ô tổng vì thế chỉ để đọc: PR vẫn gộp được khi `e2e` chưa
   chạy. Có đặt một ruleset bắt buộc `check` không? Đó là đổi luật của kho này. Gói này không tự làm
   việc đó.

## 10. Để lại cho người dựng

- Cách viết biểu thức của ô tổng, cách lấy danh sách tệp đổi trong workflow (cần `fetch-depth`).
- Định dạng đầu ra của `e2e_select.py`, chỗ đặt danh sách tệp «chỉ tài liệu».
- Cách Playwright chạy «bài theo màn cộng bài không nêu màn» trong một hay hai lượt.
- Cú pháp của danh sách đường dẫn «không phải đầu vào» ở đầu `ci.yml`.

## 11. Giới hạn đã biết

- Lần đẩy cuối chậm thêm bằng thời gian tầng nhẹ.
- Ô tổng đỏ trên mọi PR là bản nháp hay có tầng nhẹ đỏ. Đó là đúng, nhưng màu đỏ ấy nói «chưa tới lượt», không nói
  «hỏng». Lời của ô tổng phải nói rõ là cái nào.
- Chọn tổ hợp theo đường dẫn bỏ sót được: một sửa ở `_core` luôn chạy trọn bộ, nhưng một sửa trong
  preset `p` mà làm vỡ preset khác bằng một đường không qua `extends` thì chỉ lộ ra sau gộp, trên
  nhánh chính.
- Chọn màn có thể bỏ sót ở chỗ DA2 không lần được. Luật của DA2 (không lần được thì trọn bộ) và lần
  chạy trọn bộ trên nhánh chính là hai lưới đỡ.
- `onehub-inventory` chỉ được lợi khi `ci.yml` của nó chuyển `e2e` và `e2e-db` vào sau `quick` và
  theo khoá đầu vào. Việc đó đi qua đường nâng cấp RS8 (tệp đã sửa tại chỗ, gộp ba chiều) ở bước
  chạy trên kho đó.
- Dùng lại theo khoá giả định bài cho cùng kết quả trên cùng đầu vào. Bài chập chờn, hay bài phụ thuộc
  dịch vụ ngoài, có thể xanh một lần rồi được dùng lại. Lần chạy trọn bộ trên nhánh chính là lưới đỡ.
- Một đường dẫn bị khai nhầm là «không phải đầu vào» thì đổi ở đó không chạy lại tầng nặng. Danh sách
  ấy nằm trong `ci.yml`, một tệp workflow, nên đổi nó là đổi luật và PR lên hạng cao.
- Ở `onehub-inventory`, mỗi lần gộp ngược nhánh chính có đổi mã vẫn chạy lại tầng nặng. Bớt phần đó
  là DL2 và DL4.

## Nguồn

- `onehub-inventory`, `origin/main` tại `ea774a0f`: `.github/workflows/ci.yml`; ruleset của `main`
  (bắt buộc `check`, `e2e`, `gate`); 40 PR gần nhất, không PR nào là bản nháp (đọc qua GitHub ngày
  2026-11-17).
- Kho này: `.github/workflows/test.yml`, `tests/e2e.sh` (biến `PRESETS`), ruleset của `main` (không
  có), 20 PR gộp gần nhất, `tools/github_setup.py`.
- design-assembly, nhánh chính tại `93daea4`: quyết định 0053, lệnh `affected`.
- [Thiết kế tổng quan](../../three-repo-overview-design.md), mục 2 (số đo) và mục 9 («ô bị bỏ qua
  được tính là xanh»).
- Báo cáo [tổng kết sau RS8](../../reports/2026-11-17-progress-after-rs8.md): 44,2 phút máy mỗi PR
  gộp.
- Chủ kho, buổi thảo luận ngày 2026-11-17: «Có, gồm test.yml»; «Đúng rồi» cho hình dạng.
