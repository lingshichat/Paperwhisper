import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';

void main() {
  test('pending snapshot survives json round trip', () {
    const snapshot = SyncTrustSnapshot(
      state: SyncTrustState.localChangesPending,
      pendingDiaryCount: 2,
      pendingMomentCount: 1,
      pendingImageCount: 3,
      lastSuccessfulSyncPlatform: 's3',
    );

    final roundTrip = SyncTrustSnapshot.fromJson(snapshot.toJson());

    expect(roundTrip.state, SyncTrustState.localChangesPending);
    expect(roundTrip.totalPendingCount, 6);
    expect(roundTrip.lastSuccessfulSyncPlatform, 's3');
  });
}
