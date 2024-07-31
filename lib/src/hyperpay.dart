// Copyright 2022 NyarTech LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

part of hyperpay;

/// The interface for Hyperpay SDK.
/// To use this plugin, you will need to have 2 endpoints on your server.
///
/// Please check
/// [the guide to setup your server](https://wordpresshyperpay.docs.oppwa.com/tutorials/mobile-sdk/integration/server).
///
/// Refer to [HyperPay API](https://wordpresshyperpay.docs.oppwa.com/reference/parameters)
/// for more information on Test/Live systems.
class HyperpayPlugin {
  HyperpayPlugin._(this._config);
  //static HyperpayPlugin instance = HyperpayPlugin._();

  static const MethodChannel _channel =
      const MethodChannel('plugins.nyartech.com/hyperpay');

  late HyperpayConfig _config;

  CheckoutSettings? _checkoutSettings;
  String _checkoutID = '';

  /// Read the configurations used to setup this instance of HyperPay.
  HyperpayConfig get config => _config;

  /// Setup HyperPay instance with the required stuff to make a successful
  /// payment transaction.
  ///
  /// See [HyperpayConfig], [PaymentMode]
  static Future<HyperpayPlugin> setup({required HyperpayConfig config}) async {
    await _channel.invokeMethod(
      'setup_service',
      {
        'mode': config.paymentMode.string,
      },
    );

    return HyperpayPlugin._(config);
  }

  /// Instantiate a checkout session.
  void initSession({required CheckoutSettings checkoutSetting}) async {
    // ensure anything from previous session is cleaned up.
    _clearSession();
    _checkoutSettings = checkoutSetting;
  }

  /// Used to clear any lefovers from previous session
  /// before starting a new one.
  void _clearSession() {
    if (_checkoutSettings != null) {
      _checkoutSettings?.clear();
    }
  }

  /// A call to the endpoint on your server to get a checkout ID.
  Future<String> get getCheckoutID async {
    try {
      final userId = _checkoutSettings?.additionalParams.values.first;
      final isUserId = _checkoutSettings?.additionalParams.isNotEmpty ?? false;
      final url = Uri(
        scheme: _config.checkoutEndpoint.scheme,
        host: _config.checkoutEndpoint.host,
        path: _config.checkoutEndpoint.path,
        queryParameters: {
          'gateway': _checkoutSettings?.brand.name,
          'amount': _checkoutSettings?.amount.toStringAsFixed(0),
          'recurring': _checkoutSettings?.isRecurring,
          if (_checkoutSettings?.savedCardId != null)
            'registration_id': _checkoutSettings?.savedCardId,
          if (_checkoutSettings?.giftId != null)
            'gift_id': _checkoutSettings?.giftId,
          if (isUserId) 'requested_user_id': userId,
        },
      );
      final Response response = await get(
        url,
        headers: _checkoutSettings?.headers,
      );

      if (response.statusCode != 200) {
        final _res = json.decode(response.body);
        final error = _res['error'][0]['value'];
        throw HttpException(error.toString());
      }

      final Map _resBody = json.decode(response.body);

      if (_resBody['data'] != null) {
        _checkoutID = _resBody['data']['checkout_id'];
        log(_checkoutID, name: "HyperpayPlugin/getCheckoutID");
        return _checkoutID;
      } else {
        throw HyperpayException('هناك شئ خاطئ، يرجى المحاولة فى وقت لاحق');
      }
    } catch (exception) {
      log('${exception.toString()}', name: "HyperpayPlugin/getCheckoutID");
      rethrow;
    }
  }

  /// Perform the transaction using iOS/Android HyperPay SDK.
  ///
  /// It's highly recommended to setup a listner using
  /// [HyperPay webhooks](https://wordpresshyperpay.docs.oppwa.com/tutorials/webhooks),
  /// and perform the requird action after payment (e.g. issue receipt) on your server.
  Future<PaymentStatus> pay(CardInfo card) async {
    try {
      final result = await _channel.invokeMethod(
        'start_payment_transaction',
        {
          'checkoutID': _checkoutID,
          'brand': _checkoutSettings?.brand.name.toUpperCase(),
          'card': card.toMap(),
        },
      );

      log('$result', name: "HyperpayPlugin/platformResponse");

      if (result == 'canceled') {
        // Checkout session is still going on.
        return PaymentStatus.init;
      }

      final status = await paymentStatus(
        _checkoutID,
        headers: _checkoutSettings?.headers,
      );

      final String code = status['status'];

      if (code == 'false' || code == "error") {
        throw HyperpayException("تم رفض الدفع", code);
      } else {
        log(code, name: "HyperpayPlugin/paymentStatus");

        _clearSession();
        _checkoutID = '';

        return code.paymentStatus;
      }
    } catch (e) {
      log('$e', name: "HyperpayPlugin/pay");
      rethrow;
    }
  }

