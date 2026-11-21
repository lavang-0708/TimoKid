/// Đường dẫn mọi ảnh nhân vật toàn thân (E) + pet theo giai đoạn (F),
/// để golden test nạp trước vào ImageCache (codec chỉ chạy trong
/// `runAsync`, thiếu bước này thì ảnh chụp trắng trơn).
library;

import 'package:timokid/features/character/kid_assets.dart';

List<String> kidImagePaths() => <String>[
  for (final g in ['girl', 'boy'])
    for (var n = 1; n <= 3; n++) ...[
      kidFullAsset(g, n),
      kidFullAsset(g, n, wave: true),
      kidEyePatch(g, n).asset,
      kidEyePatch(g, n, wave: true).asset,
    ],
  for (final g in ['girl', 'boy'])
    for (final a in ['hat', 'bow']) kidHeadAccessoryAsset(g, a)!,
  for (final s in ['dog', 'cat', 'rabbit'])
    for (final st in ['egg', 'newborn', 'teen', 'adult'])
      'assets/images/pets/${s}_$st.png',
];
