import 'dart:io';

import 'package:deepfacelab_client/widget/common/context_menu_region.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as Path;

class _PathItem {
  final String text;
  final String path;

  _PathItem({
    required this.path,
    required this.text,
  });

  @override
  String toString() {
    return '$text: $path';
  }
}

class _FileSystemEntity {
  final String filename;
  final bool directory;
  final bool image;
  int? selected;

  _FileSystemEntity({
    required this.filename,
    required this.directory,
    required this.image,
    required this.selected,
  });
}

// /.pub-cache/hosted/pub.dev/filesystem_picker-3.1.0/lib/src/picker_page.dart
class FileManagerHeaderWidget extends HookWidget {
  final String rootPath;
  final String path;
  final ValueNotifier<String> pathNotifier;

  const FileManagerHeaderWidget(
      {Key? key,
      required this.rootPath,
      required this.path,
      required this.pathNotifier})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<BreadcrumbItem<String?>> getItems() {
      String currentPath = path;
      String dirPath = Path.relative(currentPath, from: rootPath);
      final List<String> items =
          (dirPath != '.') ? dirPath.split(Platform.pathSeparator) : [];
      List<_PathItem> pathItems = [];

      String folderName = Path.basename(rootPath);
      if (items.isNotEmpty) {
        pathItems.add(_PathItem(path: rootPath, text: folderName));

        String path = rootPath;
        for (var item in items) {
          path = Path.join(path, item);
          pathItems.add(_PathItem(path: path, text: item));
        }
      } else {
        pathItems.add(_PathItem(path: rootPath, text: folderName));
      }
      return pathItems
          .map((path) =>
              BreadcrumbItem<String>(text: path.text, data: path.path))
          .toList(growable: false);
    }

    var items = useState<List<BreadcrumbItem<String?>>>([]);

    useEffect(() {
      items.value = getItems();
      return null;
    }, [path, rootPath]);

    return Breadcrumbs<String>(
      items: items.value,
      onSelect: (String? value) {
        if (value == null || value == path) {
          return;
        }
        pathNotifier.value = value;
      },
    );
  }
}

class FileManagerFooterWidget extends HookWidget {
  final int nbSelectedItems;

  const FileManagerFooterWidget({Key? key, required this.nbSelectedItems})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox.shrink(),
        SelectableText("$nbSelectedItems items"),
      ],
    );
  }
}

class FileManagerShortcutWidget extends HookWidget {
  const FileManagerShortcutWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ExpansionTile(
      expandedAlignment: Alignment.topLeft,
      title: Text('Shortcuts'),
      tilePadding: EdgeInsets.all(0.0),
      children: <Widget>[
        MarkdownBody(data: """
- `f2`: rename
- `Ctrl + A`: Select all
- `del`: Delete
- `left click`: Select
- `right click`: Contextual menu
- `Ctrl + click`: Select multiple
- `Shift + click`: Select range
    """)
      ],
    );
  }
}

class FileManagerWidget extends HookWidget {
  final String rootPath;

