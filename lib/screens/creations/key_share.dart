import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/models/share_key.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/overlay/overlay_util.dart';
import 'package:parla/utils/share_key/share_key_generator.dart';
import 'package:parla/utils/formatter/time_formatter.dart';
import 'package:qr_flutter/qr_flutter.dart';

class KeyShareScreen extends ConsumerStatefulWidget {
  const KeyShareScreen({super.key});

  @override
  ConsumerState<KeyShareScreen> createState() => _KeyShareScreenState();
}

class _KeyShareScreenState extends ConsumerState<KeyShareScreen>
    with TickerProviderStateMixin {
  static final selectedKeyProvider = StateProvider<ShareKeyModel?>(
    (ref) => null,
  );

  static final expirationChoiceProvider = StateProvider<int>((ref) => 7);

  static final participantsProvider = StateProvider<List<String>>((ref) => []);

  static final createdProvider = StateProvider.autoDispose<bool>(
    (ref) => false,
  );

  static final isGeneratorExpandedProvider = StateProvider<bool>((ref) => true);

  static final isParticipantsExpandedProvider = StateProvider<bool>(
    (ref) => false,
  );

  // -------------------------------
  // CONTROLLERS
  // -------------------------------
  late final FSelectTileGroupController<ShareKeyModel> _keyController;
  late final AnimationController _generatorCollapseCtrl;
  late final AnimationController _participantsCollapseCtrl;

  final TextEditingController customKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _keyController = FMultiValueNotifier.radio(null);

    _generatorCollapseCtrl = AnimationController(
      value: 1,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _participantsCollapseCtrl = AnimationController(
      value: 0,
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _generatorCollapseCtrl.dispose();
    _participantsCollapseCtrl.dispose();
    customKeyController.dispose();
    super.dispose();
  }

  void showAddParticipantDialog() {
    String name = "";

    showDialog(
      context: context,
      builder: (context) {
        return FDialog(
          title: const Text("Add Participant"),
          body: FTextField(
            label: const Text("Username"),
            onChange: (v) => name = v.trim(),
            hint: "Enter username",
          ),
          actions: [
            FButton(
              onPress: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FButton(
              onPress: () {
                if (name.isEmpty) return;

                ref.read(participantsProvider.notifier).update((list) {
                  return [...list, name.toLowerCase()];
                });

                Navigator.pop(context);
                showParticipants(); // expand section
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void onKeySelected(Set<ShareKeyModel> vals) {
    if (vals.isEmpty) return;
    ref.read(selectedKeyProvider.notifier).state = vals.last;
  }

  DateTime calculateExpiration() {
    final expiration = ref.read(expirationChoiceProvider);
    if (expiration <= 0) return DateTime(9999);
    return DateTime.now().add(Duration(days: expiration));
  }

  void createKey() async {
    final chosenParticipants = ref.read(participantsProvider);

    final key = customKeyController.text.trim().isEmpty
        ? ShareKeyGenerator.generateRandomShrekey()
        : customKeyController.text.trim();

    final userModel = ref.read(currentUserProvider);
    if (userModel == null) return;

    final newKey = ShareKeyModel(
      shareKey: key,
      ownerUid: userModel.uid,
      ownerUsername: userModel.username,
      participantsUsernames: List.from(chosenParticipants),
      expireAt: calculateExpiration(),
    );

    try {
      await FirestoreService.createKeyDocument(newKey);
      ref.read(selectedKeyProvider.notifier).state = newKey;
      ref.read(createdProvider.notifier).state = true;
      _keyController.value = {newKey};
    } catch (e, st) {
      AppLogger.error(
        name: "KeyShare Screen",
        message: "Failed to create key",
        exception: e,
        stackTrace: st,
      );
      OverlayUtil.showTopOverlay("Couldn't create key, try again");
      if (context.mounted && mounted) {
        Navigator.pop(context);
      }
    }
  }

  void toggleGenerator() {
    final current = ref.read(isGeneratorExpandedProvider);
    final newVal = !current;

    ref.read(isGeneratorExpandedProvider.notifier).state = newVal;
    newVal
        ? _generatorCollapseCtrl.forward()
        : _generatorCollapseCtrl.reverse();
  }

  void toggleParticipants() {
    final current = ref.read(isParticipantsExpandedProvider);
    final newVal = !current;

    ref.read(isParticipantsExpandedProvider.notifier).state = newVal;
    newVal
        ? _participantsCollapseCtrl.forward()
        : _participantsCollapseCtrl.reverse();
  }

  void showParticipants() {
    if (!ref.read(isParticipantsExpandedProvider)) {
      ref.read(isParticipantsExpandedProvider.notifier).state = true;
      _participantsCollapseCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final currentUserModel = ref.watch(currentUserProvider);
    final selectedKey = ref.watch(selectedKeyProvider);
    final created = ref.watch(createdProvider);
    final expirationChoice = ref.watch(expirationChoiceProvider);
    final chosenParticipants = ref.watch(participantsProvider);
    final isGeneratorExpanded = ref.watch(isGeneratorExpandedProvider);
    final isParticipantsExpanded = ref.watch(isParticipantsExpandedProvider);

    if (currentUserModel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [FCircularProgress(), Text("Getting user data")],
        ),
      );
    }

    return FScaffold(
      header: FHeader.nested(
        title: const Text("Share Key"),
        prefixes: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const HeroIcon(HeroIcons.chevronLeft, size: 24),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (selectedKey != null) ...[
              QrImageView(
                data: selectedKey.shareKey,
                version: QrVersions.auto,
                size: 320,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              SelectableText(
                "Key: ${selectedKey.shareKey}",
                style: theme.typography.xl3,
              ),
              SelectableText("Username: ${selectedKey.ownerUsername}"),
              const SizedBox(height: 24),
            ],

            FirestoreQueryBuilder<ShareKeyModel>(
              query: FirestoreService.getOwnerKeys(currentUserModel.username),
              builder: (context, snapshot, _) {
                if (snapshot.isFetching) return CircularProgressIndicator();
                if (snapshot.hasError) {
                  AppLogger.error(
                    name: "KeyShare Screen",
                    message:
                        "Couldn't get keys for ${currentUserModel.username}",
                    exception: snapshot.error,
                    stackTrace: snapshot.stackTrace,
                  );
                  return SizedBox.shrink();
                }

                final keyDocs = snapshot.docs;
                final keys = keyDocs.map((e) => e.data());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your keys: ",
                      style: FTheme.of(context).typography.xl,
                    ),
                    SizedBox(height: 8),
                    FSelectTileGroup<ShareKeyModel>(
                      selectController: _keyController,
                      onChange: onKeySelected,
                      children: keys.map((k) {
                        final expired = k.expireAt.isBefore(DateTime.now());
                        return keyItem(context, theme, k, expired);
                      }).toList(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            if (!created) ...[
              /// TITLE: GENERATOR
              GestureDetector(
                onTap: toggleGenerator,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Create new share key",
                        style: theme.typography.lg,
                      ),
                    ),
                    HeroIcon(
                      isGeneratorExpanded
                          ? HeroIcons.chevronUp
                          : HeroIcons.chevronDown,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              AnimatedBuilder(
                animation: _generatorCollapseCtrl,
                builder: (_, child) => FCollapsible(
                  value: _generatorCollapseCtrl.value,
                  child: child!,
                ),
                child: Column(
                  children: [
                    FTextField(
                      controller: customKeyController,
                      label: const Text("Share Key"),
                      hint: "Leave empty to generate random",
                    ),
                    const SizedBox(height: 16),

                    FSelect<int>(
                      items: const {
                        "1 day": 1,
                        "7 days": 7,
                        "30 days": 30,
                        "90 days": 90,
                        "No Expiration": -1,
                      },
                      initialValue: expirationChoice,
                      onChange: (v) =>
                          ref.read(expirationChoiceProvider.notifier).state =
                              v ?? -1,
                      label: const Text("Expiration"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// TITLE: PARTICIPANTS
              GestureDetector(
                onTap: toggleParticipants,
                child: Row(
                  children: [
                    Expanded(
                      child: Text("Participants", style: theme.typography.lg),
                    ),
                    GestureDetector(
                      onTap: showAddParticipantDialog,
                      child: const HeroIcon(HeroIcons.userPlus, size: 22),
                    ),
                    const SizedBox(width: 8),
                    HeroIcon(
                      isParticipantsExpanded
                          ? HeroIcons.chevronUp
                          : HeroIcons.chevronDown,
                      size: 18,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              AnimatedBuilder(
                animation: _participantsCollapseCtrl,
                builder: (_, child) => FCollapsible(
                  value: _participantsCollapseCtrl.value,
                  child: child!,
                ),
                child: Material(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chosenParticipants.map((p) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Chip(label: Text(p)),
                          Positioned(
                            right: -6,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                ref
                                    .read(participantsProvider.notifier)
                                    .update(
                                      (list) =>
                                          list.where((e) => e != p).toList(),
                                    );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: const HeroIcon(
                                  HeroIcons.xMark,
                                  style: HeroIconStyle.solid,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              FButton(onPress: createKey, child: const Text("Create")),
            ],
          ],
        ),
      ),
    );
  }

  FSelectTile<ShareKeyModel> keyItem(
    BuildContext context,
    FThemeData theme,
    ShareKeyModel key,
    bool isExpired,
  ) {
    final selectedKey = ref.watch(selectedKeyProvider);
    return FSelectTile<ShareKeyModel>(
      value: key,
      title: Text(
        key.shareKey,
        style: TextStyle(
          color: isExpired ? Colors.grey : theme.colors.foreground,
        ),
      ),
      checkedIcon: selectedKey?.shareKey == key.shareKey
          ? HeroIcon(HeroIcons.check)
          : null,
      uncheckedIcon: selectedKey?.shareKey == key.shareKey
          ? HeroIcon(HeroIcons.check)
          : null,
      details: Text(
        isExpired
            ? "Expired"
            : key.expireAt.year >= 9999
            ? ""
            : "Expires ${TimeFormatter.timeUntil(key.expireAt)}",
        style: theme.typography.sm,
      ),
      subtitle: key.participantsUsernames.isEmpty
          ? null
          : Text("${key.participantsUsernames.length} participants"),
      enabled: !isExpired,
    );
  }
}
