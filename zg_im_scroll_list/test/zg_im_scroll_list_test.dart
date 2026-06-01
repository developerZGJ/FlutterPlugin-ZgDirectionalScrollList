import 'package:flutter/material.dart';
import 'package:zg_im_scroll_list/zg_im_scroll_list.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  final ZgScrollListController<int> _controller = ZgScrollListController<int>();
  final ScrollController _scrollController = ScrollController();
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      final delta = keyboardInset - _lastKeyboardInset;
      _lastKeyboardInset = keyboardInset;

      if (delta == 0 || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      final targetOffset = (_scrollController.offset + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      _scrollController.jumpTo(targetOffset);
    });
  }

  Future<List<int>> _loadMore() async {
    int? maxValue = _controller.getMoreData().lastOrNull;
    if (maxValue == null) {
      return [];
    }
    List<int> newData = List.generate(10, (index) => maxValue + 1 + index);
    return newData;
  }

  Future<List<int>> _loadPre() async {
    int? minValue = _controller.getPreData().lastOrNull;
    if (minValue == null) {
      return [];
    }
    List<int> newData = List.generate(10, (index) => minValue - 1 - index);
    return newData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _buildBody(),
      // body: AnimatedPadding(
      //   duration: const Duration(milliseconds: 250),
      //   curve: Curves.easeOutCubic,
      //   padding: EdgeInsets.only(
      //     bottom: MediaQuery.viewInsetsOf(context).bottom,
      //   ),
      //   child: _buildBody(),
      // ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: ZgDirectionalScrollList(
            controller: _controller,
            scrollController: _scrollController,
            initialMoreData: List.generate(30, (index) => 3000 + index),
            initialPreData: List.generate(30, (index) => 3000 - index - 1),
            onLoadMore: _loadMore,
            onLoadPre: _loadPre,
            itemBuilder: (context, item, index) {
              return Text("$item", style: TextStyle(fontSize: 28));
            },
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: '输入消息...',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
                child: Text("top"),
                onPressed: (){
                  _controller.scrollToTop();
                }),
            SizedBox(width: 16),
            FloatingActionButton(
                child: Text("bottom"),
                onPressed: (){
                  _controller.scrollToBottom();
                })
          ],
        )
      ],
    );
  }
}
