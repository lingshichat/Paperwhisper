import 'dart:io';

import 'package:flutter/material.dart';

import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'moment_card.dart';

/// 桌面端随心记瀑布流（纯展示，props 驱动）。
///
/// 原 `moments_page._buildDesktopWaterfall`：按宽度 1/2/3 列瀑布布局，
/// 最新在前；空列表由页面在装配层决定展示 [MomentsEmptyState]。
class MomentsWaterfall extends StatelessWidget {
  const MomentsWaterfall({
    super.key,
    required this.moments,
    required this.baseDir,
    required this.onDelete,
  });

  final List<Moment> moments;
  final Directory? baseDir;
  final Future<void> Function(Moment moment) onDelete;

  @override
  Widget build(BuildContext context) {
    // Sort by latest first for waterfall (Spontaneous inputs matter most)
    final sortedMoments = List<Moment>.from(moments);
    sortedMoments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Logic from DiaryListPage
        int columnCount = 1;
        if (width > 1200) {
          // Slightly wider for moments card
          columnCount = 3;
        } else if (width > 750) {
          columnCount = 2;
        }

        // Masonry Logic
        List<List<Moment>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < sortedMoments.length; i++) {
          columns[i % columnCount].add(sortedMoments[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            40,
            20,
            40,
            100,
          ), // Bottom padding for input widget
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1
                        ? const EdgeInsets.only(right: 24)
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((moment) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: MomentCard(
                            moment: moment,
                            baseDir: baseDir,
                            onDelete: () => onDelete(moment),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
