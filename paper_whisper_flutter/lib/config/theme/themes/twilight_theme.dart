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

// --- Twilight Color Constants ---
const Color _bgTop = Color(0xFF2E1C55);
const Color _bgMid = Color(0xFF913862);
const Color _bgBottom = Color(0xFFFF9A6C);
const Color _accentRed = Color(0xFFFF5252);
const Color _textPrimary = Color(0xFFE4E0EC);
const Color _textSecondary = Color(0xFFBCAAA4);
const Color _surface = Color(0xFF352044);

/// 黄昏之时主题
final twilightTheme = PaperWhisperTheme(
  id: 'twilight',
  name: '黄昏之时',
  description: '逢魔时刻，梦幻交织',

  // --- ThemeColors ---
  colors: ThemeColors(
    paperColor: _surface,
    textPrimary: _textPrimary,
    textSecondary: _textSecondary,
    accent: _accentRed,
    bgCenter: _bgTop,
    bgEdge: _bgBottom,
    brightness: Brightness.dark,
    scaffoldBg: _bgTop,
    seedColor: _bgMid,
  ),

  // --- Background ---
  background: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_bgTop, _bgMid, _bgBottom],
      stops: [0.0, 0.5, 1.0],
    ),
  ),

  // --- Sidebar Background ---
  sidebarBackground: BoxDecoration(
    color: _surface.withOpacity(0.5),
    border: Border(
      right: BorderSide(color: _bgBottom.withOpacity(0.2), width: 1),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        offset: const Offset(2, 0),
        blurRadius: 10,
      ),
    ],
  ),

  // --- System UI Overlay Style ---
  systemUiOverlayStyle: SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: _bgTop,
    systemNavigationBarIconBrightness: Brightness.light,
  ),

  // --- Background Overlays ---
  backgroundOverlays: const [],

  // --- FAB ---
  fab: FabThemeData(
    bg: const RadialGradient(
      center: Alignment.topLeft,
      radius: 1.0,
      colors: [_accentRed, Color(0xFFFF8A80)],
    ),
    shadow: BoxShadow(
      color: _accentRed.withOpacity(0.5),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 0),
    ),
    iconColor: Colors.white,
    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
  ),

  // --- Sidebar ---
  sidebar: SidebarThemeData(
    bgDecoration: BoxDecoration(
      color: _surface.withOpacity(0.4),
      border: Border(
        right: BorderSide(color: _bgBottom.withOpacity(0.3), width: 1),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(5, 0),
        ),
      ],
    ),
    textColor: _textSecondary,
    activeTextColor: _accentRed,
    subTextColor: const Color(0xFF8D6E63),
    pillColor: _surface.withOpacity(0.6),
    pillShadows: [
      BoxShadow(
        color: _accentRed.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(0, 0),
      ),
    ],
    pillBorder: Border.all(color: Colors.white.withOpacity(0.1)),
    buttonGradient: const LinearGradient(
      colors: [_accentRed, _bgBottom],
    ),
    buttonShadow: BoxShadow(
      color: _accentRed.withOpacity(0.4),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ),

  // --- Settings ---
  settings: SettingsThemeData(
    groupDecoration: BoxDecoration(
      color: _surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _bgBottom.withOpacity(0.1), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    dividerColor: Colors.white.withOpacity(0.05),
    textColor: _textPrimary,
    activeSwitchColor: _accentRed,
    activeTrackColor: _accentRed.withOpacity(0.3),
    titleColor: _textPrimary,
    titleShadow: const Shadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    iconColor: _accentRed,
    showPetalRain: false,
    showStarrySky: false,
    sheetTextColor: _textPrimary,
    sheetBackgroundColor: const Color(0xFF352044).withOpacity(0.95),
    sheetTitleColor: _textPrimary,
    sheetTapeColor: const Color(0xFFFF5252).withOpacity(0.3),
    sheetShadows: [
      BoxShadow(
        color: const Color(0xFFEF5350).withOpacity(0.15),
        blurRadius: 20,
        offset: const Offset(0, -5),
      ),
    ],
    sheetBorder: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
    sheetShowTape: false,
    sheetInfoBackgroundColor: _surface.withOpacity(0.55),
    sheetInfoBorderColor: Colors.white.withOpacity(0.1),
    sheetInfoDividerColor: _accentRed.withOpacity(0.18),
    optionSelectedBgColor: _accentRed,
    optionSelectedTextColor: _surface,
    optionSelectedShadow: const BoxShadow(
      color: Color.fromRGBO(255, 82, 82, 0.4),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
    optionUnselectedBgColor: const Color(0xFF352044).withOpacity(0.6),
    optionUnselectedTextColor: const Color(0xFFBCAAA4),
    optionUnselectedBorder: Border.all(color: Colors.white.withOpacity(0.1)),
  ),

  // --- Editor ---
  editor: EditorThemeData(
    appBarBg: _surface.withOpacity(0.8),
    iconColor: _accentRed,
    cursorColor: _accentRed,
    lineColor: Colors.white.withOpacity(0.05),
    dividerColor: Colors.white.withOpacity(0.1),
    applyBlur: false,
    saveButtonBg: const Color(0xFFF7F1E3),
    saveButtonTextColor: const Color(0xFF5D4037),
    saveButtonCheckColor: const Color(0xFFC0392B),
    dropdownBg: const Color(0xFF352044),
    dropdownText: const Color(0xFFE4E0EC),
    exportPaperColor: const Color(0xFF352044),
    exportBorderColor: const Color(0xFFFF5252),
    ribbonAccentColor: const Color(0xFFFF5252),
    hintColor: Colors.white24,
  ),

  // --- Diary Card ---
  diaryCard: DiaryCardThemeData(
    bgColor: _surface.withOpacity(0.6),
    titleColor: _textPrimary,
    contentColor: _textSecondary,
    dateColor: _accentRed,
    iconColor: _accentRed,
    dashedLineColor: Colors.white.withOpacity(0.1),
    shadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        offset: const Offset(0, 4),
        blurRadius: 10,
      ),
    ],
    hoverShadows: [
      BoxShadow(
        color: _accentRed.withOpacity(0.2),
        offset: const Offset(0, 8),
        blurRadius: 20,
      ),
    ],
    border: Border.all(color: _bgBottom.withOpacity(0.2), width: 1),
    dateWeight: FontWeight.normal,
    glassEffect: true,
    glassColor: _surface.withOpacity(0.6),
    blurSigma: 10.0,
    borderRadius: 12.0,
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
    iconColor: _accentRed,
    cardShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        offset: const Offset(0, 4),
        blurRadius: 10,
      ),
      BoxShadow(
        color: _accentRed.withValues(alpha: 0.16),
        offset: const Offset(0, 0),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
    cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    useGlassEffect: true,
    cardBlurSigma: 10,
    imageStackColor: _surface.withValues(alpha: 0.82),
    imageStackBorderColor: _accentRed.withValues(alpha: 0.18),
    imageStackShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4,
      offset: const Offset(2, 4),
    ),
    imageSurfaceColor: const Color(0xFF2C193A),
    imageSurfaceShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
    indicatorActiveColor: _accentRed,
    indicatorInactiveColor: Colors.white.withValues(alpha: 0.25),
    watermarkDividerColor: _accentRed.withValues(alpha: 0.18),
    audioSurfaceColor: _surface.withValues(alpha: 0.7),
    audioSurfaceBorderColor: Colors.white.withValues(alpha: 0.1),
    audioButtonColor: _accentRed,
    audioButtonIconColor: _surface,
    audioButtonShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    audioProgressBgColor: Colors.white.withValues(alpha: 0.12),
    audioProgressColor: _accentRed.withValues(alpha: 0.75),
    audioDurationColor: _textSecondary.withValues(alpha: 0.85),
    deleteIconColor: _accentRed.withValues(alpha: 0.75),
  ),

  // --- Book Directory ---
  bookDirectory: BookDirectoryThemeData(
    inkColor: _textPrimary,
    paperColor: _surface.withOpacity(0.8),
    paperBorderColor: Colors.white.withOpacity(0.1),
    paperShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15),
    ],
  ),

  // --- Moments ---
  moments: MomentsThemeData(
    rulerBg: _surface.withOpacity(0.9),
    rulerTextColor: _textSecondary,
    rulerInactiveTextColor: _textSecondary.withOpacity(0.3),
    rulerSubTextColor: _accentRed,
    rulerInactiveSubTextColor: _accentRed.withOpacity(0.3),
    rulerIndicatorColor: _accentRed,
    rulerShadowColor: Colors.black.withOpacity(0.2),
    rulerBorderColor: Colors.white.withOpacity(0.1),
    appBarIconColor: _accentRed,
    appBarTextColor: _textPrimary,
    drawerScrimColor: Colors.black54,
    appBarBg: const Color(0xFF352044).withValues(alpha: 0.8),
  ),

  // --- Search ---
  search: SearchThemeData(
    bgColor: Colors.black.withOpacity(0.2),
    textColor: _textPrimary,
    hintColor: _textSecondary.withOpacity(0.5),
    iconColor: _accentRed,
    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
  ),

  // --- Month Divider ---
  monthDivider: MonthDividerThemeData(
    textColor: _textPrimary,
    lineColor: _accentRed.withOpacity(0.4),
    paperColor: _surface.withOpacity(0.7),
    shadows: [
      BoxShadow(
        color: _accentRed.withOpacity(0.15),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  ),

  // --- Dialog ---
  dialog: AppDialogThemeData(
    paper: _surface.withOpacity(0.95),
    title: _textPrimary,
    text: _textSecondary,
    icon: _accentRed,
    tape: _accentRed.withOpacity(0.3),
    shadow: _accentRed.withOpacity(0.2),
    border: Colors.white.withOpacity(0.1),
    primaryBtn: _accentRed,
    primaryBtnText: _surface,
    secondaryBtn: _textSecondary,
  ),

  // --- Toast ---
  toast: const ToastThemeData(
    success: ToastStyleData(
      bg: _surface,
      border: _accentRed,
      icon: _accentRed,
      text: _textPrimary,
    ),
    error: ToastStyleData(
      bg: _surface,
      border: _accentRed,
      icon: _accentRed,
      text: _textPrimary,
    ),
    warning: ToastStyleData(
      bg: _surface,
      border: Color(0xFFFFB74D),
      icon: Color(0xFFFFB74D),
      text: _textPrimary,
    ),
    info: ToastStyleData(
      bg: _surface,
      border: _accentRed,
      icon: _accentRed,
      text: _textPrimary,
    ),
  ),

  // --- Lock Screen ---
  lockScreen: LockScreenThemeData(
    displayBg: _bgTop.withOpacity(0.3),
    displayBorder: _accentRed.withOpacity(0.3),
    accentColor: _accentRed,
    keyBg: _surface.withOpacity(0.4),
    keyBorder: _accentRed.withOpacity(0.2),
    keyText: _textPrimary,
  ),

  // --- Mobile Header ---
  mobileHeader: MobileHeaderColorsData(
    background: _bgTop.withOpacity(0.85),
    border: Colors.white.withOpacity(0.1),
    iconColor: _accentRed,
    titleColor: _textPrimary,
    subtitleColor: _textSecondary,
  ),

  // --- Dialog Input ---
  dialogInput: DialogInputThemeData(
    textColor: _textPrimary,
    hintColor: _textSecondary.withOpacity(0.5),
    borderColor: _accentRed.withOpacity(0.3),
    focusedBorderColor: _accentRed,
    iconColor: _accentRed.withOpacity(0.6),
    backgroundColor: const Color(0xFF352044).withOpacity(0.6),
    descriptionColor: _textSecondary,
  ),

  // --- Statistics ---
  statistics: StatisticsThemeData(
    cardBackground: BoxDecoration(
      color: _surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _bgBottom.withOpacity(0.2), width: 1),
      boxShadow: [
        BoxShadow(
          color: _accentRed.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 0),
          spreadRadius: -2,
        ),
      ],
    ),
    cardShadow: BoxShadow(
      color: _accentRed.withOpacity(0.2),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: -2,
    ),
    cardBorder: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
    accentColor: _accentRed,
    textColor: _textPrimary,
    secondaryTextColor: _textSecondary,
    chartColor: _accentRed,
    badgeStyle: StatisticsBadgeStyleData(
      backgroundColor: _accentRed.withOpacity(0.2),
      textColor: _accentRed,
      borderColor: _accentRed.withOpacity(0.3),
    ),
  ),

  // --- Trash Page ---
  trashPage: TrashPageThemeData(
    titleColor: _textPrimary,
    iconColor: _accentRed,
    restoreColor: _accentRed,
    dangerColor: const Color(0xFFE91E63),
    cardTitleColor: _textPrimary,
    cardDateColor: _textPrimary.withOpacity(0.6),
    cardDecoration: BoxDecoration(
      color: _surface.withOpacity(0.6),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _accentRed.withOpacity(0.3), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
  ),

  // --- Sync Settings ---
  syncSettings: SyncSettingsThemeData(
    titleColor: _textPrimary,
    textColor: _textPrimary,
    accentColor: _accentRed,
    lockBtnColor: _accentRed,
    switchTrackColor: _surface,
    switchThumbColor: _accentRed,
    switchActiveText: _surface,
    switchInactiveText: _accentRed.withOpacity(0.6),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFFEF5350), Color(0xFFC62828)],
    ),
    primaryShadowColor: _accentRed.withOpacity(0.3),
    secondaryBtnColor: _surface.withOpacity(0.6),
    secondaryBtnTextColor: _accentRed,
    secondaryBorderColor: _accentRed.withOpacity(0.2),
    tipsBgColor: _surface.withOpacity(0.8),
    switchBgColor: _surface.withOpacity(0.6),
    slidingSwitchShadowOpacity: 0.05,
    thumbShadowOpacity: 0.1,
  ),

  // --- Moment Input ---
  momentInput: MomentInputThemeData(
    containerColor: const Color(0xFF352044).withValues(alpha: 0.9),
    containerShadows: [
      BoxShadow(
        color: const Color(0xFFFF5252).withValues(alpha: 0.1),
        offset: const Offset(0, -4),
        blurRadius: 10,
      ),
    ],
    inputBgColor: const Color(0xFF2D1E1B).withValues(alpha: 0.5),
    inputBorderColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
    textColor: const Color(0xFFE4E0EC),
    hintColor: const Color(0xFFE4E0EC).withValues(alpha: 0.5),
    iconColor: const Color(0xFFFF5252),
    sendColor: const Color(0xFFFF5252),
    imageIconColor: const Color(0xFFFF5252),
    cursorColor: const Color(0xFFFF5252),
    recordingColor: const Color(0xFFE53935),
    cancelColor: const Color(0xFFE4E0EC).withValues(alpha: 0.5),
    imageRemoveBgColor: Colors.black.withValues(alpha: 0.45),
    imageRemoveIconColor: Colors.white,
    cassetteDeckColor: const Color(0xFF24162D),
    cassetteDeckBorderColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
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
    cassetteLabelColor: const Color(0xFFF3E5F5),
    cassetteWindowColor: Colors.black87,
    cassetteWindowBorderColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
    cassetteBridgeColor: Colors.black,
    cassetteCounterColor: const Color(0xFFFF5252),
    cassetteScrewColor: Colors.white.withValues(alpha: 0.24),
    miniCassetteBgColor: const Color(0xFF24162D).withValues(alpha: 0.95),
    miniCassettePlayColor: const Color(0xFFFF5252),
    miniCassetteTextColor: const Color(0xFFE4E0EC),
    miniCassetteHintColor: _textSecondary,
    miniCassetteDeleteColor: _textSecondary.withValues(alpha: 0.8),
  ),

  // --- Moment Editor ---
  momentEditor: MomentEditorThemeData(
    bgColor: _surface,
    appBarTextColor: _textPrimary,
    appBarIconColor: _textPrimary,
    inputBg: Colors.black.withOpacity(0.2),
    inputTextColor: _textPrimary,
    hintColor: _textSecondary.withOpacity(0.6),
    dropdownBg: Colors.black.withOpacity(0.2),
    dropdownIconColor: _accentRed,
    dropdownMenuBg: _bgTop,
    dropdownItemColor: _textPrimary,
    photoEmptyColor: Colors.white.withOpacity(0.05),
    photoIconColor: _accentRed,
  ),

  // --- Refresh Indicator ---
  refreshIndicator: const AppRefreshIndicatorThemeData(
    bookColor: Color(0xFF352044),
    pageColor: Color(0xFF2D1E1B),
    textColor: Color(0xFFFF5252),
  ),

  // --- Privacy Dialog ---
  privacyDialog: const PrivacyDialogThemeData(
    linkColor: Color(0xFFFF5252),
    contentTextColor: Color(0xFFE4E0EC),
    disclaimerTextColor: Color(0xFFBCAAA4),
  ),

  // --- Paper Sheet ---
  paperSheet: PaperSheetThemeData(
    paperColor: _surface,
    accentColor: const Color(0xFFFF5252),
    border: Border.all(
      color: const Color(0xFFFF5252).withOpacity(0.3),
      width: 1,
    ),
    shadows: [
      BoxShadow(
        color: const Color(0xFFEF5350).withOpacity(0.15),
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
    emptyStateIconColor: _accentRed.withValues(alpha: 0.5),
    emptyStateTextColor: _textSecondary.withValues(alpha: 0.8),
    emptyStateLinkColor: _accentRed,
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
    dialogBg: const Color(0xFF352044),
    headerBg: const Color(0xFF2E1A3C),
    headerText: const Color(0xFFEF5350),
    bodyText: const Color(0xFFB39DDB),
    accentColor: const Color(0xFFEF5350),
    weekDayColor: const Color(0xFF90CAF9),
    border: Border.all(
      color: const Color(0xFFEF5350).withOpacity(0.3),
      width: 1,
    ),
    shadows: [
      BoxShadow(
        color: const Color(0xFFEF5350).withValues(alpha: 0.15),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  ),
);
