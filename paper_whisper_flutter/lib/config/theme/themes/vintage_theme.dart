import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../paper_whisper_theme.dart';
import '../theme_colors.dart';
import '../components/fab_theme_data.dart';
import '../components/sidebar_theme_data.dart';
import '../components/settings_theme_data.dart';
import '../components/editor_theme_data.dart';
import '../components/diary_card_theme_data.dart';
import '../components/moment_card_theme_data.dart';
import '../components/book_directory_theme_data.dart';
import '../components/moments_theme_data.dart';
import '../components/search_theme_data.dart';
import '../components/month_divider_theme_data.dart';
import '../components/dialog_theme_data.dart';
import '../components/toast_theme_data.dart';
import '../components/lock_screen_theme_data.dart';
import '../components/mobile_header_colors_data.dart';
import '../components/dialog_input_theme_data.dart';
import '../components/statistics_theme_data.dart';
import '../components/trash_page_theme_data.dart';
import '../components/sync_settings_theme_data.dart';
import '../components/moment_input_theme_data.dart';
import '../components/moment_editor_theme_data.dart';
import '../components/refresh_indicator_theme_data.dart';
import '../components/privacy_dialog_theme_data.dart';
import '../components/paper_sheet_theme_data.dart';
import '../components/diary_list_page_theme_data.dart';
import '../components/moment_standard_card_theme_data.dart';
import '../components/date_picker_theme_data.dart';

// Vintage palette constants
const Color _vintageBgCenter = Color(0xFF4a3b32);
const Color _vintageBgEdge = Color(0xFF2d241f);
const Color _vintagePaper = Color(0xFFF4ECD8);
const Color _vintageTextPrimary = Color(0xFF2C3E50);
const Color _vintageTextSecondary = Color(0xFF5D4037);
const Color _vintageAccent = Color(0xFFFF3D00);

