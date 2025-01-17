import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wherostr_social/models/app_states.dart';
import 'package:wherostr_social/models/app_theme.dart';
import 'package:wherostr_social/widgets/main_feed.dart';
// import 'package:wherostr_social/widgets/messages_container.dart';
import 'package:wherostr_social/widgets/notification_center_container.dart';
import 'package:wherostr_social/widgets/profile.dart';
import 'package:wherostr_social/widgets/profile_avatar.dart';
import 'package:wherostr_social/widgets/profile_display_name.dart';

class MainFeedContainer extends StatelessWidget {
  const MainFeedContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final String profileHeroTag = UniqueKey().toString();
    ThemeData themeData = Theme.of(context);
    MyThemeExtension themeExtension = themeData.extension<MyThemeExtension>()!;
    final appState = context.watch<AppStatesProvider>();
    final me = appState.me;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: RawMaterialButton(
            onPressed: () => appState.navigatorPush(
              widget: Profile(
                heroTag: profileHeroTag,
                user: me,
              ),
            ),
            shape: const CircleBorder(),
            child: Hero(
              tag: profileHeroTag,
              child: ProfileAvatar(
                url: me.picture,
              ),
            ),
          ),
        ),
        leadingWidth: 68,
        title: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello!",
              style: themeData.textTheme.bodySmall!
                  .apply(color: themeExtension.textDimColor),
            ),
            ProfileDisplayName(
              user: me,
              textStyle: themeData.textTheme.bodyMedium,
              withBadge: true,
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
              child: Container(
                color: themeData.colorScheme.surfaceDim,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications,
                        color: themeData.colorScheme.primary,
                      ),
                      onPressed: () => appState.navigatorPush(
                        widget: const NotificationCenterContainer(),
                      ),
                    ),
                    // IconButton(
                    //   icon: Icon(
                    //     Icons.sms,
                    //     color: themeData.colorScheme.primary,
                    //   ),
                    //   onPressed: () => appState.navigatorPush(
                    //     widget: const MessagesContainer(),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              foregroundImage: AssetImage('assets/app/app-icon-circle.png'),
            ),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: MainFeed(key: AppStatesProvider.mainFeedKey),
      ),
    );
  }
}
