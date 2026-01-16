import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/riverpod/storage_provider.dart';
import 'package:parla/services/color.dart';
import 'package:parla/utils/encryption/key_generator.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/file_picker/media_utils.dart';
import 'package:parla/utils/formatter/time_formatter.dart';
import 'package:parla/utils/widgets/overlay_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? uid; // Null = Current User, String = View other user

  const ProfileScreen({super.key, this.uid});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // State
  bool _isEditing = false;
  bool _isLoadingExternalUser = false;

  // The user object we are actually viewing (could be self or external)
  UserModel? _externalUser;
  String publicKey = "Loading Key...";

  // Form Controllers
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;

  // Temporary Image State
  XFile? _pendingCoverPhoto;
  XFile? _pendingProfilePhoto;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();

    // Logic: If UID is provided and different from current, fetch it.
    // Otherwise we rely on the provider in build()
    _initUserLogic();
  }

  void _initUserLogic() async {
    // 1. Load Public Key (Local logic, usually only relevant for self, but kept as per request)
    _getPublicKey();

    // 2. Handle External User Fetching
    if (widget.uid != null) {
      final currentUser = ref.read(currentUserProvider);

      // Only fetch if it's NOT the current user
      if (widget.uid != currentUser?.uid) {
        setState(() => _isLoadingExternalUser = true);
        try {
          final userDoc = await FirestoreService.getUserDocument(widget.uid!);
          if (mounted) {
            setState(() {
              _externalUser = userDoc;
              _isLoadingExternalUser = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoadingExternalUser = false);
            // Handle error (show toast, etc)
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _getPublicKey() async {
    // Only show real key if viewing self, otherwise this might need
    // to be fetched from the external user model if you store it there.
    final keyExists = await KeyGenerator.keyExists();
    if (keyExists) {
      final key = await KeyGenerator.getKey();
      if (key != null) {
        final keyData = await key.extractPublicKey();
        if (mounted) setState(() => publicKey = base64Encode(keyData.bytes));
      }
    }
  }

  // --- Image Picking ---
  Future<void> _pickCoverImage() async {
    final XFile? image = await MediaUtils.pickImageFromGallery();
    if (image != null) setState(() => _pendingCoverPhoto = image);
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await MediaUtils.pickImageFromGallery();
    if (image != null) setState(() => _pendingProfilePhoto = image);
  }

  // --- BACKGROUND SAVE LOGIC ---
  Future<void> _saveProfile(UserModel currentUser) async {
    final newName = _displayNameController.text.trim();
    final newBio = _bioController.text.trim();

    // 1. Immediate Text Update
    // We update Firestore immediately so the UI reflects text changes instantly
    // The currentUserProvider stream will trigger a rebuild with new text
    await FirestoreService.updateUserProfile(
      uid: currentUser.uid,
      displayName: newName,
      bio: newBio,
    );

    // 2. Check for files
    final hasCover = _pendingCoverPhoto != null;
    final hasAvatar = _pendingProfilePhoto != null;

    if (!hasCover && !hasAvatar) {
      // No files to upload, we are done.
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile updated")));
      }
      return;
    }

    // 3. Prepare Background Upload
    List<File> filesToUpload = [];
    List<String> fileTags = []; // specific tags to identify which URL is which

    if (hasCover) {
      filesToUpload.add(File(_pendingCoverPhoto!.path));
      fileTags.add("cover"); // Tag 1
    }
    if (hasAvatar) {
      filesToUpload.add(File(_pendingProfilePhoto!.path));
      fileTags.add("avatar"); // Tag 2
    }

    // 4. Close UI Immediately (Optimistic UX)
    if (mounted) {
      setState(() {
        _isEditing = false;
        _pendingCoverPhoto = null;
        _pendingProfilePhoto = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Updating images in background...")),
      );
    }

    // 5. Fire and Forget (Background Upload)
    ref
        .read(fileUploadProvider.notifier)
        .uploadMultiple(
          files: filesToUpload,
          path: "users/${currentUser.uid}/profile_media",
          customFileNames: fileTags
              .map((tag) => "${tag}_${DateTime.now().millisecondsSinceEpoch}")
              .toList(),
          onAllUploadsComplete: (maps) async {
            String? newCoverUrl;
            String? newAvatarUrl;

            // Map back based on our custom naming convention or index
            // Since we mapped fileTags -> maps order is preserved
            for (int i = 0; i < maps.length; i++) {
              final url = maps[i]["downloadUrl"];
              final name =
                  maps[i]["name"]; // This will contain the timestamped name e.g. "cover_123456"

              if (name.contains("cover")) {
                newCoverUrl = url;
              } else if (name.contains("avatar")) {
                newAvatarUrl = url;
              }
            }

            // 6. Update Firestore with new URLs
            await FirestoreService.updateUserProfile(
              uid: currentUser.uid,
              coverURL: newCoverUrl,
              photoURL: newAvatarUrl,
            );

            // The currentUserProvider will automatically stream this update to the UI
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine who is the "Current Logged In User" (for auth checks)
    final loggedInUser = ref.watch(currentUserProvider);

    // 2. Determine who we are displaying
    UserModel? displayedUser;
    bool isOwner = false;

    if (widget.uid == null ||
        (loggedInUser != null && widget.uid == loggedInUser.uid)) {
      // We are viewing ourselves
      displayedUser = loggedInUser;
      isOwner = true;
    } else {
      // We are viewing someone else
      displayedUser = _externalUser;
      isOwner = false;
    }

    // Loading States
    if (loggedInUser == null) {
      return const Scaffold(body: Center(child: Text("Not authenticated")));
    }
    if (_isLoadingExternalUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (displayedUser == null) {
      return const Scaffold(body: Center(child: Text("User not found")));
    }

    // Sync controllers only if we are editing (and they are empty/stale)
    if (!_isEditing) {
      _displayNameController.text = displayedUser.displayName;
      _bioController.text = displayedUser.bio ?? "";
    }

    return FScaffold(
      header: AppBar(title: Text(displayedUser.displayName)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            _buildHeader(displayedUser, isOwner),
            const SizedBox(height: 16),

            // Only allow Edit Form if it is the Owner
            _isEditing && isOwner
                ? _buildEditForm(displayedUser)
                : _buildViewMode(displayedUser, isOwner),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildHeader(UserModel user, bool isOwner) {
    // Determine Cover
    ImageProvider? coverImage;
    if (_pendingCoverPhoto != null && isOwner && _isEditing) {
      coverImage = FileImage(File(_pendingCoverPhoto!.path));
    } else if (user.coverURL != null && user.coverURL!.isNotEmpty) {
      coverImage = NetworkImage(user.coverURL!);
    }

    // Determine Avatar
    ImageProvider? profileImage;
    if (_pendingProfilePhoto != null && isOwner && _isEditing) {
      profileImage = FileImage(File(_pendingProfilePhoto!.path));
    } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      profileImage = NetworkImage(user.photoURL!);
    } else {
      profileImage = NetworkImage(
        "https://api.dicebear.com/9.x/adventurer/png?seed=${user.displayName}&&backgroundColor=c0aede",
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Cover
          GestureDetector(
            onTap: (_isEditing && isOwner) ? _pickCoverImage : null,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(24),
                image: coverImage != null
                    ? DecorationImage(image: coverImage, fit: BoxFit.cover)
                    : null,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: (_isEditing && isOwner && coverImage == null)
                  ? Center(
                      child: Icon(Icons.add_a_photo, color: Colors.grey[400]),
                    )
                  : null,
            ),
          ),

          // Edit Overlay (Cover)
          if (_isEditing && isOwner)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.opacityAlpha(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "Edit Cover",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Avatar
          Positioned(
            bottom: 0,
            left: 24,
            child: GestureDetector(
              onTap: (_isEditing && isOwner) ? _pickProfileImage : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.opacityAlpha(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image(
                        image: profileImage,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (_isEditing && isOwner)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.opacityAlpha(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(UserModel user, bool isOwner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      SelectableText(
                        user.username,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contextual Action Button
            if (isOwner)
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text("Edit Profile"),
              ),
          ],
        ),

        const SizedBox(height: 24),
        if (user.bio != null && user.bio!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.theme.colors.muted.opacityAlpha(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ABOUT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  user.bio!,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.brightnessOf(context) == Brightness.light
                        ? Color(0xFF334155)
                        : Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        Row(
          children: [
            if (user.createdAt != null)
              Expanded(
                child: _buildInfoCard(
                  Icons.calendar_today,
                  "JOINED",
                  TimeFormatter.formatDate(user.createdAt!),
                  Colors.blue,
                ),
              ), // Helper to format date if you have createdAt
            const SizedBox(width: 12),
            // We only show the local key for the owner, or if we fetched the public key for the external user
            Expanded(
              child: _buildInfoCard(
                Icons.shield_outlined,
                "PUBLIC KEY",
                isOwner ? _truncateKey(publicKey) : "Hidden",
                Colors.green,
              ),
            ),
          ],
        ),

        if (isOwner) ...[
          const SizedBox(height: 30),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final shouldSignOut = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Confirm Sign Out"),
                      content: const Text("Are you sure you want to sign out?"),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false), // cancel
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, true), // confirm
                          child: const Text("Sign Out"),
                        ),
                      ],
                    );
                  },
                );

                // If user confirmed, sign out
                if (shouldSignOut == true) {
                  ref.read(authProvider.notifier).signOut();
                }
              },
              icon: Icon(Icons.logout, color: Colors.red[400]),
              label: Text(
                "Sign Out",
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditForm(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "EDIT PROFILE",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildInputLabel("Display Name"),
        TextFormField(
          controller: _displayNameController,
          decoration: _inputDecoration("e.g. Alex Rivers"),
        ),
        const SizedBox(height: 16),
        _buildInputLabel("Username"),
        TextFormField(
          initialValue: user.username,
          enabled: false,
          decoration: _inputDecoration("").copyWith(
            fillColor: Colors.grey[100],
            prefixIcon: const Icon(Icons.alternate_email, size: 16),
          ),
        ),
        const SizedBox(height: 16),
        _buildInputLabel("Biography"),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          decoration: _inputDecoration("Introduce yourself..."),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _isEditing = false;
                  _pendingCoverPhoto = null;
                  _pendingProfilePhoto = null;
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveProfile(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),

                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check, size: 20, color: Colors.white),
                label: const Text(
                  "Save Changes",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Helpers ---
  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    MaterialColor color,
  ) {
    return Builder(
      builder: (cardContext) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              final renderBox = cardContext.findRenderObject() as RenderBox;
              final offset = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;

              final rect = Rect.fromLTWH(
                offset.dx,
                offset.dy,
                size.width,
                size.height,
              );

              final overlayController = AnchoredOverlayController();

              overlayController.show(
                context: cardContext,
                anchorRect: rect,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.theme.colors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color[700], size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.blue, width: 2),
    ),
  );

  String _truncateKey(String key) => key.length < 15
      ? key
      : "${key.substring(0, 6)}...${key.substring(key.length - 4)}";
}
