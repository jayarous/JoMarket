import 'package:flutter_test/flutter_test.dart';

import 'package:jo_market/app/seller/seller_models.dart';

void main() {
  group('SellerConnectStatus', () {
    test('parses API payload', () {
      final status = SellerConnectStatus.fromMap({
        'accountId': 'acct_123',
        'chargesEnabled': true,
        'payoutsEnabled': false,
        'detailsSubmitted': true,
        'requirementsDue': ['external_account', 'company.tax_id'],
        'onboardingUrl': 'https://connect.stripe.com/setup/sessions/123',
      });

      expect(status.accountId, 'acct_123');
      expect(status.chargesEnabled, isTrue);
      expect(status.payoutsEnabled, isFalse);
      expect(status.detailsSubmitted, isTrue);
      expect(status.requirementsDue, contains('company.tax_id'));
      expect(status.onboardingUrl, isNotNull);
    });
  });
}
