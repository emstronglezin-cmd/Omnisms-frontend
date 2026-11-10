import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../widgets/common/avatar_image.dart';
import '../../utils/user_messages.dart';
import '../../services/avatar_photo_service.dart';
import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';

/// Écran « Profil » — aligné sur l'onglet Paramètres de la PWA
/// (`renderSettings()` / `saveProfile()` / `uploadAvatar()` dans public/app.js).
///
/// Champs éditables : nom, nom d'utilisateur, téléphone, email, mot de passe.
/// La photo de profil est envoyée sur POST /api/me/avatar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final _passwordController = TextEditingController();

  bool _isEditing = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: OmniTypo.corps.copyWith(color: Colors.white),
        ),
        backgroundColor: isError ? OmniPalette.erreur : OmniPalette.succes,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final password = _passwordController.text;
    if (password.isNotEmpty && password.length < 8) {
      _snack('Le mot de passe doit contenir au moins 8 caractères',
          isError: true);
      return;
    }

    final success = await authProvider.updateProfile(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.trim(),
      password: password.isNotEmpty ? password : null,
    );

    if (!mounted) return;

    if (success) {
      _passwordController.clear();
      setState(() => _isEditing = false);
      _snack('Profil mis à jour ✓');
    } else {
      _snack(authProvider.error ?? 'Erreur de mise à jour', isError: true);
    }
  }

  /// Accès à la galerie : permission **réelle**, demandée avant l'ouverture
  /// du sélecteur. Sans cette étape, `image_picker` échoue sur Android ≤ 12
  /// (`READ_EXTERNAL_STORAGE`) et sur Android 13+ lorsque le sélecteur photo
  /// système n'est pas disponible (`READ_MEDIA_IMAGES`).
  ///
  /// `permission_handler` traduit automatiquement `Permission.photos` selon la
  /// version d'Android. Sur iOS, la clé `NSPhotoLibraryUsageDescription` de
  /// Info.plist suffit : le système affiche sa propre alerte.
  Future<bool> _autoriserAccesGalerie() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

    var statut = await Permission.photos.status;
    if (statut.isGranted || statut.isLimited) return true;

    statut = await Permission.photos.request();
    if (statut.isGranted || statut.isLimited) return true;

    if (!mounted) return false;
    if (statut.isPermanentlyDenied) {
      _snack(
        "Accès à la galerie refusé définitivement. Ouvrez les réglages pour l'autoriser.",
        isError: true,
      );
      await openAppSettings();
    } else {
      _snack(
        "Autorisez l'accès à vos photos pour changer votre photo de profil.",
        isError: true,
      );
    }
    return false;
  }

  /// Photo de profil — POST /api/me/avatar.
  ///
  /// Chaîne complète, chacune des étapes étant la cause d'un échec réel
  /// constaté avant correctif :
  ///   1. permission galerie (jamais demandée auparavant) ;
  ///   2. sélection 512 px (les avatars s'affichent au maximum en 120 px) ;
  ///   3. `AvatarPhotoService` : format détecté par magic bytes, nom de fichier
  ///      avec une extension acceptée par le backend, type MIME cohérent et
  ///      compression sous la limite serveur (sinon 415 / 413 systématiques) ;
  ///   4. envoi multipart champ « avatar » puis resynchronisation du profil.
  Future<void> _handleChangePhoto() async {
    if (!await _autoriserAccesGalerie()) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        // Réduit les métadonnées : évite les demandes d'autorisation
        // supplémentaires et les formats propriétaires (HEIC) sur iOS.
        requestFullMetadata: false,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await picked.readAsBytes();

      // Préparation réelle du fichier : c'est ici qu'était le bug d'origine.
      final preparation = AvatarPhotoService.preparer(
        octets: bytes,
        nomSource: picked.name.isNotEmpty ? picked.name : null,
      );

      if (!mounted) return;

      if (preparation is AvatarPhotoErreur) {
        setState(() => _isUploadingAvatar = false);
        _snack(preparation.message, isError: true);
        return;
      }

      final photo = preparation as AvatarPhotoPreparee;

      final authProvider = context.read<AuthProvider>();
      final ok = await authProvider.uploadAvatar(
        bytes: photo.octets,
        filename: photo.nomFichier,
        mimeType: photo.mimeType,
      );

      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      _snack(
        ok
            ? 'Photo de profil mise à jour ✓'
            : (authProvider.error ?? "Échec de l'upload"),
        isError: !ok,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      _snack(
        userMessage(e, fallback: "Impossible d'accéder à la galerie."),
        isError: true,
      );
    }
  }
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _handleSave,
              child: const Text('Sauvegarder'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.currentUser;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── En-tête de profil V3 ────────────────────
                  // L'avatar n'est plus posé sur un fond neutre : il trône
                  // sur le dégradé de marque, avec le nom et le contact
                  // en dessous. C'est l'écran le plus personnel de
                  // l'application ; il mérite une vraie hiérarchie plutôt
                  // qu'une suite de champs.
                  OmniApparition(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: OmniCouleurs.of(context).degradeAccent,
                        borderRadius: OmniRayon.carte,
                        boxShadow: [
                          BoxShadow(
                            color: OmniCouleurs.of(context)
                                .accent
                                .withValues(alpha: 0.26),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        children: [
                          // ── Avatar (clic → upload) ────────────
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: OmniCouleurs.of(context)
                                        .surAccent
                                        .withValues(alpha: 0.55),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 58,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: _avatarContent(user?.photoUrl),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Material(
                                  color: OmniCouleurs.of(context).surface,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: _isUploadingAvatar
                                        ? null
                                        : _handleChangePhoto,
                                    customBorder: const CircleBorder(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: _isUploadingAvatar
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: OmniCouleurs.of(context)
                                                    .accent,
                                              ),
                                            )
                                          : Icon(
                                              Icons.photo_camera_rounded,
                                              size: 19,
                                              color:
                                                  OmniCouleurs.of(context)
                                                      .accent,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: OmniEspace.m),
                          Text(
                            user?.name?.trim().isNotEmpty == true
                                ? user!.name!.trim()
                                : 'Votre profil',
                            textAlign: TextAlign.center,
                            style: OmniTypo.sousTitre.copyWith(
                              color: OmniCouleurs.of(context).surAccent,
                            ),
                          ),
                          // Contact réel, jamais reconstitué : si le champ
                          // est vide, la ligne n'est tout simplement pas
                          // affichée.
                          if ((user?.email?.trim().isNotEmpty == true) ||
                              (user?.phone?.trim().isNotEmpty == true))
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: OmniEspace.xxs),
                              child: Text(
                                user?.email?.trim().isNotEmpty == true
                                    ? user!.email!.trim()
                                    : user!.phone!.trim(),
                                textAlign: TextAlign.center,
                                style: OmniTypo.secondaire.copyWith(
                                  color: OmniCouleurs.of(context)
                                      .surAccent
                                      .withValues(alpha: 0.86),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniEspace.xl),

                  // ── Nom ─────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    enabled: _isEditing,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Nom requis'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Nom d'utilisateur ───────────────────────
                  TextFormField(
                    controller: _usernameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: "Nom d'utilisateur",
                      prefixIcon: const Icon(Icons.alternate_email),
                      helperText: 'Lettres, chiffres, _ . - (2 à 50)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return "Nom d'utilisateur requis";
                      if (!AuthService.isValidUsername(v)) {
                        return AuthService.usernameHint();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Téléphone ───────────────────────────────
                  TextFormField(
                    controller: _phoneController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Téléphone',
                      hintText: '+22670123456',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ───────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return null; // optionnel
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        helperText: 'Laisser vide pour ne pas changer',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Infos compte ────────────────────────────
                  if (user?.createdAt != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Membre depuis',
                                    style: OmniTypo.micro.copyWith(
                                      color: OmniCouleurs.of(context)
                                          .texteSecondaire,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(user!.createdAt!),
                                    style: OmniTypo.corpsGras.copyWith(
                                      color: OmniCouleurs.of(context).texte,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── Déconnexion ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OmniPalette.erreur,
                        side: const BorderSide(color: OmniPalette.erreur),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OmniRayon.m),
                        ),
                      ),
                    ),
                  ),

                  if (authProvider.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(
                        color: OmniCouleurs.of(context).accent,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Photo de profil.
  ///
  /// `UserAvatar` affiche aussi bien un data URI (contrat actuel du backend)
  /// qu'une URL distante. `avatarVersion` est incrémenté à chaque upload
  /// réussi : si le serveur renvoyait la même URL avec un contenu différent,
  /// le cache disque serait bien invalidé.
  Widget _avatarContent(String? photoUrl) {
    final auth = context.watch<AuthProvider>();
    return UserAvatar(
      imageUrl: photoUrl,
      name: auth.currentUser?.name ?? 'Utilisateur',
      size: 120,
      cacheVersion: auth.avatarVersion,
      fallback: const Icon(Icons.person, size: 58, color: Colors.white),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
