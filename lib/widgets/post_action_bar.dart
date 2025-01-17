import 'dart:async';
import 'dart:convert';
import 'package:bolt11_decoder/bolt11_decoder.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wherostr_social/models/app_feed.dart';
import 'package:wherostr_social/models/app_states.dart';
import 'package:wherostr_social/models/app_theme.dart';
import 'package:wherostr_social/models/data_event.dart';
import 'package:wherostr_social/models/nostr_user.dart';
import 'package:wherostr_social/models/pow_filter.dart';
import 'package:wherostr_social/services/nostr.dart';
import 'package:wherostr_social/utils/app_utils.dart';
import 'package:wherostr_social/utils/nostr_event.dart';
import 'package:wherostr_social/utils/pow.dart';
import 'package:wherostr_social/widgets/emoji_picker.dart';
import 'package:wherostr_social/widgets/post_compose.dart';
import 'package:wherostr_social/widgets/zap_form.dart';

class PostActionBar extends StatefulWidget {
  final DataEvent event;

  const PostActionBar({super.key, required this.event});

  @override
  State createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  NostrEventsStream? _newEventStream;
  StreamSubscription<NostrEvent>? _newEventListener;
  NostrUser? _user;
  PoWfilter? _powFilter;
  int _repostCount = 0;
  int _commentCount = 0;
  int _reactionCount = 0;
  double _zapCount = 0;
  bool _isReposted = false;
  bool _isReacted = false;
  bool _isZapped = false;
  String? _emojiUrl;
  double _reactionIconScale = 1;
  List<String> _muteList = [];
  final List<DataEvent> _allItems = [];

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final me = context.read<AppStatesProvider>().me;
    if (_muteList.length != me.muteList.length) {
      _muteList = me.muteList.toList();
      setState(() {
        resetCounts();
        updateCounts(_allItems);
      });
    }
    final powFilter = context.read<AppFeedProvider>().powCommentFilter;
    if (_powFilter.toString() != powFilter.toString()) {
      _powFilter = PoWfilter.fromString(powFilter.toString());
      setState(() {
        _allItems.clear();
        resetCounts();
      });
      unsubscribe();
      subscribe();
    }
  }

  void initialize() {
    final powFilter = context.read<AppFeedProvider>().powCommentFilter;
    final me = context.read<AppStatesProvider>().me;
    _powFilter = PoWfilter.fromString(powFilter.toString());
    _muteList.addAll(me.muteList.toList());
    subscribe();
    NostrService.fetchUser(widget.event.pubkey, relays: me.relayList)
        .then((user) {
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    });
  }

  void subscribe() {
    const duration = Duration(milliseconds: 300);
    final Debouncer debouncer = Debouncer();
    final relayList = context.read<AppStatesProvider>().me.relayList;
    final ids = (_powFilter?.enabled ?? false) && (_powFilter?.value ?? 0) > 0
        ? [difficultyToHex(_powFilter!.value, true)]
        : null;
    _newEventStream = NostrService.subscribe(
      [
        NostrFilter(
          kinds: const [6, 7, 9735],
          e: [widget.event.id!],
        ),
        NostrFilter(
          kinds: const [1],
          e: [widget.event.id!],
          ids: ids,
        ),
      ],
      relays: relayList,
    );
    _newEventListener = _newEventStream!.stream.listen((event) {
      final e = DataEvent.fromEvent(event);
      _allItems.add(e);
      debouncer.debounce(
        duration: duration,
        onDebounce: () {
          if (mounted) {
            setState(() {
              resetCounts();
              updateCounts(_allItems);
            });
          }
        },
      );
    });
  }

  Future<void> unsubscribe() async {
    if (_newEventListener != null) {
      await _newEventListener!.cancel();
      _newEventListener = null;
    }
    if (_newEventStream != null) {
      _newEventStream!.close();
      _newEventStream = null;
    }
  }

  bool isMuted(NostrEvent event) {
    final me = context.read<AppStatesProvider>().me;
    return me.muteList.contains(event.pubkey);
  }

  void resetCounts() {
    _repostCount = 0;
    _commentCount = 0;
    _reactionCount = 0;
    _zapCount = 0;
  }

  void updateCounts(List<DataEvent> events) {
    final me = context.read<AppStatesProvider>().me;
    bool isReposted = false;
    bool isReacted = false;
    bool isZapped = false;
    String? emojiUrl;
    int repostCount = _repostCount;
    int commentCount = _commentCount;
    int reactionCount = _reactionCount;
    double zapCount = _zapCount;

    for (final event in events) {
      if (isMuted(event)) continue;
      switch (event.kind) {
        case 1:
          if (isReply(
              event: event,
              referenceEventId: widget.event.id,
              isDirectOnly: true)) {
            commentCount += 1;
          }
          continue;
        case 6:
          if (!isReposted && event.pubkey == me.pubkey) {
            isReposted = true;
          }
          repostCount += 1;
          continue;
        case 7:
          if (!isReacted && event.pubkey == me.pubkey) {
            isReacted = true;
            emojiUrl = getEmojiUrl(
              event: event,
              emoji: event.content!,
            );
          }
          reactionCount += 1;
          continue;
        case 9735:
          if (event.tags != null) {
            String? bolt11Tag = event.getTagValue('bolt11');
            String? desc = event.getTagValue('description');

            if (desc != null) {
              if (me.pubkey == jsonDecode(desc)?['pubkey']) {
                isZapped = true;
              }
            }
            if (bolt11Tag != null) {
              double amount =
                  Bolt11PaymentRequest(bolt11Tag).amount.toDouble() * 100000000;
              zapCount += amount;
            }
          }
          continue;
      }
    }

    _isReposted = _isReposted == true ? _isReposted : isReposted;
    _isReacted = _isReacted == true ? _isReacted : isReacted;
    _isZapped = _isZapped == true ? _isZapped : isZapped;
    _emojiUrl = _emojiUrl ?? emojiUrl;
    _repostCount = repostCount;
    _commentCount = commentCount;
    _reactionCount = reactionCount;
    _zapCount = zapCount;
  }

  void _handleRepostPressed() async {
    try {
      AppUtils.showSnackBar(
        text: 'Reposting...',
        withProgressBar: true,
        autoHide: false,
      );
      final event = DataEvent(
        kind: 6,
        content: jsonEncode(widget.event.toMap()),
      );
      event.addTagIfNew(['e', widget.event.id!, '', 'mention']);
      event.addTagIfNew(['p', widget.event.pubkey]);
      await event.publish(autoGenerateTags: false);
      setState(() {
        _isReposted = true;
      });
      AppUtils.showSnackBar(
        text: 'Reposted successfully.',
        status: AppStatus.success,
      );
    } catch (error) {
      AppUtils.handleError();
    }
  }

  void _handleReactPressed([List<String>? emojiTag]) {
    final customEmoji = emojiTag?.elementAtOrNull(1);
    setState(() {
      _reactionIconScale = 2;
      _isReacted = true;
      _emojiUrl = emojiTag?.elementAtOrNull(2);
    });
    final event = DataEvent(
      kind: 7,
      content: customEmoji == null ? '+' : ':$customEmoji:',
    );
    event.addTagIfNew(['e', widget.event.id!]);
    event.addTagIfNew(['p', widget.event.pubkey]);
    if (emojiTag != null) {
      event.addTagIfNew(emojiTag);
    }
    event.publish(autoGenerateTags: false);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MyThemeExtension themeExtension = themeData.extension<MyThemeExtension>()!;
    final appState = context.watch<AppStatesProvider>();
    return Row(
      children: [
        Expanded(
          child: MenuAnchor(
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return TextButton.icon(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: Icon(
                  Icons.repeat,
                  color: _isReposted
                      ? themeData.colorScheme.secondary
                      : themeExtension.textDimColor,
                ),
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
                  alignment: Alignment.centerLeft,
                ),
                label: _repostCount > 0
                    ? Text(
                        NumberFormat.compact().format(_repostCount),
                        maxLines: 1,
                        style: themeData.textTheme.labelMedium
                            ?.copyWith(color: themeExtension.textDimColor),
                      )
                    : const SizedBox.shrink(),
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: _handleRepostPressed,
                leadingIcon: const Icon(Icons.repeat),
                child: const Text('Repost'),
              ),
              MenuItemButton(
                onPressed: () => appState.navigatorPush(
                  widget: PostCompose(
                    quotedEvent: widget.event,
                  ),
                  rootNavigator: true,
                ),
                leadingIcon: const Icon(Icons.format_quote),
                child: const Text('Quote'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: () => appState.navigatorPush(
              widget: PostCompose(
                referencedEvent: widget.event,
                isReply: true,
              ),
              rootNavigator: true,
            ),
            icon: Icon(
              Icons.comment_outlined,
              color: themeExtension.textDimColor,
            ),
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
              alignment: Alignment.centerLeft,
            ),
            label: _commentCount > 0
                ? Text(
                    NumberFormat.compact().format(_commentCount),
                    maxLines: 1,
                    style: themeData.textTheme.labelMedium
                        ?.copyWith(color: themeExtension.textDimColor),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: _isReacted ? () {} : () => _handleReactPressed(),
            onLongPress: _isReacted
                ? null
                : () {
                    showModalBottomSheet(
                      isScrollControlled: true,
                      useRootNavigator: true,
                      enableDrag: false,
                      showDragHandle: true,
                      useSafeArea: true,
                      context: context,
                      builder: (context) {
                        return EmojiPicker(
                          onChanged: (value) {
                            Navigator.pop(context);
                            _handleReactPressed(value);
                          },
                        );
                      },
                    );
                  },
            icon: AnimatedScale(
              scale: _reactionIconScale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              onEnd: () {
                if (_reactionIconScale != 1) {
                  setState(() {
                    _reactionIconScale = 1;
                  });
                }
              },
              child: _emojiUrl == null
                  ? Icon(
                      _isReacted ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: _isReacted
                          ? themeData.colorScheme.secondary
                          : themeExtension.textDimColor,
                    )
                  : SizedBox(
                      width: 24,
                      height: 24,
                      child: Image(
                        width: 24,
                        height: 24,
                        image: AppUtils.getCachedImageProvider(_emojiUrl!, 80),
                      ),
                    ),
            ),
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
              alignment: Alignment.centerLeft,
            ),
            label: _reactionCount > 0
                ? Text(
                    NumberFormat.compact().format(_reactionCount),
                    maxLines: 1,
                    style: themeData.textTheme.labelMedium
                        ?.copyWith(color: themeExtension.textDimColor),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (_user?.lud06 != null || _user?.lud16 != null)
          Expanded(
            child: TextButton.icon(
              onPressed: () => appState.navigatorPush(
                widget: ZapForm(
                  user: _user!,
                  event: widget.event,
                ),
                rootNavigator: true,
              ),
              icon: Icon(
                Icons.electric_bolt,
                color: _isZapped ? Colors.orange : themeExtension.textDimColor,
              ),
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
                alignment: Alignment.centerLeft,
              ),
              label: _zapCount > 0
                  ? Text(
                      NumberFormat.compact().format(_zapCount),
                      maxLines: 1,
                      style: themeData.textTheme.labelMedium
                          ?.copyWith(color: themeExtension.textDimColor),
                    )
                  : const SizedBox.shrink(),
            ),
          )
        else
          const Expanded(
            child: SizedBox.shrink(),
          ),
      ],
    );
  }
}
