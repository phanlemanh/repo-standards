# Đường nâng cấp (RS8)

Ngày 2026-11-17. Gói RS8, bước C của [thiết kế tổng quan ba kho](../../three-repo-overview-design.md).

## Ý định

Plugin chép mẫu vào kho một lần. Sau đó, tệp nào kho đã sửa tại chỗ thì không bao giờ nhận được
bản sửa của mẫu nữa: chạy lại `apply.py` thì tệp đó bị báo `conflict` và để nguyên. Đây là gốc rễ 5
(bản sao trôi khỏi nguồn). Ví dụ: `onehub-inventory` dựng từ 0.4.0 có 34 trên 81 tệp đã sửa, gồm
`security.yml`, nên bản sửa quét bí mật của RS1 không tự tới đó. RS8 là điều kiện trước khi chạy
bộ setup mới trên `onehub-inventory`.

Xong là: một kho có tệp đã sửa tại chỗ vẫn nhận được bản sửa của mẫu, và `doctor` nói tệp nào lệch
nguồn, lệch từ bản nào.

## Hiện trạng

- `.repo-setup.json` ghi `version` (một số cho cả kho) và `files`: băm sha256 của nội dung plugin
  đã ghi cho từng tệp. Không có nội dung gốc.
- `apply.py`, với mỗi tệp trong kế hoạch:
  - giống hệt mẫu mới: `unchanged`;
  - khớp `user_owned` (`package.json`, `pyproject.toml`, `src/index.css`, manifest của plugin,
    `CHANGELOG.md` của preset `claude-plugin`): luôn `kept`, kể cả khi băm còn khớp. Lời nhắc
    «gộp tay» chỉ in ở lần cài đầu;
  - băm khớp lần ghi trước (chưa ai sửa): `updated`;
  - còn lại: `conflict`, để nguyên, `--diff` in diff hai chiều giữa tệp hiện tại và mẫu mới;
  - tệp đã ghi trước đây mà kho đã xoá: tạo lại (`created`).
- Khi ghi manifest, `version` lên bản mới cho cả kho, kể cả tệp bị `conflict` hay `kept`. Vì vậy
  không biết được tệp nào đang theo bản nào.
- Bản plugin đã cài không có mẫu của các bản cũ. Bản clone marketplace là clone nông, không có tag;
  cache chỉ giữ bản hiện tại.

## Số đo trên `onehub-inventory`

Đọc trên một bản sao, không sửa kho đó. Dựng lại mẫu 0.4.0 bằng đúng các lựa chọn trong
`.repo-setup.json` của kho thì ra đúng băm đã ghi ở 79 trên 81 tệp. Hai tệp lệch là
`wiki/log.md` (có ngày) và `.claude/skills/review-change/SKILL.md`. Mã `apply.py` hiện tại dựng
mẫu 0.4.0 cũng ra 79 trên 81, nên không cần chạy mã của bản cũ. Gộp ba chiều (gốc 0.4.0, tệp hiện
tại, mẫu 0.6.0) bằng `git merge-file`:

| Trạng thái tệp                   | Số tệp | Hôm nay     | Gộp ba chiều               |
| -------------------------------- | -----: | ----------- | -------------------------- |
| Chưa sửa, mẫu không đổi          |     27 | `unchanged` | `unchanged`                |
| Chưa sửa, mẫu đổi                |     11 | `updated`   | `updated`                  |
| Đã sửa, mẫu không đổi            |     19 | `conflict`  | không có gì để làm         |
| Đã sửa, mẫu đổi, không đụng nhau |      9 | `conflict`  | gộp sạch                   |
| Đã sửa, mẫu đổi, đụng nhau       |      7 | `conflict`  | ghi dấu xung đột (1–2 chỗ) |
| Kho đã xoá                       |      8 | tạo lại     | giữ đã xoá, có báo         |

Chín tệp gộp sạch gồm `security.yml`, `.pre-commit-config.yaml`, `.gitattributes`, `package.json`
và bốn skill wiki. Bảy tệp đụng nhau: `AGENTS.md` (2 chỗ), `Makefile`, `.claude/settings.json`,
`.prettierignore`, `ontology/relations.yaml`, `tools/boundaries.py`, `tools/ontology_actions.py`.

## Mục tiêu

1. Bản sửa của mẫu tới được tệp đã sửa tại chỗ: tự gộp khi không đụng nhau, ghi dấu xung đột khi
   đụng nhau.
