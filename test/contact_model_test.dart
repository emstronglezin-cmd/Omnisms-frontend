import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/models/models.dart';

/// Les contacts Google arrivent dans la MÊME liste que les contacts manuels
/// et VCF (GET /api/contacts fusionne contacts_manual + contacts_synced).
/// Le backend marque les correspondances OmniSMS avec `isOnOmniSms` et la
/// provenance avec `source`.
void main() {
  group('ContactModel.fromJson — contacts Google', () {
    test('contact Google correspondant à un utilisateur OmniSMS', () {
      final contact = ContactModel.fromJson({
        'name': 'Awa Ouédraogo',
        'phone': '+22670000001',
        'avatar': 'https://lh3.googleusercontent.com/a/xyz',
        'isOnOmniSms': true,
        'userId': 'uid-123',
        'registeredUserId': 'uid-123',
        'source': 'google',
        'googleResourceName': 'people/c123',
      });

      expect(contact.name, 'Awa Ouédraogo');
      expect(contact.phone, '+22670000001');
      expect(contact.isRegistered, isTrue,
          reason: 'isOnOmniSms doit alimenter le statut OmniSMS');
      expect(contact.isExternal, isFalse);
      expect(contact.isGoogleContact, isTrue);
      expect(contact.source, 'google');
      expect(contact.photoUrl, 'https://lh3.googleusercontent.com/a/xyz');
    });

    test('contact Google externe (aucun utilisateur OmniSMS)', () {
      final contact = ContactModel.fromJson({
        'name': 'Contact Externe',
        'phone': '+22670000002',
        'isOnOmniSms': false,
        'userId': null,
        'source': 'google',
      });

      expect(contact.isRegistered, isFalse);
      expect(contact.isExternal, isTrue);
      expect(contact.isGoogleContact, isTrue);
    });

    test('contact manuel/VCF existant : comportement inchangé', () {
      final manual = ContactModel.fromJson({
        'id': '+22670000003',
        'name': 'Contact Manuel',
        'phone': '+22670000003',
        'isRegistered': true,
      });

      expect(manual.isRegistered, isTrue);
      expect(manual.source, isNull);
      expect(manual.isGoogleContact, isFalse);
      expect(manual.id, '+22670000003');

      final vcf = ContactModel.fromJson({
        'name': 'Contact VCF',
        'phone': '+22670000004',
        'is_registered': false,
      });

      expect(vcf.isRegistered, isFalse);
      expect(vcf.isExternal, isTrue);
    });

    test('champs manquants → valeurs sûres', () {
      final contact = ContactModel.fromJson(const {});

      expect(contact.id, '');
      expect(contact.name, 'Contact');
      expect(contact.phone, isNull);
      expect(contact.isRegistered, isFalse);
      expect(contact.source, isNull);
    });
  });

  group('UserModel.fromJson — session Google', () {
    test('structure renvoyée par POST /api/auth/google/exchange', () {
      final user = UserModel.fromJson({
        'id': 'omnisms-uid-1',
        'name': 'Awa Ouédraogo',
        'username': null,
        'email': 'awa@example.com',
        'phone': null,
        'avatar': 'https://lh3.googleusercontent.com/a/xyz',
        'phoneVerified': true,
        'isSubscribed': false,
        'credits': 0,
        'needsPhone': true,
      });

      expect(user.id, 'omnisms-uid-1');
      expect(user.name, 'Awa Ouédraogo');
      expect(user.email, 'awa@example.com');
      expect(user.phone, isNull);
      expect(user.photoUrl, 'https://lh3.googleusercontent.com/a/xyz');
    });
  });
}
