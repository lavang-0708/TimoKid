/// Hồ sơ nhân vật của bé (T2-03).
///
/// Lưu gọn thành JSON trong `settings` (khóa `character_profile`, theo
/// từng bé) — không thêm bảng mới: theo quyết định (e) của PLAN, bảng
/// `pets` thuộc T2-07 và `inventory` thuộc T2-05; hồ sơ nhân vật chỉ là
/// vài giá trị của một bé nên bảng `settings` đã đủ (cùng cách lưu
/// bảng thưởng `rewards` và `sound_enabled`).
library;

import 'onboarding_config.dart';

/// Hồ sơ nhân vật: giới tính, màu da, kiểu/màu tóc, kiểu/màu mắt,
/// kiểu miệng, váy (nữ bộ 1), tên. Màu lưu dạng ARGB int
/// (`Color.value`).
///
/// Dáng nữ bộ nhân vật nữ 1 (PR #18) chỉ dùng [hairColor] + [dress]:
/// thân đã có sẵn mắt/miệng/giày/bộ đồ gốc nên không chọn màu da,
/// kiểu mắt, kiểu miệng; các trường đó giữ mặc định, không dùng.
/// Dáng nam (chưa có hình thật) vẫn dùng đủ các trường như manifest
/// v1, xem trước bằng hình tạm.
class CharacterProfile {
  const CharacterProfile({
    required this.gender,
    required this.skinColor,
    required this.hairStyle,
    required this.hairColor,
    required this.eyeStyle,
    required this.eyeColor,
    required this.mouthStyle,
    this.dress,
    required this.name,
  });

  /// Hồ sơ mặc định của bước mở đầu (nữ, tông da sáng, tóc hồng kiểu
  /// 1, mắt tím kiểu 1, miệng cười, bộ đồ gốc, chưa đặt tên).
  factory CharacterProfile.defaults() => const CharacterProfile(
    gender: 'girl',
    skinColor: 0xFFFFE3CE,
    hairStyle: 'girl_hair_01',
    hairColor: 0xFFFFB9D7,
    eyeStyle: 'girl_eyes_01',
    eyeColor: 0xFF9B7EDE,
    mouthStyle: 'girl_mouth_01',
    dress: null,
    name: '',
  );

  final String gender;
  final int skinColor;
  final String hairStyle;
  final int hairColor;
  final String eyeStyle;
  final int eyeColor;
  final String mouthStyle;

  /// Váy dáng nữ bộ 1: mã manifest lớp `top` (`girl_top_01` váy
  /// hồng, `girl_top_02` váy tím); null = mặc bộ đồ gốc trên thân.
  /// Dáng nam không dùng trường này.
  final String? dress;

  /// Tên nhân vật bé đặt (tối đa 12 ký tự, không bắt buộc dấu).
  final String name;

  CharacterProfile copyWith({
    String? gender,
    int? skinColor,
    String? hairStyle,
    int? hairColor,
    String? eyeStyle,
    int? eyeColor,
    String? mouthStyle,
    String? dress,
    // `dress: null` một mình nghĩa là "giữ nguyên" (mẫu `??`
    // chung); muốn chọn lại bộ đồ gốc thì truyền thêm cờ này.
    bool dressToNull = false,
    String? name,
  }) => CharacterProfile(
    gender: gender ?? this.gender,
    skinColor: skinColor ?? this.skinColor,
    hairStyle: hairStyle ?? this.hairStyle,
    hairColor: hairColor ?? this.hairColor,
    eyeStyle: eyeStyle ?? this.eyeStyle,
    eyeColor: eyeColor ?? this.eyeColor,
    mouthStyle: mouthStyle ?? this.mouthStyle,
    dress: dressToNull ? null : (dress ?? this.dress),
    name: name ?? this.name,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'gender': gender,
    'skinColor': skinColor,
    'hairStyle': hairStyle,
    'hairColor': hairColor,
    'eyeStyle': eyeStyle,
    'eyeColor': eyeColor,
    'mouthStyle': mouthStyle,
    'dress': dress,
    'name': name,
  };

  factory CharacterProfile.fromJson(Map<String, Object?> json) {
    return CharacterProfile(
      gender: json['gender'] as String? ?? 'girl',
      skinColor: json['skinColor'] as int? ?? 0xFFFFE3CE,
      hairStyle: json['hairStyle'] as String? ?? 'girl_hair_01',
      hairColor: json['hairColor'] as int? ?? 0xFFFFB9D7,
      eyeStyle: json['eyeStyle'] as String? ?? 'girl_eyes_01',
      eyeColor: json['eyeColor'] as int? ?? 0xFF9B7EDE,
      mouthStyle: json['mouthStyle'] as String? ?? 'girl_mouth_01',
      dress: json['dress'] as String?,
      name: json['name'] as String? ?? '',
    );
  }
}

/// Tên hợp lệ khi đã cắt khoảng trắng hai đầu, dài 1–12 ký tự.
/// Chỉ kiểm độ dài (PLAN T2-03): không ép dấu, không cấm ký tự.
bool isValidCharacterName(String name) {
  final trimmed = name.trim();
  return trimmed.isNotEmpty && trimmed.runes.length <= onboardingMaxNameLength;
}
