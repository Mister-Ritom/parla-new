import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/screens/chat/conversations_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider);
    if (authUser == null) {
      return Text("No user found");
    }
    return FScaffold(
      header: FHeader.nested(
        prefixes: [Text(authUser.displayName ?? "Parla")],
        title: Image.asset('assets/logo/Parla.png', width: 64, height: 64),
        suffixes: [
          IconButton(
            onPressed: () {},
            icon: HeroIcon(HeroIcons.magnifyingGlass),
          ),
        ],
      ),
      child: ConversationsList(),
      scaffoldStyle: (style) => style.copyWith(childPadding: EdgeInsets.zero),
    );
  }
}