  Future<PaymentStatus> payWithSaveCard(String id, String cvv) async {
    try {
      final result = await _channel.invokeMethod(
        'start_saved_card_transaction',
        {
          'checkoutID': _checkoutID,
          'brand': _checkoutSettings?.brand.name.toUpperCase(),
          'registrationID': id,
          'cvv': cvv,
        },
      );

      log('$result', name: "HyperpayPlugin/platformResponse");

      if (result == 'canceled') {
        // Checkout session is still going on.
        return PaymentStatus.init;
      }

      final status = await paymentStatus(
        _checkoutID,
        headers: _checkoutSettings?.headers,
      );

      final String code = status['status'];

      if (code == 'false' || code == "error") {
        throw HyperpayException("تم رفض الدفع", code);
      } else {
        log(code, name: "HyperpayPlugin/paymentStatus");

        _clearSession();
        _checkoutID = '';

        return code.paymentStatus;
      }
    } catch (e) {
      log('$e', name: "HyperpayPlugin/pay");
      rethrow;
    }
  }

  /// Perform a transaction natively with Apple Pay.
  ///
  /// This method will throw a [NOT_SUPPORTED] error on any platform other than iOS.
  Future<PaymentStatus> payWithApplePay(ApplePaySettings applePay) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw HyperpayException(
        'Apple Pay غير مدعوم على $defaultTargetPlatform.',
        'NOT_SUPPORTED',
      );
    }

    try {
      final result = await _channel.invokeMethod(
        'start_payment_transaction',
        {
          'checkoutID': _checkoutID,
          'brand': BrandType.applepay.name.toUpperCase(),
          ...applePay.toJson(),
        },
      );

      log('$result', name: "HyperpayPlugin/platformResponse");

      if (result == 'canceled') {
        // Checkout session is still going on.
        return PaymentStatus.init;
      }

      final status = await paymentStatus(
        _checkoutID,
        headers: _checkoutSettings?.headers,
      );

      final String code = status['status'];

      if (code.paymentStatus == PaymentStatus.rejected) {
        throw HyperpayException("تم رفض الدفع", code, status['description']);
      } else {
        log('${code.paymentStatus}', name: "HyperpayPlugin/paymentStatus");
        _clearSession();
        _checkoutID = '';

        return code.paymentStatus;
      }
    } catch (e) {
      log('$e', name: "HyperpayPlugin/payWithApplePay");
      rethrow;
    }
  }

  /// Check for payment status using a checkout ID, this method is called
  /// once right after a transaction.
  Future<Map<String, dynamic>> paymentStatus(String checkoutID,
      {Map<String, String>? headers}) async {
    try {
      final userId = _checkoutSettings?.additionalParams.values.first;
      final isUserId = _checkoutSettings?.additionalParams.isNotEmpty ?? false;
      final url = Uri(
        scheme: _config.statusEndpoint.scheme,
        host: _config.statusEndpoint.host,
        path: _config.statusEndpoint.path,
        queryParameters: {
          'gateway': _checkoutSettings?.brand.name,
          'amount': _checkoutSettings?.amount.toStringAsFixed(0),
          'id': _checkoutID,
          if (isUserId) 'requested_user_id': userId,
        },
      );
      final Response response = await get(
        url,
        headers: _checkoutSettings?.headers,
      );

      if (response.statusCode != 200) {
        final _res = json.decode(response.body);
        final error = _res['error'][0]['value'];
        throw HttpException(error.toString());
      }

      final Map _resBody = json.decode(response.body);

      if (_resBody['data'] != null) {
        return {"status": _resBody['data']['status']};
      } else {
        throw HyperpayException('هناك شئ خاطئ، يرجى المحاولة فى وقت لاحق');
      }
    } catch (exception) {
      log('${exception.toString()}', name: "HyperpayPlugin/paymentstatus");
      rethrow;
    }
  }
}
