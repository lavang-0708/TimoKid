import 'generators/arith_generators.dart';
import 'generators/comb_generators.dart';
import 'generators/geo_generators.dart';
import 'generators/logic_generators.dart';
import 'generators/number_generators.dart';
import 'generators/timo2_generators.dart';
import 'question.dart';

/// Toàn bộ 72 dạng bài của TimoKid: 48 dạng chuyển từ `gen.py` và 24 dạng
/// bổ sung theo đề vòng loại TIMO lớp 2 (`gen_timo2.py`).
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
];

/// Số dạng bài theo từng mảng (`gen.py` + `gen_timo2.py`).
const Map<String, int> generatorCountByTopic = {
  'logic': 16,
  'arith': 13,
  'number': 16,
  'geo': 11,
  'comb': 16,
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
