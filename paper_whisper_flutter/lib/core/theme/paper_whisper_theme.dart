import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_colors.dart';
import 'components/fab_theme_data.dart';
import 'components/sidebar_theme_data.dart';
import 'components/settings_theme_data.dart';
import 'components/editor_theme_data.dart';
import 'components/diary_card_theme_data.dart';
import 'components/moment_card_theme_data.dart';
import 'components/book_directory_theme_data.dart';
import 'components/moments_theme_data.dart';
import 'components/search_theme_data.dart';
import 'components/month_divider_theme_data.dart';
import 'components/dialog_theme_data.dart';
import 'components/toast_theme_data.dart';
import 'components/lock_screen_theme_data.dart';
import 'components/mobile_header_colors_data.dart';
import 'components/dialog_input_theme_data.dart';
import 'components/statistics_theme_data.dart';
import 'components/trash_page_theme_data.dart';
import 'components/sync_settings_theme_data.dart';
import 'components/moment_input_theme_data.dart';
import 'components/moment_editor_theme_data.dart';
import 'components/refresh_indicator_theme_data.dart';
import 'components/privacy_dialog_theme_data.dart';
import 'components/paper_sheet_theme_data.dart';
import 'components/diary_list_page_theme_data.dart';
import 'components/moment_standard_card_theme_data.dart';
import 'components/date_picker_theme_data.dart';

/// 主主题类 — 包含所有组件主题和全局装饰
class PaperWhisperTheme {
  final String id;
  final String name;
  final String description;
  final ThemeColors colors;

  // 全局装饰
  final BoxDecoration background;
  final BoxDecoration sidebarBackground;
  final SystemUiOverlayStyle systemUiOverlayStyle;
  final List<Widget> backgroundOverlays;

  // 组件主题 (26)
  final FabThemeData fab;
  final SidebarThemeData sidebar;
  final SettingsThemeData settings;
  final EditorThemeData editor;
  final DiaryCardThemeData diaryCard;
  final MomentCardThemeData momentCard;
  final BookDirectoryThemeData bookDirectory;
  final MomentsThemeData moments;
  final SearchThemeData search;
  final MonthDividerThemeData monthDivider;
  final AppDialogThemeData dialog;
  final ToastThemeData toast;
  final LockScreenThemeData lockScreen;
  final MobileHeaderColorsData mobileHeader;
  final DialogInputThemeData dialogInput;
  final StatisticsThemeData statistics;
  final TrashPageThemeData trashPage;
  final SyncSettingsThemeData syncSettings;
  final MomentInputThemeData momentInput;
  final MomentEditorThemeData momentEditor;
  final AppRefreshIndicatorThemeData refreshIndicator;
  final PrivacyDialogThemeData privacyDialog;
  final PaperSheetThemeData paperSheet;
  final DiaryListPageThemeData diaryListPage;
  final MomentStandardCardThemeData momentStandardCard;
  final AppDatePickerThemeData datePicker;

  const PaperWhisperTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
    required this.background,
    required this.sidebarBackground,
    required this.systemUiOverlayStyle,
    this.backgroundOverlays = const [],
    required this.fab,
    required this.sidebar,
    required this.settings,
    required this.editor,
    required this.diaryCard,
    required this.momentCard,
    required this.bookDirectory,
    required this.moments,
    required this.search,
    required this.monthDivider,
    required this.dialog,
    required this.toast,
    required this.lockScreen,
    required this.mobileHeader,
    required this.dialogInput,
    required this.statistics,
    required this.trashPage,
    required this.syncSettings,
    required this.momentInput,
    required this.momentEditor,
    required this.refreshIndicator,
    required this.privacyDialog,
    required this.paperSheet,
    required this.diaryListPage,
    required this.momentStandardCard,
    required this.datePicker,
  });
}
