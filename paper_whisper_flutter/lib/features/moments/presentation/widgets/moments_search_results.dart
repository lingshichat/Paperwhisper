import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'moment_card.dart';

/// 随心记搜索结果列表（纯展示，props 驱动）。
///
/// 原 `moments_page._buildSearchResults`：命中列表 / 无结果空态文案，
/// 底部留白由页面按输入区高度传入。
class MomentsSearchResults extends StatelessWidget {
  const MomentsSearchResults({
    super.key,
    required this.moments,
    required this.baseDir,
    required this.textColor,
    required this.bottomPadding,
    required this.onDelete,
  });

  final List<Moment> moments;
  final Directory? baseDir;
  final Color? textColor;
  final double bottomPadding;
  final Future<void> Function(Moment moment) onDelete;

  @override
  Widget build(BuildContext context) {
    // 使用透明容器，确保背景可以穿透显示
    return Container(
      color: Colors.transparent, // 透明背景
      child: moments.isEmpty
          ? Center(
              child: Opacity(
                opacity: 0.7,
                child: Text(
                  '没有找到相关记忆...',
                  style: GoogleFonts.notoSerifSc(
                    color: textColor?.withValues(alpha: 0.7) ?? Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : BackdropGroup(
              child: ListView.builder(
                padding: EdgeInsets.only(top: 20, bottom: bottomPadding),
                itemCount: moments.length,
                itemBuilder: (context, i) {
                  return MomentCard(
                    moment: moments[i],
                    baseDir: baseDir,
                    onDelete: () => onDelete(moments[i]),
                  );
                },
              ),
            ),
    );
  }
}
