import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';

/// Opens PayU payment page in an in-app WebView.
/// Detects surl/furl redirect to determine payment result.
class PaymentWebView extends StatefulWidget {
  final Map<String, dynamic> payuParams;
  final String txnid;
  const PaymentWebView({super.key, required this.payuParams, required this.txnid});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    final params = widget.payuParams;

    // Determine PayU endpoint
    final key = (params['key'] ?? '').toString();
    final isTest = key.toLowerCase().contains('test');
    final endpoint = isTest
        ? 'https://test.payu.in/_payment'
        : 'https://secure.payu.in/_payment';

    // Build auto-submit HTML form
    final sb = StringBuffer();
    sb.write('<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>');
    sb.write('<body onload="document.getElementById(\'payuForm\').submit();">');
    sb.write('<div style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;">');
    sb.write('<p>Redirecting to payment gateway...</p></div>');
    sb.write('<form id="payuForm" method="post" action="$endpoint">');
    params.forEach((k, v) {
      final escaped = v.toString().replaceAll('"', '&quot;');
      sb.write('<input type="hidden" name="$k" value="$escaped">');
    });
    sb.write('</form></body></html>');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          // Intercept the surl/furl redirect (result page)
          if (request.url.contains('/payments/result')) {
            _handlePaymentResult(request.url);
            return NavigationDecision.prevent;
          }
          // Handle non-HTTP schemes (upi://, phonepe://, gpay://, intent://, etc.)
          final uri = Uri.tryParse(request.url);
          if (uri != null && !['http', 'https', 'about', 'data'].contains(uri.scheme)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(sb.toString());
  }

  Future<void> _handlePaymentResult(String url) async {
    if (_handled) return;
    _handled = true;

    final uri = Uri.parse(url);
    final status = uri.queryParameters['status'] ?? 'unknown';
    final orderId = int.tryParse(uri.queryParameters['order_id'] ?? '');

    if (!mounted) return;

    if (status == 'success') {
      Navigator.pop(context, {
        'status': 'success',
        'order_id': orderId,
        'order_number': uri.queryParameters['order_number'],
        'total': double.tryParse(uri.queryParameters['total'] ?? '0'),
        'coins_redeemed': int.tryParse(uri.queryParameters['coins_redeemed'] ?? '0'),
      });
    } else {
      // No order was created yet, so no need to call cancelOrder.
      // Just return to checkout.
      Navigator.pop(context, {'status': 'failed', 'txnid': widget.txnid});
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitDialog,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(child: PizzaSpinner(size: 40)),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Payment?'),
        content: const Text(
            'Your order has not been placed yet. If you exit now, your payment will not be completed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              if (!mounted) return;
              Navigator.pop(context, {'status': 'cancelled', 'txnid': widget.txnid});
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
