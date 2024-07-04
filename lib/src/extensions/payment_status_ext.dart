// Copyright 2022 NyarTech LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

part of hyperpay;

/// Uses Regular Expressions to define the group
/// of a transaction result code.
///
/// Refer to [API Result Codes](https://wordpresshyperpay.docs.oppwa.com/reference/resultCodes)
/// for more information on what each group includes.
extension PaymentStatusFromRegExp on String {
  PaymentStatus get paymentStatus {
    final successRegExp = 'success';

    if (successRegExp == this) {
      return PaymentStatus.successful;
    } else {
      return PaymentStatus.rejected;
    }
  }
}