/// 复古纸张主题
final vintageTheme = PaperWhisperTheme(
  id: 'default',
  name: '复古纸张',
  description: '深色圆木，温润如玉',
  colors: ThemeColors(
    paperColor: _vintagePaper,
    textPrimary: _vintageTextPrimary,
    textSecondary: _vintageTextSecondary,
    accent: _vintageAccent,
    bgCenter: _vintageBgCenter,
    bgEdge: _vintageBgEdge,
    brightness: Brightness.dark,
    scaffoldBg: Color(0xFF2d241f),
    seedColor: Colors.brown,
  ),
  background: const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.25,
      colors: [_vintageBgCenter, _vintageBgEdge],
      stops: [0.0, 1.0],
    ),
  ),
  sidebarBackground: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3e2723), Color(0xFF281815)],
    ),
    border: Border(right: BorderSide(color: Color(0xFF1a100d), width: 1)),
    boxShadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.3),
        offset: Offset(2, 0),
        blurRadius: 10,
        spreadRadius: -2,
      ),
    ],
  ),
  systemUiOverlayStyle: SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF2d241f),
    systemNavigationBarIconBrightness: Brightness.light,
  ),
  backgroundOverlays: const [],
  fab: FabThemeData(
    bg: const Color(0xFFC0392B),
    shadow: const BoxShadow(color: Colors.transparent),
    iconColor: Colors.white,
  ),
  sidebar: SidebarThemeData(
    bgDecoration: const BoxDecoration(
      color: Color(0xFF3E2723),
      image: DecorationImage(
        image: AssetImage('assets/textures/leather_dark.png'),
        fit: BoxFit.cover,
        opacity: 0.6,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black45,
          blurRadius: 10,
          offset: Offset(5, 0),
        ),
      ],
    ),
    textColor: const Color(0xFFD7CCC8),
    activeTextColor: const Color(0xFFFF5252),
    subTextColor: const Color(0xFFA1887F),
    hitokotoBackgroundColor: Colors.black26,
    hitokotoBorderColor: Colors.white10,
    dividerColor: Colors.white10,
    pillColor: const Color(0xFF2D1E1B),
    pillShadows: [
      BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
      BoxShadow(
        color: Colors.black87,
        offset: Offset(0, -2),
        blurRadius: 1,
      ),
    ],
    buttonGradient: const LinearGradient(
      colors: [Color(0xFFE57373), Color(0xFFD32F2F)],
    ),
  ),
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: const Color(0xFF3E2723).withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _vintagePaper.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    dividerColor: _vintagePaper.withOpacity(0.1),
    textColor: _vintagePaper,
    activeSwitchColor: _vintageAccent,
    activeTrackColor: _vintageAccent.withOpacity(0.3),
    titleColor: _vintagePaper,
    titleShadow: const Shadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    iconColor: _vintagePaper.withOpacity(0.8),
    showPetalRain: false,
    showStarrySky: false,
    sheetTextColor: const Color(0xFF5D4037),
    sheetBackgroundColor: const Color(0xFFF4ECD8),
    sheetTitleColor: const Color(0xFF5D4037),
    sheetTapeColor: const Color(0xD9E0E0E0),
    sheetShadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.2),
        blurRadius: 20,
        offset: Offset(0, -5),
      ),
    ],
    sheetShowTape: true,
    sheetInfoBackgroundColor: const Color(0xFFF7F1E3),
    sheetInfoBorderColor: const Color(0xFFE0D6C2),
    sheetInfoDividerColor: const Color(0xFF5D4037),
    optionSelectedBgColor: const Color(0xFF5D4037),
    optionSelectedTextColor: _vintagePaper,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(93, 64, 55, 0.4),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: const Color(0xFFEFEBE9),
    optionUnselectedTextColor: const Color(0xFF8D6E63),
    optionUnselectedShadow: const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ),
  editor: EditorThemeData(
    appBarBg: const Color(0xFF281815).withOpacity(0.75),
    iconColor: const Color(0xFFD7CCC8),
    cursorColor: const Color(0xFFC0392B),
    lineColor: const Color(0xFF5D4037).withOpacity(0.12),
    dividerColor: const Color(0xFF5D4037).withOpacity(0.15),
    applyBlur: false,
    saveButtonBg: const Color(0xFFF7F1E3),
    saveButtonTextColor: const Color(0xFF5D4037),
    saveButtonCheckColor: const Color(0xFFC0392B),
    dropdownBg: const Color(0xFFFAF9F6),
    dropdownText: const Color(0xFF5D4037),
    exportPaperColor: const Color(0xFFF4ECD8),
    exportBorderColor: const Color(0xFFC0392B),
    ribbonAccentColor: const Color(0xFFC0392B),
    hintColor: Colors.black26,
  ),
  diaryCard: DiaryCardThemeData(
    bgColor: _vintagePaper,
    titleColor: const Color(0xFF5D4037),
    contentColor: const Color(0xFF5D4037).withOpacity(0.9),
    dateColor: const Color(0xFF8D6E63),
    iconColor: const Color(0xFF8D6E63),
    dashedLineColor: const Color.fromRGBO(93, 64, 55, 0.15),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.1),
        offset: Offset(0, 5),
        blurRadius: 10,
      ),
    ],
    hoverShadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.15),
        offset: Offset(0, 10),
        blurRadius: 20,
      ),
    ],
    dateWeight: FontWeight.normal,
    glassEffect: false,
    glassColor: Colors.transparent,
    blurSigma: 0.0,
    borderRadius: 4.0,
    hoverTranslateY: -4.0,
    hoverScale: 1.0,
    showStarWatermark: false,
    showFlowerWatermark: false,
    usePaperContainer: true,
  ),
  momentCard: MomentCardThemeData(
    cardColor: _vintagePaper.withOpacity(0.96),
    textColor: const Color(0xFF3E2723),
    metaColor: const Color(0xFF8D6E63),
    iconColor: const Color(0xFF8D6E63),
    cardShadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        offset: const Offset(1, 2),
        blurRadius: 3,
      ),
    ],
    cardBorder: Border.all(color: const Color(0xFFE7DCC8)),
    useGlassEffect: false,
    cardBlurSigma: 0.001,
    imageStackColor: Colors.white,
    imageStackBorderColor: const Color(0xFFE0D6C2),
    imageStackShadow: BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFFF5F1E8),
    imageSurfaceShadow: BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: const Color(0xFF8D6E63),
    indicatorInactiveColor: const Color(0xFFBCAAA4).withOpacity(0.7),
    watermarkDividerColor: Colors.black.withOpacity(0.05),
    audioSurfaceColor: const Color(0xFF5D4037).withOpacity(0.08),
    audioSurfaceBorderColor: const Color(0xFF5D4037).withOpacity(0.15),
    audioButtonColor: const Color(0xFF8D6E63),
    audioButtonIconColor: Colors.white,
    audioButtonShadow: BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: const Color(0xFF8D6E63).withOpacity(0.2),
    audioProgressColor: const Color(0xFF8D6E63).withOpacity(0.75),
    audioDurationColor: const Color(0xFF8D6E63).withOpacity(0.8),
    deleteIconColor: const Color(0xFF8D6E63).withOpacity(0.75),
  ),
  bookDirectory: const BookDirectoryThemeData(),
  moments: MomentsThemeData(
    // 恢复复古纸张主题下刻度尺的原始深灰底色
    rulerBg: const Color(0xFF1E1E1E),
    rulerTextColor: const Color(0xFFD7CCC8),
    rulerInactiveTextColor: const Color(0xFFD7CCC8).withOpacity(0.3),
    rulerSubTextColor: _vintageAccent,
    rulerInactiveSubTextColor: _vintageAccent.withOpacity(0.3),
    rulerIndicatorColor: _vintageAccent,
    rulerShadowColor: Colors.black.withOpacity(0.3),
    rulerBorderColor: Colors.white.withOpacity(0.08),
    appBarIconColor: const Color(0xFFD7CCC8),
    appBarTextColor: const Color(0xFFD7CCC8),
    drawerScrimColor: Colors.black54,
    appBarBg: const Color(0xFF1E1E1E).withOpacity(0.5),
    emptyStateIconColor: const Color(0xFFD7CCC8).withValues(alpha: 0.78),
    emptyStateTextColor: const Color(0xFFD7CCC8),
  ),
  search: const SearchThemeData(),
  monthDivider: const MonthDividerThemeData(),
  dialog: const AppDialogThemeData(),
  toast: const ToastThemeData(),
  lockScreen: const LockScreenThemeData(),
  mobileHeader: MobileHeaderColorsData(
    background: const Color(0xFF3e2723).withOpacity(0.85),
    border: const Color(0xFF1a100d),
    iconColor: const Color(0xFFD7CCC8),
    titleColor: const Color(0xFFEEFFEB),
    subtitleColor: const Color(0xFFD7CCC8).withOpacity(0.8),
  ),
  dialogInput: DialogInputThemeData(
    textColor: const Color(0xFF5D4037),
    hintColor: const Color(0xFF5D4037).withOpacity(0.4),
    borderColor: const Color(0xFF5D4037).withOpacity(0.2),
    focusedBorderColor: const Color(0xFF5D4037).withOpacity(0.6),
    iconColor: const Color(0xFF5D4037).withOpacity(0.4),
    backgroundColor: Colors.white.withOpacity(0.5),
    descriptionColor: const Color(0xFF5D4037).withOpacity(0.7),
  ),
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      color: _vintagePaper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFF5D4037).withOpacity(0.2),
        width: 1,
      ),
    ),
    cardShadow: BoxShadow(
      color: const Color(0xFF3E2723).withOpacity(0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
    cardBorder: Border.all(
      color: const Color(0xFF5D4037).withOpacity(0.2),
      width: 1,
    ),
    accentColor: const Color(0xFFFF3D00),
    textColor: const Color(0xFF2C3E50),
    secondaryTextColor: const Color(0xFF5D4037),
    chartColor: const Color(0xFFFF3D00),
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: const Color(0xFFFF3D00).withOpacity(0.15),
      textColor: const Color(0xFFFF3D00),
      borderColor: const Color(0xFFFF3D00).withOpacity(0.3),
    ),
  ),
  trashPage: TrashPageThemeData(
    titleColor: _vintagePaper,
    iconColor: const Color(0xFFD7CCC8),
    restoreColor: Colors.green,
    dangerColor: Colors.redAccent,
    cardTitleColor: const Color(0xFF2d241f),
    cardDateColor: const Color(0xFF5D4037).withOpacity(0.6),
    cardDecoration: BoxDecoration(
      color: const Color(0xFFF4F0E6),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: const Color(0xFF5D4037).withOpacity(0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
  ),
  syncSettings: SyncSettingsThemeData(
    titleColor: _vintagePaper,
    textColor: const Color(0xFFD7CCC8),
    accentColor: const Color(0xFF795548),
    lockBtnColor: const Color(0xFF5D4037),
    switchTrackColor: const Color(0xFFD7CCC8),
    switchThumbColor: const Color(0xFFEFEBE9),
    switchActiveText: const Color(0xFF5D4037),
    switchInactiveText: const Color(0xFF5D4037).withOpacity(0.5),
    primaryBtnColor: const Color(0xFF5D4037),
    primaryShadowColor: Colors.black26,
    secondaryBtnColor: Colors.white.withOpacity(0.2),
    secondaryBtnTextColor: const Color(0xFF3E2723),
    secondaryBorderColor: Colors.white.withOpacity(0.1),
    tipsBgColor: Colors.white.withOpacity(0.2),
    switchBgColor: Colors.black.withOpacity(0.05),
    slidingSwitchShadowOpacity: 0.05,
    thumbShadowOpacity: 0.1,
  ),
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFF2D1E1B),
    containerShadows: const [
      BoxShadow(
        color: Colors.black38,
        offset: Offset(0, -2),
        blurRadius: 4,
      ),
    ],
    inputBgColor: const Color(0xFF3E2723),
    inputBorderColor: const Color(0xFF5D4037),
    textColor: const Color(0xFFD7CCC8),
    hintColor: const Color(0xFFA1887F),
    iconColor: const Color(0xFFD7CCC8),
    sendColor: Colors.white,
    imageIconColor: const Color(0xFFA1887F),
    cursorColor: _vintageAccent,
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFFA1887F),
    imageRemoveBgColor: Colors.black.withOpacity(0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF2D1E1B),
    cassetteDeckBorderColor: const Color(0xFF5D4037),
    cassetteDeckShadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.08),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
    ],
    cassetteLabelColor: _vintagePaper,
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFF8D6E63),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: _vintageAccent.withOpacity(0.85),
    cassetteScrewColor: Colors.white.withOpacity(0.24),
    miniCassetteBgColor: const Color(0xFF3E2723),
    miniCassettePlayColor: const Color(0xFFD7CCC8),
    miniCassetteTextColor: const Color(0xFFD7CCC8),
    miniCassetteHintColor: const Color(0xFFA1887F),
    miniCassetteDeleteColor: const Color(0xFFA1887F).withOpacity(0.8),
  ),
  momentEditor: MomentEditorThemeData(
    bgColor: const Color(0xFFF4ECD8),
    appBarTextColor: const Color(0xFF5D4037),
    appBarIconColor: const Color(0xFF5D4037),
    inputBg: Colors.white.withOpacity(0.5),
    inputTextColor: const Color(0xFF3E2723),
    hintColor: const Color(0xFF3E2723).withOpacity(0.5),
    dropdownBg: Colors.white.withOpacity(0.5),
    dropdownIconColor: const Color(0xFF8D6E63),
    dropdownMenuBg: const Color(0xFFF4ECD8),
    dropdownItemColor: const Color(0xFF5D4037),
    photoEmptyColor: Colors.white.withOpacity(0.3),
    photoIconColor: const Color(0xFF8D6E63),
  ),
  refreshIndicator: AppRefreshIndicatorThemeData(
    bookColor: const Color(0xFF6D4C41),
    pageColor: const Color(0xFFFAF8F5),
    textColor: const Color(0xFF8D6E63),
  ),
  privacyDialog: PrivacyDialogThemeData(
    linkColor: const Color(0xFF6D4C41),
    contentTextColor: const Color(0xFF5D4037),
    disclaimerTextColor: const Color(0xFF8D6E63),
  ),
  paperSheet: PaperSheetThemeData(
    paperColor: _vintagePaper,
    accentColor: const Color(0xFFC0392B),
    border: const Border(top: BorderSide(color: Color(0xFFC0392B), width: 8)),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 5),
        blurRadius: 10,
        spreadRadius: 0,
      ),
    ],
    borderRadius: 2.0,
    useGlassEffect: false,
  ),
  diaryListPage: DiaryListPageThemeData(
    drawerScrimColor: Colors.black54,
    headerBoxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
    headerApplyBlur: false,
    emptyStateIconColor: const Color(0xFFD7CCC8).withOpacity(0.5),
    emptyStateTextColor: const Color(0xFFD7CCC8).withOpacity(0.8),
    emptyStateLinkColor: const Color(0xFFFF5252),
    updateDialogSecondaryColor: const Color(0xFF8D6E63),
  ),
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: Colors.white,
    textColor: const Color(0xFF3E2723),
    metaColor: Colors.grey[400]!,
  ),
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFFF4ECD8),
    headerBg: const Color(0xFF5D4037),
    headerText: const Color(0xFFF4ECD8),
    bodyText: const Color(0xFF5D4037),
    accentColor: const Color(0xFFD32F2F),
    weekDayColor: const Color(0xFF795548),
    border: Border.all(color: const Color(0xFF3E2723), width: 1),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.3),
        offset: Offset(0, 5),
        blurRadius: 5,
        spreadRadius: -2,
      ),
    ],
  ),
);
