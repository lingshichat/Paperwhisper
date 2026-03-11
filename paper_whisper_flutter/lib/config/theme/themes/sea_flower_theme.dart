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
import '../../../widgets/visual_effects.dart';

/// 海底花海主题
final seaFlowerTheme = PaperWhisperTheme(
  id: 'sea_flower',
  name: '海底花海',
  description: '深邃梦境，繁花相拥',

  // --- ThemeColors ---
  colors: ThemeColors(
    paperColor: const Color(0xD9FFFFFF),
    textPrimary: const Color(0xFF880E4F),
    textSecondary: const Color(0xFFC2185B),
    accent: const Color(0xFFF50057),
    bgCenter: const Color(0xFFF6D9E6),
    bgEdge: const Color(0xFFCDA8C7),
    brightness: Brightness.light,
    scaffoldBg: const Color(0xFFF6D9E6),
    seedColor: const Color(0xFFF06292),
  ),

  // --- Background ---
  background: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFEFDFF),
        Color(0xFFF6D9E6),
        Color(0xFFDBBAD0),
        Color(0xFFCDA8C7),
      ],
      stops: [0.0, 0.3, 0.6, 1.0],
    ),
  ),

  // --- Sidebar Background ---
  sidebarBackground: BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    border: const Border(
      right: BorderSide(color: Color(0x4DFFFFFF), width: 1),
    ),
  ),

  // --- System UI Overlay Style ---
  systemUiOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: const Color(0xFFF6D9E6),
    systemNavigationBarIconBrightness: Brightness.dark,
  ),

  // --- Background Overlays ---
  backgroundOverlays: const [Positioned.fill(child: PetalRainWidget())],

  // --- FAB ---
  fab: const FabThemeData(
    bg: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF8BBD0), Color(0xFFF06292)],
    ),
    shadow: BoxShadow(
      color: Color.fromRGBO(240, 98, 146, 0.5),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    iconColor: Colors.white,
  ),

  // --- Sidebar ---
  sidebar: SidebarThemeData(
    bgDecoration: BoxDecoration(
      color: const Color(0xFFFCE4EC).withOpacity(0.6),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(5, 0),
        ),
      ],
    ),
    textColor: const Color(0xFF880E4F),
    activeTextColor: const Color(0xFFD81B60),
    subTextColor: const Color(0xFFBC477B),
    pillColor: Colors.white,
    pillShadows: [
      BoxShadow(
        color: const Color(0xFFF48FB1).withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
    buttonGradient: const LinearGradient(
      colors: [Color(0xFFF06292), Color(0xFFD81B60)],
    ),
    buttonShadow: BoxShadow(
      color: const Color(0xFFD81B60).withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ),

  // --- Settings ---
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF48FB1).withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    dividerColor: Colors.white.withOpacity(0.3),
    textColor: const Color(0xFFAD1457),
    activeSwitchColor: const Color(0xFFEC407A),
    activeTrackColor: const Color(0xFFF48FB1).withOpacity(0.3),
    titleColor: const Color(0xFF880E4F),
    titleShadow: const Shadow(
      color: Color.fromRGBO(255, 255, 255, 0.5),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    iconColor: const Color(0xFFEC407A),
    showPetalRain: true,
    showStarrySky: false,
    sheetTextColor: const Color(0xFF880E4F),
    sheetBackgroundColor: const Color(0xFFFCE4EC),
    sheetTitleColor: const Color(0xFF880E4F),
    sheetTapeColor: const Color(0xFFF8BBD0),
    sheetShadows: const [
      BoxShadow(
        color: Color.fromRGBO(173, 20, 87, 0.25),
        blurRadius: 20,
        offset: Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(color: const Color(0xFFF48FB1), width: 1),
    sheetShowTape: false,
    sheetInfoBackgroundColor: Colors.white.withOpacity(0.45),
    sheetInfoBorderColor: const Color(0xFFF8BBD0).withOpacity(0.6),
    sheetInfoDividerColor: const Color(0xFFF8BBD0).withOpacity(0.5),
    optionSelectedBgColor: const Color(0xFFEC407A),
    optionSelectedTextColor: Colors.white,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(236, 64, 122, 0.4),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: Colors.white.withOpacity(0.5),
    optionUnselectedTextColor: const Color(0xFFAD1457),
    optionUnselectedBorder: Border.all(
      color: const Color(0xFFF48FB1).withOpacity(0.5),
    ),
  ),

  // --- Editor ---
  editor: EditorThemeData(
    appBarBg: Colors.white.withOpacity(0.2),
    iconColor: const Color(0xFF880E4F),
    cursorColor: const Color(0xFFEC407A),
    lineColor: const Color(0xFFEC407A).withOpacity(0.08),
    dividerColor: const Color(0xFFEC407A).withOpacity(0.15),
    appBarBorder: Border(
      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
    ),
    applyBlur: true,
    saveButtonBg: Colors.white.withValues(alpha: 0.9),
    saveButtonTextColor: const Color(0xFF880E4F),
    saveButtonCheckColor: const Color(0xFFC2185B),
    dropdownBg: const Color(0xFFFFF0F5),
    dropdownText: const Color(0xFF880E4F),
    exportPaperColor: Colors.white.withValues(alpha: 0.95),
    exportBorderColor: Colors.pink.withValues(alpha: 0.1),
    ribbonAccentColor: const Color(0xFFEC407A),
    hintColor: Colors.black26,
  ),

  // --- Diary Card ---
  diaryCard: DiaryCardThemeData(
    bgColor: Colors.white.withOpacity(0.35),
    titleColor: const Color(0xFF880E4F),
    contentColor: const Color(0xFFC2185B),
    dateColor: const Color(0xFFAD1457),
    iconColor: const Color(0xFFEC407A),
    dashedLineColor: const Color(0x4DC2185B),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(200, 150, 200, 0.2),
        offset: Offset(0, 8),
        blurRadius: 32,
      ),
    ],
    hoverShadows: const [
      BoxShadow(
        color: Color.fromRGBO(255, 255, 255, 0.6),
        offset: Offset(0, 0),
        blurRadius: 20,
        spreadRadius: 4,
      ),
    ],
    border: Border.all(color: Colors.white.withOpacity(0.5)),
    dateWeight: FontWeight.w600,
    glassEffect: true,
    glassColor: Colors.white.withValues(alpha: 0.65),
    blurSigma: 8.0,
    borderRadius: 16.0,
    hoverTranslateY: -8.0,
    hoverScale: 1.02,
    showStarWatermark: false,
    showFlowerWatermark: true,
    usePaperContainer: false,
  ),

  // --- Moment Card ---
  momentCard: MomentCardThemeData(
    cardColor: Colors.white.withValues(alpha: 0.82),
    textColor: const Color(0xFF880E4F),
    metaColor: const Color(0xFFAD1457).withValues(alpha: 0.65),
    iconColor: const Color(0xFFEC407A),
    cardShadows: [
      BoxShadow(
        color: const Color(0xFFF48FB1).withValues(alpha: 0.15),
        offset: const Offset(0, 6),
        blurRadius: 18,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        offset: const Offset(1, 2),
        blurRadius: 3,
      ),
    ],
    cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    useGlassEffect: true,
    cardBlurSigma: 10,
    imageStackColor: Colors.white,
    imageStackBorderColor: const Color(0xFFF8BBD0).withValues(alpha: 0.6),
    imageStackShadow: BoxShadow(
      color: const Color(0xFFEC407A).withValues(alpha: 0.12),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFFFFF7FA),
    imageSurfaceShadow: BoxShadow(
      color: const Color(0xFFEC407A).withValues(alpha: 0.18),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: const Color(0xFFEC407A),
    indicatorInactiveColor: const Color(0xFFF8BBD0).withValues(alpha: 0.7),
    watermarkDividerColor: const Color(0xFFF8BBD0).withValues(alpha: 0.4),
    audioSurfaceColor: Colors.white.withValues(alpha: 0.45),
    audioSurfaceBorderColor: const Color(0xFFF8BBD0).withValues(alpha: 0.6),
    audioButtonColor: const Color(0xFFEC407A),
    audioButtonIconColor: Colors.white,
    audioButtonShadow: BoxShadow(
      color: const Color(0xFFEC407A).withValues(alpha: 0.25),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: const Color(0xFFF8BBD0).withValues(alpha: 0.45),
    audioProgressColor: const Color(0xFFEC407A).withValues(alpha: 0.75),
    audioDurationColor: const Color(0xFF880E4F).withValues(alpha: 0.65),
    deleteIconColor: const Color(0xFFEC407A).withValues(alpha: 0.75),
  ),

  // --- Book Directory (empty in original) ---
  bookDirectory: const BookDirectoryThemeData(),

  // --- Moments ---
  moments: MomentsThemeData(
    rulerBg: Colors.white.withOpacity(0.9),
    rulerTextColor: const Color(0xFF880E4F),
    rulerInactiveTextColor: const Color(0xFF880E4F).withOpacity(0.4),
    rulerSubTextColor: const Color(0xFF880E4F),
    rulerInactiveSubTextColor: const Color(0xFF880E4F).withOpacity(0.4),
    rulerIndicatorColor: const Color(0xFFF50057),
    rulerShadowColor: const Color(0x1F880E4F),
    rulerBorderColor: Colors.transparent,
    appBarIconColor: const Color(0xFFD81B60),
    appBarTextColor: const Color(0xFF880E4F),
    drawerScrimColor: Colors.transparent,
    appBarBg: const Color(0xFFFCE4EC).withOpacity(0.8),
  ),

  // --- Search (empty in original) ---
  search: const SearchThemeData(),

  // --- Month Divider (empty in original) ---
  monthDivider: const MonthDividerThemeData(),

  // --- Dialog (empty in original) ---
  dialog: const AppDialogThemeData(),

  // --- Toast (empty in original) ---
  toast: const ToastThemeData(),

  // --- Lock Screen (empty in original) ---
  lockScreen: const LockScreenThemeData(),

  // --- Mobile Header ---
  mobileHeader: MobileHeaderColorsData(
    background: const Color(0xFFFFFFFF).withOpacity(0.15),
    border: const Color(0x4DFFFFFF),
    iconColor: const Color(0xFF880E4F),
    titleColor: const Color(0xFF880E4F),
    subtitleColor: const Color(0xCC880E4F),
  ),

  // --- Dialog Input ---
  dialogInput: DialogInputThemeData(
    textColor: const Color(0xFF880E4F),
    hintColor: const Color(0xFF880E4F).withOpacity(0.4),
    borderColor: const Color(0xFF880E4F).withOpacity(0.2),
    focusedBorderColor: const Color(0xFF880E4F).withOpacity(0.6),
    iconColor: const Color(0xFF880E4F).withOpacity(0.4),
    backgroundColor: const Color(0xFFFCE4EC).withOpacity(0.5),
    descriptionColor: const Color(0xFF880E4F).withOpacity(0.7),
  ),

  // --- Statistics ---
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
    ),
    cardShadow: const BoxShadow(
      color: Color.fromRGBO(240, 98, 146, 0.2),
      blurRadius: 15,
      offset: Offset(0, 6),
      spreadRadius: -2,
    ),
    cardBorder: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
    accentColor: const Color(0xFFF06292),
    textColor: const Color(0xFF880E4F),
    secondaryTextColor: const Color(0xFFC2185B),
    chartColor: const Color(0xFFF06292),
    badgeStyle: const StatisticsBadgeStyleData(
      backgroundColor: Color(0xFFFCE4EC),
      textColor: Color(0xFFD81B60),
      borderColor: Color(0xFFF48FB1),
    ),
  ),

  // --- Trash Page ---
  trashPage: TrashPageThemeData(
    titleColor: const Color(0xFF880E4F),
    iconColor: const Color(0xFFAD1457),
    restoreColor: const Color(0xFFE91E63),
    dangerColor: const Color(0xFFC2185B),
    cardTitleColor: const Color(0xFF880E4F),
    cardDateColor: const Color(0xFF880E4F).withOpacity(0.6),
    cardDecoration: BoxDecoration(
      color: Colors.white.withOpacity(0.4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF48FB1).withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  ),

  // --- Sync Settings ---
  syncSettings: SyncSettingsThemeData(
    titleColor: const Color(0xFF880E4F),
    textColor: const Color(0xFFAD1457),
    accentColor: const Color(0xFFD81B60),
    lockBtnColor: const Color(0xFFAD1457),
    switchTrackColor: Colors.pink[50]!,
    switchThumbColor: Colors.white,
    switchActiveText: const Color(0xFFAD1457),
    switchInactiveText: const Color(0xFFAD1457).withOpacity(0.5),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFFF06292), Color(0xFFAD1457)],
    ),
    primaryShadowColor: const Color(0xFFAD1457).withOpacity(0.3),
    secondaryBtnColor: Colors.white.withOpacity(0.5),
    secondaryBtnTextColor: const Color(0xFF880E4F),
    secondaryBorderColor: const Color(0xFFAD1457).withOpacity(0.2),
    tipsBgColor: Colors.white.withOpacity(0.2),
    switchBgColor: Colors.white.withOpacity(0.4),
    slidingSwitchShadowOpacity: 0.05,
    thumbShadowOpacity: 0.1,
  ),

  // --- Moment Input ---
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFFFCE4EC),
    containerShadows: const [
      BoxShadow(
        color: Colors.black12,
        offset: Offset(0, -2),
        blurRadius: 4,
      ),
    ],
    inputBgColor: Colors.white,
    inputBorderColor: const Color(0xFFF8BBD0),
    textColor: const Color(0xFF880E4F),
    hintColor: const Color(0xFF880E4F).withValues(alpha: 0.35),
    iconColor: const Color(0xFFD81B60),
    sendColor: const Color(0xFFEC407A),
    imageIconColor: const Color(0xFFD81B60),
    cursorColor: const Color(0xFFD81B60),
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFF880E4F).withValues(alpha: 0.35),
    imageRemoveBgColor: Colors.black.withValues(alpha: 0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF5A2D45),
    cassetteDeckBorderColor: const Color(0xFFF48FB1).withValues(alpha: 0.45),
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
    cassetteLabelColor: const Color(0xFFFCE4EC),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFFF8BBD0),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: const Color(0xFFD81B60),
    cassetteScrewColor: Colors.white.withValues(alpha: 0.24),
    miniCassetteBgColor: const Color(0xFF6A334F),
    miniCassettePlayColor: const Color(0xFFEC407A),
    miniCassetteTextColor: const Color(0xFFFCE4EC),
    miniCassetteHintColor: const Color(0xFFF8BBD0).withValues(alpha: 0.7),
    miniCassetteDeleteColor: const Color(0xFFF8BBD0).withValues(alpha: 0.8),
  ),

  // --- Moment Editor (falls to default vintage in original) ---
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

  // --- Refresh Indicator ---
  refreshIndicator: const AppRefreshIndicatorThemeData(
    bookColor: Color(0xFFAD1457),
    pageColor: Color(0xFFFCE4EC),
    textColor: Color(0xFFAD1457),
  ),

  // --- Privacy Dialog ---
  privacyDialog: PrivacyDialogThemeData(
    linkColor: const Color(0xFFAD1457),
    contentTextColor: const Color(0xFFAD1457),
    disclaimerTextColor: const Color(0xFFAD1457).withOpacity(0.7),
  ),

  // --- Paper Sheet ---
  paperSheet: PaperSheetThemeData(
    paperColor: Colors.white.withValues(alpha: 0.55),
    accentColor: const Color(0xFFEC407A),
    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
    shadows: const [
      BoxShadow(
        color: Color.fromRGBO(200, 150, 200, 0.2),
        offset: Offset(0, 8),
        blurRadius: 32,
      ),
    ],
    borderRadius: 16.0,
    useGlassEffect: true,
  ),

  // --- Diary List Page ---
  diaryListPage: DiaryListPageThemeData(
    drawerScrimColor: Colors.transparent,
    headerBoxShadow: const [],
    headerApplyBlur: true,
    emptyStateIconColor: const Color(0xFF6D5D5D).withValues(alpha: 0.6),
    emptyStateTextColor: const Color(0xFF6D5D5D).withValues(alpha: 0.8),
    emptyStateLinkColor: const Color(0xFFC2185B),
    updateDialogSecondaryColor: const Color(0xFFC2185B),
  ),

  // --- Moment Standard Card ---
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: Colors.white,
    textColor: const Color(0xFF3E2723),
    metaColor: Colors.grey[400]!,
  ),

  // --- Date Picker ---
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFFFFF0F5),
    headerBg: const Color(0xFFF8BBD0),
    headerText: const Color(0xFF880E4F),
    bodyText: const Color(0xFF880E4F),
    accentColor: const Color(0xFFF50057),
    weekDayColor: const Color(0xFFAD1457),
    border: Border.all(color: Colors.white, width: 2),
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
