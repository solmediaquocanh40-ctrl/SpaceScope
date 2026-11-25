# SpaceScope 1.2.0

**Package:** `com.anhdang.spacescope` — app riêng (Theos application, kiểu TweakPacker), không chích vào SpringBoard.

Quét toàn máy jailbreak để trả lời câu hỏi "dung lượng nặng nằm ở đâu, vì sao máy full và lag", rồi dọn an toàn.

## Tính năng

Mới ở 1.2.0 — Dọn sâu kiểu iCleaner nhưng xem được toàn bộ nội dung trước khi xoá: mọi nhóm dọn trong tab Dọn dẹp (cache từng app, cache chung, log, file tạm, dữ liệu & cache Safari, ảnh thu nhỏ của thư viện Ảnh, file đính kèm tin nhắn, cache bàn phím) đều bấm vào để mở ra danh sách từng file (dung lượng/loại/mức cảnh báo/ghi chú/đường dẫn), tick chọn lọc từng file, chọn các file nặng nhất, backup hoặc xoá — không còn xoá cả nhóm mù. Thêm mục liệt kê gói phụ thuộc có thể mồ côi (chỉ liệt kê, gỡ bằng Sileo). **Danh sách bảo vệ** (trong Cài đặt): dữ liệu Zalo và thư mục ghi âm cuộc gọi (AudioRecorder…) mặc định được bảo vệ — có mục riêng trong tab Dọn dẹp, bị khoá 3 lớp (không chọn hàng loạt được, tầng xoá từ chối, chỉ xoá lẻ từng file sau cảnh báo riêng); anh tự thêm được app/thư mục khác vào danh sách. Cơ sở dữ liệu (.sqlite/.db) cũng tự động bị đánh dấu bảo vệ. Kèm mục **Giao diện** trong Cài đặt: đổi nền toàn app với 11 mẫu (mặc định theo hệ thống, 8 màu sáng pastel, Xanh đậm, Đen tuyền — nền tối tự chuyển chữ sang sáng).

Trước đó ở 1.1.0: mỗi file có thẻ riêng (loại file: ảnh/video/ghi âm/tài liệu/file nén; mức cảnh báo 🟢/🟡/🔴 kèm ghi chú lý do; thuộc app/tweak nào — tra từ dpkg, file lõi của tweak đang cài bị đánh dấu 🔴; đường dẫn đầy đủ). Tab File nặng có chế độ Chọn: tick từng file, chọn nhiều xoá cùng lúc, hoặc Chọn hết để xoá toàn bộ — file 🟡/🔴 khi xoá sẽ được hỏi backup trước. Nút Backup nén các file đã chọn thành 1 file zip (kèm MANIFEST.txt ghi đường dẫn gốc) trong Documents/SpaceScope/Backup rồi mở bảng chia sẻ để gửi lên Google Drive/Files. Tab Dọn dẹp cũng chọn được nhiều mục để dọn một lần; chi tiết từng app liệt kê các file lớn nhất trong app kèm mức cảnh báo.

- **Tổng quan:** dung lượng trống/tổng, đồng hồ mức an toàn (mục tiêu trống 10%), báo MỨC NGUY HIỂM khi trống dưới ngưỡng đặt (mặc định 5 GB) kèm số GB cần giải phóng; kết luận **3 nguyên nhân lớn nhất** làm máy đầy; file mới sinh 7/30/90 ngày; app **phình nhanh nhất** so với lần quét trước (snapshot tự lưu, giữ 12 lần).
- **File nặng:** 200 file lớn nhất (từ 5 MB), lọc theo Ảnh / Video / Tải về / Cài đặt; xem đường dẫn đầy đủ, sao chép, chuyển vào thùng rác tạm.
- **Trùng lặp:** gom theo kích thước → hash một phần → hash toàn bộ (SHA-256), chỉ báo trùng khi giống hệt 100% nội dung. Mỗi nhóm chọn **1 file gốc** (ưu tiên: trong thư viện Ảnh > thư mục chính thức > ngày tạo sớm nhất > không nằm trong Cache/Tải về) — file gốc bị **khoá cứng 2 lớp** (giao diện không cho chọn + tầng xoá từ chối). Chỉ bản sao mới xoá được.
- **Dọn dẹp 3 mức + Dọn sâu:** 🟢 Xanh (cache từng app, cache chung, log/crash, /var/tmp, thùng rác Filza) • 🟡 Vàng (file .deb/.ipa/zip source thừa, backup TweakPacker, plist cài đặt mồ côi của app/tweak đã gỡ, bản cập nhật iOS chờ cài, Safari, thumbnail ảnh, đính kèm tin nhắn — vào thùng rác tạm trước) • ℹ️ Thông tin (Ảnh đã xoá gần đây — hướng dẫn xoá trong app Ảnh; gói phụ thuộc mồ côi — gỡ bằng Sileo; vùng được bảo vệ). Mọi nhóm dạng danh sách đều mở ra xem được từng file trước khi xoá.
- **Ứng dụng:** mọi app xếp theo tổng dung lượng (gói cài + dữ liệu), chi tiết Documents/Cache/tmp, dấu vết thư mục offline/download lớn trong app, dọn cache từng app ngay tại chỗ.
- **Thùng rác tạm:** mọi lần dọn dạng file đều vào đây trước, giữ 7 ngày (tuỳ chỉnh 1–30), khôi phục được, tự dọn quá hạn, xoá hẳn toàn bộ khi cần giải phóng ngay.
- **Cài đặt:** ngưỡng báo nguy hiểm (GB), ngày giữ thùng rác, ngưỡng kích thước xét trùng (MB); xem/chia sẻ log gỡ lỗi.

## Nguyên tắc an toàn

- File trong **thư viện Ảnh** (DCIM/PhotoData) chỉ xem, không xoá file thô — tránh hỏng thư viện; muốn xoá hãy dùng app Ảnh.
- Không xoá file bên trong gói **.app**.
- Cache xoá thẳng vì app tự sinh lại; mọi thứ còn lại đều qua thùng rác tạm.
- Log gỡ lỗi: `/var/mobile/Documents/SpaceScope.log`.

## Giới hạn đã biết

- Cục "Dữ liệu hệ thống" của iOS (snapshot APFS, cache nội bộ) không bóc tách được 100% — app chỉ ra phần quét được.
- Nhóm trùng mà **mọi bản đều nằm trong thư viện Ảnh** sẽ được liệt kê nhưng phải xử lý trong app Ảnh.
- Lần quét đầu có thể mất vài phút nếu máy rất nhiều file; các lần sau đối chiếu snapshot để thấy thay đổi.

## Build

Giải nén gói nguồn trên máy tính rồi up CẢ CÂY lên repo (nhớ cả thư mục ẩn `.github`), tạo **commit mới** (đừng bấm Re-run). Workflow cổ điển build thẳng từ cây nguồn 3 bản rootful / rootless / roothide, file .deb có hậu tố scheme tương ứng. Máy của anh (iPhone 12 Pro, iOS 16.3.1, Dopamine rootless) cài bản **-rootless**.
