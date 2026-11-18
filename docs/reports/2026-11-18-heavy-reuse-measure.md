# Tầng nặng lặp lại một lượt xanh bao nhiêu

Ngày 2026-11-18. Bước đầu của kế hoạch RS3, theo
[thiết kế CI xếp tầng](../superpowers/specs/2026-11-17-tiered-ci-design.md), mục 8.

## 1. Đo gì, đo thế nào

Đo trên lịch sử thật của `onehub-inventory`, chỉ đọc. Lấy mọi lượt `CI` qua `gh api`: 465 lượt, gồm
391 lượt trên PR (83 PR) và 74 lượt đẩy lên `main`. Lượt đầu của `CI` là ngày 2026-11-09, nên cửa sổ
14 ngày thật ra là 2026-11-09 đến 2026-11-17. Commit gộp của mỗi lượt trên PR lấy từ log bước
checkout, dòng «Merge <đầu PR> into <gốc>». Rồi kéo đúng commit đó về bản sao bằng sha. Cả 384 commit
gộp đều kéo được, và cha của chúng khớp với log. Vì vậy **không có ước lượng**: khoá tính trên đúng
cây mà GitHub đã chạy. Khoá là sha256 trên `git ls-tree -r`, bỏ các tệp khớp `docs/**`, `wiki/**`,
`*.md`, `_acceptance/**`, `LO-TRINH.html`, `PRODUCT-MAP.md`. Lượt xanh là lượt có `e2e` và `e2e-db`
thành công ở lần chạy cuối. Một lượt «dùng lại được» khi khoá của nó trùng khoá một lượt xanh của
cùng PR, hay của một lượt xanh trên `main`, và tầng nặng của lượt xanh ấy đã xong trước khi lượt này
bắt đầu. Lệnh đo ở thư mục nháp của phiên, không commit.

## 2. Số đo

| Dòng                              | Mọi lượt trên PR          | Lượt lúc `gate` đỏ                                                 |
| --------------------------------- | ------------------------- | ------------------------------------------------------------------ |
| Số lượt `CI` trên PR              | 391                       | 251 (64,2%)                                                        |
| Khoá trùng một lượt xanh trước đó | 66 (16,9%)                | 31 (12,4%)                                                         |
| · trong đó của cùng PR            | 61                        | 30                                                                 |
| · trong đó của nhánh chính        | 5                         | 1                                                                  |
| Phút `e2e` dùng lại được          | 1.321 trên 7.213          | 632 trên 4.705                                                     |
| Phút `e2e-db` dùng lại được       | 830 trên 4.975            | 440 trên 3.445                                                     |
| Cộng hai ô                        | 2.151 trên 12.187 (17,6%) | 1.071 trên 8.150 (13,1%)                                           |
| Tỉ lệ trên 64%                    | —                         | 12,4% số lượt, tức khoảng 8 trong 64 điểm; 13,1% số phút tầng nặng |

Số phút làm tròn từng ô, nên tổng có thể lệch một phút.

Tỉ lệ không gần 0. Nhưng nó nhỏ hơn nhiều so với 64%, đúng như mục 8 của thiết kế đã đoán. Thêm 63
lượt lúc `gate` đỏ có khoá trùng một lượt trước đó của cùng PR, nhưng lượt đó bị `concurrency` huỷ
giữa chừng. Không có lượt xanh nào để dùng lại, nên các lượt này vẫn phải chạy tầng nặng.

## 3. Giới hạn

- Cửa sổ chỉ có 9 ngày dữ liệu, vì `CI` mới có từ 2026-11-09.
- 7 lượt bị huỷ trước bước checkout. Không có commit gộp, nên được tính là không dùng lại được.
- `e2e-db` chỉ có từ 2026-11-13. Ở 179 lượt trước đó, «xanh» chỉ có nghĩa là `e2e` xanh.
- «Trước đó» nghĩa là tầng nặng của lượt xanh đã xong trước khi lượt này được tạo. Ở thiết kế mới,
  tầng nặng chờ tầng nhẹ thêm khoảng 3,4 phút. Nới điều kiện (lượt xanh chỉ cần được tạo trước) thì
  có 71 lượt thay vì 66; số lượt lúc `gate` đỏ vẫn là 31.
- Không mô phỏng bộ nhớ đệm của GitHub: khoá hết hạn sau 7 ngày không dùng, trần 10 GB.
- Không thấy được lần đỏ ngẫu nhiên. Một lượt dùng lại được có `e2e` đỏ, trên đúng đầu vào đã xanh
  trước đó. Dùng lại kết quả sẽ giấu lần đỏ đó.
- Phút là thời gian của job từ lúc bắt đầu đến lúc xong, cộng mọi lần chạy lại (13 lượt có chạy lại),
  kể cả job bị huỷ giữa chừng. Không tính thời gian chờ hàng đợi. Không làm tròn theo cách GitHub
  tính phút.
- Không tính phần thiết kế mới bớt thêm khi tầng nhẹ đỏ: khi đó tầng nặng không chạy. Đó là khoản
  khác, không phải dùng lại.
- Một PR được nhận theo nhánh nguồn của nó. Hai PR dùng chung một nhánh sẽ bị gộp làm một.
