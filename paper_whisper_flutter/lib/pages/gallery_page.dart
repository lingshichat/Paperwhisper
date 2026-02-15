import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../services/moment_service.dart';
import '../services/thumbnail_cache_service.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';

class GalleryImage {
  final String imagePath;
  final Moment moment;
  final int imageIndex;

  GalleryImage({
    required this.imagePath,
    required this.moment,
    required this.imageIndex,
  });
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final MomentService _momentService = MomentService();
  final ThumbnailCacheService _thumbnailCache = ThumbnailCacheService();
  List<GalleryImage> _galleryImages = [];
  bool _isLoading = true;
  Directory? _baseDir;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _thumbnailCache.init();

    try {
      final moments = await _momentService.getMoments();
      _baseDir = _momentService.dataDir;

      final List<GalleryImage> images = [];
      for (var moment in moments) {
        for (int i = 0; i < moment.images.length; i++) {
          images.add(GalleryImage(
            imagePath: moment.images[i],
            moment: moment,
            imageIndex: i,
          ));
        }
      }

      // 按时间倒序排列
      images.sort((a, b) => b.moment.createdAt.compareTo(a.moment.createdAt));

      setState(() {
        _galleryImages = images;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载图库失败: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '图库',
          style: GoogleFonts.notoSerifSc(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_galleryImages.length} 张',
                style: GoogleFonts.notoSerifSc(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(colorScheme)
          : _galleryImages.isEmpty
              ? _buildEmptyView(colorScheme, theme)
              : _buildGalleryGrid(colorScheme, theme),
    );
  }

  Widget _buildLoadingView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '加载中...',
            style: GoogleFonts.notoSerifSc(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(ColorScheme colorScheme, String theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无图片',
            style: GoogleFonts.notoSerifSc(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在随心记中添加照片，它们会显示在这里',
            style: GoogleFonts.notoSerifSc(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(ColorScheme colorScheme, String theme) {
    return Container(
      decoration: AppTheme.getBackground(theme),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        // 使用懒加载，只渲染可视区域
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _galleryImages.length,
        // 使用 addAutomaticKeepAlives: false 避免保持所有子组件
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        cacheExtent: 200, // 预加载距离
        itemBuilder: (context, index) {
          final galleryImage = _galleryImages[index];
          return _ImageTile(
            key: ValueKey('${galleryImage.moment.uuid}_${galleryImage.imagePath}'),
            galleryImage: galleryImage,
            baseDir: _baseDir,
            thumbnailCache: _thumbnailCache,
            onTap: () => _showImageDetail(index),
          );
        },
      ),
    );
  }

  void _showImageDetail(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailPage(
          galleryImages: _galleryImages,
          baseDir: _baseDir,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// 全局队列控制并发数量
class _ThumbnailLoadQueue {
  static final _ThumbnailLoadQueue _instance = _ThumbnailLoadQueue._internal();
  factory _ThumbnailLoadQueue() => _instance;
  _ThumbnailLoadQueue._internal();

  final List<_QueueItem> _queue = [];
  int _runningCount = 0;
  static const int _maxConcurrent = 2; // 最多同时处理2个

  Future<Uint8List?> enqueue(
    String imagePath,
    ThumbnailCacheService cache,
  ) async {
    final completer = Completer<Uint8List?>();
    _queue.add(_QueueItem(imagePath: imagePath, cache: cache, completer: completer));
    _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    if (_runningCount >= _maxConcurrent || _queue.isEmpty) return;

    _runningCount++;
    final item = _queue.removeAt(0);

    try {
      final result = await _loadThumbnail(item.imagePath, item.cache);
      item.completer.complete(result);
    } catch (e) {
      item.completer.complete(null);
    } finally {
      _runningCount--;
      // 延迟处理下一个，避免CPU占用过高
      Future.delayed(const Duration(milliseconds: 50), _processQueue);
    }
  }

  Future<Uint8List?> _loadThumbnail(
    String imagePath,
    ThumbnailCacheService cache,
  ) async {
    // 先检查缓存
    final cached = await cache.getThumbnail(imagePath);
    if (cached != null) return cached;

    // 生成缩略图
    final thumbnail = await cache.generateThumbnail(imagePath);
    if (thumbnail != null) {
      await cache.saveThumbnail(imagePath, thumbnail);
      return thumbnail;
    }

    return null;
  }
}

class _QueueItem {
  final String imagePath;
  final ThumbnailCacheService cache;
  final Completer<Uint8List?> completer;

  _QueueItem({
    required this.imagePath,
    required this.cache,
    required this.completer,
  });
}

// 独立的图片Tile组件
class _ImageTile extends StatefulWidget {
  final GalleryImage galleryImage;
  final Directory? baseDir;
  final ThumbnailCacheService thumbnailCache;
  final VoidCallback onTap;

  const _ImageTile({
    super.key,
    required this.galleryImage,
    required this.baseDir,
    required this.thumbnailCache,
    required this.onTap,
  });

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // 延迟加载，避免同时加载太多
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() => _isVisible = true);
        _loadThumbnail();
      }
    });
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading) return;
    
    final fullPath = widget.baseDir != null
        ? '${widget.baseDir!.path}${Platform.pathSeparator}${widget.galleryImage.imagePath}'
        : widget.galleryImage.imagePath;

    // 先检查缓存
    final cached = await widget.thumbnailCache.getThumbnail(fullPath);
    if (cached != null && mounted) {
      setState(() => _thumbnailBytes = cached);
      return;
    }

    // 使用队列控制并发
    setState(() => _isLoading = true);
    
    final thumbnail = await _ThumbnailLoadQueue().enqueue(
      fullPath,
      widget.thumbnailCache,
    );

    if (mounted) {
      setState(() {
        _thumbnailBytes = thumbnail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorScheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(colorScheme),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    // 如果有缩略图，显示缩略图
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true, // 避免闪烁
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(colorScheme);
        },
      );
    }

    // 否则显示占位符
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary.withOpacity(0.5),
                ),
              )
            : Icon(
                Icons.image,
                color: colorScheme.onSurface.withOpacity(0.2),
                size: 32,
              ),
      ),
    );
  }
}