2. Chỗ chưa gộp xong làm `make check` đỏ. Không phải nhớ.
3. Tệp nào không có gốc khớp, hay chưa đọc được gốc, thì lệnh nói ra, không im lặng.
4. `doctor` báo từng tệp: đúng nguồn, đã sửa tại chỗ, hay đang theo bản cũ (từ bản nào).
5. Dùng được ngay cho các kho đã cài từ trước (0.4.0, 0.5.0), không đòi chúng làm gì thêm.

## Không làm

- Lưu bản gốc trong kho (ví dụ `.repo-setup/base/`).
- Mang mẫu của các bản cũ trong plugin.
- Tự gỡ dấu xung đột. Người, hoặc agent trong phiên làm việc, gỡ; máy chỉ giữ cho tới khi xong.
- Tự chạy `npm install` hay cập nhật tệp khoá phụ thuộc.
- Gộp khi `--adopt` lần đầu: tệp của kho có trước khi cài không có gốc, và vẫn đi đường hiện tại
  (`merge_lines`, `skipped`, `conflict`).

## Không được thành

- Một lần nâng cấp lặng lẽ ghi đè phần kho đã sửa.
- Một tệp có dấu xung đột mà `make check` vẫn xanh.
- Gốc không tải được, hay dựng ra sai băm, mà lệnh vẫn gộp như thể có gốc.
- Chạy mã tải từ mạng về.

## Ràng buộc

- `apply.py` và `doctor.py` chỉ dùng thư viện chuẩn của Python 3.11.
- Gộp dùng `git merge-file`. Các kho này là kho git, nên máy có git. Không có git thì lệnh nói ra
  và cư xử như hôm nay.
- Bộ kiểm nhanh (`tests/run.sh`) chạy không cần mạng.
- Theo [nguyên tắc của setup](../../setup-principles.md): không thêm chỗ nào bắt người dừng lại.
  PR nâng cấp chạm CI và `AGENTS.md`, nên đằng nào nó cũng là hạng `high` và chủ kho quyết gộp; RS8
  không thêm bước duyệt nào.

## Các cách đã cân nhắc

Gộp ba chiều cần bản gốc: đúng nội dung plugin đã ghi ở lần cài trước.

- **A. Tải mẫu của bản cũ theo tag rồi dựng lại.** `apply.py` tải tệp nén của tag
  `repo-setup-v<bản>` từ GitHub (khoảng 190 KB, dưới một giây), lấy thư mục `plugins/repo-setup`,
  rồi dựng lại mẫu bằng các lựa chọn đã ghi. Tệp nào dựng ra khớp băm đã ghi thì dùng làm gốc. Kho
  không mang thêm tệp nào, và đây là cách duy nhất cứu được các kho cũ. Cái giá: cần mạng lúc nâng
  cấp.
- **B. Lưu bản gốc trong kho mỗi lần cài.** Không cần mạng, gốc chính xác. Nhưng khoảng 80 tệp dẫn
  xuất nằm trong kho và đổi ở mỗi PR nâng cấp, trái với hướng RS2b. Nó cũng không cứu được kho cũ.
- **C. Plugin mang mẫu của mọi bản đã phát hành.** Không cần mạng, nhưng plugin to thêm khoảng
  1,4 MB mỗi bản và to mãi.

**Chủ kho chọn A (2026-11-17).** Chủ kho cũng chọn: chỗ đụng nhau thì ghi dấu xung đột vào tệp,
thay vì để nguyên rồi báo.

## Thiết kế

### Gốc của một tệp

1. Bản gốc của tệp: `file_versions[<đường dẫn>]` trong `.repo-setup.json`. Manifest cũ không có
   khoá này, khi đó dùng `version` của cả kho.
2. Tải mẫu của bản đó, mỗi bản một lần cho cả lượt chạy:
   `https://codeload.github.com/phanlemanh/repo-standards/tar.gz/refs/tags/repo-setup-v<bản>`.
   Tên kho nguồn là một hằng trong `apply.py`. Giải nén vào thư mục tạm, chỉ lấy
   `plugins/repo-setup/`, xoá khi xong. Giải nén có lọc đường dẫn, để không tệp nào ra ngoài thư
   mục tạm.
3. Dựng lại bằng mã `apply.py` hiện tại trên thư mục mẫu vừa tải. Chỉ đọc tệp mẫu (dữ liệu), không
   chạy mã nào tải về. Dùng đúng preset, level, archetype, deploy, capabilities và vars đã ghi.
