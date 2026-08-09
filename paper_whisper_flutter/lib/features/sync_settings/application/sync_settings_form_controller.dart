import 'package:flutter/widgets.dart';

import '../../../models/sync_config.dart';
import '../../../providers/sync_provider.dart';

/// 同步设置表单动作的 typed 结果（context-free，不含任何 UI 文案）。
///
/// 页面负责把结果翻译为既有 Toast 文案；本类型不复制
/// '连接成功，配置已保存' 等用户可见文案，也不复制任何同步算法。
sealed class SyncFormActionOutcome {
  const SyncFormActionOutcome();
}

/// 保存成功（saveAndTest 中连接测试同样成功）。
class SyncFormActionSaved extends SyncFormActionOutcome {
  const SyncFormActionSaved();
}

/// 配置已保存但连接测试失败；[lastError] 原样透传 provider 的错误信息，
/// 由页面决定展示原文还是兜底文案。
class SyncFormActionTestFailed extends SyncFormActionOutcome {
  const SyncFormActionTestFailed({required this.lastError});

  final String lastError;
}

/// 表单校验未通过，未执行任何 gateway 调用。
class SyncFormActionInvalid extends SyncFormActionOutcome {
  const SyncFormActionInvalid();
}

/// 保存/测试过程抛出异常。
class SyncFormActionError extends SyncFormActionOutcome {
  const SyncFormActionError();
}

/// 窄 gateway：只暴露表单动作所需的 [SyncProvider] 能力。
///
/// 不暴露 sync 算法、通知、调度等能力，避免控制器越过职责边界。
abstract class SyncProviderGateway {
  SyncConfig get config;

  String get lastError;

  Future<void> saveConfig(SyncConfig config);

  Future<bool> connect();
}

/// 生产实现：包装 [SyncProvider]。
class SyncProviderGatewayImpl implements SyncProviderGateway {
  SyncProviderGatewayImpl(this._provider);

  final SyncProvider _provider;

  @override
  SyncConfig get config => _provider.config;

  @override
  String get lastError => _provider.lastError;

  @override
  Future<void> saveConfig(SyncConfig config) => _provider.saveConfig(config);

  @override
  Future<bool> connect() => _provider.connect();
}

/// 同步设置表单控制器（context-free，不持有 BuildContext）。
///
/// 拥有并负责释放 8 个 TextEditingController（WebDAV 3 + S3 5），
/// 以及 autoSync / compressImages / syncType 三个草稿状态。职责：
/// - hydrate：从 [SyncConfig] 填充全部输入与开关（含 bootstrap 引导后刷新）；
/// - build：以 base 配置 copyWith 构建草稿配置，严格保留默认值、secret 与
///   storage key 语义（未覆盖字段原样透传，空 region 归一为 null）；
/// - 切协议：只切换 syncType，8 个输入与开关全部保留；
/// - 校验：逐字复刻页面的 required / serverUrl 校验与整体 validate()；
/// - 动作：saveAndTest / disableSync 经窄 gateway 编排，返回 typed outcome。
///
/// 迁移来源：sync_settings_page.dart 的 8 个 controller、_autoSync、
/// _compressImages、_buildDraftConfig、_validateRequiredField、
/// _validateServerUrl、_saveAndTest、_disableSync。
///
/// 手动同步（_syncNow）不在此实现：它依赖 SyncUiCoordinator（持 BuildContext）
/// 完成权限前置与结果 Toast，属于展示/应用协调边界，保留在页面。
class SyncSettingsFormController {
  SyncSettingsFormController({required SyncConfig config})
    : serverController = TextEditingController(text: config.serverUrl),
      usernameController = TextEditingController(text: config.username),
      passwordController = TextEditingController(text: config.password),
      s3EndPointController = TextEditingController(text: config.s3EndPoint),
      s3AccessKeyController = TextEditingController(text: config.s3AccessKey),
      s3SecretKeyController = TextEditingController(text: config.s3SecretKey),
      s3BucketController = TextEditingController(text: config.s3BucketName),
      s3RegionController = TextEditingController(text: config.s3Region ?? ''),
      autoSync = config.autoSync,
      compressImages = config.compressImages,
      _syncType = config.syncType;

  /// WebDAV 输入控制器。
  final TextEditingController serverController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  /// S3 输入控制器。
  final TextEditingController s3EndPointController;
  final TextEditingController s3AccessKeyController;
  final TextEditingController s3SecretKeyController;
  final TextEditingController s3BucketController;
  final TextEditingController s3RegionController;

  /// 草稿开关状态（与页面 _autoSync / _compressImages 一一对应）。
  bool autoSync;
  bool compressImages;
  SyncType _syncType;