  const FileManagerWidget({Key? key, required this.rootPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var folderPath = useState<String>(rootPath);
    var fileSystemEntities = useState<List<_FileSystemEntity>?>(null);
    var nbSelectedItems = useState<int>(0);
    var myFocusNode = useState<FocusNode>(FocusNode());

    loadFilesFolders() async {
      fileSystemEntities.value = null;
      List<_FileSystemEntity> newFileSystemEntities =
          await (Directory(folderPath.value).list()).map((fileSystemEntity) {
        // https://stackoverflow.com/questions/75915594/pathinfo-method-equivalent-for-dart-language#answer-75915804
        String filename = Path.basename(fileSystemEntity.path);
        return _FileSystemEntity(
          filename: filename,
          directory: fileSystemEntity is Directory,
          image: filename.contains('.png') ||
              filename.contains('.jpeg') ||
              filename.contains('.jpg'),
          selected: null,
        );
      }).toList();
      newFileSystemEntities.sort((a, b) {
        if (a.directory == true && b.directory == true) {
          return a.filename.compareTo(b.filename);
        }
        if (a.directory == true) {
          return -1;
        }
        if (b.directory == true) {
          return 1;
        }
        return a.filename.compareTo(b.filename);
      });
      fileSystemEntities.value = newFileSystemEntities;
    }

    onTapContainer() {
      FocusScope.of(context).requestFocus(myFocusNode.value);
      ContextMenuController.removeAny();
      fileSystemEntities.value = fileSystemEntities.value!.map((e) {
        e.selected = null;
        return e;
      }).toList();
    }

    selectAll() {
      int now = DateTime.now().millisecondsSinceEpoch;
      fileSystemEntities.value = fileSystemEntities.value!.map((e) {
        e.selected = now;
        return e;
      }).toList();
    }

    rename() {
      print("rename");
    }

    delete() {
      print("delete");
    }

    changeDirectory(int index) {
      if (fileSystemEntities.value![index].directory == true) {
        folderPath.value =
            "${folderPath.value}${Platform.pathSeparator}${fileSystemEntities.value![index].filename}";
      }
    }

    onTapCard(int index,
        {Set<LogicalKeyboardKey>? keysPressed, bool? rightClick}) {
      FocusScope.of(context).requestFocus(myFocusNode.value);
      ContextMenuController.removeAny();
      int now = DateTime.now().millisecondsSinceEpoch;
      int? lastSelected = fileSystemEntities.value![index].selected;
      if (rightClick != true &&
          lastSelected != null &&
          lastSelected + 500 >= now) {
        if (fileSystemEntities.value![index].directory == true) {
          changeDirectory(index);
        } else {
          String executable = 'xdg-open';
          if (Platform.isWindows) {
            executable = 'start';
          }
          Process.run(executable, [
            folderPath.value +
                Platform.pathSeparator +
                fileSystemEntities.value![index].filename
          ]);
        }
        return;
      }
      bool ctrl = false;
      bool shift = false;
      if (keysPressed != null) {
        ctrl = keysPressed.contains(LogicalKeyboardKey.controlLeft);
        shift = keysPressed.contains(LogicalKeyboardKey.shiftLeft);
      }
      var newFileSystemEntities = fileSystemEntities.value;
      int length = newFileSystemEntities?.length ?? 0;
      if (length > 0) {
        if (shift == true) {
          int firstSelectedIndex =
              newFileSystemEntities?.indexWhere((e) => e.selected != null) ?? 0;
          for (var i = 0; i < length; i++) {
            if ((i >= firstSelectedIndex && i <= index) ||
                (i <= firstSelectedIndex && i >= index)) {
              newFileSystemEntities![i].selected = now;
            } else {
              newFileSystemEntities![i].selected = null;
            }
          }
        } else {
          if (ctrl == false) {
            for (var i = 0; i < length; i++) {
              newFileSystemEntities![i].selected = null;
            }
          }
          newFileSystemEntities![index].selected = now;
        }
        fileSystemEntities.value = newFileSystemEntities?.toList();
      }
    }

    useEffect(() {
      folderPath.value = rootPath;
      return null;
    }, [rootPath]);

    useEffect(() {
      loadFilesFolders();
      return null;
    }, [folderPath.value]);

    useEffect(() {
      nbSelectedItems.value = fileSystemEntities.value
              ?.where((element) => element.selected != null)
              .length ??
          0;
      return null;
    }, [fileSystemEntities.value]);

    return fileSystemEntities.value == null
        ? const Center(child: CircularProgressIndicator())
        : Expanded(
            child: GestureDetector(
              onTap: () => onTapContainer(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FileManagerHeaderWidget(
                      pathNotifier: folderPath,
                      path: folderPath.value,
                      rootPath: rootPath),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.keyA,
                            control: true): selectAll,
                        const SingleActivator(LogicalKeyboardKey.f2): rename,
                        const SingleActivator(LogicalKeyboardKey.delete):
                            delete,
                      },
                      child: Focus(
                        focusNode: myFocusNode.value,
                        autofocus: true,
                        child: GridView.builder(
                            // https://stackoverflow.com/questions/53612200/flutter-how-to-give-height-to-the-childrens-of-gridview-builder
                            // https://www.youtube.com/watch?v=0blNt4XIi0g
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 100,
                            ),
                            itemCount: fileSystemEntities.value!.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Tooltip(
                                message:
                                    fileSystemEntities.value![index].filename,
                                child: ContextMenuRegion(
                                  beforeShow: () =>
                                      onTapCard(index, rightClick: true),
                                  contextMenuBuilder: (context, primaryAnchor,
                                      [secondaryAnchor]) {
                                    return AdaptiveTextSelectionToolbar
                                        .buttonItems(
                                      anchors: TextSelectionToolbarAnchors(
                                        primaryAnchor: primaryAnchor,
                                        secondaryAnchor:
                                            secondaryAnchor as Offset?,
                                      ),
                                      buttonItems: <ContextMenuButtonItem>[
                                        ContextMenuButtonItem(
                                          onPressed: () {
                                            ContextMenuController.removeAny();
                                          },
                                          label: 'Back',
                                        ),
                                      ],
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () => onTapCard(index,
                                        keysPressed:
                                            RawKeyboard.instance.keysPressed),
                                    child: Card(
                                      color: fileSystemEntities
                                                  .value![index].selected !=
                                              null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          fileSystemEntities
                                                  .value![index].directory
                                              ? const Icon(Icons.folder,
                                                  size: 50)
                                              : fileSystemEntities
                                                      .value![index].image
                                                  ? Image.asset(
                                                      height: 70,
                                                      ("${folderPath.value}/${fileSystemEntities.value![index].filename}"))
                                                  : const Icon(Icons.file_open,
                                                      size: 50),
                                          Text(
                                              fileSystemEntities
                                                  .value![index].filename,
                                              maxLines: 1),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                      ),
                    ),
                  ),
                  FileManagerFooterWidget(
                    nbSelectedItems: nbSelectedItems.value,
                  ),
                ],
              ),
            ),
          );
  }
}