4. Gốc chỉ được dùng khi băm của nó khớp `files[<đường dẫn>]`. Không khớp thì thử lần lượt các
   bản đã phát hành trước đó, mới nhất trước (danh sách tag đọc từ kho nguồn bằng
   `git ls-remote --tags`). Bản đầu tiên khớp băm là gốc. Lý do: trước RS8, mỗi lần chạy lại đều
   nâng `version` của cả kho, kể cả tệp bị `conflict` hay `kept`, nên băm của một tệp có thể thuộc
   một bản cũ hơn `version`.
5. Không bản nào khớp, hoặc không bản nào có tệp đó: tệp **không có gốc khớp**. Không tải được mẫu
   hay danh sách tag: tệp **chưa đọc được gốc**. Hai trường hợp này xử lý khác nhau (bảng dưới).
6. `--base-from <thư mục hoặc tệp nén>` thay cho việc tải: một bản plugin của bản gốc, cho máy không
   có mạng và cho bộ kiểm.
7. Từ RS8, `today` (ngày lần cài đầu) được ghi vào `vars` của manifest, để lần dựng lại sau ra đúng
   `wiki/log.md`. Manifest cũ không có `today`, nên tệp đó ở các kho cũ rơi vào «không có gốc
   khớp».

### Với mỗi tệp trong kế hoạch

| Tình huống                                                                | Kết quả                                               | Ghi                                                    |
| ------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------ |
| Giống hệt mẫu mới                                                         | `unchanged`                                           | băm mới, bản mới                                       |
| Băm khớp lần ghi trước (chưa sửa), kể cả tệp `user_owned`                 | `updated`                                             | mẫu mới; băm mới, bản mới                              |
| Đã sửa, có gốc, gộp sạch                                                  | `merged`                                              | kết quả gộp; băm mới, bản mới                          |
| Đã sửa, có gốc, đụng nhau                                                 | `marked`                                              | tệp có dấu; băm mới, bản mới                           |
| Đã sửa, không có gốc khớp                                                 | `marked`                                              | gộp hai chiều (gốc rỗng), tệp có dấu; băm mới, bản mới |
| Đã sửa, chưa đọc được gốc (không có mạng, không có git)                   | `base_unread`                                         | để nguyên; giữ băm cũ, bản cũ; nói lý do               |
| Trong manifest cũ nhưng kho đã xoá                                        | `removed`                                             | không tạo lại; giữ băm cũ, bản cũ                      |
| Trong manifest cũ nhưng mẫu mới không còn sinh ra                         | `dropped`                                             | để nguyên tệp; bỏ khỏi manifest                        |
| Không có trong manifest cũ, chưa có trong kho                             | `created`                                             | như hôm nay                                            |
| Không có trong manifest cũ, đã có trong kho (`user_owned` lần đầu, adopt) | như hôm nay (`kept`, `merged`, `skipped`, `conflict`) | như hôm nay                                            |

- `conflict` giữ nghĩa cũ: tệp có sẵn trong kho từ trước khi cài, để nguyên, không dấu. Các skill
  và `doctor` vẫn tả nó là «để nguyên». Tệp được ghi dấu có nhãn riêng, `marked`.
- «Không có gốc khớp» thì gộp với gốc rỗng: mọi chỗ khác nhau giữa tệp và mẫu mới thành một vùng
  có dấu, không có gì tự gộp. Đo trên `onehub-inventory`: `wiki/log.md` (102 dòng) ra một vùng có
  dấu; `review-change/SKILL.md` khác gần hết nên ra một vùng cả tệp. Như vậy tệp đi cùng một bức
  tường với `marked`, gỡ dấu xong thì lần sau đã có gốc, không cần lệnh hay cờ nào để báo «đã gộp».
- «Chưa đọc được gốc» thì không ghi dấu: chạy lại khi có mạng là đủ, không nên bắt kho gỡ dấu
  cho cả loạt tệp chỉ vì mất mạng.
- `dropped`: tệp thôi là của plugin và thành tệp của kho. Đó là trường hợp mẫu bỏ tệp, hay level,
  capability hoặc `not_applicable` đổi.

- Sau một lần gộp, gốc của lần sau là mẫu mới: phần kho sửa đã nằm trong tệp, còn mẫu mới đã được
  gộp vào. Vì vậy cả `merged` lẫn `conflict` đều ghi băm và bản của mẫu mới.
