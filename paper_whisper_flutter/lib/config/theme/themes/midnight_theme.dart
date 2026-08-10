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
import 'package:paper_whisper_flutter/shared/widgets/visual_effects.dart';

// Midnight palette constants
const Color _midnightBgCenter = Color(0xFF1a237e);
const Color _midnightBgMid = Color(0xFF050510);
const Color _midnightBgEdge = Colors.black;
const Color _midnightPaper = Color(0xFF161b22);
const Color _midnightTextPrimary = Color(0xFFe6edf3);
const Color _midnightTextSecondary = Color(0xFF8b949e);
const Color _midnightAccent = Color(0xFF7986cb);

/// 午夜星尘主题
final midnightTheme = PaperWhisperTheme(
  id: 'midnight',
  name: '午夜星尘',
  description: '静谧深夜，独处时光',
  colors: ThemeColors(
    paperColor: _midnightPaper,
    textPrimary: _midnightTextPrimary,
    textSecondary: _midnightTextSecondary,
    accent: _midnightAccent,
    bgCenter: _midnightBgCenter,
    bgEdge: Colors.black,
    brightness: Brightness.dark,
    scaffoldBg: Color(0xFF050510),
    seedColor: Color(0xFF3949AB),
  ),
  background: BoxDecoration(
    color: _midnightBgEdge,
    gradient: const RadialGradient(
      center: Alignment(0, 0.5),
      radius: 1.2,
      colors: [_midnightBgCenter, _midnightBgMid, _midnightBgEdge],
      stops: [0.0, 0.4, 1.0],
    ),
  ),
  sidebarBackground: BoxDecoration(
    color: const Color(0xFF0D1117).withValues(alpha: 0.7),
    border: const Border(right: BorderSide(color: Color(0x0DFFFFFF))),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(1, 0),
        blurRadius: 15,
      ),
    ],
  ),
  systemUiOverlayStyle: SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ),
  backgroundOverlays: const [Positioned.fill(child: StarrySkyWidget())],
  fab: FabThemeData(
    backgroundGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7986cb), Color(0xFF303f9f)],
    ),
    shadow: const BoxShadow(
      color: Color.fromRGBO(121, 134, 203, 0.5),
      blurRadius: 15,
      offset: Offset(0, 0),
      spreadRadius: 2,
    ),
    iconColor: Colors.white,
  ),
  sidebar: SidebarThemeData(
    bgDecoration: const BoxDecoration(
      color: Color(0xFF0D1117),
      border: Border(right: BorderSide(color: Colors.white12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black87,
          blurRadius: 10,
          offset: Offset(5, 0),
        ),
      ],
    ),
    textColor: const Color(0xFFc9d1d9),
    activeTextColor: const Color(0xFF7986cb),
    subTextColor: const Color(0xFF8b949e),
    hitokotoBackgroundColor: Colors.black26,
    hitokotoBorderColor: Colors.white10,
    dividerColor: Colors.white10,
    pillColor: const Color(0xFF161b22),
    pillShadows: [
      BoxShadow(
        color: Color.fromRGBO(121, 134, 203, 0.2),
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ],
    pillBorder: Border.all(color: Colors.white10),
    buttonGradient: const LinearGradient(
      colors: [Color(0xFF7986cb), Color(0xFF3F51B5)],
    ),
    buttonShadow: BoxShadow(
      color: const Color(0xFF3F51B5).withValues(alpha: 0.4),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ),
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: const Color(0xFF161b22).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF30363d)),
      boxShadow: const [
        BoxShadow(
          color: Colors.black,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    dividerColor: const Color(0xFF30363d),
    textColor: const Color(0xFFc9d1d9),
    activeSwitchColor: _midnightAccent,
    activeTrackColor: _midnightAccent.withValues(alpha: 0.3),
    titleColor: _midnightTextPrimary,
    titleShadow: const Shadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    iconColor: _midnightAccent,
    showPetalRain: false,
    showStarrySky: true,
    sheetTextColor: const Color(0xFFc9d1d9),
    sheetBackgroundColor: const Color(0xFF161b22),
    sheetTitleColor: _midnightTextPrimary,
    sheetTapeColor: const Color(0xFF30363d),
    sheetShadows: const [
      BoxShadow(
        color: Colors.black,
        blurRadius: 20,
        offset: Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(color: const Color(0xFF30363d), width: 1),
    sheetShowTape: false,
    sheetInfoBackgroundColor: const Color(0xFF0D1117).withValues(alpha: 0.6),
    sheetInfoBorderColor: const Color(0xFF30363d),
    sheetInfoDividerColor: Colors.white.withValues(alpha: 0.08),
    optionSelectedBgColor: const Color(0xFF5C6BC0),
    optionSelectedTextColor: _midnightTextPrimary,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(92, 107, 192, 0.4),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: const Color(0xFF21262d),
    optionUnselectedTextColor: const Color(0xFF8b949e),
    optionUnselectedBorder: Border.all(color: const Color(0xFF30363d)),
  ),
  editor: EditorThemeData(
    appBarBg: const Color(0xFF0D1117).withValues(alpha: 0.9),
    iconColor: const Color(0xFFc9d1d9),
    cursorColor: const Color(0xFF7986cb),
    lineColor: Colors.white.withValues(alpha: 0.08),
    dividerColor: Colors.white.withValues(alpha: 0.1),
    applyBlur: false,
    saveButtonBg: const Color(0xFFF7F1E3),
    saveButtonTextColor: const Color(0xFF5D4037),
    saveButtonCheckColor: const Color(0xFFC0392B),
    dropdownBg: const Color(0xFF2D333B),
    dropdownText: const Color(0xFFc9d1d9),
    exportPaperColor: const Color(0xFF161b22),
    exportBorderColor: const Color(0xFF30363d),
    ribbonAccentColor: const Color(0xFF7986cb),
    hintColor: Colors.white24,
  ),
  diaryCard: DiaryCardThemeData(
    bgColor: const Color(0xFF161b22).withValues(alpha: 0.9),
    titleColor: const Color(0xFFe6edf3),
    contentColor: const Color(0xFF8b949e),
    dateColor: const Color(0xFF8b949e),
    iconColor: const Color(0xFF7986cb),
    dashedLineColor: const Color(0xFF30363d),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 4),
        blurRadius: 10,
      ),
    ],
    hoverShadows: const [
      BoxShadow(
        color: Color(0xFF7986cb),
        offset: Offset(0, 0),
        blurRadius: 15,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.8),
        offset: Offset(0, 10),
        blurRadius: 25,
      ),
    ],
    border: Border.all(color: const Color(0xFF30363d)),
    hoverBorderColor: const Color(0xFF7986cb),
    dateWeight: FontWeight.normal,
    glassEffect: false,
    glassColor: Colors.transparent,
    blurSigma: 0.0,
    borderRadius: 6.0,
    hoverTranslateY: -4.0,
    hoverScale: 1.0,
    showStarWatermark: true,
    showFlowerWatermark: false,
    usePaperContainer: false,
  ),
  momentCard: MomentCardThemeData(
    cardColor: const Color(0xFF161B22).withValues(alpha: 0.95),
    textColor: _midnightTextPrimary,
    metaColor: _midnightTextSecondary,
    iconColor: _midnightAccent,
    cardShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.54),
        offset: const Offset(0, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: _midnightAccent.withValues(alpha: 0.16),
        offset: const Offset(0, 0),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
    cardBorder: Border.all(color: const Color(0xFF30363D)),
    useGlassEffect: false,
    cardBlurSigma: 0.001,
    imageStackColor: const Color(0xFF1F242B),
    imageStackBorderColor: const Color(0xFF30363D),
    imageStackShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFF0D1117),
    imageSurfaceShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: _midnightAccent,
    indicatorInactiveColor: Colors.white.withValues(alpha: 0.18),
    watermarkDividerColor: Colors.white.withValues(alpha: 0.1),
    audioSurfaceColor: const Color(0xFF0D1117).withValues(alpha: 0.72),
    audioSurfaceBorderColor: const Color(0xFF30363D),
    audioButtonColor: _midnightAccent,
    audioButtonIconColor: _midnightTextPrimary,
    audioButtonShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: const Color(0xFF30363D),
    audioProgressColor: _midnightAccent.withValues(alpha: 0.7),
    audioDurationColor: _midnightTextSecondary.withValues(alpha: 0.9),
    deleteIconColor: _midnightAccent.withValues(alpha: 0.75),
  ),
  bookDirectory: const BookDirectoryThemeData(),
  moments: MomentsThemeData(
    rulerBg: const Color(0xFF0D1117).withValues(alpha: 0.95),
    rulerTextColor: _midnightTextSecondary,
    rulerInactiveTextColor: _midnightTextSecondary.withValues(alpha: 0.3),
    rulerSubTextColor: _midnightAccent,
    rulerInactiveSubTextColor: _midnightAccent.withValues(alpha: 0.3),
    rulerIndicatorColor: _midnightAccent,
    rulerShadowColor: Colors.black.withValues(alpha: 0.4),
    rulerBorderColor: Colors.white.withValues(alpha: 0.1),
    appBarIconColor: Colors.white70,
    appBarTextColor: Colors.white,
    drawerScrimColor: Colors.black54,
    appBarBg: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
    emptyStateIconColor: _midnightTextSecondary.withValues(alpha: 0.7),
    emptyStateTextColor: _midnightTextSecondary,
  ),
  search: const SearchThemeData(),
  monthDivider: MonthDividerThemeData(
    textColor: const Color(0xFFE8EAF6),
    lineColor: const Color(0xFF5C6BC0).withValues(alpha: 0.5),
    paperColor: const Color(0xFF283593).withValues(alpha: 0.9),
    shadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  dialog: const AppDialogThemeData(),
  toast: const ToastThemeData(),
  lockScreen: const LockScreenThemeData(),
  mobileHeader: MobileHeaderColorsData(
    background: const Color(0xFF0D1117).withValues(alpha: 0.9),
    border: const Color(0xFF21262d),
    iconColor: const Color(0xFFc9d1d9),
    titleColor: const Color(0xFFe6edf3),
    subtitleColor: const Color(0xFF8b949e),
  ),
  dialogInput: DialogInputThemeData(
    textColor: Colors.white70,
    hintColor: Colors.white30,
    borderColor: Colors.white24,
    focusedBorderColor: Colors.white54,
    iconColor: Colors.white38,
    backgroundColor: Colors.black.withValues(alpha: 0.3),
    descriptionColor: Colors.white54,
  ),
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1a237e), Color(0xFF283593)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    ),
    cardShadow: BoxShadow(
      color: const Color(0xFF7986cb).withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
    cardBorder: Border.all(
      color: Colors.white.withValues(alpha: 0.1),
      width: 1,
    ),
    accentColor: const Color(0xFF7986cb),
    textColor: const Color(0xFFe6edf3),
    secondaryTextColor: const Color(0xFF8b949e),
    chartColor: const Color(0xFF7986cb),
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: const Color(0xFF1a237e).withValues(alpha: 0.6),
      textColor: const Color(0xFF7986cb),
      borderColor: const Color(0xFF7986cb).withValues(alpha: 0.3),
    ),
  ),
  trashPage: TrashPageThemeData(
    titleColor: _midnightTextPrimary,
    iconColor: const Color(0xFFc9d1d9),
    restoreColor: const Color(0xFF69f0ae),
    dangerColor: const Color(0xFFff5252),
    cardTitleColor: _midnightTextPrimary,
    cardDateColor: _midnightTextPrimary.withValues(alpha: 0.6),
    cardDecoration: BoxDecoration(
      color: const Color(0xFF161b22).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF30363d), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Colors.black,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
  ),
  syncSettings: SyncSettingsThemeData(
    titleColor: _midnightTextPrimary,
    textColor: const Color(0xFFc9d1d9),
    accentColor: _midnightAccent,
    lockBtnColor: _midnightAccent,
    switchTrackColor: const Color(0xFF0D1117),
    switchThumbColor: const Color(0xFF37474F),
    switchActiveText: _midnightAccent,
    switchInactiveText: Colors.white54,
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF7986cb), Color(0xFF283593)],
    ),
    primaryShadowColor: const Color(0xFF283593).withValues(alpha: 0.4),
    secondaryBtnColor: const Color(0xFF21262d),
    secondaryBtnTextColor: const Color(0xFFc9d1d9),
    secondaryBorderColor: Colors.white.withValues(alpha: 0.1),
    tipsBgColor: const Color(0xFF161b22).withValues(alpha: 0.8),
    switchBgColor: const Color(0xFF0D1117).withValues(alpha: 0.5),
    slidingSwitchShadowOpacity: 0.3,
    thumbShadowOpacity: 0.3,
  ),
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFF0D1117),
    containerShadows: const [
      BoxShadow(
        color: Colors.black45,
        offset: Offset(0, -1),
        blurRadius: 4,
      ),
    ],
    inputBgColor: const Color(0xFF161B22),
    inputBorderColor: const Color(0xFF30363D),
    textColor: const Color(0xFFc9d1d9),
    hintColor: const Color(0xFF8B949E).withValues(alpha: 0.7),
    iconColor: const Color(0xFF7986CB),
    sendColor: const Color(0xFF7986CB),
    imageIconColor: const Color(0xFF8B949E),
    cursorColor: const Color(0xFF7986CB),
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFF8B949E).withValues(alpha: 0.7),
    imageRemoveBgColor: Colors.black.withValues(alpha: 0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF161B22),
    cassetteDeckBorderColor: const Color(0xFF30363D),
    cassetteDeckShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.08),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
    ],
    cassetteLabelColor: const Color(0xFFE6EDF3),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFF7986CB).withValues(alpha: 0.45),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: const Color(0xFF7986CB),
    cassetteScrewColor: Colors.white.withValues(alpha: 0.24),
    miniCassetteBgColor: const Color(0xFF161B22),
    miniCassettePlayColor: const Color(0xFF7986CB),
    miniCassetteTextColor: const Color(0xFFE6EDF3),
    miniCassetteHintColor: const Color(0xFF8B949E),
    miniCassetteDeleteColor: const Color(0xFF8B949E).withValues(alpha: 0.8),
  ),
  momentEditor: MomentEditorThemeData(
    bgColor: const Color(0xFFF4ECD8),
    appBarTextColor: const Color(0xFF5D4037),
    appBarIconColor: const Color(0xFF5D4037),
    inputBg: Colors.white.withValues(alpha: 0.5),
    inputTextColor: const Color(0xFF3E2723),
    hintColor: const Color(0xFF3E2723).withValues(alpha: 0.5),
    dropdownBg: Colors.white.withValues(alpha: 0.5),
    dropdownIconColor: const Color(0xFF8D6E63),
    dropdownMenuBg: const Color(0xFFF4ECD8),
    dropdownItemColor: const Color(0xFF5D4037),
    photoEmptyColor: Colors.white.withValues(alpha: 0.3),
    photoIconColor: const Color(0xFF8D6E63),
  ),
  refreshIndicator: AppRefreshIndicatorThemeData(
    bookColor: const Color(0xFF5C6BC0),
    pageColor: const Color(0xFFE8EAF6),
    textColor: const Color(0xFFB0BEC5),
  ),
  privacyDialog: PrivacyDialogThemeData(
    linkColor: const Color(0xFF7986cb),
    contentTextColor: const Color(0xFFc9d1d9),
    disclaimerTextColor: const Color(0xFF8b949e),
  ),
  paperSheet: PaperSheetThemeData(
    paperColor: _midnightPaper,
    accentColor: const Color(0xFF7986cb),
    border: Border.all(color: const Color(0xFF30363d), width: 1),
    shadows: const [
      BoxShadow(
        color: Colors.black,
        offset: Offset(0, 4),
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
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
    headerApplyBlur: false,
    emptyStateIconColor: Colors.grey.shade500.withValues(alpha: 0.7),
    emptyStateTextColor: Colors.grey.shade400,
    emptyStateLinkColor: _midnightAccent,
    updateDialogSecondaryColor: const Color(0xFF8b949e),
  ),
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: const Color(0xFF1E1E1E),
    textColor: const Color(0xFFE0E0E0),
    metaColor: Colors.grey[400]!,
  ),
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFF161b22),
    headerBg: const Color(0xFF0D1117),
    headerText: const Color(0xFFe6edf3),
    bodyText: const Color(0xFFc9d1d9),
    accentColor: const Color(0xFF7986cb),
    weekDayColor: const Color(0xFF8b949e),
    border: Border.all(color: const Color(0xFF30363d)),
    shadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  ),
);
