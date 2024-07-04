import 'package:hyperpay/hyperpay.dart';

class TestConfig implements HyperpayConfig {
  @override
  String? creditcardEntityID = '8ac7a4c87fb6a3ac017fb6e49efa0167';
  @override
  String? madaEntityID = '8ac7a4c87fb6a3ac017fb6e52dfb016d';
  @override
  String? applePayEntityID = '';
  @override
  Uri checkoutEndpoint = _checkoutEndpoint;
  @override
  Uri statusEndpoint = _statusEndpoint;
  @override
  PaymentMode paymentMode = PaymentMode.test;
}

class LiveConfig implements HyperpayConfig {
  @override
  String? creditcardEntityID = '8ac7a4c87fb6a3ac017fb6e49efa0167';
  @override
  String? madaEntityID = '8ac7a4c87fb6a3ac017fb6e52dfb016d';
  @override
  String? applePayEntityID = '';
  @override
  Uri checkoutEndpoint = _checkoutEndpoint;
  @override
  Uri statusEndpoint = _statusEndpoint;
  @override
  PaymentMode paymentMode = PaymentMode.live;
}

// Setup using your own endpoints.
// https://wordpresshyperpay.docs.oppwa.com/tutorials/mobile-sdk/integration/server.

String _host = 'staging-abyan.manafatech.com';
//const paymentAuthHeader= 'Bearer OGFjN2E0Yzg3ZmI2YTNhYzAxN2ZiNmU0M2RiOTAxNjJ8RDNTZEJ5dHNYNg==';

Uri _checkoutEndpoint = Uri(
  scheme: 'https',
  host: _host,
  path: '/api/v1/payments/checkout-id',
);
// http://demo.iselh.com/api/v1/hyperpay/checkouts
Uri _statusEndpoint = Uri(
  scheme: 'https',
  host: _host,
  path: '/api/v1/payments/get-payment-status',

);