- Dấu xung đột theo kiểu diff3, có nhãn để người gộp biết bên nào là bên nào:
  `<<<<<<< this repository`, `||||||| repo-setup <bản gốc>` (hoặc
  `||||||| repo-setup: no matching base`), `=======`, `>>>>>>> repo-setup <bản mới>`.
- Tệp `user_owned` không còn ngoại lệ khi có gốc. Lời nhắc `hand_merge` chỉ còn cho tệp có sẵn
  trong kho từ trước khi cài.
- Khi `package.json` hay `pyproject.toml` được `updated` hoặc `merged`, lệnh nhắc chạy lệnh cài để
  cập nhật tệp khoá. Tệp khoá không khớp thì `npm ci` hay `uv sync --locked` trong CI tự đỏ.
- `--dry-run` cho ra cùng các nhóm (`merged`, `marked`, `base_unread`, `removed`, `dropped`) mà
  không ghi gì. `--diff` in phần sẽ ghi vào tệp `marked`.
- Mã thoát: 1 khi có ít nhất một tệp `marked` hoặc `base_unread`, 0 khi không có. `conflict` của
  lần cài đầu hay `--adopt` không đổi mã thoát, như hôm nay. Đầu ra in danh sách và việc phải làm:
  gỡ dấu rồi chạy `make check`; với `base_unread`, chạy lại khi có mạng.

### Manifest

- `files` vẫn là băm của nội dung plugin đã ghi lần cuối cho từng tệp.
- Khoá mới `file_versions`: bản plugin của nội dung đó, cho từng tệp. Lần chạy đầu tiên có RS8 ghi
  khoá này cho mọi tệp, theo bản gốc tìm được ở bước «Gốc của một tệp». Tệp `base_unread` và
  `removed` giữ bản cũ. Tệp `dropped` ra khỏi cả `files` lẫn `file_versions`.
- `version` vẫn là bản plugin của lần chạy gần nhất.

### Bức tường cho dấu xung đột

- Tệp mới `_core/starter/mk/upgrade.mk` thêm bước `upgrade` vào `CHECK_TARGETS` (cơ chế
  `-include mk/*.mk` có sẵn ở cả ba preset). Bước này chạy `tools/upgrade_markers.py`, cũng là tệp
  mới của `_core/starter`.
- Lệnh đọc danh sách tệp trong `.repo-setup.json` và đỏ khi một tệp còn dòng mở đầu bằng
  `<<<<<<< this repository` hoặc `>>>>>>> repo-setup `. Nó in tên tệp và số dòng. Chỉ quét tệp của
  setup, nên tài liệu của kho có chép dấu xung đột làm ví dụ cũng không bị báo nhầm.
- Nó chạy ở mọi level, vì `make check` chạy ở mọi level và trong CI. Một workflow có dấu thì YAML
  hỏng và ô bắt buộc không báo, nên PR cũng bị chặn.
- Hai tệp này mới, nên lần nâng cấp đầu tiên có RS8 tạo ra chúng (`created`) trước khi có xung đột
  nào cần giữ. Kho có `Makefile` riêng không `-include mk/*.mk` thì không có bức tường này; `doctor`
  báo việc đó.

### `doctor`

- Một mục mới, «Upgrade», cho kho có `.repo-setup.json`. Nó liệt kê:
  - tệp đã sửa tại chỗ (băm khác `files`);
  - tệp đang theo bản cũ, kèm bản gốc và bản plugin hiện tại (ví dụ «0.4.0 → 0.6.0»), đếm theo
    `file_versions`;
  - tệp kho đã xoá;
  - tệp còn dấu xung đột.
- Một phép kiểm có điểm, `setup_in_sync`: đỏ khi còn tệp có dấu xung đột, hoặc còn tệp đang theo bản
  cũ hơn bản plugin đã chạy lần cuối (`version`), tức tệp `base_unread`. Tệp chỉ «đã sửa tại chỗ»
  thì không đỏ: sửa tại chỗ là quyền của kho. Tệp kho đã xoá cũng không đỏ.
- Một phép kiểm `upgrade_wall`: đỏ khi `make check` không gồm bước `upgrade`.
- `doctor` không tải gì từ mạng; nó chỉ đọc manifest và tệp.

## Kiểm chứng

