import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/media_source.dart';
import '../../providers/download_provider.dart';
import '../../services/platform_detector.dart';

/// A built-in browser so users can log into platforms (Facebook, Instagram,
/// TikTok, …) and then resolve the currently open page for download, passing
/// the logged-in session cookie to the extractor.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final _urlBar = TextEditingController();
  double _progress = 0;
  String _currentUrl = '';

  static const _home = 'https://m.youtube.com';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onUrlChange: (change) {
            final url = change.url ?? '';
            setState(() {
              _currentUrl = url;
              _urlBar.text = url;
            });
          },
          onPageFinished: (url) => setState(() => _progress = 0),
        ),
      )
      ..loadRequest(Uri.parse(_home));
  }

  @override
  void dispose() {
    _urlBar.dispose();
    super.dispose();
  }

  void _go() {
    var text = _urlBar.text.trim();
    if (text.isEmpty) return;
    // Treat non-URLs as a web search.
    if (!text.startsWith('http') && !text.contains('.')) {
      text = 'https://www.google.com/search?q=${Uri.encodeComponent(text)}';
    } else if (!text.startsWith('http')) {
      text = 'https://$text';
    }
    _controller.loadRequest(Uri.parse(text));
    FocusScope.of(context).unfocus();
  }

  Future<void> _downloadCurrent() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<DownloadProvider>();
    final url = await _controller.currentUrl() ?? _currentUrl;
    if (url.isEmpty) return;

    String? cookie;
    try {
      final res =
          await _controller.runJavaScriptReturningResult('document.cookie');
      cookie = res.toString().replaceAll('"', '');
      if (cookie.isEmpty) cookie = null;
    } catch (_) {}

    messenger.showSnackBar(
      const SnackBar(content: Text('Resolving current page…')),
    );
    await provider.resolveViaBrowser(url, cookie);
    if (provider.resolveError != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.resolveError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canDetect =
        PlatformDetector.detect(_currentUrl) != MediaSource.unknown;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _urlBar,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
            hintText: l.t('browserHint'),
            isDense: true,
            prefixIcon: const Icon(Icons.public, size: 20),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _progress > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloadCurrent,
        icon: const Icon(Icons.download),
        label: Text(l.t('download')),
        backgroundColor: canDetect
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) _controller.goBack();
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await _controller.canGoForward()) _controller.goForward();
              },
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => _controller.loadRequest(Uri.parse(_home)),
            ),
          ],
        ),
      ),
    );
  }
}
