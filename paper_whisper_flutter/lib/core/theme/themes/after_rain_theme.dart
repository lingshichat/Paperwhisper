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

// --- After Rain Color Constants ---
const Color _primaryMain = Color(0xFF4FC3F7);
const Color _primaryLight = Color(0xFFB3E5FC);
const Color _surface = Color(0xFFF0F8FF);
const Color _textSecondary = Color(0xFF455A64);
const Color _accentBlue = Color(0xFF0288D1);

/// 雨后天空主题
final afterRainTheme = PaperWhisperTheme(
  id: 'after_rain',
  name: '雨后天空',
  description: '极简呼吸，宁静希望',

  // --- ThemeColors ---
  colors: ThemeColors(
    paperColor: _surface,
    textPrimary: _textSecondary,
    textSecondary: _accentBlue,
    accent: _primaryMain,
    bgCenter: _surface,
    bgEdge: _surface,
    brightness: Brightness.light,
    scaffoldBg: _surface,
    seedColor: _primaryMain,
  ),

  // --- Background ---
  background: const BoxDecoration(
    color: _surface,
    image: DecorationImage(
      image: AssetImage('assets/textures/rainy_paper.png'),
      fit: BoxFit.cover,
      opacity: 0.8,
    ),
  ),

  // --- Sidebar Background ---
  sidebarBackground: BoxDecoration(
    color: _surface.withValues(alpha: 0.65),
    border: Border(
      right: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1),
    ),
  ),

  // --- System UI Overlay Style ---
  systemUiOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: _surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  ),

  // --- Background Overlays ---
  backgroundOverlays: const [Positioned.fill(child: AfterRainVisuals())],

  // --- FAB ---
  fab: FabThemeData(
    backgroundGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE0F7FA), _accentBlue],
      stops: [0.1, 0.9],
    ),
    shadow: BoxShadow(
      color: _accentBlue.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
    iconColor: Colors.white,
    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
  ),

  // --- Sidebar ---
  sidebar: SidebarThemeData(
    bgDecoration: BoxDecoration(
      color: _surface.withValues(alpha: 0.65),
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1),
      ),
      boxShadow: [
        BoxShadow(
          color: _accentBlue.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(2, 0),
        ),
      ],
    ),
    textColor: _textSecondary,
    activeTextColor: _accentBlue,
    subTextColor: const Color(0xFF78909C),
    hitokotoBackgroundColor: Colors.white.withValues(alpha: 0.4),
    hitokotoBorderColor: Colors.white10,
    dividerColor: Colors.white10,
    pillColor: _surface.withValues(alpha: 0.5),
    pillShadows: [
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-1, -1),
        blurRadius: 2,
      ),
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.2),
        offset: const Offset(1, 1),
        blurRadius: 3,
      ),
    ],
    pillBorder: Border.all(color: Colors.white.withValues(alpha: 0.3)),
    buttonGradient: const LinearGradient(colors: [_primaryLight, _primaryMain]),
    buttonShadow: BoxShadow(
      color: _primaryMain.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ),

  // --- Settings ---
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.6),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: _accentBlue.withValues(alpha: 0.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    dividerColor: _accentBlue.withValues(alpha: 0.1),
    textColor: _textSecondary,
    activeSwitchColor: _primaryMain,
    activeTrackColor: _primaryLight.withValues(alpha: 0.3),
    titleColor: _textSecondary,
    titleShadow: Shadow(
      color: Colors.white.withValues(alpha: 0.8),
      offset: const Offset(0, 1),
      blurRadius: 0,
    ),
    iconColor: _accentBlue,
    showPetalRain: false,
    showStarrySky: false,
    sheetTextColor: _textSecondary,
    sheetBackgroundColor: const Color(0xFFF0F8FF).withValues(alpha: 0.95),
    sheetTitleColor: _textSecondary,
    sheetTapeColor: const Color(0xFFB3E5FC).withValues(alpha: 0.5),
    sheetShadows: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.15),
        blurRadius: 20,
        offset: const Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(color: Colors.white, width: 1),
    sheetShowTape: false,
    sheetInfoBackgroundColor: Colors.white.withValues(alpha: 0.85),
    sheetInfoBorderColor: Colors.white,
    sheetInfoDividerColor: _accentBlue.withValues(alpha: 0.15),
    optionSelectedBgColor: _accentBlue,
    optionSelectedTextColor: Colors.white,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(2, 136, 209, 0.3),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: Colors.white.withValues(alpha: 0.6),
    optionUnselectedTextColor: _textSecondary,
    optionUnselectedBorder: Border.all(color: Colors.white),
  ),

  // --- Editor ---
  editor: EditorThemeData(
    appBarBg: _surface.withValues(alpha: 0.8),
    iconColor: _textSecondary,
    cursorColor: _accentBlue,
    lineColor: _accentBlue.withValues(alpha: 0.1),
    dividerColor: _accentBlue.withValues(alpha: 0.2),
    applyBlur: false,
    saveButtonBg: const Color(0xFFF7F1E3),
    saveButtonTextColor: const Color(0xFF5D4037),
    saveButtonCheckColor: const Color(0xFFC0392B),
    dropdownBg: const Color(0xFFF0F8FF),
    dropdownText: const Color(0xFF455A64),
    exportPaperColor: const Color(0xFFF0F8FF),
    exportBorderColor: const Color(0x339999BF),
    ribbonAccentColor: const Color(0xFF29B6F6),
    hintColor: Colors.black26,
  ),

  // --- Diary Card ---
  diaryCard: DiaryCardThemeData(
    bgColor: Colors.white.withValues(alpha: 0.7),
    titleColor: _textSecondary,
    contentColor: _textSecondary.withValues(alpha: 0.9),
    dateColor: _accentBlue,
    iconColor: _accentBlue,
    dashedLineColor: _accentBlue.withValues(alpha: 0.2),
    shadows: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.08),
        offset: const Offset(0, 6),
        blurRadius: 15,
        spreadRadius: -2,
      ),
    ],
    hoverShadows: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.15),
        offset: const Offset(0, 10),
        blurRadius: 25,
        spreadRadius: -2,
      ),
    ],
    border: Border.all(color: Colors.white, width: 1.5),
    dateWeight: FontWeight.normal,
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

  // --- Moment Card ---
  momentCard: MomentCardThemeData(
    cardColor: Colors.white.withValues(alpha: 0.78),
    textColor: _textSecondary,
    metaColor: _textSecondary.withValues(alpha: 0.65),
    iconColor: _accentBlue,
    cardShadows: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.08),
        offset: const Offset(0, 6),
        blurRadius: 15,
        spreadRadius: -2,
      ),
    ],
    cardBorder: Border.all(color: Colors.white, width: 1.2),
    useGlassEffect: true,
    cardBlurSigma: 8,
    imageStackColor: Colors.white.withValues(alpha: 0.92),
    imageStackBorderColor: _primaryLight.withValues(alpha: 0.8),
    imageStackShadow: BoxShadow(
      color: _accentBlue.withValues(alpha: 0.12),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFFF7FBFF),
    imageSurfaceShadow: BoxShadow(
      color: _accentBlue.withValues(alpha: 0.15),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: _accentBlue,
    indicatorInactiveColor: _primaryLight.withValues(alpha: 0.6),
    watermarkDividerColor: _accentBlue.withValues(alpha: 0.15),
    audioSurfaceColor: Colors.white.withValues(alpha: 0.58),
    audioSurfaceBorderColor: Colors.white,
    audioButtonColor: _accentBlue,
    audioButtonIconColor: Colors.white,
    audioButtonShadow: BoxShadow(
      color: _accentBlue.withValues(alpha: 0.2),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: _primaryLight.withValues(alpha: 0.6),
    audioProgressColor: _accentBlue.withValues(alpha: 0.75),
    audioDurationColor: _textSecondary.withValues(alpha: 0.75),
    deleteIconColor: _accentBlue.withValues(alpha: 0.75),
  ),

  // --- Book Directory ---
  bookDirectory: BookDirectoryThemeData(
    inkColor: _textSecondary,
    paperColor: _surface.withValues(alpha: 0.95),
    paperBorderColor: Colors.white.withValues(alpha: 0.8),
    paperShadow: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.1),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  ),

  // --- Moments ---
  moments: MomentsThemeData(
    rulerBg: _surface.withValues(alpha: 0.8),
    rulerTextColor: _textSecondary,
    rulerInactiveTextColor: _textSecondary.withValues(alpha: 0.3),
    rulerSubTextColor: _accentBlue,
    rulerInactiveSubTextColor: _accentBlue.withValues(alpha: 0.3),
    rulerIndicatorColor: _accentBlue,
    rulerShadowColor: _accentBlue.withValues(alpha: 0.1),
    rulerBorderColor: Colors.white.withValues(alpha: 0.5),
    appBarIconColor: _textSecondary,
    appBarTextColor: _textSecondary,
    drawerScrimColor: Colors.transparent,
    appBarBg: const Color(0xFFF0F8FF).withValues(alpha: 0.6),
    emptyStateIconColor: _accentBlue.withValues(alpha: 0.68),
    emptyStateTextColor: _textSecondary.withValues(alpha: 0.92),
  ),

  // --- Search ---
  search: SearchThemeData(
    bgColor: Colors.white.withValues(alpha: 0.6),
    textColor: _textSecondary,
    hintColor: _textSecondary.withValues(alpha: 0.4),
    iconColor: _accentBlue,
    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
  ),

  // --- Month Divider ---
  monthDivider: MonthDividerThemeData(
    textColor: _textSecondary,
    lineColor: _accentBlue.withValues(alpha: 0.2),
    paperColor: Colors.white.withValues(alpha: 0.8),
    shadows: [
      BoxShadow(
        color: _accentBlue.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  ),

  // --- Dialog ---
  dialog: AppDialogThemeData(
    paper: _surface.withValues(alpha: 0.95),
    title: _textSecondary,
    text: _textSecondary,
    icon: _accentBlue,
    tape: _primaryLight.withValues(alpha: 0.4),
    shadow: _accentBlue.withValues(alpha: 0.15),
    border: Colors.white,
    primaryBtn: _accentBlue,
    primaryBtnText: Colors.white,
    secondaryBtn: _textSecondary,
  ),

  // --- Toast ---
  toast: ToastThemeData(
    success: ToastStyleData(
      bg: _surface,
      border: _primaryMain,
      icon: _primaryMain,
      text: _textSecondary,
    ),
    error: const ToastStyleData(
      bg: Color(0xFFFFF0F0),
      border: Color(0xFFE57373),
      icon: Color(0xFFE57373),
      text: _textSecondary,
    ),
    warning: const ToastStyleData(
      bg: Color(0xFFFFF8E1),
      border: Color(0xFFFFB74D),
      icon: Color(0xFFFFB74D),
      text: _textSecondary,
    ),
    info: ToastStyleData(
      bg: _surface,
      border: _accentBlue,
      icon: _accentBlue,
      text: _textSecondary,
    ),
  ),

  // --- Lock Screen ---
  lockScreen: LockScreenThemeData(
    displayBg: Colors.white.withValues(alpha: 0.4),
    displayBorder: Colors.white.withValues(alpha: 0.6),
    accentColor: _accentBlue,
    keyBg: Colors.white.withValues(alpha: 0.5),
    keyBorder: Colors.white.withValues(alpha: 0.8),
    keyText: _textSecondary,
  ),

  // --- Mobile Header ---
  mobileHeader: MobileHeaderColorsData(
    background: _surface.withValues(alpha: 0.85),
    border: Colors.white.withValues(alpha: 0.4),
    iconColor: _accentBlue,
    titleColor: _textSecondary,
    subtitleColor: _textSecondary.withValues(alpha: 0.7),
  ),

  // --- Dialog Input ---
  dialogInput: DialogInputThemeData(
    textColor: const Color(0xFF455A64),
    hintColor: const Color(0xFF455A64).withValues(alpha: 0.4),
    borderColor: const Color(0xFF455A64).withValues(alpha: 0.2),
    focusedBorderColor: const Color(0xFF455A64).withValues(alpha: 0.6),
    iconColor: const Color(0xFF455A64).withValues(alpha: 0.4),
    backgroundColor: Colors.white.withValues(alpha: 0.5),
    descriptionColor: const Color(0xFF455A64).withValues(alpha: 0.7),
  ),

  // --- Statistics ---
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.8),
        width: 1.5,
      ),
    ),
    cardShadow: BoxShadow(
      color: _accentBlue.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
    cardBorder: Border.all(
      color: Colors.white.withValues(alpha: 0.8),
      width: 1.5,
    ),
    accentColor: _accentBlue,
    textColor: _textSecondary,
    secondaryTextColor: _textSecondary.withValues(alpha: 0.7),
    chartColor: _primaryMain,
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: _primaryLight.withValues(alpha: 0.4),
      textColor: _accentBlue,
      borderColor: _accentBlue.withValues(alpha: 0.3),
    ),
  ),

  // --- Trash Page ---
  trashPage: TrashPageThemeData(
    titleColor: _textSecondary,
    iconColor: _accentBlue,
    restoreColor: _accentBlue,
    dangerColor: const Color(0xFFE57373),
    cardTitleColor: _textSecondary,
    cardDateColor: _textSecondary.withValues(alpha: 0.6),
    cardDecoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      boxShadow: [
        BoxShadow(
          color: _accentBlue.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  ),

  // --- Sync Settings ---
  syncSettings: SyncSettingsThemeData(
    titleColor: _textSecondary,
    textColor: _textSecondary,
    accentColor: _accentBlue,
    lockBtnColor: _accentBlue,
    switchTrackColor: Colors.lightBlue[50]!,
    switchThumbColor: Colors.white,
    switchActiveText: _accentBlue,
    switchInactiveText: _accentBlue.withValues(alpha: 0.5),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
    ),
    primaryShadowColor: _accentBlue.withValues(alpha: 0.3),
    secondaryBtnColor: Colors.white.withValues(alpha: 0.6),
    secondaryBtnTextColor: const Color(0xFF0277BD),
    secondaryBorderColor: _accentBlue.withValues(alpha: 0.2),
    tipsBgColor: Colors.white.withValues(alpha: 0.2),
    switchBgColor: Colors.black.withValues(alpha: 0.05),
    slidingSwitchShadowOpacity: 0.05,
    thumbShadowOpacity: 0.1,
  ),

  // --- Moment Input ---
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFFF0F8FF).withValues(alpha: 0.9),
    containerShadows: [
      BoxShadow(
        color: const Color(0xFF0288D1).withValues(alpha: 0.1),
        offset: const Offset(0, -4),
        blurRadius: 10,
      ),
    ],
    inputBgColor: Colors.white,
    inputBorderColor: Colors.white,
    textColor: const Color(0xFF455A64),
    hintColor: const Color(0xFF90A4AE),
    iconColor: const Color(0xFF0288D1),
    sendColor: const Color(0xFF0288D1),
    imageIconColor: const Color(0xFF29B6F6),
    cursorColor: const Color(0xFF0288D1),
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFF90A4AE),
    imageRemoveBgColor: Colors.black.withValues(alpha: 0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF37474F),
    cassetteDeckBorderColor: const Color(0xFFB3E5FC),
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
    cassetteLabelColor: const Color(0xFFEAF7FF),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFF90A4AE),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: const Color(0xFF0288D1),
    cassetteScrewColor: Colors.white.withValues(alpha: 0.24),
    miniCassetteBgColor: const Color(0xFF37474F),
    miniCassettePlayColor: const Color(0xFF4FC3F7),
    miniCassetteTextColor: const Color(0xFFEAF7FF),
    miniCassetteHintColor: const Color(0xFFB0BEC5),
    miniCassetteDeleteColor: const Color(0xFFB0BEC5).withValues(alpha: 0.8),
  ),

  // --- Moment Editor ---
  momentEditor: MomentEditorThemeData(
    bgColor: _surface,
    appBarTextColor: _textSecondary,
    appBarIconColor: _textSecondary,
    inputBg: Colors.white.withValues(alpha: 0.6),
    inputTextColor: _textSecondary,
    hintColor: _textSecondary.withValues(alpha: 0.5),
    dropdownBg: Colors.white.withValues(alpha: 0.6),
    dropdownIconColor: _accentBlue,
    dropdownMenuBg: _surface,
    dropdownItemColor: _textSecondary,
    photoEmptyColor: _accentBlue.withValues(alpha: 0.05),
    photoIconColor: _accentBlue,
  ),

  // --- Refresh Indicator ---
  refreshIndicator: const AppRefreshIndicatorThemeData(
    bookColor: Color(0xFF0288D1),
    pageColor: Color(0xFFF0F8FF),
    textColor: Color(0xFF455A64),
  ),

  // --- Privacy Dialog ---
  privacyDialog: const PrivacyDialogThemeData(
    linkColor: Color(0xFF0288D1),
    contentTextColor: Color(0xFF455A64),
    disclaimerTextColor: Color(0xFF78909C),
  ),

  // --- Paper Sheet ---
  paperSheet: PaperSheetThemeData(
    paperColor: _surface,
    accentColor: const Color(0xFF29B6F6),
    border: Border.all(color: const Color(0x339999BF), width: 1),
    shadows: [
      BoxShadow(
        color: const Color(0xFF8981AA).withValues(alpha: 0.3),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
    borderRadius: 2.0,
    useGlassEffect: false,
  ),

  // --- Diary List Page ---
  diaryListPage: DiaryListPageThemeData(
    drawerScrimColor: Colors.transparent,
    headerBoxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
    headerApplyBlur: false,
    emptyStateIconColor: _accentBlue.withValues(alpha: 0.6),
    emptyStateTextColor: _accentBlue.withValues(alpha: 0.8),
    emptyStateLinkColor: _primaryMain,
    updateDialogSecondaryColor: const Color(0xFF8D6E63),
  ),

  // --- Moment Standard Card ---
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: Colors.white,
    textColor: const Color(0xFF3E2723),
    metaColor: Colors.grey[400]!,
  ),

  // --- Date Picker ---
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFFF0F8FF),
    headerBg: const Color(0xFFB3E5FC),
    headerText: const Color(0xFF455A64),
    bodyText: const Color(0xFF455A64),
    accentColor: const Color(0xFF0288D1),
    weekDayColor: const Color(0xFF0277BD),
    border: Border.all(color: Colors.white, width: 2),
    shadows: [
      BoxShadow(
        color: const Color(0xFF81D4FA).withValues(alpha: 0.3),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
);
