import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class InAppPaymentWebviewScreen extends StatefulWidget {
  final Uri url;
  final String? successRedirectPrefix;
  final String? cancelRedirectPrefix;

  const InAppPaymentWebviewScreen({
    super.key,
    required this.url,
    this.successRedirectPrefix,
    this.cancelRedirectPrefix,
  });

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
            _checkRedirectUrl(url);
          },
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final shouldPrevent = _checkRedirectUrl(request.url);
            return shouldPrevent
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  bool _checkRedirectUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final normalizedUrl = uri.toString();
      final status = uri.queryParameters['status']?.toLowerCase();
      final isSuccessUrl = widget.successRedirectPrefix != null &&
          normalizedUrl.startsWith(widget.successRedirectPrefix!);
      final isCancelUrl = widget.cancelRedirectPrefix != null &&
          normalizedUrl.startsWith(widget.cancelRedirectPrefix!);

      if (isSuccessUrl) {
        if (status == 'cancelled' || status == 'failed' || status == 'error') {
          if (mounted) Navigator.of(context).pop(false);
          return true;
        }
        if (status == 'successful' || status == 'success') {
          if (mounted) Navigator.of(context).pop(true);
          return true;
        }

        // If the URL matches the success prefix and no explicit status is present,
        // assume it is a completion redirect from Flutterwave.
        if (mounted) Navigator.of(context).pop(true);
        return true;
      }

      if (isCancelUrl || status == 'cancelled' || status == 'failed') {
        if (mounted) Navigator.of(context).pop(false);
        return true;
      }
    } catch (_) {
      // Ignore parse failures and allow navigation to continue.
    }
    return false;
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
