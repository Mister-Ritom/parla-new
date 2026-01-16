import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/screens/creations/add_contact.dart';
import 'package:parla/screens/creations/create_community.dart';
import 'package:parla/screens/creations/key_share.dart';
import 'package:parla/screens/navigation_child/home_screen.dart';
import 'package:parla/screens/navigation_child/profile_screen.dart';
import 'package:parla/screens/navigation_child/search_screen.dart';

final currentIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with TickerProviderStateMixin {
  late final FPopoverController popoverController;
  final pages = const [HomeScreen(), SearchScreen(), ProfileScreen()];
  final _pageController = PageController();

  @override
  void initState() {
    popoverController = FPopoverController(vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  void onItemTapped(int index) {
    ref.read(currentIndexProvider.notifier).state = index;

    _pageController.jumpToPage(index);

    if (index == 1) {
      popoverController.toggle();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              ref.read(currentIndexProvider.notifier).state = index;
            },
            children: pages,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: FPopover(
                controller: popoverController,
                style: (style) => style.copyWith(
                  decoration: style.decoration.copyWith(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  barrierFilter: (animation) => ImageFilter.compose(
                    outer: ImageFilter.blur(
                      sigmaX: animation * 5,
                      sigmaY: animation * 5,
                    ),
                    inner: ColorFilter.mode(
                      Color.lerp(
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        animation,
                      )!,
                      BlendMode.srcOver,
                    ),
                  ),
                ),

                popoverBuilder: (context, controller) => SizedBox(
                  width: 360,
                  height: 208,
                  child: FCard(
                    child: FItemGroup(
                      divider: FItemDivider.indented,
                      children: [
                        FItem(
                          title: const Text("Share Key"),
                          subtitle: const Text(
                            "Share your key to let others contact you",
                          ),
                          prefix: const HeroIcon(HeroIcons.qrCode, size: 24),
                          onPress: () {
                            popoverController.hide();
                            ref.read(currentIndexProvider.notifier).state = 0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KeyShareScreen(),
                              ),
                            );
                          },
                        ),
                        FItem(
                          title: const Text("New Contact"),
                          subtitle: const Text("Add a contact"),
                          prefix: const HeroIcon(HeroIcons.userPlus),
                          onPress: () {
                            popoverController.hide();
                            ref.read(currentIndexProvider.notifier).state = 0;
                            showFSheet(
                              context: context,
                              builder: (_) => AddContact(),
                              side: FLayout.btt,
                            );
                          },
                        ),
                        FItem(
                          title: const Text("New Community"),
                          subtitle: const Text("Create a community"),
                          prefix: const HeroIcon(HeroIcons.users),
                          onPress: () {
                            popoverController.hide();
                            ref.read(currentIndexProvider.notifier).state = 0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateCommunityScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FBottomNavigationBar(
        index: ref.watch(currentIndexProvider),
        onChange: onItemTapped,
        children: const [
          FBottomNavigationBarItem(
            icon: HeroIcon(HeroIcons.homeModern, style: HeroIconStyle.solid),
            label: Text("Home"),
          ),
          FBottomNavigationBarItem(
            icon: HeroIcon(HeroIcons.plusCircle, style: HeroIconStyle.outline),
            label: Text("Add"),
          ),
          FBottomNavigationBarItem(
            icon: HeroIcon(HeroIcons.user, style: HeroIconStyle.solid),
            label: Text("Profile"),
          ),
        ],
      ),
    );
  }
}
