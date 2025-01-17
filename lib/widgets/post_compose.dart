import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wherostr_social/models/app_states.dart';
import 'package:wherostr_social/models/app_theme.dart';
import 'package:wherostr_social/models/data_event.dart';
import 'package:wherostr_social/models/nostr_user.dart';
import 'package:wherostr_social/services/file.dart';
import 'package:wherostr_social/services/nostr.dart';
import 'package:wherostr_social/utils/app_utils.dart';
import 'package:wherostr_social/widgets/gradient_decorated_box.dart';
import 'package:wherostr_social/widgets/map_geohash_picker.dart';
import 'package:wherostr_social/widgets/post_item.dart';
import 'package:wherostr_social/widgets/post_location_chip.dart';
import 'package:wherostr_social/widgets/post_proof_of_work_adjustment.dart';
import 'package:wherostr_social/widgets/post_proof_of_work_chip.dart';
import 'package:wherostr_social/widgets/profile_display_name.dart';
import 'package:wherostr_social/widgets/profile_avatar.dart';
import 'package:wherostr_social/widgets/profile_list.dart';

const uuid = Uuid();

class PostCompose extends StatefulWidget {
  final DataEvent? quotedEvent;
  final DataEvent? referencedEvent;
  final bool isReply;

  const PostCompose({
    super.key,
    this.quotedEvent,
    this.referencedEvent,
    this.isReply = false,
  });

  @override
  State createState() => _PostComposeState();
}

class _PostComposeState extends State<PostCompose> {
  final _editorController = QuillController.basic();
  final _editorFocusNode = FocusNode();
  bool _isEmpty = true;
  bool _isProfileListOpen = false;
  int _atSignIndex = -1;
  String? _keyword;
  String? _geohash;
  int? _difficulty;
  bool _isLoading = false;
  String? _bestHash;
  Completer<String>? _powCompleter;
  final StreamController<String> _bestHashController =
      StreamController<String>();
  StateSetter? _setState;

  @override
  void initState() {
    super.initState();
    _editorController.addListener(editorListener);
    _bestHashController.stream.listen((data) {
      _setState?.call(() {
        _bestHash = data;
      });
    });
  }

  @override
  void dispose() {
    _bestHashController.close();
    _editorController.removeListener(editorListener);
    _editorController.dispose();
    super.dispose();
  }

  void editorListener() {
    try {
      final index = _editorController.selection.baseOffset;
      final text = _editorController.plainTextEditingValue.text;
      final isEmpty = !text.trim().isNotEmpty;
      setState(() {
        _isEmpty = isEmpty;
      });
      if (index == 0 || isEmpty) {
        _hideProfileList();
      } else {
        final newCharacter = text.substring(index - 1, index);
        if (newCharacter == '@') {
          setState(() {
            _atSignIndex = index;
            _keyword = null;
          });
          _showProfileList();
        } else if (_isProfileListOpen) {
          if (_atSignIndex >= index) {
            _hideProfileList();
          } else {
            final keyword = text.substring(_atSignIndex, index);
            if (keyword.contains(' ') || keyword.contains('\n')) {
              _hideProfileList();
            } else {
              setState(() {
                _keyword = keyword;
              });
            }
          }
        }
      }
    } catch (error) {
      AppUtils.handleError();
    }
  }

  void _showProfileList() {
    Future.delayed(const Duration(milliseconds: 300)).then((_) {
      if (!_isProfileListOpen) {
        setState(() {
          _keyword = null;
          _isProfileListOpen = true;
        });
      }
    });
  }

  void _hideProfileList() {
    Future.delayed(const Duration(milliseconds: 300)).then((_) {
      if (_isProfileListOpen) {
        setState(() {
          _atSignIndex = -1;
          _keyword = null;
          _isProfileListOpen = false;
        });
      }
    });
  }

  void _addProfileMention(NostrUser profile) {
    final index = _atSignIndex - 1;
    final length = _editorController.selection.extentOffset - index;
    _editorController.replaceText(
      index,
      length,
      Embeddable(CustomEmbed.profileMentionType,
          ' nostr:${NostrService.instance.utilsService.encodeNProfile(pubkey: profile.pubkey)} '),
      null,
      shouldNotifyListeners: false,
    );
    _editorController.document.insert(index + 1, ' ');
    _editorController.moveCursorToPosition(index + 2);
    _hideProfileList();
  }

