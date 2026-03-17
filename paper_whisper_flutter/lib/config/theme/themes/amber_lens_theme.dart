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

// Amber Lens palette constants
const Color _amberBgCenter = Color(0xFF2C2C2C);
const Color _amberBgEdge = Color(0xFF000000);
const Color _amberPaper = Color(0xFF1E1E1E);
const Color _amberTextPrimary = Color(0xFFE0E0E0);
const Color _amberTextSecondary = Color(0xFF9E9E9E);
const Color _amberAccent = Color(0xFFFF9800);

/// 琥珀光圈主题
final amberLensTheme = PaperWhisperTheme(
  id: 'amber_lens',
  name: '琥珀光圈',
  description: '深邃皮革，暖橙微光',
  colors: ThemeColors(
    paperColor: _amberPaper,
    textPrimary: _amberTextPrimary,
    textSecondary: _amberTextSecondary,
    accent: _amberAccent,
    bgCenter: _amberBgCenter,
    bgEdge: _amberBgEdge,
    brightness: Brightness.dark,
    scaffoldBg: Color(0xFF1E1E1E),
    seedColor: Color(0xFFFF9800),
  ),
  background: const BoxDecoration(
    color: _amberBgEdge,
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [_amberBgCenter, _amberBgEdge],
      stops: [0.0, 1.0],
    ),
  ),
  sidebarBackground: BoxDecoration(
    color: const Color(0xFF1E1E1E).withOpacity(0.85),
    border: const Border(
      right: BorderSide(color: Color(0xFFFF9800), width: 1),
    ),
    boxShadow: const [
      BoxShadow(
        color: Colors.black,
        offset: Offset(2, 0),
        blurRadius: 10,
      ),
    ],
  ),
  systemUiOverlayStyle: SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ),
  backgroundOverlays: const [],
  fab: FabThemeData(
    bg: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
    ),
    shadow: const BoxShadow(
      color: Color.fromRGBO(255, 152, 0, 0.5),
      blurRadius: 15,
      offset: Offset(0, 0),
      spreadRadius: 2,
    ),
    iconColor: Colors.white,
  ),
  sidebar: SidebarThemeData(
    bgDecoration: const BoxDecoration(
      color: Color(0xFF2C2C2C),
      image: DecorationImage(
        image: AssetImage('assets/textures/leather_dark.png'),
        fit: BoxFit.cover,
        opacity: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black45,
          blurRadius: 10,
          offset: Offset(5, 0),
        ),
      ],
    ),
    textColor: const Color(0xFFBDBDBD),
    activeTextColor: const Color(0xFFFF9800),
    subTextColor: const Color(0xFF757575),
    hitokotoBackgroundColor: Colors.black26,
    hitokotoBorderColor: Colors.white10,
    dividerColor: Colors.white10,
    pillColor: const Color(0xFF222222),
    pillShadows: [
      BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
      BoxShadow(
        color: Colors.black87,
        offset: Offset(0, -2),
        blurRadius: 1,
      ),
    ],
    buttonGradient: const LinearGradient(
      colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
    ),
  ),
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: const Color(0xFF1E1E1E).withOpacity(0.78),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _amberAccent.withOpacity(0.18)),
      boxShadow: const [
        BoxShadow(
          color: Colors.black,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    dividerColor: _amberAccent.withOpacity(0.12),
    textColor: const Color(0xFFD7CCC8),
    activeSwitchColor: _amberAccent,
    activeTrackColor: _amberAccent.withOpacity(0.25),
    titleColor: _amberTextPrimary,
    titleShadow: const Shadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    iconColor: _amberAccent,
    showPetalRain: false,
    showStarrySky: false,
    sheetTextColor: _amberTextPrimary,
    sheetBackgroundColor: const Color(0xFF1E1E1E),
    sheetTitleColor: _amberTextPrimary,
    sheetTapeColor: const Color(0xFFFF9800),
    sheetShadows: const [
      BoxShadow(
        color: Colors.black,
        blurRadius: 20,
        offset: Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(
      color: _amberAccent.withOpacity(0.3),
      width: 1,
    ),
    sheetShowTape: false,
    sheetInfoBackgroundColor: Colors.white.withOpacity(0.08),
    sheetInfoBorderColor: _amberAccent.withOpacity(0.2),
    sheetInfoDividerColor: _amberAccent.withOpacity(0.15),
    optionSelectedBgColor: _amberAccent,
    optionSelectedTextColor: _amberTextPrimary,
    optionSelectedShadow: const BoxShadow(
      color: Colors.black26,
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: const Color(0xFF2C2C2C),
    optionUnselectedTextColor: const Color(0xFF9E9E9E),
    optionUnselectedBorder: Border.all(
      color: _amberAccent.withOpacity(0.3),
    ),
  ),
  editor: EditorThemeData(
    appBarBg: const Color(0xFF1E1E1E).withOpacity(0.9),
    iconColor: const Color(0xFFFF9800),
    cursorColor: const Color(0xFFFF9800),
    lineColor: const Color(0x1FFFFFFF),
    dividerColor: const Color(0xFFFF9800).withOpacity(0.15),
    appBarBorder: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
    applyBlur: false,
    saveButtonBg: const Color(0xFFFF9800),
    saveButtonTextColor: Colors.black,
    saveButtonCheckColor: Colors.black,
    dropdownBg: const Color(0xFFFAF9F6),
    dropdownText: const Color(0xFF5D4037),
    exportPaperColor: const Color(0xFF1E1E1E),
    exportBorderColor: const Color(0xFFFF9800),
    ribbonAccentColor: const Color(0xFFFF9800),
    hintColor: Colors.grey,
  ),
  diaryCard: DiaryCardThemeData(
    bgColor: const Color(0xFF1E1E1E).withOpacity(0.95),
    titleColor: const Color(0xFFE0E0E0),
    contentColor: const Color(0xFFBDBDBD),
    dateColor: _amberAccent,
    iconColor: _amberAccent,
    dashedLineColor: const Color(0x40FF9800),
    shadows: const [
      BoxShadow(
        color: Colors.black,
        offset: Offset(0, 4),
        blurRadius: 8,
      ),
    ],
    hoverShadows: const [
      BoxShadow(
        color: Color(0x66FF9800),
        offset: Offset(0, 0),
        blurRadius: 15,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Colors.black,
        offset: Offset(0, 10),
        blurRadius: 20,
      ),
    ],
    border: Border.all(color: const Color(0xFF424242)),
    hoverBorderColor: _amberAccent,
    dateWeight: FontWeight.w600,
    glassEffect: false,
    glassColor: Colors.transparent,
    blurSigma: 0.0,
    borderRadius: 6.0,
    hoverTranslateY: -4.0,
    hoverScale: 1.0,
    showStarWatermark: false,
    showFlowerWatermark: false,
    usePaperContainer: false,
  ),
  momentCard: MomentCardThemeData(
    cardColor: const Color(0xFF1E1E1E).withOpacity(0.96),
    textColor: _amberTextPrimary,
    metaColor: _amberTextSecondary,
    iconColor: _amberAccent,
    cardShadows: [
      const BoxShadow(
        color: Colors.black54,
        offset: Offset(0, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: _amberAccent.withOpacity(0.13),
        offset: const Offset(0, 0),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
    cardBorder: Border.all(color: _amberAccent.withOpacity(0.18)),
    useGlassEffect: false,
    cardBlurSigma: 0.001,
    imageStackColor: const Color(0xFF2C2C2C),
    imageStackBorderColor: _amberAccent.withOpacity(0.18),
    imageStackShadow: BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: Colors.black12,
    imageSurfaceShadow: BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: _amberAccent,
    indicatorInactiveColor: _amberTextSecondary.withOpacity(0.45),
    watermarkDividerColor: Colors.white10,
    audioSurfaceColor: Colors.white.withOpacity(0.06),
    audioSurfaceBorderColor: _amberAccent.withOpacity(0.2),
    audioButtonColor: _amberAccent,
    audioButtonIconColor: _amberTextPrimary,
    audioButtonShadow: BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: _amberTextSecondary.withOpacity(0.25),
    audioProgressColor: _amberAccent.withOpacity(0.75),
    audioDurationColor: _amberTextSecondary.withOpacity(0.9),
    deleteIconColor: _amberAccent.withOpacity(0.75),
  ),
  bookDirectory: const BookDirectoryThemeData(),
  moments: MomentsThemeData(
    rulerBg: const Color(0xFF1E1E1E).withOpacity(0.95),
    rulerTextColor: _amberTextSecondary,
    rulerInactiveTextColor: _amberTextSecondary.withOpacity(0.3),
    rulerSubTextColor: _amberAccent,
    rulerInactiveSubTextColor: _amberAccent.withOpacity(0.3),
    rulerIndicatorColor: _amberAccent,
    rulerShadowColor: Colors.black.withOpacity(0.3),
    rulerBorderColor: _amberAccent.withOpacity(0.15),
    appBarIconColor: Colors.white70,
    appBarTextColor: Colors.white,
    drawerScrimColor: Colors.black54,
    appBarBg: const Color(0xFF1E1E1E).withOpacity(0.5),
    emptyStateIconColor: _amberTextSecondary.withOpacity(0.72),
    emptyStateTextColor: _amberTextSecondary,
  ),
  search: const SearchThemeData(),
  monthDivider: const MonthDividerThemeData(),
  dialog: const AppDialogThemeData(),
  toast: const ToastThemeData(),
  lockScreen: const LockScreenThemeData(),
  mobileHeader: MobileHeaderColorsData(
    background: const Color(0xFF1E1E1E).withOpacity(0.9),
    border: const Color(0xFFFF9800).withOpacity(0.5),
    iconColor: const Color(0xFFFF9800),
    titleColor: const Color(0xFFE0E0E0),
    subtitleColor: const Color(0xFF9E9E9E),
  ),
  dialogInput: DialogInputThemeData(
    textColor: _amberTextPrimary,
    hintColor: _amberTextSecondary.withOpacity(0.5),
    borderColor: _amberAccent.withOpacity(0.4),
    focusedBorderColor: _amberAccent,
    iconColor: _amberAccent.withOpacity(0.6),
    backgroundColor: Colors.black.withOpacity(0.3),
    descriptionColor: _amberTextSecondary,
  ),
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFFF9800).withOpacity(0.3),
        width: 1,
      ),
    ),
    cardShadow: BoxShadow(
      color: const Color(0xFFFF9800).withOpacity(0.2),
      blurRadius: 15,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
    cardBorder: Border.all(
      color: const Color(0xFFFF9800).withOpacity(0.3),
      width: 1,
    ),
    accentColor: const Color(0xFFFF9800),
    textColor: const Color(0xFFE0E0E0),
    secondaryTextColor: const Color(0xFF9E9E9E),
    chartColor: const Color(0xFFFFB74D),
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: const Color(0xFFFF9800).withOpacity(0.2),
      textColor: const Color(0xFFFF9800),
      borderColor: const Color(0xFFFF9800).withOpacity(0.4),
    ),
  ),
  trashPage: TrashPageThemeData(
    titleColor: const Color(0xFFE0E0E0),
    iconColor: _amberAccent,
    restoreColor: Colors.green,
    dangerColor: Colors.redAccent,
    cardTitleColor: const Color(0xFFE0E0E0),
    cardDateColor: const Color(0xFFE0E0E0).withOpacity(0.6),
    cardDecoration: BoxDecoration(
      color: const Color(0xFF2C2C2C).withOpacity(0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _amberAccent.withOpacity(0.3), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Colors.black,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
  ),
  syncSettings: SyncSettingsThemeData(
    titleColor: const Color(0xFFE0E0E0),
    textColor: const Color(0xFFD7CCC8),
    accentColor: _amberAccent,
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
    containerColor: const Color(0xFF1E1E1E).withOpacity(0.96),
    containerShadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.45),
        offset: const Offset(0, -2),
        blurRadius: 6,
      ),
      BoxShadow(
        color: _amberAccent.withOpacity(0.12),
        offset: const Offset(0, -4),
        blurRadius: 12,
      ),
    ],
    inputBgColor: const Color(0xFF2C2C2C),
    inputBorderColor: _amberAccent.withOpacity(0.3),
    textColor: _amberTextPrimary,
    hintColor: _amberTextSecondary,
    iconColor: _amberAccent,
    sendColor: _amberAccent,
    imageIconColor: const Color(0xFFFFB74D),
    cursorColor: _amberAccent,
    recordingColor: const Color(0xFFE53935),
    cancelColor: _amberTextSecondary,
    imageRemoveBgColor: Colors.black.withOpacity(0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF1E1E1E),
    cassetteDeckBorderColor: _amberAccent.withOpacity(0.35),
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
    cassetteLabelColor: const Color(0xFFE0E0E0),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: _amberAccent.withOpacity(0.35),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: _amberAccent,
    cassetteScrewColor: Colors.white.withOpacity(0.24),
    miniCassetteBgColor: const Color(0xFF1E1E1E),
    miniCassettePlayColor: _amberAccent,
    miniCassetteTextColor: _amberTextPrimary,
    miniCassetteHintColor: _amberTextSecondary,
    miniCassetteDeleteColor: _amberTextSecondary.withOpacity(0.8),
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
    bookColor: const Color(0xFFFF6F00),
    pageColor: const Color(0xFF424242),
    textColor: const Color(0xFFFFB74D),
  ),
  privacyDialog: PrivacyDialogThemeData(
    linkColor: const Color(0xFFFF9800),
    contentTextColor: const Color(0xFFBDBDBD),
    disclaimerTextColor: const Color(0xFF9E9E9E),
  ),
  paperSheet: PaperSheetThemeData(
    paperColor: _amberPaper,
    accentColor: const Color(0xFFFF9800),
    border: Border.all(color: const Color(0xFFFF9800), width: 1),
    shadows: const [
      BoxShadow(
        color: Colors.black,
        offset: Offset(0, 5),
        blurRadius: 20,
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
    emptyStateIconColor: Colors.grey.shade500.withOpacity(0.7),
    emptyStateTextColor: Colors.grey.shade400,
    emptyStateLinkColor: _amberAccent,
    updateDialogSecondaryColor: const Color(0xFF8D6E63),
  ),
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: const Color(0xFF1E1E1E),
    textColor: const Color(0xFFE0E0E0),
    metaColor: const Color(0xFF9E9E9E),
  ),
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFF1E1E1E),
    headerBg: Colors.black,
    headerText: const Color(0xFFE0E0E0),
    bodyText: const Color(0xFFBDBDBD),
    accentColor: const Color(0xFFFF9800),
    weekDayColor: const Color(0xFFFB8C00),
    border: Border.all(color: const Color(0xFFFF9800), width: 1),
    shadows: const [],
  ),
);
