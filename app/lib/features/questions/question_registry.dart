import 'generators/arith_generators.dart';
import 'generators/comb_generators.dart';
import 'generators/geo_generators.dart';
import 'generators/logic_generators.dart';
import 'generators/number_generators.dart';
import 'generators/timo2_generators.dart';
import 'generators/timo3_generators.dart';
import 'question.dart';

/// Toàn bộ 84 dạng bài của TimoKid: 48 dạng chuyển từ `gen.py`, 24 dạng
/// bổ sung theo đề vòng loại TIMO lớp 2 (`gen_timo2.py`) và 12 dạng bổ sung
/// đợt 3 (`timo3_generators.dart`, ưu tiên Hình học).
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
];

/// Số dạng bài theo từng mảng (`gen.py` + `gen_timo2.py` + đợt 3).
const Map<String, int> generatorCountByTopic = {
  'logic': 18,
  'arith': 15,
  'number': 17,
  'geo': 17,
  'comb': 17,
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