  Future<void> _addPhoto(XFile? file) async {
    if (file != null) {
      int index = _editorController.selection.baseOffset;
      final length = _editorController.selection.extentOffset - index;
      if (index > 0) {
        _editorController.document.insert(index, '\n');
        index += 1;
      }
      _editorController.replaceText(
        index,
        length,
        Embeddable(CustomEmbed.imageFileType, File(file.path)),
        null,
      );
      _editorController.document.insert(index + 1, '\n');
      _editorController.moveCursorToPosition(index + 2);
    }
  }

  void _handleProfileSelected(NostrUser profile) async {
    _addProfileMention(profile);
  }

  Future<void> _handleChooseFromLibraryPressed() async {
    try {
      FocusScope.of(context).unfocus();
      _addPhoto(await FileService.pickAPhoto());
    } catch (error) {
      AppUtils.handleError();
    }
  }

  Future<void> _handleTakeAPhotoPressed() async {
    try {
      FocusScope.of(context).unfocus();
      _addPhoto(await FileService.takeAPhoto());
    } catch (error) {
      AppUtils.handleError();
    }
  }

  Future<void> _showDialog() {
    return showDialog(
      useRootNavigator: true,
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            _setState = setState;
            final currentDiff = _bestHash != null
                ? NostrService.instance.utilsService
                    .countDifficultyOfHex(_bestHash!)
                : 0;
            return AlertDialog(
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hashing...'),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    value: (currentDiff / _difficulty!).toDouble(),
                  ),
                  Text('Difficulty level: $currentDiff/$_difficulty'),
                  Text('Hash: ${_bestHash?.substring(0, 16)}...'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      _powCompleter?.completeError('cancel');
                      print('canceled: $_bestHash');
                    } catch (err) {
                      print(err);
                    }
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePostPressed() async {
    setState(() {
      _isLoading = true;
    });
    _hideProfileList();
    _editorController.readOnly = true;
    try {
      final items = _editorController.document.toDelta().toList();
      String content = '';
      List<File> files = [];
      List<String> fileIds = [];
      final event = DataEvent(kind: 1);
      for (var item in items) {
        if (item.key == 'insert' && item.data != null) {
          if (item.data is String) {
            content = content + (item.data as String);
          } else if (item.data is Map) {
            final data = item.data as Map;
            if (data.containsKey(CustomEmbed.imageFileType)) {
              files.add(data[CustomEmbed.imageFileType]);
              final fileId = '{${uuid.v1()}}';
              fileIds.add(fileId);
              content = content + fileId;
            } else if (data.containsKey(CustomEmbed.profileMentionType)) {
              content = content + data[CustomEmbed.profileMentionType];
            }
          }
        }
      }
      if (files.isNotEmpty) {
        AppUtils.showSnackBar(
          text:
              'Uploading ${files.length} image${files.length > 1 ? 's' : ''}...',
          withProgressBar: true,
          autoHide: false,
        );
        final fileUrls = await FileService.uploadMultiple(files);
        for (var index = 0; index < fileUrls.length; index++) {
          content =
              content.replaceAll(fileIds[index], '\n${fileUrls[index].url}\n');
          event.addTagIfNew(fileUrls[index].toTag());
        }
      }
      if (widget.quotedEvent != null) {
        content =
            '$content\nnostr:${NostrService.instance.utilsService.encodeNevent(
          eventId: widget.quotedEvent!.id!,
          pubkey: widget.quotedEvent!.pubkey,
        )}';
      }
      event.content = content.trim();
      if (mounted) {
        if (_geohash != null) {
          for (int index = _geohash!.length - 1; index > 0; index--) {
            event.addTagIfNew(['g', _geohash!.substring(0, index)]);
          }
        }
        if (widget.isReply && widget.referencedEvent != null) {
          final rEvent = widget.referencedEvent!;
          List<String>? rootETags = rEvent.tags
              ?.where(
                  (tag) => tag.firstOrNull == 'e' && tag.lastOrNull == 'root')
              .firstOrNull;
          event.addTagIfNew(rootETags ?? ['e', rEvent.id!, '', 'root']);
          if (rootETags != null) {
            event.addTagEvent(rEvent.id!, 'reply');
          }
          event.addTagUser(rEvent.pubkey);
          rEvent.tags?.where((tag) => tag.firstOrNull == 'p').forEach((tag) {
            event.addTagIfNew(tag);
          });
        }
        final me = context.read<AppStatesProvider>().me;
        if (_difficulty != null && _difficulty! > 0) {
          event.pubkey = me.pubkey;
          await event.generateContentTags();
          final streamPoW = event.mine(_difficulty!);
          int bestDiff = 0;
          int currentDiff = 0;
          _powCompleter = Completer<String>();
          final streamListener = streamPoW.listen(null);
          streamListener.onData((text) async {
            final [hash, nonce, date, index] = text.split('|');
            currentDiff =
                NostrService.instance.utilsService.countDifficultyOfHex(hash);
            if (currentDiff >= _difficulty!) {
              streamListener.cancel();
              _powCompleter?.complete(text);
            } else if (currentDiff > bestDiff) {
              bestDiff = currentDiff;
              _bestHashController.add(hash);
              print('best hash: $hash, index: $index');
            }
          });
          _showDialog();
          // AppUtils.showSnackBar(
          //   text: 'Hashing...',
          //   withProgressBar: true,
          //   autoHide: false,
          // );
          await _powCompleter?.future.then((v) {
            if (v.isEmpty) return null;
            final [hash, nonce, date, index] = v.split('|');
            event.id = hash;
            event.createdAt =
                DateTime.fromMillisecondsSinceEpoch(int.parse(date));
            event.addTagIfNew(['nonce', nonce, _difficulty!.toString()]);
            return event.sendEventToRelays(relays: me.relayList);
          }).catchError((e) {
            streamListener.cancel();
            throw const FormatException('Canceled.');
          }).whenComplete(() {
            context.read<AppStatesProvider>().navigatorPop();
          });
        } else {
          AppUtils.showSnackBar(
            text: 'Posting...',
            withProgressBar: true,
            autoHide: false,
          );
          await event.publish(
            autoGenerateTags: true,
            difficulty: _difficulty,
            relays: me.relayList,
          );
        }
        AppUtils.showSnackBar(
          text: 'Posted successfully.',
          status: AppStatus.success,
        );
        if (mounted) {
          context.read<AppStatesProvider>().navigatorPop();
        }
      } else {
        AppUtils.hideSnackBar();
      }
    } on FormatException catch (e) {
      AppUtils.showSnackBar(text: e.message, status: AppStatus.error);
    } catch (error) {
      print(error);
      AppUtils.hideSnackBar();
      AppUtils.handleError();
    } finally {
      if (mounted) {
        _editorController.readOnly = false;
        setState(() {
          _bestHash = null;
          _isLoading = false;
        });
      }
    }
  }

