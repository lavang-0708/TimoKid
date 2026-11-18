// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daos.dart';

// ignore_for_file: type=lint
mixin _$ChildrenDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChildrenTable get children => attachedDatabase.children;
  ChildrenDaoManager get managers => ChildrenDaoManager(this);
}

class ChildrenDaoManager {
  final _$ChildrenDaoMixin _db;
  ChildrenDaoManager(this._db);
  $$ChildrenTableTableManager get children =>
      $$ChildrenTableTableManager(_db.attachedDatabase, _db.children);
}

mixin _$AttemptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AttemptsTable get attempts => attachedDatabase.attempts;
  AttemptsDaoManager get managers => AttemptsDaoManager(this);
}

class AttemptsDaoManager {
  final _$AttemptsDaoMixin _db;
  AttemptsDaoManager(this._db);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db.attachedDatabase, _db.attempts);
}

mixin _$SkillProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $SkillProgressTable get skillProgress => attachedDatabase.skillProgress;
  SkillProgressDaoManager get managers => SkillProgressDaoManager(this);
}

class SkillProgressDaoManager {
  final _$SkillProgressDaoMixin _db;
  SkillProgressDaoManager(this._db);
  $$SkillProgressTableTableManager get skillProgress =>
      $$SkillProgressTableTableManager(_db.attachedDatabase, _db.skillProgress);
}

mixin _$ReviewQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReviewQueueTable get reviewQueue => attachedDatabase.reviewQueue;
  ReviewQueueDaoManager get managers => ReviewQueueDaoManager(this);
}

class ReviewQueueDaoManager {
  final _$ReviewQueueDaoMixin _db;
  ReviewQueueDaoManager(this._db);
  $$ReviewQueueTableTableManager get reviewQueue =>
      $$ReviewQueueTableTableManager(_db.attachedDatabase, _db.reviewQueue);
}

mixin _$DailySetsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailySetsTable get dailySets => attachedDatabase.dailySets;
  DailySetsDaoManager get managers => DailySetsDaoManager(this);
}

class DailySetsDaoManager {
  final _$DailySetsDaoMixin _db;
  DailySetsDaoManager(this._db);
  $$DailySetsTableTableManager get dailySets =>
      $$DailySetsTableTableManager(_db.attachedDatabase, _db.dailySets);
}

mixin _$WalletDaoMixin on DatabaseAccessor<AppDatabase> {
  $WalletLedgerTable get walletLedger => attachedDatabase.walletLedger;
  WalletDaoManager get managers => WalletDaoManager(this);
}

class WalletDaoManager {
  final _$WalletDaoMixin _db;
  WalletDaoManager(this._db);
  $$WalletLedgerTableTableManager get walletLedger =>
      $$WalletLedgerTableTableManager(_db.attachedDatabase, _db.walletLedger);
}

mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}
