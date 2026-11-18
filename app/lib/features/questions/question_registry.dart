import 'generators/arith_generators.dart';
import 'generators/comb_generators.dart';
import 'generators/geo_generators.dart';
import 'generators/logic_generators.dart';
import 'generators/number_generators.dart';
import 'question.dart';

/// Toàn bộ 48 dạng bài của TimoKid, chuyển từ `gen.py`.
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
];

/// Số dạng bài theo từng mảng, khớp với `gen.py`.
const Map<String, int> generatorCountByTopic = {
  'logic': 11,
  'arith': 7,
  'number': 10,
  'geo': 9,
  'comb': 11,
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
