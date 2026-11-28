/// Provider Riverpod cho đăng nhập và đồng bộ (T3-03/T3-04).
///
/// Test ghi đè [httpClientProvider] (bằng `MockClient`) và
/// [sessionStoreProvider] (bằng [MemorySessionStore]) nên không cần mạng.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../database/database_provider.dart';
import 'neon_client.dart';
import 'session_store.dart';
import 'sync_config.dart';
import 'sync_engine.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final neonClientProvider = Provider<NeonClient>(
  (ref) => NeonClient(
    client: ref.watch(httpClientProvider),
    store: ref.watch(sessionStoreProvider),
  ),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    db: ref.watch(databaseProvider),
    client: ref.watch(neonClientProvider),
  ),
);

/// Khóa `settings` (chung, chỉ trên máy): đã hỏi đăng nhập lần đầu rồi
/// (đã đăng nhập hoặc bấm "Dùng không cần tài khoản"). Tiền tố `sync_`
/// nên không bao giờ đồng bộ.
const loginPromptDoneKey = 'sync_login_prompt_done';

// ------------------------------------------------------------- đăng nhập

class AuthState {
  const AuthState({this.signedIn = false, this.email, this.busy = false});

  final bool signedIn;
  final String? email;
  final bool busy;

  AuthState copyWith({bool? signedIn, String? email, bool? busy}) => AuthState(
    signedIn: signedIn ?? this.signedIn,
    email: email ?? this.email,
    busy: busy ?? this.busy,
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  NeonClient get _client => ref.read(neonClientProvider);

  /// Đọc phiên đã lưu (gọi một lần lúc mở app).
  Future<void> refresh() async {
    final signedIn = await _client.hasSession();
    state = AuthState(
      signedIn: signedIn,
      email: signedIn ? await _client.savedEmail() : null,
    );
  }

  /// Đăng nhập (hoặc đăng ký nếu [signUp]); xong gọi `ensure_family`
  /// rồi đồng bộ ngay. Ném [NeonException] (thông điệp tiếng Việt) khi lỗi.
  Future<void> signIn(
    String email,
    String password, {
    bool signUp = false,
  }) async {
    state = state.copyWith(busy: true);
    try {
      if (signUp) {
        await _client.signUp(email, password);
      } else {
        await _client.signIn(email, password);
      }
      try {
        await _client.ensureFamily();
      } on NeonException {
        // Đăng nhập đã xong; bộ đồng bộ sẽ gọi lại ensure_family.
      }
      state = AuthState(signedIn: true, email: email);
    } on Object {
      state = state.copyWith(busy: false);
      rethrow;
    }
    final sync = ref.read(syncControllerProvider.notifier);
    sync.startPeriodic();
    unawaited(sync.syncNow());
  }

  Future<void> signOut() async {
    await _client.signOut();
    state = const AuthState();
    ref.read(syncControllerProvider.notifier).reset();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

// ------------------------------------------------------------- đồng bộ

enum SyncStatus { signedOut, syncing, synced, offline, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.signedOut,
    this.lastSyncedAt,
    this.message,
    this.revision = 0,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? message;

  /// Tăng sau mỗi lần đồng bộ xong (thành công) để màn hình tải lại
  /// (vd hiện chấm đỏ khi có thư mới).
  final int revision;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? message,
    int? revision,
  }) => SyncState(
    status: status ?? this.status,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
    revision: revision ?? this.revision,
  );
}

class SyncController extends Notifier<SyncState> {
  Timer? _timer;

  @override
  SyncState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SyncState();
  }

  /// Về trạng thái chưa đăng nhập (sau đăng xuất).
  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const SyncState();
  }

  /// Bắt đầu đồng bộ định kỳ (mỗi 15 phút khi app đang mở).
  void startPeriodic() {
    _timer?.cancel();
    _timer = Timer.periodic(SyncConfig.interval, (_) => syncNow());
  }

  /// Đồng bộ sau một việc (xong chặng, nhận quà...): không chờ, không ném lỗi.
  void syncSoon() {
    // microtask: có nơi gọi từ trong lúc dựng giao diện.
    unawaited(Future.microtask(syncNow));
  }

  Future<SyncResult> syncNow() async {
    if (state.status == SyncStatus.syncing) {
      return const SyncResult(SyncOutcome.ok);
    }
    final before = state;
    state = state.copyWith(status: SyncStatus.syncing);
    final SyncResult result;
    try {
      result = await ref.read(syncEngineProvider).syncOnce();
    } on Object catch (e) {
      state = before.copyWith(status: SyncStatus.error, message: '$e');
      return SyncResult(SyncOutcome.error, message: '$e');
    }
    switch (result.outcome) {
      case SyncOutcome.ok:
        state = SyncState(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          revision: state.revision + 1,
        );
      case SyncOutcome.offline:
        state = before.copyWith(
          status: SyncStatus.offline,
          message: result.message,
        );
      case SyncOutcome.needsLogin:
        state = before.copyWith(
          status: SyncStatus.error,
          message: 'Cần đăng nhập lại.',
        );
      case SyncOutcome.error:
        state = before.copyWith(
          status: SyncStatus.error,
          message: result.message,
        );
      case SyncOutcome.notSignedIn:
        state = SyncState(revision: state.revision);
    }
    return result;
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Bọc quanh app: đọc phiên khi mở app, đồng bộ ngay nếu đã đăng nhập,
/// đồng bộ định kỳ, và đồng bộ khi app quay lại từ nền.
class SyncHost extends ConsumerStatefulWidget {
  const SyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncHost> createState() => _SyncHostState();
}

class _SyncHostState extends ConsumerState<SyncHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    await ref.read(authProvider.notifier).refresh();
    if (!mounted || !ref.read(authProvider).signedIn) return;
    ref.read(syncControllerProvider.notifier).startPeriodic();
    await ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(authProvider).signedIn) {
      ref.read(syncControllerProvider.notifier).syncSoon();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
