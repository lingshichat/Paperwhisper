import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 免费额度提示条（纯展示，props 驱动）。
///
/// 原 `moments_page._buildLimitBanner`：免费用户当日 3 条用尽时展示，
/// 「去赞助」动作经 [onUpgrade] 回调交给页面导航。
class MomentsLimitBanner extends StatelessWidget {
  const MomentsLimitBanner({super.key, required this.onUpgrade});

  /// 去赞助回调（页面负责跳转 PremiumMembershipPage）。
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8D6E63).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '今日随心记已用完 (3/3)，赞助后解锁无限创作',
              style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onUpgrade,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '去赞助',
                style: GoogleFonts.notoSerifSc(
                  color: const Color(0xFFFFE0B2),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