// 图片详情页
class ImageDetailPage extends StatefulWidget {
  final List<GalleryImage> galleryImages;
  final Directory? baseDir;
  final int initialIndex;

  const ImageDetailPage({
    super.key,
    required this.galleryImages,
    this.baseDir,
    required this.initialIndex,
  });

  @override
  State<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage> {
  late PageController _pageController;
  late int _currentIndex;
  GalleryImage get _currentImage => widget.galleryImages[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final moment = _currentImage.moment;

    final dateStr = '${moment.createdAt.year}-${moment.createdAt.month.toString().padLeft(2, '0')}-${moment.createdAt.day.toString().padLeft(2, '0')}';
    final timeStr = '${moment.createdAt.hour.toString().padLeft(2, '0')}:${moment.createdAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$dateStr $timeStr',
          style: GoogleFonts.notoSerifSc(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${widget.galleryImages.length}',
                style: GoogleFonts.notoSerifSc(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.galleryImages.length,
              itemBuilder: (context, index) {
                final galleryImage = widget.galleryImages[index];
                final fullPath = widget.baseDir != null
                    ? '${widget.baseDir!.path}${Platform.pathSeparator}${galleryImage.imagePath}'
                    : galleryImage.imagePath;
                final file = File(fullPath);

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image,
                          size: 80,
                          color: Colors.white.withOpacity(0.5),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_currentImage.moment.uuid + _currentImage.imagePath),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '随心记',
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 13,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '第 ${_currentImage.imageIndex + 1}/${_currentImage.moment.images.length} 张',
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (moment.content.isNotEmpty)
                      Text(
                        moment.content,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 15,
                          color: colorScheme.onSurface,
                          height: 1.6,
                        ),
                      )
                    else
                      Text(
                        '（无文字内容）',
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.4),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