- `tests/run.sh`, mục mới (không cần mạng, gốc qua `--base-from`, bản cũ dựng bằng cách sửa một tệp
  mẫu trong bản sao của plugin). Mỗi trường hợp có chiều đỏ:
  - gộp sạch: phần kho sửa và bản sửa của mẫu đều có trong tệp;
  - đụng nhau: tệp có dấu đúng nhãn, mã thoát 1, `make check` đỏ vì `upgrade`, gỡ dấu thì xanh;
  - `user_owned` chưa sửa được cập nhật;
  - gốc ở một bản cũ hơn `version` vẫn được tìm ra;
  - không có gốc khớp: gộp hai chiều, tệp có dấu, mã thoát 1; gỡ dấu xong thì lần chạy sau sạch;
  - chưa đọc được gốc: tệp để nguyên, `base_unread`, có lý do, mã thoát 1;
  - tệp kho đã xoá không bị tạo lại; tệp mẫu thôi sinh ra thành `dropped`;
  - `--adopt` lần đầu vẫn trả mã 0 và `conflict` vẫn để nguyên;
  - `file_versions` ghi đúng; manifest cũ không có khoá này vẫn đọc được;
  - `doctor` liệt kê đúng bốn nhóm và đỏ `setup_in_sync` đúng lúc.
- `tests/e2e.sh`, một combo mới: dựng kho từ tag của bản phát hành trước (có mạng), sửa vài tệp tại
  chỗ, nâng lên bản đang xét, rồi `make check`. Đây là đường mà các combo hiện tại, luôn cài mới,
  không bao giờ đi qua.
- Trên GitHub, kho thử `design-ci-probe`, là một phần của việc dựng (chủ kho cho phép thao tác trên
  kho thử ở bước đó). Kho này được nâng ngày 16/11 từ `main` tại `1446c1e`, một bản không có tag,
  nên băm của nó không khớp tag nào. Vì vậy:

  1. nâng nó lên tag `repo-setup-v0.6.0` bằng `apply.py` của 0.6.0, gộp PR đó;
  2. sửa tại chỗ vài tệp mà mẫu sẽ đổi trong RS8, trong đó có một chỗ đụng nhau, gộp PR đó;
  3. nâng bằng bản có RS8: tệp đã sửa nhận được bản sửa của mẫu, chỗ đụng nhau làm `make check`
     đỏ trên PR, gỡ dấu thì xanh và gộp được.

  Đây là tiêu chí «xong» của bước C.

## Để lại cho người dựng

- Cách tách mã: `apply.py` đã 754 dòng; phần tải và dựng gốc nên thành một mô-đun riêng trong
  `scripts/`.
- Cách đổi `build_plan` để nhận thư mục mẫu làm tham số, thay vì đọc hằng `PLUGIN_ROOT`.
- Thông báo lỗi và chữ in ra, theo giọng của các lệnh hiện có.
- Cách dựng bản cũ giả trong bộ kiểm.

## Quyết định của người viết (chủ kho xem lại)

- Tệp kho đã xoá thì không tạo lại. Hôm nay lệnh tạo lại chúng; ở `onehub-inventory` có 8 tệp như
  vậy.
- Tệp không có gốc khớp thì gộp hai chiều với gốc rỗng và ghi dấu, để nó đi cùng bức tường với
  chỗ đụng nhau và tự hết sau khi gỡ dấu. Tệp chưa đọc được gốc thì để nguyên.
- Tìm gốc qua các bản phát hành cũ hơn `version` khi băm không khớp.
- Mã thoát 1 khi còn `marked` hay `base_unread`. Hôm nay `apply.py` luôn trả 0. `conflict` của lần
  cài đầu và `--adopt` không đổi mã thoát.
- Tệp mẫu thôi sinh ra thành tệp của kho (`dropped`), không xoá.
- Ghi `today` vào manifest.
- `doctor` cho biết bản gốc và bản hiện tại của tệp, không đếm số lần phát hành ở giữa: plugin không
  mang danh sách các bản đã phát hành.
- Tên kho nguồn là một hằng. Một bản fork của plugin sẽ tải mẫu từ kho gốc, trừ khi dùng
  `--base-from`.

## Ghi vào CHANGELOG khi phát hành

Thay đổi phá tương thích khi nâng cấp: `apply.py` nay ghi vào tệp kho đã sửa (gộp, hoặc ghi dấu xung
đột); không còn tạo lại tệp kho đã xoá; trả mã 1 khi còn việc phải làm; tệp `user_owned` chưa sửa
được cập nhật; `make check` có thêm bước `upgrade`.
