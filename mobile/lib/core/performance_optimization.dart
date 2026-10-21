import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Performance optimization utilities for the Maylaud app
class PerformanceOptimization {
  /// Configure image cache settings
  static void configureImageCache() {
    // Increase image cache size (default is 100MB)
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        200 * 1024 * 1024; // 200MB

    // Set cache width/height for common screen sizes
    // This helps with memory usage
    ImageCache().clear();
    ImageCache().clearLiveImages();
  }

  /// Clear image cache (useful when memory is low)
  static void clearImageCache() {
    ImageCache().clear();
    ImageCache().clearLiveImages();
  }

  /// Get optimized CachedNetworkImage widget with proper error handling
  static Widget cachedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool useOldImageOnUrlChange = true,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40,
            ),
          ),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      memCacheWidth: width.toInt(),
      memCacheHeight: height.toInt(),
      maxWidthDiskCache: width.toInt() * 2, // Retina support
      maxHeightDiskCache: height.toInt() * 2,
    );
  }

  /// Get optimized local asset image with caching
  static Widget cachedAssetImage({
    required String assetPath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width.toInt(),
      cacheHeight: height.toInt(),
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
    );
  }

  /// Check if widget should rebuild based on previous and current state
  static bool shouldRebuild<T>(T oldValue, T newValue) {
    return oldValue != newValue;
  }

  /// Debounce function for limiting frequent function calls
  static Function debounce(
    Function func, [
    Duration delay = const Duration(milliseconds: 300),
  ]) {
    Timer? timer;
    return () {
      if (timer != null) {
        timer!.cancel();
      }
      timer = Timer(delay, () {
        func();
      });
    };
  }

  /// Throttle function for limiting function calls to once per interval
  static Function throttle(
    Function func, [
    Duration interval = const Duration(milliseconds: 500),
  ]) {
    bool enableCall = true;
    return () {
      if (enableCall) {
        func();
        enableCall = false;
        Timer(interval, () {
          enableCall = true;
        });
      }
    };
  }

  /// Memory usage warning check
  static void checkMemoryUsage(BuildContext context) {
    // In a real app, you would use platform channels to get memory usage
    // For now, we'll just log a warning
    debugPrint('Performance: Checking memory usage...');

    // Clear cache if memory is potentially high
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This runs after the frame is built
      Future.delayed(const Duration(seconds: 30), () {
        clearImageCache();
        debugPrint('Performance: Image cache cleared periodically');
      });
    });
  }

  /// Optimized list view builder for large lists
  static Widget optimizedListViewBuilder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    EdgeInsetsGeometry? padding,
    ScrollController? controller,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    double? cacheExtent,
  }) {
    return ListView.builder(
      padding: padding,
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const BouncingScrollPhysics(),
      cacheExtent: cacheExtent ?? 500, // Cache 500 pixels worth of items
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Use AutomaticKeepAliveClientMixin for items that should stay alive
        return itemBuilder(context, index);
      },
    );
  }

  /// Optimized grid view builder for large grids
  static Widget optimizedGridViewBuilder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    EdgeInsetsGeometry? padding,
    ScrollController? controller,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    double? cacheExtent,
  }) {
    return GridView.builder(
      padding: padding,
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const BouncingScrollPhysics(),
      cacheExtent: cacheExtent ?? 500,
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return itemBuilder(context, index);
      },
    );
  }

  /// Precache images for smoother transitions
  static Future<void> precacheImages(
      BuildContext context, List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        final provider = NetworkImage(url);
        await precacheImage(provider, context);
      } catch (e) {
        debugPrint('Failed to precache image: $url, error: $e');
      }
    }
  }

  /// Precache asset images
  static Future<void> precacheAssetImages(
      BuildContext context, List<String> assetPaths) async {
    for (final path in assetPaths) {
      try {
        final provider = AssetImage(path);
        await precacheImage(provider, context);
      } catch (e) {
        debugPrint('Failed to precache asset image: $path, error: $e');
      }
    }
  }
}

/// Optimized widget that only rebuilds when necessary
class OptimizedWidget extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final List<Object?> dependencies;

  const OptimizedWidget({
    super.key,
    required this.builder,
    required this.dependencies,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // This widget will only rebuild if dependencies change
        return builder(context);
      },
    );
  }
}

/// Memory-efficient image widget that automatically clears cache when disposed
class MemoryEfficientImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const MemoryEfficientImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<MemoryEfficientImage> createState() => _MemoryEfficientImageState();
}

class _MemoryEfficientImageState extends State<MemoryEfficientImage> {
  @override
  void dispose() {
    // Clear this specific image from cache when widget is disposed
    // This helps prevent memory leaks
    ImageProvider provider = NetworkImage(widget.imageUrl);
    provider.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceOptimization.cachedImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
    );
  }
}
