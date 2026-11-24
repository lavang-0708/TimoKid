import 'generators/arith_generators.dart';
import 'generators/comb_generators.dart';
import 'generators/geo_generators.dart';
import 'generators/logic_generators.dart';
import 'generators/number_generators.dart';
import 'generators/timo2_generators.dart';
import 'generators/timo3_generators.dart';
import 'generators/timo4_generators.dart';
import 'question.dart';

/// Toàn bộ 90 dạng bài của TimoKid: 48 dạng chuyển từ `gen.py`, 24 dạng
/// bổ sung theo đề vòng loại TIMO lớp 2 (`gen_timo2.py`), 12 dạng bổ sung
/// đợt 3 (`timo3_generators.dart`, ưu tiên Hình học) và 6 dạng đợt 4
/// (`timo4_generators.dart`, 24/11).
///
/// Mỗi dạng là một [QuestionGenerator] với mã dạng (`formId`) dạng
/// `mảng.tên`, vd `logic.balance`. Danh sách này là nguồn duy nhất để
/// đếm dạng bài: test nghiệm thu đối chiếu nó với `gen.py`.
const List<QuestionGenerator> allQuestionGenerators = [
  ...logicGenerators,
  ...arithGenerators,
  ...numberGenerators,
  ...geoGenerators,
  ...combGenerators,
  ...timo2LogicGenerators,
  ...timo2ArithGenerators,
  ...timo2NumberGenerators,
  ...timo2GeoGenerators,
  ...timo2CombGenerators,
  ...timo3LogicGenerators,
  ...timo3ArithGenerators,
  ...timo3NumberGenerators,
  ...timo3GeoGenerators,
  ...timo3CombGenerators,
  ...timo4LogicGenerators,
  ...timo4ArithGenerators,
  ...timo4NumberGenerators,
  ...timo4GeoGenerators,
  ...timo4CombGenerators,
];

/// Số dạng bài theo từng mảng (`gen.py` + `gen_timo2.py` + đợt 3 + đợt 4).
const Map<String, int> generatorCountByTopic = {
  'logic': 19,
  'arith': 16,
  'number': 18,
  'geo': 19,
  'comb': 18,
};

/// Tìm generator theo mã dạng, vd `questionGeneratorFor('logic.balance')`.
/// Trả về null nếu không có dạng nào mang mã đó.
QuestionGenerator? questionGeneratorFor(String formId) {
  for (final generator in allQuestionGenerators) {
    if (generator.formId == formId) {
      return generator;
    }
  }
  return null;
}
