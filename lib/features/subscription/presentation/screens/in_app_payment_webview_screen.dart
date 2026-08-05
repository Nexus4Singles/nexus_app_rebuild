import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class InAppPaymentWebviewScreen extends StatefulWidget {
  final Uri url;
  final String? successRedirectPrefix;

  const InAppPaymentWebviewScreen({super.key, required this.url, this.successRedirectPrefix});

  @override
  State<InAppPaymentWebviewScreen> createState() => _InAppPaymentWebviewScreenState();
}

class _InAppPaymentWebviewScreenState extends State<InAppPaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            // Check for success redirect
            final redirect = widget.successRedirectPrefix;
            if (redirect != null && url.startsWith(redirect)) {
              // Treat this as success and pop with true
              if (mounted) Navigator.of(context).pop(true);
            }
          },
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final redirect = widget.successRedirectPrefix;
            if (redirect != null && request.url.startsWith(redirect)) {
              if (mounted) Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
