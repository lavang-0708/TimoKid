/// Cấu hình album ảnh (T5-05): mọi con số ở một chỗ.
library;

/// Số ảnh tối đa mỗi bé; quá thì xóa ảnh cũ nhất (có báo cho bé).
const int albumPhotoLimit = 60;

/// Tỉ lệ điểm ảnh khi chụp (so với màn hình) và cạnh dài tối đa (px) để
/// file PNG không quá nặng trên máy yếu.
const double albumPixelRatio = 2.0;
const int albumMaxLongSide = 2000;

/// Tên thư mục con trong thư mục tài liệu của app.
const String albumFolderName = 'photos';