  void _updateGeohash(String? geohash) {
    setState(() {
      _geohash = geohash;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MyThemeExtension themeExtension = themeData.extension<MyThemeExtension>()!;
    final me = context.watch<AppStatesProvider>().me;
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isReply ? 'Reply' : 'New post'),
        ),
        body: GradientDecoratedBox(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ProfileAvatar(url: me.picture),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: QuillEditor.basic(
                            focusNode: _editorFocusNode,
                            configurations: QuillEditorConfigurations(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  themeData.textTheme.bodyLarge!,
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                placeHolder: DefaultTextBlockStyle(
                                  themeData.textTheme.bodyLarge!.apply(
                                    color: themeExtension.textDimColor,
                                  ),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                              controller: _editorController,
                              placeholder: widget.isReply
                                  ? 'Add a reply'
                                  : 'What\'s happening?',
                              scrollable: true,
                              autoFocus: true,
                              expands: true,
                              embedBuilders: [
                                ImageEmbedBuilder(),
                                ProfileMentionEmbedBuilder(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_geohash != null || _difficulty != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_geohash != null)
                          PostLocationChip(
                            geohash: _geohash,
                            enableShowMapAction: false,
                          ),
                        const Spacer(),
                        if (_difficulty != null)
                          PostProofOfWorkChip(
                            difficulty: _difficulty,
                          )
                      ],
                    ),
                  ),
                if (widget.quotedEvent != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.transparent,
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeData.colorScheme.primary,
                          ),
                        ),
                        child: LimitedBox(
                          maxHeight: _isProfileListOpen ? 0 : 108,
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            primary: false,
                            child: PostItem(
                              event: widget.quotedEvent!,
                              enableTap: false,
                              enableElementTap: false,
                              enableMenu: false,
                              enableActionBar: false,
                              enableLocation: false,
                              enableProofOfWork: false,
                              enableShowProfileAction: false,
                              depth: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Material(
                  child: Column(
                    children: [
                      if (_isProfileListOpen) ...[
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height > 640
                              ? 192
                              : 128,
                          child: ProfileList(
                            keyword: _keyword,
                            onProfileSelected: _handleProfileSelected,
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 16),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _handleChooseFromLibraryPressed,
                              icon: const Icon(Icons.photo),
                              color: themeExtension.textDimColor,
                            ),
                            if (!kIsWeb &&
                                (Platform.isAndroid || Platform.isIOS)) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: _handleTakeAPhotoPressed,
                                icon: const Icon(Icons.camera_alt),
                                color: themeExtension.textDimColor,
                              ),
                            ],
                            if (!widget.isReply) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => showModalBottomSheet(
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  useRootNavigator: true,
                                  enableDrag: false,
                                  showDragHandle: true,
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: FractionallySizedBox(
                                        heightFactor:
                                            MediaQuery.sizeOf(context).height >
                                                    640
                                                ? 0.75
                                                : 1,
                                        child: Container(
                                          padding: EdgeInsets.only(
                                              bottom: MediaQuery.of(context)
                                                  .viewInsets
                                                  .bottom),
                                          child: MapGeohashPicker(
                                            initialGeohash: _geohash,
                                            onGeohashUpdate: _updateGeohash,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                icon: const Icon(Icons.share_location),
                                color: _geohash == null
                                    ? themeExtension.textDimColor
                                    : themeData.colorScheme.secondary,
                              ),
                            ],
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                useRootNavigator: true,
                                enableDrag: true,
                                showDragHandle: true,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (context) {
                                  return ProofOfWorkAdjustment(
                                    value: _difficulty,
                                    onChange: (value) {
                                      setState(() {
                                        _difficulty = value;
                                      });
                                    },
                                  );
                                },
                              ),
                              icon: const Icon(Icons.memory),
                              color: _difficulty == null
                                  ? themeExtension.textDimColor
                                  : themeData.colorScheme.secondary,
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _isEmpty ? null : _handlePostPressed,
                              child: const Text('Post'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomEmbed {
  static const String imageFileType = "image-file";
  static const String profileMentionType = "profile-mention";
}

class ImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => CustomEmbed.imageFileType;

  @override
  Widget build(BuildContext context, QuillController controller, Embed node,
      bool readOnly, bool inline, TextStyle textStyle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).width - 32) * (4 / 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(node.value.data),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileMentionEmbedBuilder extends EmbedBuilder {
  @override
  String get key => CustomEmbed.profileMentionType;

  @override
  Widget build(BuildContext context, QuillController controller, Embed node,
      bool readOnly, bool inline, TextStyle textStyle) {
    ThemeData themeData = Theme.of(context);
    final uri = (node.value.data as String).trim();
    final pubkey = NostrService.instance.utilsService.decodeNprofileToMap(
        uri.startsWith('nostr:') ? uri.substring(6) : uri)['pubkey'];
    return AbsorbPointer(
      child: Transform.translate(
        offset: const Offset(0, 2.5),
        child: ProfileDisplayName(
          pubkey: pubkey,
          textStyle: textStyle.apply(color: themeData.colorScheme.primary),
          withAtSign: true,
        ),
      ),
    );
  }
}
