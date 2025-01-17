import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wherostr_social/models/app_feed.dart';
import 'package:wherostr_social/models/app_states.dart';
import 'package:wherostr_social/models/feed_menu_item.dart';

class FeedFilterMenu extends StatefulWidget {
  final ValueChanged<FeedMenuItem>? onChange;
  const FeedFilterMenu({super.key, this.onChange});

  @override
  State createState() => _FeedFilterMenuState();
}

final followingMenuItem = FeedMenuItem(
    id: 'following', name: 'Following', type: 'default', value: ['following']);
final globalMenuItem = FeedMenuItem(
    id: 'global', name: 'Global', type: 'default', value: ['global']);

class _FeedFilterMenuState extends State<FeedFilterMenu> {
  FeedMenuItem _selectedItem = followingMenuItem;

  @override
  void initState() {
    super.initState();
    final appFeedMenu = context.read<AppFeedProvider>();
    setState(() {
      _selectedItem = appFeedMenu.selectedItem;
    });
  }

  List<FeedMenuItem> _generateDropdownMenu() {
    var me = context.read<AppStatesProvider>().me;
    List<FeedMenuItem> menuItems = [];
    menuItems.add(followingMenuItem);
    menuItems.add(globalMenuItem);
    if (me.followSets.isNotEmpty) {
      menuItems.addAll(me.followSets.map((e) {
        return FeedMenuItem(
            type: e.type, id: e.id, name: e.name, value: e.value);
      }));
    }
    if (me.interestSets.isNotEmpty == true) {
      for (var t in me.interestSets) {
        menuItems.add(FeedMenuItem(id: t, name: t, type: 'tag', value: [t]));
      }
    } else {
      menuItems.add(
        FeedMenuItem(id: 'nostr', name: 'nostr', type: 'tag', value: ['nostr']),
      );
      menuItems.add(
        FeedMenuItem(
            id: 'siamstr', name: 'siamstr', type: 'tag', value: ['siamstr']),
      );
      menuItems.add(
        FeedMenuItem(
            id: 'wherostr', name: 'wherostr', type: 'tag', value: ['wherostr']),
      );
    }
    return menuItems;
  }

  void _showDropdownMenu(BuildContext context) async {
    final appFeedMenu = context.read<AppFeedProvider>();
    var menuItems = _generateDropdownMenu();
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(const Offset(4, 0)),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomCenter(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final FeedMenuItem? selected = await showMenu<FeedMenuItem>(
      context: context,
      position: position,
      items: menuItems.map((FeedMenuItem item) {
        return PopupMenuItem<FeedMenuItem>(
          value: item,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.type == 'tag') ...[
                const Icon(Icons.tag_sharp)
              ] else if (item.type == 'list') ...[
                const Icon(Icons.list_sharp)
              ] else if (item.id == 'following') ...[
                const Icon(Icons.group_sharp)
              ] else if (item.id == 'global') ...[
                const Icon(Icons.public_sharp)
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              Text(item.name),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        _selectedItem = selected;
      });
      appFeedMenu.setSelectedItem(selected);
    }
    widget.onChange!(_selectedItem);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        _showDropdownMenu(context);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedItem.type == 'tag') ...[
            const Icon(Icons.tag_sharp)
          ] else if (_selectedItem.type == 'list') ...[
            const Icon(Icons.list_sharp)
          ] else if (_selectedItem.id == 'following') ...[
            const Icon(Icons.group_sharp)
          ] else if (_selectedItem.id == 'global') ...[
            const Icon(Icons.public_sharp)
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
          ),
          Text(_selectedItem.name),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
