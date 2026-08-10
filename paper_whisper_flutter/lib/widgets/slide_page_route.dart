// 兼容层：真实定义已集中到 app/navigation/route_transitions.dart。
// 迁移完成并删除本文件前，现有消费者 import 路径保持不变。
// 仅导出本旧文件原有的公开符号：SlidePageRoute / FadeSlidePageRoute。
export '../app/navigation/route_transitions.dart'
    show SlidePageRoute, FadeSlidePageRoute;
