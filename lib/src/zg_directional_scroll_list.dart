import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 双向滚动列表控制器
class ZgScrollListController<T> {
  _ZgDirectionalScrollListState<T>? _state;

  /// 是否已附加到列表
  bool get isAttached => _state != null;

  /// 附加到列表状态（内部使用）
  void _attach(_ZgDirectionalScrollListState<T> state) {
    _state = state;
  }

  /// 分离列表状态（内部使用）
  void _detach() {
    _state = null;
  }

  /// 追加数据到底部
  void appendData(List<T> items) {
    _state?.appendData(items);
  }

  /// 前置添加数据到顶部
  void prependData(List<T> items) {
    _state?.prependData(items);
  }

  /// 插入单条数据
  void insertData(int index, T item, {bool toPreList = true}) {
    _state?.insertData(index, item, toPreList: toPreList);
  }

  /// 批量插入数据
  void insertAllData(int index, List<T> items, {bool toPreList = true}) {
    _state?.insertAllData(index, items, toPreList: toPreList);
  }

  /// 清除所有数据
  void clearData() {
    _state?.clearData();
  }

  /// 清除前置数据
  void clearPreData() {
    _state?.clearPreData();
  }

  /// 清除后置数据
  void clearMoreData() {
    _state?.clearMoreData();
  }

  /// 更新指定位置的数据
  void updateData(int index, T item, {bool toPreList = true}) {
    _state?.updateData(index, item, toPreList: toPreList);
  }

  /// 删除指定位置的数据
  void removeData(int index, {bool toPreList = true}) {
    _state?.removeData(index, toPreList: toPreList);
  }

  /// 获取所有数据
  List<T> getAllData() {
    return _state?.getAllData() ?? [];
  }

  /// 获取前置数据
  List<T> getPreData() {
    return _state?.getPreData() ?? [];
  }

  /// 获取后置数据
  List<T> getMoreData() {
    return _state?.getMoreData() ?? [];
  }

  /// 滚动到顶部
  void scrollToTop({bool animated = true}) {
    _state?.scrollToTop(animated: animated);
  }

  /// 滚动到底部
  void scrollToBottom({bool animated = true}) {
    _state?.scrollToBottom(animated: animated);
  }

  /// 刷新列表
  void refresh() {
    _state?.refresh();
  }

  /// 设置前置数据（替换）
  void setPreData(List<T> data) {
    _state?.setPreData(data);
  }

  /// 设置后置数据（替换）
  void setMoreData(List<T> data) {
    _state?.setMoreData(data);
  }
}

/// 双向滚动列表组件
///
/// 支持上下双向加载更多数据，适用于聊天记录、评论列表等场景
class ZgDirectionalScrollList<T> extends StatefulWidget {
  /// 初始上方数据（前置数据）
  final List<T> initialPreData;

  /// 初始下方数据（后置数据）
  final List<T> initialMoreData;

  /// 加载更多数据的回调（向下滚动加载）
  final Future<List<T>> Function() onLoadMore;

  /// 加载前置数据的回调（向上滚动加载）
  final Future<List<T>> Function() onLoadPre;

  /// 单个项目的构建器
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 列表控制器（用于外部控制）
  final ZgScrollListController<T>? controller;

  /// 滚动距离底部/顶部的阈值，触发加载（默认200）
  final double loadThreshold;

  /// 是否显示加载指示器
  final bool showLoadIndicator;

  /// 自定义加载更多指示器
  final Widget? loadingMoreWidget;

  /// 自定义加载前置指示器
  final Widget? loadingPreWidget;

  /// 自定义空数据指示器
  final Widget? emptyWidget;

  /// 滚动控制器（可选）
  final ScrollController? scrollController;

  /// 列表滚动时的回调
  final void Function(double offset)? onScroll;

  /// 是否自动失去焦点
  final bool autoUnfocus;

  /// 是否反转列表（聊天模式）
  final bool reverse;

