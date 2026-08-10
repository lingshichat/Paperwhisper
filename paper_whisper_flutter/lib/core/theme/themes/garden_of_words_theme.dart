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

// --- Garden of Words Color Constants ---
const Color _bgCenter = Color(0xFF37474F);
const Color _surface = Color(0xFF455A64);
const Color _textPrimary = Color(0xFFECEFF1);
const Color _textSecondary = Color(0xFFB0BEC5);
const Color _accent = Color(0xFF81C784);
const Color _accentDark = Color(0xFF4CAF50);

/// 言叶之庭主题
final gardenOfWordsTheme = PaperWhisperTheme(
  id: 'garden_of_words',
  name: '言叶之庭',
  description: '隐约雷鸣，阴霾天空',

  // --- ThemeColors ---
  colors: ThemeColors(
    paperColor: _surface,
    textPrimary: _textSecondary,
    textSecondary: _accentDark,
    accent: _accent,
    bgCenter: _bgCenter,
    bgEdge: const Color(0xFF263238),
    brightness: Brightness.dark,
    scaffoldBg: _bgCenter,
    seedColor: _accent,
  ),

  // --- Background ---
  background: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF37474F), Color(0xFF263238)],
      stops: [0.0, 1.0],
    ),
    image: DecorationImage(
      image: AssetImage('assets/textures/rainy_paper.png'),
      fit: BoxFit.cover,
      opacity: 0.1,
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
  backgroundOverlays: const [],

  // --- FAB ---
  fab: FabThemeData(
    backgroundGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA5D6A7), _accentDark],
      stops: [0.0, 1.0],
    ),
    shadow: BoxShadow(
      color: _accentDark.withValues(alpha: 0.5),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -2,
    ),
    iconColor: Colors.white,
    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
  ),

  // --- Sidebar ---
  sidebar: SidebarThemeData(
    bgDecoration: BoxDecoration(
      color: const Color(0xFF263238).withValues(alpha: 0.6),
      border: Border(
        right: BorderSide(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(5, 0),
        ),
      ],
    ),
    textColor: const Color(0xFFB0BEC5),
    activeTextColor: _accent,
    subTextColor: const Color(0xFF78909C),
    hitokotoBackgroundColor: const Color(0xFF263238).withValues(alpha: 0.4),
    hitokotoBorderColor: Colors.white.withValues(alpha: 0.05),
    dividerColor: Colors.white.withValues(alpha: 0.1),
    pillColor: Colors.white.withValues(alpha: 0.05),
    pillShadows: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.1),
        offset: const Offset(0, 0),
        blurRadius: 10,
        spreadRadius: 0,
      ),
    ],
    pillBorder: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    buttonGradient: LinearGradient(colors: [_accentDark, _accent]),
    buttonShadow: BoxShadow(
      color: _accentDark.withValues(alpha: 0.4),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ),

  // --- Settings ---
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: const Color(0xFF263238).withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    dividerColor: Colors.white.withValues(alpha: 0.1),
    textColor: const Color(0xFFCFD8DC),
    activeSwitchColor: _accent,
    activeTrackColor: _accent.withValues(alpha: 0.3),
    titleColor: const Color(0xFFECEFF1),
    titleShadow: const Shadow(
      color: Color.fromRGBO(129, 199, 132, 0.3),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    iconColor: _accent,
    showPetalRain: false,
    showStarrySky: false,
    sheetTextColor: const Color(0xFFECEFF1),
    sheetBackgroundColor: const Color(0xFF263238).withValues(alpha: 0.95),
    sheetTitleColor: const Color(0xFFECEFF1),
    sheetTapeColor: Colors.white.withValues(alpha: 0.5),
    sheetShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(
      color: Colors.white.withValues(alpha: 0.1),
      width: 1,
    ),
    sheetShowTape: false,
    sheetInfoBackgroundColor: _surface.withValues(alpha: 0.45),
    sheetInfoBorderColor: _accent.withValues(alpha: 0.2),
    sheetInfoDividerColor: _accent.withValues(alpha: 0.15),
    optionSelectedBgColor: const Color(0xFF8BC34A).withValues(alpha: 0.8),
    optionSelectedTextColor: Colors.white,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(139, 195, 74, 0.4),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: const Color(0xFF37474F).withValues(alpha: 0.4),
    optionUnselectedTextColor: const Color(0xFFCFD8DC),
    optionUnselectedBorder: Border.all(
      color: const Color(0xFF8BC34A).withValues(alpha: 0.3),
    ),
  ),

  // --- Editor ---
  editor: EditorThemeData(
    appBarBg: const Color(0xFF263238).withValues(alpha: 0.9),
    iconColor: _textSecondary,
    cursorColor: _accent,
    lineColor: Colors.white.withValues(alpha: 0.05),
    dividerColor: Colors.white.withValues(alpha: 0.05),
    applyBlur: false,
    saveButtonBg: const Color(0xFFF7F1E3),
    saveButtonTextColor: const Color(0xFF5D4037),
    saveButtonCheckColor: const Color(0xFFC0392B),
    dropdownBg: const Color(0xFFF0F4F2),
    dropdownText: const Color(0xFF5A6B72),
    exportPaperColor: const Color(0xFF455A64),
    exportBorderColor: const Color(0xFF8BC34A),
    ribbonAccentColor: const Color(0xFF8BC34A),
    hintColor: Colors.white24,
  ),

  // --- Diary Card ---
  diaryCard: DiaryCardThemeData(
    bgColor: const Color(0xFF455A64).withValues(alpha: 0.3),
    titleColor: _textPrimary,
    contentColor: _textSecondary,
    dateColor: _accent,
    iconColor: _accent,
    dashedLineColor: Colors.white.withValues(alpha: 0.1),
    shadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        offset: const Offset(0, 4),
        blurRadius: 12,
      ),
    ],
    hoverShadows: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.1),
        offset: const Offset(0, 8),
        blurRadius: 20,
      ),
    ],
    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
    cardColor: _surface.withValues(alpha: 0.55),
    textColor: _textPrimary,
    metaColor: _textSecondary,
    iconColor: _accent,
    cardShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        offset: const Offset(0, 4),
        blurRadius: 12,
      ),
      BoxShadow(
        color: _accent.withValues(alpha: 0.12),
        offset: const Offset(0, 0),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
    cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    useGlassEffect: true,
    cardBlurSigma: 9,
    imageStackColor: const Color(0xFF37474F).withValues(alpha: 0.9),
    imageStackBorderColor: _accent.withValues(alpha: 0.2),
    imageStackShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.24),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFF263238),
    imageSurfaceShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.24),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: _accent,
    indicatorInactiveColor: Colors.white.withValues(alpha: 0.2),
    watermarkDividerColor: _accent.withValues(alpha: 0.15),
    audioSurfaceColor: _surface.withValues(alpha: 0.62),
    audioSurfaceBorderColor: _accent.withValues(alpha: 0.18),
    audioButtonColor: _accent,
    audioButtonIconColor: _surface,
    audioButtonShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: Colors.white.withValues(alpha: 0.12),
    audioProgressColor: _accent.withValues(alpha: 0.7),
    audioDurationColor: _textSecondary.withValues(alpha: 0.9),
    deleteIconColor: _accent.withValues(alpha: 0.75),
  ),

  // --- Book Directory ---
  bookDirectory: BookDirectoryThemeData(
    inkColor: _textSecondary,
    paperColor: _surface.withValues(alpha: 0.95),
    paperBorderColor: _accent.withValues(alpha: 0.3),
    paperShadow: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.15),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  ),

  // --- Moments ---
  moments: MomentsThemeData(
    rulerBg: const Color(0xFF263238).withValues(alpha: 0.95),
    rulerTextColor: _textSecondary,
    rulerInactiveTextColor: _textSecondary.withValues(alpha: 0.3),
    rulerSubTextColor: _accent,
    rulerInactiveSubTextColor: _accent.withValues(alpha: 0.4),
    rulerIndicatorColor: _accent,
    rulerShadowColor: Colors.black.withValues(alpha: 0.3),
    rulerBorderColor: Colors.white.withValues(alpha: 0.05),
    appBarIconColor: _textPrimary,
    appBarTextColor: _textPrimary,
    drawerScrimColor: Colors.black54,
    appBarBg: const Color(0xFF263238).withValues(alpha: 0.8),
    emptyStateIconColor: _accent.withValues(alpha: 0.68),
    emptyStateTextColor: _textPrimary.withValues(alpha: 0.92),
  ),

  // --- Search ---
  search: SearchThemeData(
    bgColor: const Color(0xFF263238).withValues(alpha: 0.5),
    textColor: _textSecondary,
    hintColor: _textSecondary.withValues(alpha: 0.5),
    iconColor: _accent,
    border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
  ),

  // --- Month Divider ---
  monthDivider: MonthDividerThemeData(
    textColor: _textPrimary,
    lineColor: _accent.withValues(alpha: 0.4),
    paperColor: _surface.withValues(alpha: 0.8),
    shadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),

  // --- Dialog ---
  dialog: AppDialogThemeData(
    paper: _surface.withValues(alpha: 0.95),
    title: _textPrimary,
    text: _textSecondary,
    icon: _accentDark,
    tape: Colors.white.withValues(alpha: 0.5),
    shadow: Colors.black.withValues(alpha: 0.15),
    border: Colors.white.withValues(alpha: 0.2),
    primaryBtn: _accent,
    primaryBtnText: Colors.white,
    secondaryBtn: _textSecondary,
  ),

  // --- Toast ---
  toast: ToastThemeData(
    success: ToastStyleData(
      bg: _surface,
      border: _accent,
      icon: _accent,
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
      border: _accentDark,
      icon: _accentDark,
      text: _textSecondary,
    ),
  ),

  // --- Lock Screen ---
  lockScreen: LockScreenThemeData(
    displayBg: _surface.withValues(alpha: 0.3),
    displayBorder: _accent.withValues(alpha: 0.3),
    accentColor: _accent,
    keyBg: _surface.withValues(alpha: 0.4),
    keyBorder: _accent.withValues(alpha: 0.2),
    keyText: _textSecondary,
  ),

  // --- Mobile Header ---
  mobileHeader: MobileHeaderColorsData(
    background: _surface.withValues(alpha: 0.9),
    border: _accent.withValues(alpha: 0.3),
    iconColor: _accentDark,
    titleColor: _textSecondary,
    subtitleColor: _textSecondary.withValues(alpha: 0.7),
  ),

  // --- Dialog Input ---
  dialogInput: DialogInputThemeData(
    textColor: _textPrimary,
    hintColor: _textSecondary.withValues(alpha: 0.5),
    borderColor: _accent.withValues(alpha: 0.3),
    focusedBorderColor: _accent,
    iconColor: _accent.withValues(alpha: 0.6),
    backgroundColor: Colors.black.withValues(alpha: 0.2),
    descriptionColor: _textPrimary.withValues(alpha: 0.7),
  ),

  // --- Statistics ---
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      color: const Color(0xFF263238).withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
    ),
    cardShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 15,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
    cardBorder: Border.all(
      color: Colors.white.withValues(alpha: 0.1),
      width: 1,
    ),
    accentColor: _accent,
    textColor: _textPrimary,
    secondaryTextColor: _textSecondary,
    chartColor: _accent,
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: _accent.withValues(alpha: 0.2),
      textColor: _accent,
      borderColor: _accent.withValues(alpha: 0.3),
    ),
  ),

  // --- Trash Page ---
  trashPage: TrashPageThemeData(
    titleColor: _textPrimary,
    iconColor: const Color(0xFF558B2F),
    restoreColor: const Color(0xFF8BC34A),
    dangerColor: const Color(0xFFE57373),
    cardTitleColor: _textPrimary,
    cardDateColor: _textPrimary.withValues(alpha: 0.6),
    cardDecoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF8BC34A).withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8BC34A).withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  ),

  // --- Sync Settings ---
  syncSettings: SyncSettingsThemeData(
    titleColor: _textPrimary,
    textColor: _textSecondary,
    accentColor: _accent,
    lockBtnColor: _accentDark,
    switchTrackColor: const Color(0xFFF0F4F2),
    switchThumbColor: const Color(0xFF8BC34A),
    switchActiveText: const Color(0xFFF0F4F2),
    switchInactiveText: const Color(0xFF5A6B72),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF8BC34A), Color(0xFF558B2F)],
    ),
    primaryShadowColor: const Color(0xFF8BC34A).withValues(alpha: 0.3),
    secondaryBtnColor: Colors.white.withValues(alpha: 0.6),
    secondaryBtnTextColor: const Color(0xFF2E4A35),
    secondaryBorderColor: const Color(0xFF8BC34A).withValues(alpha: 0.2),
    tipsBgColor: Colors.white.withValues(alpha: 0.2),
    switchBgColor: Colors.black.withValues(alpha: 0.05),
    slidingSwitchShadowOpacity: 0.05,
    thumbShadowOpacity: 0.1,
  ),

  // --- Moment Input ---
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFF263238).withValues(alpha: 0.95),
    containerShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        offset: const Offset(0, -4),
        blurRadius: 15,
      ),
    ],
    inputBgColor: const Color(0xFF37474F).withValues(alpha: 0.5),
    inputBorderColor: const Color(0xFF8BC34A).withValues(alpha: 0.3),
    textColor: const Color(0xFFECEFF1),
    hintColor: const Color(0xFFB0BEC5).withValues(alpha: 0.7),
    iconColor: const Color(0xFF8BC34A),
    sendColor: const Color(0xFF8BC34A),
    imageIconColor: const Color(0xFF8BC34A),
    cursorColor: const Color(0xFF8BC34A),
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFFB0BEC5).withValues(alpha: 0.7),
    imageRemoveBgColor: Colors.black.withValues(alpha: 0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF263238),
    cassetteDeckBorderColor: const Color(0xFF8BC34A).withValues(alpha: 0.35),
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
    cassetteLabelColor: const Color(0xFFECEFF1),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFF8BC34A).withValues(alpha: 0.25),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: const Color(0xFF8BC34A),
    cassetteScrewColor: Colors.white.withValues(alpha: 0.24),
    miniCassetteBgColor: const Color(0xFF263238).withValues(alpha: 0.95),
    miniCassettePlayColor: const Color(0xFF8BC34A),
    miniCassetteTextColor: const Color(0xFFECEFF1),
    miniCassetteHintColor: const Color(0xFFB0BEC5),
    miniCassetteDeleteColor: const Color(0xFFB0BEC5).withValues(alpha: 0.8),
  ),

  // --- Moment Editor ---
  momentEditor: MomentEditorThemeData(
    bgColor: _surface.withValues(alpha: 0.95),
    appBarTextColor: _textSecondary,
    appBarIconColor: _textSecondary,
    inputBg: Colors.white.withValues(alpha: 0.7),
    inputTextColor: _textSecondary,
    hintColor: _textSecondary.withValues(alpha: 0.5),
    dropdownBg: Colors.white.withValues(alpha: 0.7),
    dropdownIconColor: _accentDark,
    dropdownMenuBg: _surface,
    dropdownItemColor: _textSecondary,
    photoEmptyColor: _accent.withValues(alpha: 0.1),
    photoIconColor: _accentDark,
  ),

  // --- Refresh Indicator ---
  refreshIndicator: const AppRefreshIndicatorThemeData(
    bookColor: Color(0xFF2E4A35),
    pageColor: Color(0xFFF0F4F2),
    textColor: Color(0xFF5A6B72),
  ),

  // --- Privacy Dialog ---
  privacyDialog: const PrivacyDialogThemeData(
    linkColor: Color(0xFF81C784),
    contentTextColor: Color(0xFFB0BEC5),
    disclaimerTextColor: Color(0xFF78909C),
  ),

  // --- Paper Sheet ---
  paperSheet: PaperSheetThemeData(
    paperColor: _surface,
    accentColor: const Color(0xFF8BC34A),
    border: Border.all(
      color: const Color(0xFF8BC34A).withValues(alpha: 0.3),
      width: 1,
    ),
    shadows: [
      BoxShadow(
        color: const Color(0xFF8BC34A).withValues(alpha: 0.15),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
    borderRadius: 2.0,
    useGlassEffect: false,
  ),

  // --- Diary List Page ---
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
    emptyStateIconColor: _accentDark.withValues(alpha: 0.6),
    emptyStateTextColor: _accentDark.withValues(alpha: 0.8),
    emptyStateLinkColor: _accent,
    updateDialogSecondaryColor: const Color(0xFF5A6B72),
  ),

  // --- Moment Standard Card ---
  momentStandardCard: MomentStandardCardThemeData(
    cardBg: Colors.white,
    textColor: const Color(0xFF3E2723),
    metaColor: Colors.grey[400]!,
  ),

  // --- Date Picker ---
  datePicker: AppDatePickerThemeData(
    dialogBg: const Color(0xFFF0F4F2),
    headerBg: const Color(0xFF2E4A35),
    headerText: const Color(0xFFF0F4F2),
    bodyText: const Color(0xFF5A6B72),
    accentColor: const Color(0xFF8BC34A),
    weekDayColor: const Color(0xFF1B3321),
    border: Border.all(
      color: const Color(0xFF8BC34A).withValues(alpha: 0.3),
      width: 1,
    ),
    shadows: [
      BoxShadow(
        color: const Color(0xFF8BC34A).withValues(alpha: 0.15),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  ),
);
