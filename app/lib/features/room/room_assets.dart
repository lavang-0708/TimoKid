/// Hình thật và câu phản ứng của màn Phòng (A1, phong cách v2).
///
/// Nền phòng là PNG `room_v2.png` (1600x900, phối cảnh 1 điểm tụ);
/// 8 món nội thất là PNG trong suốt 512x512 ở
/// `app/assets/images/furniture/` (xem `docs/ASSETS.md` mục "Phòng v2").
/// SVG tạm ở `assets/temp/room/` (T2-04) không còn dùng — nhờ Claude
/// xóa bằng git (push-files không xóa được file).
library;

/// Đường dẫn asset PNG nền phòng v2.
const String roomBackgroundAsset = 'assets/images/backgrounds/room_v2.png';

/// Một món nội thất đặt ở ô cố định trong phòng.
class RoomFurniture {
  const RoomFurniture({
    required this.key,
    required this.asset,
    required this.label,
    required this.reaction,
    required this.bottomRow,
    this.hanging = false,
  });

  /// Khóa widget của món (để test tìm).
  final String key;

  /// Đường dẫn asset PNG của món.
  final String asset;

  /// Tên món, hiện ở bong bóng phản ứng.
  final String label;

  /// Câu phản ứng khi bé chạm vào món.
  final String reaction;

  /// Hàng pixel mờ đục cuối cùng của món trong khung 512x512
  /// (đo từ PNG thật): mép đáy để app neo bóng đổ mềm ngay dưới đó.
  final int bottomRow;

  /// Món treo (dây cờ, đèn sao): không đặt sàn nên app không vẽ
  /// bóng đổ dưới món.
  final bool hanging;
}

/// Nội thất đặt sẵn trong phòng (vị trí cố định ở màn Phòng).
const List<RoomFurniture> roomFurniture = [
  RoomFurniture(
    key: 'room-furniture-day-co',
    asset: 'assets/images/furniture/day_co.png',
    label: 'Dây cờ',
    reaction: 'Dây cờ bay bay, phòng xinh quá!',
    bottomRow: 359,
    hanging: true,
  ),
  RoomFurniture(
    key: 'room-furniture-den-sao',
    asset: 'assets/images/furniture/den_sao.png',
    label: 'Đèn sao',
    reaction: 'Đèn sao sáng rồi, đọc sách thôi!',
    bottomRow: 433,
    hanging: true,
  ),
  RoomFurniture(
    key: 'room-furniture-khung-anh',
    asset: 'assets/images/furniture/khung_anh.png',
    label: 'Khung ảnh',
    reaction: 'Khung ảnh này ai tặng nhỉ?',
    bottomRow: 423,
  ),
  RoomFurniture(
    key: 'room-furniture-chau-cay',
    asset: 'assets/images/furniture/chau_cay.png',
    label: 'Chậu cây',
    reaction: 'Cây lớn nhanh nhé!',
    bottomRow: 421,
  ),
  RoomFurniture(
    key: 'room-furniture-goi',
    asset: 'assets/images/furniture/goi.png',
    label: 'Gối',
    reaction: 'Gối êm quá, ngủ ngon lắm!',
    bottomRow: 426,
  ),
  RoomFurniture(
    key: 'room-furniture-gau-bong',
    asset: 'assets/images/furniture/gau_bong.png',
    label: 'Gấu bông',
    reaction: 'Gấu bông ôm thích lắm!',
    bottomRow: 433,
  ),
  RoomFurniture(
    key: 'room-furniture-coc-sao',
    asset: 'assets/images/furniture/coc_sao.png',
    label: 'Cốc sao',
    reaction: 'Cốc sao uống sữa ngon lắm!',
    bottomRow: 392,
  ),
  RoomFurniture(
    key: 'room-furniture-binh-hoa',
    asset: 'assets/images/furniture/binh_hoa.png',
    label: 'Bình hoa',
    reaction: 'Hoa thơm quá!',
    bottomRow: 426,
  ),
];

/// Câu pet vui khi bé chơi với pet (đã mở khóa).
const Map<String, String> petHappyLines = <String, String>{
  'dog': 'Gâu gâu! Chơi với tớ nhé!',
  'cat': 'Meo meo! Tớ vui lắm!',
  'rabbit': 'Nhảy nhảy! Vui quá!',
};

/// Câu khi bé chạm vào pet mà phần chơi còn khóa.
const String petLockedLine = 'Chơi với tớ cần xong đề ngày đã nhé!';
