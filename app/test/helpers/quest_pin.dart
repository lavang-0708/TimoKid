/// Cố định 3 nhiệm vụ ngày cho golden: mã bé ngẫu nhiên nên seed đổi mỗi
/// lần chạy. Bộ này (xong đề ngày, đấu trường, tháp) chỉ xong "xong đề
/// ngày" khi đủ 5/5 chặng, nên chấm đỏ hiện đúng ở golden 5/5 và không
/// hiện ở golden giữa đề — không chập chờn.
library;

import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/quests/quest_service.dart';

Future<void> pinQuestsForGolden(AppDatabase db, String childId) =>
    db.settingsDao.setValue(
      childId: childId,
      key: questDayKey(db.clock.today()),
      value: '["dailyComplete","arena","towerFloor"]',
    );
