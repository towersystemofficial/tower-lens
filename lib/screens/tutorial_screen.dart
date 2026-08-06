import 'package:flutter/material.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return _TutorialPager(onComplete: onComplete);
  }
}

class _TutorialPager extends StatefulWidget {
  const _TutorialPager({this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<_TutorialPager> createState() => _TutorialPagerState();
}

class _TutorialPagerState extends State<_TutorialPager> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.auto_awesome_outlined, 'Welcome to Tower Lens',
      'Turn dense text into a format that is easier to read.'),
    (Icons.add_a_photo_outlined, 'Bring in text',
      'Scan with the camera, import a document, or paste text directly.'),
    (Icons.grid_view_outlined, 'Choose a tool',
      'Summarize, simplify, analyze terms, or check an ingredient label.'),
    (Icons.folder_outlined, 'Keep your results',
      'Review AI output before saving it to your local Library.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial'),
        automaticallyImplyLeading: widget.onComplete == null,
        actions: [
          if (!lastPage)
            TextButton(onPressed: _finish, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.$1, size: 80,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 28),
                        Text(page.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        Text(page.$3,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  Text('${_page + 1} of ${_pages.length}'),
                  const Spacer(),
                  FilledButton(
                    onPressed: lastPage
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                    child: Text(lastPage ? 'Start using Tower Lens' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