  /// 列表分隔线
  final Widget? separator;

  /// 缓存范围
  final double cacheExtent;

  const ZgDirectionalScrollList({
    super.key,
    this.initialPreData = const [],
    this.initialMoreData = const [],
    required this.onLoadMore,
    required this.onLoadPre,
    required this.itemBuilder,
    this.controller,
    this.loadThreshold = 200,
    this.showLoadIndicator = true,
    this.loadingMoreWidget,
    this.loadingPreWidget,
    this.emptyWidget,
    this.scrollController,
    this.onScroll,
    this.autoUnfocus = true,
    this.reverse = false,
    this.separator,
    this.cacheExtent = 500,
  });

  @override
  State<ZgDirectionalScrollList<T>> createState() => _ZgDirectionalScrollListState<T>();
}

class _ZgDirectionalScrollListState<T> extends State<ZgDirectionalScrollList<T>> {
  late ScrollController _scrollController;
  late List<T> _preDataList;
  late List<T> _moreDataList;

  bool _isLoadingMore = false;
  bool _isLoadingPre = false;
  bool _hasLoadedInCurrentScroll = false;
  bool _hasRefreshedInCurrentScroll = false;

  final GlobalKey _centerKey = GlobalKey();
  double _scrollPositionBeforeLoad = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _preDataList = List.from(widget.initialPreData);
    _moreDataList = List.from(widget.initialMoreData);
    _scrollController.addListener(_onScroll);

    // 附加控制器
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    // 分离控制器
    widget.controller?._detach();

    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentScroll = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;

    widget.onScroll?.call(currentScroll);

    // 快到底部时加载更多
    if (currentScroll >= maxScroll - widget.loadThreshold) {
      if (!_hasLoadedInCurrentScroll && !_isLoadingMore) {
        _hasLoadedInCurrentScroll = true;
        _loadMore();
      }
    }

