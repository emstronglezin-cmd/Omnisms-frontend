// ─────────────────────────────────────────────────────────────────────────
// Photos de profil — tests du contrat réel et de l'affichage.
//
// Rappel du contrat serveur (vérifié dans le backend) :
//   POST /api/me/avatar → { success, avatarUrl: "data:image/png;base64,…" }
//   GET  /api/me        → { …, avatar:     "data:image/png;base64,…" }
//   GET  /api/contacts  → { …, avatar:     "data:image/png;base64,…" }
//   GET  /api/messages  → conv.otherUserAvatar = "data:image/png;base64,…"
//
// Le bug d'origine : ces valeurs étaient passées à Image.network /
// CachedNetworkImage, qui font une requête HTTP — donc aucune photo ne
// s'affichait, ni la mienne ni celles de mes amis.
//
// Aucun jeton ni donnée personnelle n'est utilisé ici : les images sont des
// carrés de 8×8 pixels générés pour le test.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/models/contact_model.dart';
import 'package:omnisms/models/group_model.dart';
import 'package:omnisms/models/user_model.dart';
import 'package:omnisms/widgets/common/avatar_image.dart';

/// Carré rouge 8×8 (PNG réel, encodé pour le test).
const String _carreRouge =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGO8o6HBgA0wYRUdtBIA78QBPFxuqR4AAAAASUVORK5CYII=';

