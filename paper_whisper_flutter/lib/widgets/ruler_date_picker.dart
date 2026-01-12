import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RulerDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final FixedExtentScrollController? controller; // External controller
  final Color? accentColor;

  const RulerDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.controller,
    this.accentColor,
  });

  @override
  State<RulerDatePicker> createState() => _RulerDatePickerState();
}

class _RulerDatePickerState extends State<RulerDatePicker> {
  late FixedExtentScrollController _controller;
  final int _dayRange = 3650; 
  late DateTime _startDate; 

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 365 * 5));
    
    // If external controller provided, use it. Otherwise create one.
    // Note: If using external, parent is responsible for initial offset!
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      final selectedNormalized = DateTime(
        widget.selectedDate.year, 
        widget.selectedDate.month, 
        widget.selectedDate.day
      );
      int initialIndex = selectedNormalized.difference(_startDate).inDays;
      if (initialIndex < 0) initialIndex = 0;
      _controller = FixedExtentScrollController(initialItem: initialIndex);
    }
  }
  
  @override
  void didUpdateWidget(covariant RulerDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final selectedNormalized = DateTime(
        widget.selectedDate.year, 
        widget.selectedDate.month, 
        widget.selectedDate.day
      );
      
      int index = selectedNormalized.difference(_startDate).inDays;
      if (index >= 0 && _controller.hasClients && _controller.selectedItem != index) {
        _controller.animateToItem(
          index, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOutCubic
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lens Ring Height
    const double height = 85;
    const double itemWidth = 70;
    
    final Color activeColor = widget.accentColor ?? const Color(0xFFFF9800);
    // Indicator defaults to activeColor if provided, else RedFocus
    // Use Red as per user feedback
    final Color indicatorColor = const Color(0xFFFF3D00);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Lens Body
        border: Border(bottom: BorderSide(color: Color(0xFF121212), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8)
        ]
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Horizontal ListWheelScrollView (Rotated)
          // Use ShaderMask for "Side Fade"
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [
                  Colors.transparent, 
                  Colors.white, 
                  Colors.white, 
                  Colors.transparent
                ],
                stops: [0.0, 0.2, 0.8, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: RotatedBox(
              quarterTurns: -1, // Rotate -90 deg to make it horizontal
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: itemWidth,
                perspective: 0.003, // 3D cylinder effect
                diameterRatio: 1.5, // Curvature
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  final date = _startDate.add(Duration(days: index));
                  if (!_isSameDay(date, widget.selectedDate)) {
                    widget.onDateChanged(date);
                  }
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _dayRange,
                  builder: (context, index) {
                    final date = _startDate.add(Duration(days: index));
                    final isSelected = _isSameDay(date, widget.selectedDate);
                    final isToday = _isSameDay(date, DateTime.now());

                    // Rotate children back 90 deg so they stay upright
                    return RotatedBox(
                      quarterTurns: 1,
                      child: Container(
                         alignment: Alignment.center,
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             // Value (Date)
                             Text(
                               date.day.toString(),
                               style: GoogleFonts.robotoMono(
                                 fontSize: isSelected ? 20 : 16,
                                 fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                                 color: isSelected ? activeColor : Colors.grey[600],
                               ),
                             ),
                             const SizedBox(height: 4),
                             // Label (Day)
                             Text(
                               isToday ? "TODAY" : DateFormat('E').format(date).toUpperCase(),
                               style: GoogleFonts.roboto( 
                                 fontSize: 10,
                                 color: isSelected ? Colors.white : Colors.grey[700],
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             const SizedBox(height: 6),
                             // Hash Marks
                             Container(
                               width: 1,
                               height: isSelected ? 12 : 8,
                               color: isSelected ? activeColor : Colors.grey[700],
                             )
                           ],
                         ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // 2. Center Indicator (The "Red Line" on the lens barrel)
          Positioned(
             bottom: 0,
             child: Container(
               width: 3,
               height: 12,
               decoration: BoxDecoration(
                 color: indicatorColor,
                 borderRadius: BorderRadius.circular(1.5),
                 boxShadow: [BoxShadow(color: indicatorColor.withOpacity(0.5), blurRadius: 4)]
               ),
             ),
          ),
          
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
