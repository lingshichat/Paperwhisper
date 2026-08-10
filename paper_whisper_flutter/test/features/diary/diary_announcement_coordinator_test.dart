import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_announcement_coordinator.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';

/// DiaryAnnouncementCoordinator 单元测试（阶段 4 Wave B1，两阶段 typed 协议）。
///
/// 契约覆盖（逐字保持 `diary_list_page._checkAndShowAnnouncement`）：
/// - prepare：只读版本，same → none；different → pending；失败 typed；
///   **绝不写 key、不加载本地公告**；
/// - resolve：严格先记录 `last_run_version` 再加载本地公告；
///   null → none（key 已写、仅不展示）；存在 → show；异常 → failure；
/// - 契约：prepare 返回 pending 但未 resolve 时**不写 key**。
///
/// 纯逻辑测试：注入 fake gateway，不触碰 SharedPreferences / rootBundle。
void main() {
  late FakeDiaryAnnouncementGateway gateway;
  late DiaryAnnouncementCoordinator coordinator;

  setUp(() {
    gateway = FakeDiaryAnnouncementGateway();
    coordinator = DiaryAnnouncementCoordinator(gateway: gateway);
  });

  UpdateInfo localInfo() => UpdateInfo(
    latestVersion: '1.0.0',
    title: '版本更新公告',
    changelog: const ['✨ [新增] 测试公告'],
  );

  group('prepare', () {
    test('版本相同：返回 none，不写 key、不加载本地公告', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '1.0.0';
      gateway.localInfo = localInfo();

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementNone>());
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
      expect(gateway.events, ['getCurrentVersion', 'getLastRunVersion']);
    });

    test('版本不同：返回 pending，携带 currentVersion，不写 key、不加载', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '0.9.0';
      gateway.localInfo = localInfo();

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementPending>());
      expect((outcome as DiaryAnnouncementPending).currentVersion, '1.0.0');
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
      expect(gateway.events, ['getCurrentVersion', 'getLastRunVersion']);
    });

    test('首次运行（无上次版本记录）：返回 pending，不写 key', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = null;

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementPending>());
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
    });

    test('读取当前版本失败：返回 failure，不写 key、不加载', () async {
      gateway.currentVersion = '1.0.0';
      gateway.currentVersionError = Exception('version read failed');

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementFailure>());
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
    });

    test('读取上次运行版本失败：返回 failure，不写 key、不加载', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersionError = Exception('last version read failed');

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementFailure>());
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
    });
  });

  group('resolve', () {
    DiaryAnnouncementPending pending(String version) =>
        DiaryAnnouncementPending(version);

    test('严格先写 key 再加载本地公告，存在则返回 show', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '0.9.0';
      gateway.localInfo = localInfo();

      final outcome = await coordinator.resolve(pending('1.0.0'));

      expect(outcome, isA<DiaryAnnouncementShow>());
      expect((outcome as DiaryAnnouncementShow).info.title, '版本更新公告');
      expect(gateway.recordedVersions, ['1.0.0']);
      expect(gateway.localInfoLoadCount, 1);
      // 调用顺序：写 key → 加载公告
      expect(gateway.events, ['setLastRunVersion', 'getLocalUpdateInfo']);
    });

    test('本地公告为 null：key 已写、仅不展示，返回 none', () async {
      gateway.localInfo = null;

      final outcome = await coordinator.resolve(pending('1.0.0'));

      expect(outcome, isA<DiaryAnnouncementNone>());
      expect(gateway.recordedVersions, ['1.0.0']); // key 已写，仅不展示
      expect(gateway.localInfoLoadCount, 1);
    });

    test('写 key 失败：返回 failure，不加载本地公告', () async {
      gateway.setVersionError = Exception('key write failed');

      final outcome = await coordinator.resolve(pending('1.0.0'));

      expect(outcome, isA<DiaryAnnouncementFailure>());
      expect(gateway.localInfoLoadCount, 0);
    });

    test('加载本地公告失败：返回 failure（key 已写，UI 不变）', () async {
      gateway.localInfoError = Exception('asset load failed');

      final outcome = await coordinator.resolve(pending('1.0.0'));

      expect(outcome, isA<DiaryAnnouncementFailure>());
      expect(gateway.recordedVersions, ['1.0.0']);
    });
  });

  group('两阶段契约', () {
    test('prepare 返回 pending 但未 resolve：不写 key、不加载公告', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '0.9.0';
      gateway.localInfo = localInfo();

      await coordinator.prepare();

      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
    });

    test('prepare + resolve 完整链路：先读版本，后写 key 再加载', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '0.9.0';
      gateway.localInfo = localInfo();

      final prepared = await coordinator.prepare();
      expect(prepared, isA<DiaryAnnouncementPending>());
      final outcome = await coordinator.resolve(
        prepared as DiaryAnnouncementPending,
      );

      expect(outcome, isA<DiaryAnnouncementShow>());
      expect(gateway.events, [
        'getCurrentVersion',
        'getLastRunVersion',
        'setLastRunVersion',
        'getLocalUpdateInfo',
      ]);
    });

    test('版本相同链路：prepare none 后不 resolve，始终无写操作', () async {
      gateway.currentVersion = '1.0.0';
      gateway.lastRunVersion = '1.0.0';
      gateway.localInfo = localInfo();

      final outcome = await coordinator.prepare();

      expect(outcome, isA<DiaryAnnouncementNone>());
      expect(gateway.recordedVersions, isEmpty);
      expect(gateway.localInfoLoadCount, 0);
    });
  });
}

/// 记录调用事件与版本写入的 fake 网关。
class FakeDiaryAnnouncementGateway implements DiaryAnnouncementGateway {
  String? currentVersion = '1.0.0';
  String? lastRunVersion;
  UpdateInfo? localInfo;

  Object? currentVersionError;
  Object? lastRunVersionError;
  Object? setVersionError;
  Object? localInfoError;

  final List<String> events = [];
  final List<String> recordedVersions = [];
  int localInfoLoadCount = 0;

  @override
  Future<String?> getLastRunVersion() async {
    events.add('getLastRunVersion');
    if (lastRunVersionError != null) throw lastRunVersionError!;
    return lastRunVersion;
  }

  @override
  Future<void> setLastRunVersion(String version) async {
    events.add('setLastRunVersion');
    if (setVersionError != null) throw setVersionError!;
    recordedVersions.add(version);
  }

  @override
  Future<String> getCurrentVersion() async {
    events.add('getCurrentVersion');
    if (currentVersionError != null) throw currentVersionError!;
    return currentVersion!;
  }

  @override
  Future<UpdateInfo?> getLocalUpdateInfo() async {
    events.add('getLocalUpdateInfo');
    localInfoLoadCount++;
    if (localInfoError != null) throw localInfoError!;
    return localInfo;
  }
}
