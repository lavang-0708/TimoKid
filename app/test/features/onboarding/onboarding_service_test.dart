/// Test lưu hồ sơ nhân vật + cờ hoàn thành mở đầu (T2-03).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/features/onboarding/onboarding_model.dart';
import 'package:timokid/features/onboarding/onboarding_service.dart';

void main() {
  late AppDatabase db;
  late String childId;
  late OnboardingService service;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    childId = await db.ensureSeeded();
    service = OnboardingService(db: db);
  });

  test('DB mới tạo: chưa xong mở đầu (onCreate gieo cờ false)', () async {
    expect(await service.isCompleted(), isFalse);
    expect(
      await db.settingsDao.getValue(
        key: OnboardingService.onboardingCompletedKey,
      ),
      'false',
    );
  });

  test(
    'máy 0.1 cũ (không có cờ): coi như đã xong, không bắt làm lại',
    () async {
      await db.settingsDao.deleteSetting(
        key: OnboardingService.onboardingCompletedKey,
      );
      expect(await service.isCompleted(), isTrue);
    },
  );

  test('xong mở đầu: lưu hồ sơ, đổi tên bé, lưu trứng, đặt cờ true', () async {
    const profile = CharacterProfile(
      gender: 'girl',
      skinColor: 0xFFFFE3CE,
      hairStyle: 'girl_hair_02',
      hairColor: 0xFFA9715C,
      eyeStyle: 'girl_eyes_03',
      eyeColor: 0xFF35C4D8,
      mouthStyle: 'girl_mouth_02',
      dress: 'girl_top_02',
      name: '  An  ',
    );
    await service.completeOnboarding(
      childId: childId,
      profile: profile,
      eggSpecies: 'cat',
    );

    final saved = await service.loadProfile(childId);
    expect(saved, isNotNull);
    expect(saved!.gender, 'girl');
    expect(saved.hairStyle, 'girl_hair_02');
    expect(saved.eyeStyle, 'girl_eyes_03');
    expect(saved.mouthStyle, 'girl_mouth_02');
    expect(saved.dress, 'girl_top_02');
    // Tên cắt khoảng trắng hai đầu khi lưu.
    expect(saved.name, 'An');

    final child = await db.childrenDao.getChild(childId);
    expect(child!.name, 'An');

    expect(
      await db.settingsDao.getValue(childId: childId, key: 'selected_egg'),
      'cat',
    );
    expect(await service.isCompleted(), isTrue);
  });

  test('chưa tạo hồ sơ thì loadProfile trả null', () async {
    expect(await service.loadProfile(childId), isNull);
  });

  test('JSON hồ sơ hỏng thì loadProfile trả null, không ném', () async {
    await db.settingsDao.setValue(
      childId: childId,
      key: OnboardingService.profileKey,
      value: 'không phải json',
    );
    expect(await service.loadProfile(childId), isNull);
  });

  group('kiểm tên nhân vật (chỉ kiểm độ dài 1–12 ký tự)', () {
    test('tên hợp lệ: 1 ký tự, 12 ký tự, có dấu', () {
      expect(isValidCharacterName('A'), isTrue);
      expect(isValidCharacterName('Trần An Bình'), isTrue);
      expect(isValidCharacterName('An'), isTrue);
    });

    test('tên không hợp lệ: rỗng, chỉ khoảng trắng, 13 ký tự', () {
      expect(isValidCharacterName(''), isFalse);
      expect(isValidCharacterName('   '), isFalse);
      expect(isValidCharacterName('Trần An Bìnhh'), isFalse);
    });
  });

  test('hồ sơ JSON đi-về giữ nguyên giá trị', () {
    final profile = CharacterProfile.defaults().copyWith(name: 'Bé An');
    final restored = CharacterProfile.fromJson(profile.toJson());
    expect(restored.toJson(), profile.toJson());
    // Váy đi-về giữ nguyên; mặc định là bộ đồ gốc (null), chọn lại
    // bộ đồ gốc qua `dressToNull` cũng về null.
    final withDress = profile.copyWith(dress: 'girl_top_01');
    expect(CharacterProfile.fromJson(withDress.toJson()).dress, 'girl_top_01');
    expect(withDress.copyWith(dressToNull: true).dress, isNull);
  });
}
