enum SyncTrustState {
  notEnabled,
  localChangesPending,
  syncing,
  syncedSuccessfully,
  syncFailed,
  needsAttention,
}

class SyncTrustSnapshot {
  final SyncTrustState state;
  final int pendingDiaryCount;
  final int pendingMomentCount;
  final int pendingImageCount;
  final int pendingAudioCount;
  final DateTime? lastSuccessfulSyncAt;
  final String? lastSuccessfulSyncPlatform;
  final String? failureReason;
  final bool configurationInvalid;

  const SyncTrustSnapshot({
    required this.state,
    this.pendingDiaryCount = 0,
    this.pendingMomentCount = 0,
    this.pendingImageCount = 0,
    this.pendingAudioCount = 0,
    this.lastSuccessfulSyncAt,
    this.lastSuccessfulSyncPlatform,
    this.failureReason,
    this.configurationInvalid = false,
  });

  static const SyncTrustSnapshot notEnabled = SyncTrustSnapshot(
    state: SyncTrustState.notEnabled,
  );

  int get totalPendingCount =>
      pendingDiaryCount +
      pendingMomentCount +
      pendingImageCount +
      pendingAudioCount;

  bool get hasPendingChanges => totalPendingCount > 0;

  bool get canRetry =>
      state == SyncTrustState.syncFailed ||
      state == SyncTrustState.needsAttention ||
      hasPendingChanges;

  SyncTrustSnapshot copyWith({
    SyncTrustState? state,
    int? pendingDiaryCount,
    int? pendingMomentCount,
    int? pendingImageCount,
    int? pendingAudioCount,
    DateTime? lastSuccessfulSyncAt,
    String? lastSuccessfulSyncPlatform,
    String? failureReason,
    bool? configurationInvalid,
    bool clearLastSuccessfulSyncAt = false,
    bool clearFailureReason = false,
  }) {
    return SyncTrustSnapshot(
      state: state ?? this.state,
      pendingDiaryCount: pendingDiaryCount ?? this.pendingDiaryCount,
      pendingMomentCount: pendingMomentCount ?? this.pendingMomentCount,
      pendingImageCount: pendingImageCount ?? this.pendingImageCount,
      pendingAudioCount: pendingAudioCount ?? this.pendingAudioCount,
      lastSuccessfulSyncAt: clearLastSuccessfulSyncAt
          ? null
          : (lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt),
      lastSuccessfulSyncPlatform: clearLastSuccessfulSyncAt
          ? null
          : (lastSuccessfulSyncPlatform ?? this.lastSuccessfulSyncPlatform),
      failureReason: clearFailureReason
          ? null
          : (failureReason ?? this.failureReason),
      configurationInvalid: configurationInvalid ?? this.configurationInvalid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'pendingDiaryCount': pendingDiaryCount,
      'pendingMomentCount': pendingMomentCount,
      'pendingImageCount': pendingImageCount,
      'pendingAudioCount': pendingAudioCount,
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
      'lastSuccessfulSyncPlatform': lastSuccessfulSyncPlatform,
      'failureReason': failureReason,
      'configurationInvalid': configurationInvalid,
    };
  }

  factory SyncTrustSnapshot.fromJson(Map<String, dynamic> json) {
    final stateName = json['state']?.toString();

    return SyncTrustSnapshot(
      state: SyncTrustState.values.firstWhere(
        (value) => value.name == stateName,
        orElse: () => SyncTrustState.notEnabled,
      ),
      pendingDiaryCount: json['pendingDiaryCount'] ?? 0,
      pendingMomentCount: json['pendingMomentCount'] ?? 0,
      pendingImageCount: json['pendingImageCount'] ?? 0,
      pendingAudioCount: json['pendingAudioCount'] ?? 0,
      lastSuccessfulSyncAt: json['lastSuccessfulSyncAt'] == null
          ? null
          : DateTime.tryParse(json['lastSuccessfulSyncAt'] as String),
      lastSuccessfulSyncPlatform: json['lastSuccessfulSyncPlatform']
          ?.toString(),
      failureReason: json['failureReason']?.toString(),
      configurationInvalid: json['configurationInvalid'] ?? false,
    );
  }
}