    // 快到顶部时加载前置数据
    if (currentScroll <= minScroll + widget.loadThreshold) {
      if (!_hasRefreshedInCurrentScroll && !_isLoadingPre) {
        _hasRefreshedInCurrentScroll = true;
        _loadPre();
      }
    }
  }

  /// 检查是否为空数据
  bool get _isEmpty => _preDataList.isEmpty && _moreDataList.isEmpty;

  /// 加载更多数据（底部）
  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newData = await widget.onLoadMore();
      if (newData.isNotEmpty && mounted) {
        setState(() {
          _moreDataList.addAll(newData);
        });
      }
    } catch (e) {
      debugPrint('BiDirectionalScrollList: 加载更多失败 - $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// 加载前置数据（顶部）
  Future<void> _loadPre() async {
    if (_isLoadingPre) return;

    setState(() {
      _isLoadingPre = true;
    });

    try {
      final newData = await widget.onLoadPre();
      if (newData.isNotEmpty && mounted) {
        setState(() {
          _preDataList.addAll(newData);
        });
      }
    } catch (e) {
      debugPrint('BiDirectionalScrollList: 加载前置失败 - $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPre = false;
        });
      }
    }
  }

  /// 构建空数据视图
  Widget _buildEmptyView() {
    if (widget.emptyWidget != null) {
      return widget.emptyWidget!;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建带分隔符的列表项
  Widget _buildItemWithSeparator(BuildContext context, int index, bool isPreList) {
    final item = isPreList ? _preDataList[index] : _moreDataList[index];
    final child = widget.itemBuilder(context, item, index);

    if (widget.separator == null) return child;

    return Column(
      children: [
        child,
        if (index != (isPreList ? _preDataList.length - 1 : _moreDataList.length - 1))
          widget.separator!,
      ],
    );
  }

  // 公开方法供控制器调用

  void appendData(List<T> items) {
    if (!mounted) return;
    setState(() {
      _moreDataList.addAll(items);
    });
  }

  void prependData(List<T> items) {
    if (!mounted) return;
    setState(() {
      _preDataList.insertAll(0, items);
    });
  }

  void insertData(int index, T item, {bool toPreList = true}) {
    if (!mounted) return;
    setState(() {
      if (toPreList) {
        if (index >= 0 && index <= _preDataList.length) {
          _preDataList.insert(index, item);
        }
      } else {
        if (index >= 0 && index <= _moreDataList.length) {
          _moreDataList.insert(index, item);
        }
      }
    });
  }

  void insertAllData(int index, List<T> items, {bool toPreList = true}) {
    if (!mounted) return;
    setState(() {
      if (toPreList) {
        if (index >= 0 && index <= _preDataList.length) {
          _preDataList.insertAll(index, items);
        }
      } else {
        if (index >= 0 && index <= _moreDataList.length) {
          _moreDataList.insertAll(index, items);
        }
      }
    });
  }

  void clearData() {
    if (!mounted) return;
    setState(() {
      _preDataList.clear();
      _moreDataList.clear();
    });
  }

  void clearPreData() {
    if (!mounted) return;
    setState(() {
      _preDataList.clear();
    });
  }

  void clearMoreData() {
    if (!mounted) return;
    setState(() {
      _moreDataList.clear();
    });
  }

  void updateData(int index, T item, {bool toPreList = true}) {
    if (!mounted) return;
    setState(() {
      if (toPreList) {
        if (index >= 0 && index < _preDataList.length) {
          _preDataList[index] = item;
        }
      } else {
        if (index >= 0 && index < _moreDataList.length) {
          _moreDataList[index] = item;
        }
      }
    });
  }

  void removeData(int index, {bool toPreList = true}) {
    if (!mounted) return;
    setState(() {
      if (toPreList) {
        if (index >= 0 && index < _preDataList.length) {
          _preDataList.removeAt(index);
        }
      } else {
        if (index >= 0 && index < _moreDataList.length) {
          _moreDataList.removeAt(index);
        }
      }
    });
  }

  List<T> getAllData() {
    return [..._preDataList, ..._moreDataList];
  }

  List<T> getPreData() {
    return List.unmodifiable(_preDataList);
  }

  List<T> getMoreData() {
    return List.unmodifiable(_moreDataList);
  }

  void setPreData(List<T> data) {
    if (!mounted) return;
    setState(() {
      _preDataList = List.from(data);
    });
  }

  void setMoreData(List<T> data) {
    if (!mounted) return;
    setState(() {
      _moreDataList = List.from(data);
    });
  }

  void scrollToTop({bool animated = true}) {
    if (_scrollController.hasClients) {
      final minScroll = _scrollController.position.minScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          minScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(minScroll);
      }
    }
  }

  void scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    }
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return _buildEmptyView();
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (widget.autoUnfocus) {
          if (notification.direction != ScrollDirection.idle) {
            FocusManager.instance.primaryFocus?.unfocus();
          } else {
            _hasLoadedInCurrentScroll = false;
            _hasRefreshedInCurrentScroll = false;
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        center: _centerKey,
        reverse: widget.reverse,
        cacheExtent: widget.cacheExtent,
        slivers: [
          // 加载前置指示器
          if (widget.showLoadIndicator && _isLoadingPre)
            SliverToBoxAdapter(
              child: widget.loadingPreWidget ??
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            ),

          // 前置数据列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildItemWithSeparator(context, index, true),
              childCount: _preDataList.length,
            ),
          ),

          // 中心锚点
          SliverPadding(
            padding: EdgeInsets.zero,
            key: _centerKey,
          ),

          // 后置数据列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildItemWithSeparator(context, index, false),
              childCount: _moreDataList.length,
            ),
          ),

          // 加载更多指示器
          if (widget.showLoadIndicator && _isLoadingMore)
            SliverToBoxAdapter(
              child: widget.loadingMoreWidget ??
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}