# SpaceScope 1.0.0

**Package:** `com.anhdang.spacescope` — app riêng (Theos application, kiểu TweakPacker), không chích vào SpringBoard.

Quét toàn máy jailbreak để trả lời câu hỏi "dung lượng nặng nằm ở đâu, vì sao máy full và lag", rồi dọn an toàn.

## Tính năng 1.0.0

- **Tổng quan:** dung lượng trống/tổng, đồng hồ mức an toàn (mục tiêu trống 10%), báo MỨC NGUY HIỂM khi trống dưới ngưỡng đặt (mặc định 5 GB) kèm số GB cần giải phóng; kết luận **3 nguyên nhân lớn nhất** làm máy đầy; file mới sinh 7/30/90 ngày; app **phình nhanh nhất** so với lần quét trước (snapshot tự lưu, giữ 12 lần).
- **File nặng:** 200 file lớn nhất (từ 5 MB), lọc theo Ảnh / Video / Tải về / Cài đặt; xem đường dẫn đầy đủ, sao chép, chuyển vào thùng rác tạm.
- **Trùng lặp:** gom theo kích thước → hash một phần → hash toàn bộ (SHA-256), chỉ báo trùng khi giống hệt 100% nội dung. Mỗi nhóm chọn **1 file gốc** (ưu tiên: trong thư viện Ảnh > thư mục chính thức > ngày tạo sớm nhất > không nằm trong Cache/Tải về) — file gốc bị **khoá cứng 2 lớp** (giao diện không cho chọn + tầng xoá từ chối). Chỉ bản sao mới xoá được.
- **Dọn dẹp 3 mức:** 🟢 Xanh (cache từng app, cache chung, log/crash, /var/tmp, thùng rác Filza — xoá nội dung, app tự tạo lại) • 🟡 Vàng (file .deb/.ipa/zip source thừa, backup TweakPacker, plist cài đặt mồ côi của app/tweak đã gỡ, bản cập nhật iOS chờ cài — vào thùng rác tạm trước) • ℹ️ Thông tin (Ảnh đã xoá gần đây — hướng dẫn xoá trong app Ảnh).
- **Ứng dụng:** mọi app xếp theo tổng dung lượng (gói cài + dữ liệu), chi tiết Documents/Cache/tmp, dấu vết thư mục offline/download lớn trong app, dọn cache từng app ngay tại chỗ.
- **Thùng rác tạm:** mọi lần dọn dạng file đều vào đây trước, giữ 7 ngày (tuỳ chỉnh 1–30), khôi phục được, tự dọn quá hạn, xoá hẳn toàn bộ khi cần giải phóng ngay.
- **Cài đặt:** ngưỡng báo nguy hiểm (GB), ngày giữ thùng rác, ngưỡng kích thước xét trùng (MB); xem/chia sẻ log gỡ lỗi.

## Nguyên tắc an toàn

- File trong **thư viện Ảnh** (DCIM/PhotoData) chỉ xem, không xoá file thô — tránh hỏng thư viện; muốn xoá hãy dùng app Ảnh.
- Không xoá file bên trong gói **.app**.
- Cache xoá thẳng vì app tự sinh lại; mọi thứ còn lại đều qua thùng rác tạm.
- Log gỡ lỗi: `/var/mobile/Documents/SpaceScope.log`.

## Giới hạn đã biết (1.0.0)

- Cục "Dữ liệu hệ thống" của iOS (snapshot APFS, cache nội bộ) không bóc tách được 100% — app chỉ ra phần quét được.
- Nhóm trùng mà **mọi bản đều nằm trong thư viện Ảnh** sẽ được liệt kê nhưng phải xử lý trong app Ảnh.
- Lần quét đầu có thể mất vài phút nếu máy rất nhiều file; các lần sau đối chiếu snapshot để thấy thay đổi.

## Build

Đẩy file `build-spacescope-1.0.0.yml` vào `.github/workflows/build.yml` của repo, đẩy tiếp file `SpaceScope-1.0.0-source.zip` lên gốc repo và tạo **commit mới** (đừng bấm Re-run). Workflow tự mở zip và build 3 bản rootful / rootless / roothide, file .deb có hậu tố scheme tương ứng. Máy của anh (iPhone 12 Pro, iOS 16.3.1, Dopamine rootless) cài bản **-rootless**.
