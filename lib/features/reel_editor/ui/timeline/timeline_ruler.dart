import 'package:flutter/material.dart';
class TimelineRuler extends StatelessWidget {
  final Duration duration; final double pixelsPerSecond; final Duration position;
  const TimelineRuler({super.key, required this.duration, required this.pixelsPerSecond, required this.position});
  @override Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, constraints) {
      final width = duration.inMilliseconds/1000*pixelsPerSecond;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: SizedBox(width: width.clamp(constraints.maxWidth,double.infinity), height: 28, child: CustomPaint(painter: _RulerPainter(duration,pixelsPerSecond,Theme.of(context)), size: Size(width,28))));
    });
  }
}
class _RulerPainter extends CustomPainter {
  final Duration duration; final double pps; final ThemeData theme;
  _RulerPainter(this.duration,this.pps,this.theme);
  @override void paint(Canvas canvas, Size size){
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final major = Paint()..color=theme.dividerColor;
    final minor = Paint()..color=theme.dividerColor.withValues(alpha:0.4);
    for(int s=0; s<= duration.inSeconds; s++){
      final x = s * pps;
      final isMajor = s % 5==0;
      canvas.drawLine(Offset(x, isMajor?0:8), Offset(x, size.height), isMajor?major:minor);
      if(isMajor){ textPainter.text=TextSpan(text: '${s}s', style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color)); textPainter.layout(); textPainter.paint(canvas, Offset(x+2,2));}
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old)=>true;
}
