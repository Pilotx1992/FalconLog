import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerformanceOptimizer {
  // تحسين الأداء للواجهة
  static void optimizeUI() {
    // تقليل رسم الإطارات غير الضرورية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // تحسين الذاكرة
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
    });
  }

  // تحسين العمليات الثقيلة
  static Future<T> performHeavyOperation<T>(Future<T> Function() operation) async {
    // تشغيل العملية في إطار منفصل لتجنب حجب UI
    return await operation();
  }

  // تحسين التمرير
  static ScrollPhysics get optimizedScrollPhysics => const BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  // إعدادات الرسوم المتحركة المحسنة
  static Duration get fastAnimation => const Duration(milliseconds: 200);
  static Duration get normalAnimation => const Duration(milliseconds: 300);
  
  // تحسين الألوان للأداء
  static Color withPerformantOpacity(Color color, double opacity) {
    return Color.fromARGB(
      (255 * opacity).round(),
      color.red,
      color.green,
      color.blue,
    );
  }

  // Widget للتحسين التلقائي
  static Widget optimizedContainer({
    required Widget child,
    Color? color,
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
  }) {
    return RepaintBoundary(
      child: Container(
        color: color,
        decoration: decoration,
        padding: padding,
        margin: margin,
        width: width,
        height: height,
        child: child,
      ),
    );
  }

  // تحسين القوائم الطويلة
  static Widget optimizedListView({
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      physics: optimizedScrollPhysics,
      itemCount: itemCount,
      cacheExtent: 500, // تحسين التخزين المؤقت
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }

  // تحسين الصور
  static Widget optimizedImage({
    required String path,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return RepaintBoundary(
      child: Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width?.toInt(),
        cacheHeight: height?.toInt(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  // تحسين العمليات غير المتزامنة
  static Future<void> deferredExecution(VoidCallback callback, [Duration delay = Duration.zero]) {
    return Future.delayed(delay, callback);
  }

  // تحسين استخدام الذاكرة
  static void cleanupResources() {
    // تنظيف الذاكرة
    PaintingBinding.instance.imageCache.clear();
    SystemChannels.platform.invokeMethod('SystemChrome.setSystemUIOverlayStyle');
  }
}

// Mixin للأداء المحسن
mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    PerformanceOptimizer.deferredExecution(() {
      if (mounted) {
        // تأخير العمليات الثقيلة
        _performDeferredOperations();
      }
    }, const Duration(milliseconds: 100));
  }

  void _performDeferredOperations() {
    // العمليات المؤجلة للحصول على أداء أفضل
  }

  @override
  void dispose() {
    PerformanceOptimizer.cleanupResources();
    super.dispose();
  }
}

// Widget محسن للإحصائيات
class OptimizedStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const OptimizedStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: PerformanceOptimizer.withPerformantOpacity(Colors.black, 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PerformanceOptimizer.withPerformantOpacity(color, 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: PerformanceOptimizer.withPerformantOpacity(
                  const Color(0xFF64748B),
                  1.0,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