/// Carré bleu 8×8 — volontairement DIFFÉRENT du rouge.
const String _carreBleu =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGOUi7rDgA0wYRUdtBIADVEBZGkX5zoAAAAASUVORK5CYII=';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('Résolution de la valeur d\'avatar', () {
    test('un data URI est reconnu comme tel', () {
      final v = AvatarValue.parse(_carreRouge);
      expect(v.kind, AvatarKind.dataUri);
      expect(v.hasImage, isTrue);
      // Surtout pas d'URL HTTP : c'est le cœur du bug.
      expect(v.httpUrl, isNull);
      expect(v.bytes, isNotNull);
    });

    test('une URL distante reste une URL', () {
      final v = AvatarValue.parse('https://omnisms.example/photo.jpg');
      expect(v.kind, AvatarKind.remoteUrl);
      expect(v.httpUrl, 'https://omnisms.example/photo.jpg');
      expect(v.bytes, isNull);
    });

    test('un chemin relatif est résolu avec l\'URL du backend', () {
      final v = AvatarValue.parse('/uploads/avatars/abc.jpg');
      expect(v.kind, AvatarKind.relativePath);
      expect(v.httpUrl, endsWith('/uploads/avatars/abc.jpg'));
      expect(v.httpUrl, startsWith('http'));
    });

    test('absence de photo : ni erreur, ni requête', () {
      for (final valeur in <String?>[null, '', '   ']) {
        final v = AvatarValue.parse(valeur);
        expect(v.kind, AvatarKind.none);
        expect(v.hasImage, isFalse);
        expect(v.httpUrl, isNull);
      }
    });

    test('une valeur incompréhensible n\'est jamais affichée comme image', () {
      final v = AvatarValue.parse('pas-une-image');
      expect(v.kind, AvatarKind.unsupported);
      expect(v.hasImage, isFalse);
    });

    test('deux photos différentes donnent deux jeux d\'octets différents', () {
      final a = AvatarValue.parse(_carreRouge).bytes!;
      final b = AvatarValue.parse(_carreBleu).bytes!;
      expect(a, isNot(equals(b)));
    });

    test('un data URI corrompu ne provoque pas d\'erreur', () {
      // Base64 invalide : le décodage doit être tolérant (retour à null).
      final v = AvatarValue.parse('data:image/png;base64,PAS%%%DU_BASE64');
      expect(v.kind, AvatarKind.dataUri);
      expect(v.bytes, isNull, reason: 'Contenu illisible → initiales, pas de crash');
    });
  });

  group('Cache mémoire des data URI', () {
    setUp(() => AvatarBytesCache.instance.clear());

    test('le décodage est mémoïsé (une seule lecture par image)', () {
      final premier = AvatarBytesCache.instance.decode(_carreRouge);
      expect(premier, isNotNull);
      expect(AvatarBytesCache.instance.length, 1);

      final second = AvatarBytesCache.instance.decode(_carreRouge);
      // Même instance : pas de second décodage dans les listes.
      expect(identical(premier, second), isTrue);
      expect(AvatarBytesCache.instance.length, 1);
    });

    test('la mémoire est bornée (pas de fuite sur un long défilement)', () {
      for (var i = 0; i < AvatarBytesCache.maxEntries + 25; i++) {
        AvatarBytesCache.instance.decode(
          'data:image/png;base64,${base64Encode(Uint8List.fromList([i, 2, 3]))}',
        );
      }
      expect(AvatarBytesCache.instance.length,
          lessThanOrEqualTo(AvatarBytesCache.maxEntries));
    });
  });

  group('Modèles — contrat réel du backend', () {
    test('utilisateur : GET /api/me renvoie `avatar`', () {
      // Copie exacte de la forme renvoyée par routes/me.js.
      final json = <String, dynamic>{
        'id': 'uid-123',
        'name': 'Awa Traoré',
        'phone': '+22670000000',
        'avatar': _carreRouge,
      };
      expect(UserModel.fromJson(json).photoUrl, _carreRouge);
    });

    test('utilisateur : POST /api/me/avatar renvoie `avatarUrl`', () {
      final json = <String, dynamic>{
        'id': 'uid-123',
        'avatarUrl': _carreBleu,
      };
      expect(UserModel.fromJson(json).photoUrl, _carreBleu);
    });

    test('utilisateur sans photo : null, jamais de chaîne vide', () {
      final user = UserModel.fromJson(<String, dynamic>{'id': 'uid-1', 'name': 'Ali'});
      expect(user.photoUrl, isNull);
    });

    test('conversation : le backend envoie `otherUserAvatar`', () {
      // routes/messages.v2.js : conv.otherUserAvatar = contact.avatar || …
      final json = <String, dynamic>{
        'id': 'conv-1',
        'otherUserId': 'uid-2',
        'otherUserName': 'Jean Dupont',
        'otherUserAvatar': _carreBleu,
        'lastMessage': 'Salut',
      };
      expect(ConversationModel.fromJson(json).otherUserPhotoUrl, _carreBleu);
    });

    test('conversation sans photo : null (repli sur les initiales)', () {
      final conv = ConversationModel.fromJson(<String, dynamic>{
        'id': 'conv-2',
        'otherUserId': 'uid-3',
        'otherUserName': 'Marie',
      });
      expect(conv.otherUserPhotoUrl, isNull);
    });

    test('contact : `avatar` (contacts Google inclus)', () {
      final contact = ContactModel.fromJson(<String, dynamic>{
        'id': 'c-1',
        'name': 'Fatou',
        'avatar': _carreRouge,
        'isOnOmniSms': true,
      });
      expect(contact.photoUrl, _carreRouge);
      expect(contact.isRegistered, isTrue);
    });

    test('groupe : `avatar` (base64, comme les utilisateurs)', () {
      final json = <String, dynamic>{
        'id': 'g-1',
        'name': 'Famille',
        'avatar': _carreRouge,
      };
      expect(GroupModel.fromJson(json).photoUrl, _carreRouge);
    });

    test('réponse JSON complète de /api/contacts (contrat réel)', () {
      final body = jsonEncode(<String, dynamic>{
        'success': true,
        'contacts': <Map<String, dynamic>>[
          {
            'id': 'c-1',
            'name': 'Awa',
            'phone': '+22670111111',
            'avatar': _carreRouge,
            'isOnOmniSms': true,
            'source': 'google',
          },
          {
            'id': 'c-2',
            'name': 'Boubacar',
            'phone': '+22670222222',
            'avatar': null,
            'isOnOmniSms': true,
          },
        ],
      });
      final data = jsonDecode(body) as Map<String, dynamic>;
      final liste = (data['contacts'] as List).cast<Map<String, dynamic>>();
      final contacts = liste.map(ContactModel.fromJson).toList();

      expect(contacts.first.photoUrl, _carreRouge);
      expect(contacts.last.photoUrl, isNull);
    });
  });

  group('Affichage (widgets)', () {
    testWidgets('une photo valide est affichée en image mémoire', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: _carreRouge, name: 'Awa Traoré')),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>(),
          reason: 'Un data URI doit être décodé en mémoire, jamais chargé '
              'par requête HTTP (bug d\'origine).');
      // Aucune initiale affichée puisque la photo est disponible.
      expect(find.text('AT'), findsNothing);
    });

    testWidgets('sans photo, les initiales sont affichées', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: null, name: 'Awa Traoré')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('AT'), findsOneWidget);
    });

    testWidgets('une valeur incompréhensible retombe sur les initiales', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: 'pas-une-image', name: 'Jean Dupont')),
      );
      await tester.pumpAndSettle();

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('un data URI illisible n\'affiche jamais d\'image cassée', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(
          imageUrl: 'data:image/png;base64,XXXX',
          name: 'Marie K',
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('MK'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
    });

    testWidgets('deux contacts affichent deux photos différentes', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: const <Widget>[
              UserAvatar(imageUrl: _carreRouge, name: 'Awa', size: 40),
              UserAvatar(imageUrl: _carreBleu, name: 'Boubacar', size: 40),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 2);
      final premier = images[0].image as MemoryImage;
      final second = images[1].image as MemoryImage;
      expect(premier.bytes, isNot(equals(second.bytes)),
          reason: 'Chaque avatar doit afficher SA photo, jamais celle du voisin.');
    });

    testWidgets('même URL, photo remplacée : la clé de cache change', (tester) async {
      // Cas d'un serveur qui renverrait la même URL avec un contenu nouveau :
      // `cacheVersion` doit produire une clé de cache différente, sinon
      // l'ancienne photo continuerait de s'afficher.
      const url = 'https://omnisms.example/uploads/moi.jpg';

      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: url, name: 'Moi', cacheVersion: 1)),
      );
      final cleV1 = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: url, name: 'Moi', cacheVersion: 2)),
      );
      final cleV2 = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      expect(cleV1, isNotNull);
      expect(cleV2, isNotNull);
      expect(cleV1, isNot(equals(cleV2)));
      expect(cleV2, contains('v2'));
    });

    testWidgets('deux URL différentes ne partagent pas la même clé de cache',
        (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(
          imageUrl: 'https://omnisms.example/a.jpg',
          name: 'A',
        )),
      );
      final cleA = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      await tester.pumpWidget(
        _app(const UserAvatar(
          imageUrl: 'https://omnisms.example/b.jpg',
          name: 'B',
        )),
      );
      final cleB = tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .cacheKey;

      expect(cleA, isNot(equals(cleB)),
          reason: 'Un cache partagé afficherait la photo d\'un autre utilisateur.');
    });

    testWidgets('un repli personnalisé est respecté', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(
          imageUrl: null,
          name: 'Sans photo',
          fallback: Icon(Icons.person, size: 30),
        )),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('un avatar de groupe sans photo affiche l\'icône de groupe',
        (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(imageUrl: null, name: 'Famille', isGroup: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.group), findsOneWidget);
    });
  });
}