  SyncType get syncType => _syncType;

  /// 切协议：仅切换草稿协议，8 个输入与开关全部保留。
  void setSyncType(SyncType type) => _syncType = type;

  /// 用最新 [config] 重新填充全部输入与开关（bootstrap 引导完成后的刷新）。
  void hydrate(SyncConfig config) {
    serverController.text = config.serverUrl;
    usernameController.text = config.username;
    passwordController.text = config.password;
    s3EndPointController.text = config.s3EndPoint;
    s3AccessKeyController.text = config.s3AccessKey;
    s3SecretKeyController.text = config.s3SecretKey;
    s3BucketController.text = config.s3BucketName;
    s3RegionController.text = config.s3Region ?? '';
    autoSync = config.autoSync;
    compressImages = config.compressImages;
    _syncType = config.syncType;
  }

  /// 构建草稿配置：以 [base] 为底 copyWith，逐字复刻页面 _buildDraftConfig。
  ///
  /// 覆盖 8 个输入（trim）与三个草稿状态；其余字段（默认值、secret、storage
  /// key 语义）由 copyWith 原样透传；region 为空串归一为 null。
  SyncConfig buildConfig({required SyncConfig base, required bool enabled}) {
    return base.copyWith(
      serverUrl: serverController.text.trim(),
      username: usernameController.text.trim(),
      password: passwordController.text.trim(),
      autoSync: autoSync,
      compressImages: compressImages,
      enabled: enabled,
      syncType: _syncType,
      s3EndPoint: s3EndPointController.text.trim(),
      s3AccessKey: s3AccessKeyController.text.trim(),
      s3SecretKey: s3SecretKeyController.text.trim(),
      s3BucketName: s3BucketController.text.trim(),
      s3Region: s3RegionController.text.trim().isEmpty
          ? null
          : s3RegionController.text.trim(),
    );
  }

  /// 逐字复刻页面 _validateServerUrl：必填 + http(s):// 前缀。
  String? validateServerUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入服务器地址';
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '服务器地址需以 http:// 或 https:// 开头';
    }
    return null;
  }

  /// 逐字复刻页面 _validateRequiredField。
  String? validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  /// 当前协议可见字段的整体校验，等价于页面 Form.validate()。
  ///
  /// WebDAV：serverUrl + username + password；
  /// S3：endPoint + bucket + accessKey + secretKey（region 可选，不校验）。
  bool validate() {
    switch (_syncType) {
      case SyncType.webdav:
        return validateServerUrl(serverController.text) == null &&
            validateRequired(usernameController.text, '请输入账号') == null &&
            validateRequired(passwordController.text, '请输入密码或应用授权码') == null;
      case SyncType.s3:
        return validateRequired(s3EndPointController.text, '请输入 Endpoint 地址') ==
                null &&
            validateRequired(s3BucketController.text, '请输入 Bucket 名称') ==
                null &&
            validateRequired(s3AccessKeyController.text, '请输入 Access Key') ==
                null &&
            validateRequired(s3SecretKeyController.text, '请输入 Secret Key') ==
                null;
    }
  }

  /// 保存并测试连接：整体校验后经 [gateway] 保存（enabled=true）并 connect。
  ///
  /// 逐字复刻页面 _saveAndTest 的编排（校验 → saveConfig → connect），
  /// loading 状态与 Toast 反馈留在页面。
  Future<SyncFormActionOutcome> saveAndTest(SyncProviderGateway gateway) async {
    if (!validate()) {
      return const SyncFormActionInvalid();
    }
    try {
      await gateway.saveConfig(
        buildConfig(base: gateway.config, enabled: true),
      );
      final connected = await gateway.connect();
      return connected
          ? const SyncFormActionSaved()
          : SyncFormActionTestFailed(lastError: gateway.lastError);
    } catch (_) {
      return const SyncFormActionError();
    }
  }

  /// 停用同步：经 [gateway] 保存 enabled=false。
  ///
  /// 与页面 _disableSync 一致：不做表单校验（停用不要求配置完整）。
  Future<SyncFormActionOutcome> disableSync(SyncProviderGateway gateway) async {
    try {
      await gateway.saveConfig(
        buildConfig(base: gateway.config, enabled: false),
      );
      return const SyncFormActionSaved();
    } catch (_) {
      return const SyncFormActionError();
    }
  }

  /// 释放全部 8 个输入控制器。
  void dispose() {
    serverController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    s3EndPointController.dispose();
    s3AccessKeyController.dispose();
    s3SecretKeyController.dispose();
    s3BucketController.dispose();
    s3RegionController.dispose();
  }
}
