/// Hình tạm và câu phản ứng của màn Phòng (T2-04).
///
/// Nền phòng + nội thất là SVG vẽ đơn giản, để riêng ở
/// `assets/temp/room/` (ngoài phạm vi `tools/assets/check_assets.py`).
/// Hình thật (nền JPEG 16:9, nội thất PNG 512x512 theo manifest) về
/// thì thay file tại đúng đường dẫn này rồi đổi sang đường dẫn
/// manifest, không sửa code màn Phòng. Trứng/pet đã là PNG thật
/// (PR #21, `app/assets/images/pets/`, đọc qua map ở
/// `onboarding_config.dart`), không còn dùng SVG tạm nữa.
library;

/// Đường dẫn asset SVG nền phòng tạm.
const String roomBackgroundAsset = 'assets/temp/room/room_bg.svg';

/// Một món nội thất đặt ở ô cố định trong phòng.
class RoomFurniture {
  const RoomFurniture({
    required this.key,
    required this.asset,
    required this.label,
    required this.reaction,
  });

  /// Khóa widget của món (để test tìm).
  final String key;

  /// Đường dẫn asset SVG tạm của món.
  final String asset;

  /// Tên món, hiện ở bong bóng phản ứng.
  final String label;

  /// Câu phản ứng khi bé chạm vào món.
  final String reaction;
}

/// Nội thất đặt sẵn trong phòng (vị trí cố định ở màn Phòng).
const List<RoomFurniture> roomFurniture = [
  RoomFurniture(
    key: 'room-furniture-bed',
    asset: 'assets/temp/room/bed.svg',
    label: 'Giường',
    reaction: 'Giường êm quá, ngủ ngon lắm!',
  ),
  RoomFurniture(
    key: 'room-furniture-shelf',
    asset: 'assets/temp/room/shelf.svg',
    label: 'Kệ sách',
    reaction: 'Sách toán hay nhất ở đây!',
  ),
  RoomFurniture(
    key: 'room-furniture-lamp',
    asset: 'assets/temp/room/lamp.svg',
    label: 'Đèn',
    reaction: 'Đèn sáng rồi, đọc sách thôi!',
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
