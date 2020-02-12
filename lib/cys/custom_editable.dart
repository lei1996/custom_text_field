// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui show TextBox, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

// import 'box.dart';
// import 'layer.dart';
// import 'object.dart';
// import 'viewport_offset.dart';

/// 插入符号间隙
const double _kCaretGap = 1.0; // pixels
/// 插入符号高度偏移
const double _kCaretHeightOffset = 2.0; // pixels

// The additional size on the x and y axis with which to expand the prototype
// cursor to render the floating cursor in pixels.
/// 在x轴和y轴上的附加大小，用以扩展原型光标以呈现浮动游标为像素。
const Offset _kFloatingCaretSizeIncrease = Offset(0.5, 1.0);

// The corner radius of the floating cursor in pixels.
/// 以像素为单位的浮动光标的角半径。
const double _kFloatingCaretRadius = 1.0;

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
///
/// 用户更改所选内容（包括光标位置）时报告的回调的签名。
///
/// Used by [RenderEditable.onSelectionChanged].
///
/// 由 [RenderEditable.onSelectionChanged] 使用。
/// 选择更改处理程序
typedef SelectionChangedHandler = void Function(TextSelection selection,
    RenderEditable renderObject, SelectionChangedCause cause);

/// Indicates what triggered the change in selected text (including changes to
/// the cursor location).
///
/// 指示触发选定文本中更改的内容（包括更改光标位置）。
enum SelectionChangedCause {
  /// The user tapped on the text and that caused the selection (or the location
  /// of the cursor) to change.
  ///
  /// 用户点击文本，导致选择（或光标位置）改变。
  tap,

  /// The user tapped twice in quick succession on the text and that caused
  /// the selection (or the location of the cursor) to change.
  ///
  /// 用户连续两次快速点击文本，导致选择（或光标位置）发生变化。
  doubleTap,

  /// The user long-pressed the text and that caused the selection (or the
  /// location of the cursor) to change.
  ///
  /// 用户长时间按下文本，导致选择（或光标位置）发生更改。
  longPress,

  /// The user force-pressed the text and that caused the selection (or the
  /// location of the cursor) to change.
  ///
  /// 用户强制按下文本，导致选择（或光标位置）发生更改。
  forcePress,

  /// The user used the keyboard to change the selection or the location of the
  /// cursor.
  ///
  /// 用户使用键盘更改光标的选择或位置。
  ///
  /// Keyboard-triggered selection changes may be caused by the IME as well as
  /// by accessibility tools (e.g. TalkBack on Android).
  ///
  /// 键盘触发的选择更改可能是由输入法和辅助工具（如Android上的对讲）引起的。
  keyboard,

  /// The user used the mouse to change the selection by dragging over a piece
  /// of text.
  ///
  /// 用户使用鼠标通过在文本上拖动来更改选择。
  drag,
}

/// Signature for the callback that reports when the caret location changes.
///
/// 插入符号位置更改时报告的回调的签名。
///
/// Used by [RenderEditable.onCaretChanged].
/// 由 [RenderEditable.onCaretChanged] 使用.
typedef CaretChangedHandler = void Function(Rect caretRect);

/// Represents the coordinates of the point in a selection, and the text
/// direction at that point, relative to top left of the [RenderEditable] that
/// holds the selection.
///
/// 表示所选内容中点的坐标，以及该点相对于保存所选内容的[可渲染]左上角的文本方向。
@immutable
class TextSelectionPoint {
  /// Creates a description of a point in a text selection.
  ///
  /// 在文本选择中创建点的描述。
  ///
  /// The [point] argument must not be null.
  ///
  /// [点]参数不能为空。
  const TextSelectionPoint(this.point, this.direction) : assert(point != null);

  /// Coordinates of the lower left or lower right corner of the selection,
  /// relative to the top left of the [RenderEditable] object.
  ///
  /// 所选内容左下角或右下角相对于[可渲染]对象左上角的坐标。
  final Offset point;

  /// Direction of the text at this edge of the selection.
  ///
  /// 所选内容边缘的文本方向。
  final TextDirection direction;

  @override
  String toString() {
    switch (direction) {
      case TextDirection.ltr:
        return '$point-ltr';
      case TextDirection.rtl:
        return '$point-rtl';
    }
    return '$point';
  }
}

// Check if the given code unit is a white space or separator
// character.
// 检查给定的代码单元是否为空格或分隔符。
//
// Includes newline characters from ASCII and separators from the
// [unicode separator category](https://www.compart.com/en/unicode/category/Zs)
// 包括来自ASCII的换行符和来自 [unicode分隔符类别] (https://www.compart.com/en/unicode/category/Zs) 的分隔符

// TODO(gspencergoog): replace when we expose this ICU information.
// TODO(gspencergoog): 当我们暴露这个ICU信息时替换。
bool _isWhitespace(int codeUnit) {
  switch (codeUnit) {
    case 0x9: // horizontal tab 水平选项卡
    case 0xA: // line feed 换行
    case 0xB: // vertical tab 垂直制表符
    case 0xC: // form feed 表单馈送
    case 0xD: // carriage return 回车
    case 0x1C: // file separator 文件分隔符
    case 0x1D: // group separator 分组分隔符
    case 0x1E: // record separator 记录分隔符
    case 0x1F: // unit separator 单元分离器
    case 0x20: // space 空格
    case 0xA0: // no-break space 不换行空格
    case 0x1680: // ogham space mark 奥格姆空间标记
    case 0x2000: // en quad
    case 0x2001: // em quad
    case 0x2002: // en space
    case 0x2003: // em space
    case 0x2004: // three-per-em space 每个空间3个
    case 0x2005: // four-er-em space 每个空间4个
    case 0x2006: // six-per-em space 每个空间6个
    case 0x2007: // figure space  图形空间
    case 0x2008: // punctuation space  标点符号空间
    case 0x2009: // thin space
    case 0x200A: // hair space
    case 0x202F: // narrow no-break space 缩小不间断空间
    case 0x205F: // medium mathematical space 中等数学空间
    case 0x3000: // ideographic space 表意空间
      break;
    default:
      return false;
  }
  return true;
}

/// Displays some text in a scrollable container with a potentially blinking
/// cursor and with gesture recognizers.
///
/// 在带有潜在闪烁光标和手势识别器的可滚动容器中显示一些文本。
///
/// This is the renderer for an editable text field. It does not directly
/// provide affordances for editing the text, but it does handle text selection
/// and manipulation of the text cursor.
///
/// 这是可编辑文本字段的呈现程序。它不直接提供编辑文本的功能，但它处理文本选择和文本光标的操作。
///
/// The [text] is displayed, scrolled by the given [offset], aligned according
/// to [textAlign]. The [maxLines] property controls whether the text displays
/// on one line or many. The [selection], if it is not collapsed, is painted in
/// the [selectionColor]. If it _is_ collapsed, then it represents the cursor
/// position. The cursor is shown while [showCursor] is true. It is painted in
/// the [cursorColor].
///
/// 显示[文本]，按给定的[偏移量]滚动，根据[文本对齐]对齐。
/// [maxLines]属性控制文本是显示在一行还是多行上。如果没有折叠，
/// [selection]将在[selectionColor]中绘制。如果它是折叠的，则表示光标位置。
/// 当[showCursor]为true时，将显示光标。它是用[草色]画的。
///
/// If, when the render object paints, the caret is found to have changed
/// location, [onCaretChanged] is called.
///
/// 如果在渲染对象绘制时，发现插入符号已更改位置，则调用[onCaretChanged]。
///
/// The user may interact with the render object by tapping or long-pressing.
/// When the user does so, the selection is updated, and [onSelectionChanged] is
/// called.
///
/// 用户可以通过轻敲或长按与渲染对象交互。当用户这样做时，将更新所选内容，并调用[onSelectionChanged]。
///
/// Keyboard handling, IME handling, scrolling, toggling the [showCursor] value
/// to actually blink the cursor, and other features not mentioned above are the
/// responsibility of higher layers and not handled by this object.
///
/// 键盘处理、输入法处理、滚动、切换[showCursor]值以实际闪烁光标，
/// 以及上面未提及的其他功能由更高层负责，而不是由该对象处理。
class RenderEditable extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  /// Creates a render object that implements the visual aspects of a text field.
  ///
  /// 创建实现文本字段视觉方面的呈现对象。
  ///
  /// The [textAlign] argument must not be null. It defaults to [TextAlign.start].
  ///
  /// [textAlign]参数不能为空。默认为[TextAlign.start]。
  ///
  /// The [textDirection] argument must not be null.
  ///
  /// [textDirection]参数不能为空。
  ///
  /// If [showCursor] is not specified, then it defaults to hiding the cursor.
  ///
  /// 如果未指定[showCursor]，则默认为隐藏光标。
  ///
  /// The [maxLines] property can be set to null to remove the restriction on
  /// the number of lines. By default, it is 1, meaning this is a single-line
  /// text field. If it is not null, it must be greater than zero.
  ///
  /// [maxLines]属性可以设置为空，以删除对行数的限制。
  /// 默认情况下，它是1，这意味着这是一个单行文本字段。如果不为空，则必须大于零。
  ///
  /// The [offset] is required and must not be null. You can use [new
  /// ViewportOffset.zero] if you have no need for scrolling.
  ///
  /// [偏移量]是必需的，不能为空。如果不需要滚动，可以使用[new ViewportOffset.zero]。
  RenderEditable({
    TextSpan text,
    // 文本方向
    @required TextDirection textDirection,
    // 文本对齐
    TextAlign textAlign = TextAlign.start,
    // 光标颜色
    Color cursorColor,
    // 背景光标颜色
    Color backgroundCursorColor,
    // 显示光标
    ValueNotifier<bool> showCursor,
    // 聚焦
    bool hasFocus,
    // 开始句柄层链接
    @required LayerLink startHandleLayerLink,
    // 结束句柄层链接
    @required LayerLink endHandleLayerLink,
    // 最大行
    int maxLines = 1,
    // 最小行
    int minLines,
    // 扩展
    bool expands = false,
    // 结构样式
    StrutStyle strutStyle,
    // 选择 颜色
    Color selectionColor,
    // 文本缩放因子
    double textScaleFactor = 1.0,
    // 选择
    TextSelection selection,
    // 偏移量
    @required ViewportOffset offset,
    // 选择更改时
    this.onSelectionChanged,
    // 插入符号更改时
    this.onCaretChanged,
    // 忽略指针
    this.ignorePointer = false,
    // 只读
    bool readOnly = false,
    // 强制线
    bool forceLine = true,
    // 文本宽度基
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    // 模糊文本
    bool obscureText = false,
    // 本地化
    Locale locale,
    // 光标宽度
    double cursorWidth = 1.0,
    // 光标半径
    Radius cursorRadius,
    // 在文本上方绘制光标
    bool paintCursorAboveText = false,
    // 光标偏移量
    Offset cursorOffset,
    // 设备像素比
    double devicePixelRatio = 1.0,
    // 启用交互式选择
    bool enableInteractiveSelection,
    // 浮动光标添加边距
    EdgeInsets floatingCursorAddedMargin =
        const EdgeInsets.fromLTRB(4, 4, 4, 5),
    // 文本选择委托
    @required this.textSelectionDelegate,
  })  : assert(textAlign != null),
        assert(textDirection != null,
            'RenderEditable created without a textDirection.'),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(startHandleLayerLink != null),
        assert(endHandleLayerLink != null),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          'minLines can\'t be greater than maxLines',
        ),
        assert(expands != null),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(textScaleFactor != null),
        assert(offset != null),
        assert(ignorePointer != null),
        assert(textWidthBasis != null),
        assert(paintCursorAboveText != null),
        assert(obscureText != null),
        assert(textSelectionDelegate != null),
        assert(cursorWidth != null && cursorWidth >= 0.0),
        assert(readOnly != null),
        assert(forceLine != null),
        assert(devicePixelRatio != null),
        _textPainter = TextPainter(
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
          textScaleFactor: textScaleFactor,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
        ),
        _cursorColor = cursorColor,
        _backgroundCursorColor = backgroundCursorColor,
        _showCursor = showCursor ?? ValueNotifier<bool>(false),
        _maxLines = maxLines,
        _minLines = minLines,
        _expands = expands,
        _selectionColor = selectionColor,
        _selection = selection,
        _offset = offset,
        _cursorWidth = cursorWidth,
        _cursorRadius = cursorRadius,
        _paintCursorOnTop = paintCursorAboveText,
        _cursorOffset = cursorOffset,
        _floatingCursorAddedMargin = floatingCursorAddedMargin,
        _enableInteractiveSelection = enableInteractiveSelection,
        _devicePixelRatio = devicePixelRatio,
        _startHandleLayerLink = startHandleLayerLink,
        _endHandleLayerLink = endHandleLayerLink,
        _obscureText = obscureText,
        _readOnly = readOnly,
        _forceLine = forceLine {
    assert(_showCursor != null);
    assert(!_showCursor.value || cursorColor != null);
    this.hasFocus = hasFocus ?? false;
  }

  /// Character used to obscure text if [obscureText] is true.
  ///
  /// 如果[obseretext]为true，则用于隐藏文本的字符。
  static const String obscuringCharacter = '•';

  /// Called when the selection changes.
  ///
  /// 选择更改时调用。
  ///
  /// If this is null, then selection changes will be ignored.
  ///
  /// 如果为空，则将忽略选择更改。
  SelectionChangedHandler onSelectionChanged;

  /// 文本布局最后最大宽度
  double _textLayoutLastMaxWidth;

  /// 文本布局最后最小宽度
  double _textLayoutLastMinWidth;

  /// Called during the paint phase when the caret location changes.
  ///
  /// 在插入符号位置更改时在绘制阶段调用。
  CaretChangedHandler onCaretChanged;

  /// If true [handleEvent] does nothing and it's assumed that this
  /// renderer will be notified of input gestures via [handleTapDown],
  /// [handleTap], [handleDoubleTap], and [handleLongPress].
  ///
  /// 如果为true，则[handleEvent]不起任何作用，并且假定此渲染器将通过
  /// [handleTapDown]、[handleTap]、[handleDoubleTap]和
  /// [handleLongPress]收到输入手势的通知。
  ///
  /// The default value of this property is false.
  ///
  /// 此属性的默认值为false。
  bool ignorePointer;

  /// {@macro flutter.widgets.text.DefaultTextStyle.textWidthBasis}
  TextWidthBasis get textWidthBasis => _textPainter.textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    assert(value != null);
    if (_textPainter.textWidthBasis == value) return;
    _textPainter.textWidthBasis = value;
    markNeedsTextLayout();
  }

  /// The pixel ratio of the current device.
  ///
  /// 当前设备的像素比率。
  ///
  /// Should be obtained by querying MediaQuery for the devicePixelRatio.
  ///
  /// 应通过查询MediaQuery获取设备像素比率。
  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsTextLayout();
  }

  /// Whether to hide the text being edited (e.g., for passwords).
  ///
  /// 是否隐藏正在编辑的文本（例如，密码）。
  bool get obscureText => _obscureText;
  bool _obscureText;
  set obscureText(bool value) {
    if (_obscureText == value) return;
    _obscureText = value;
    markNeedsSemanticsUpdate();
  }

  /// The object that controls the text selection, used by this render object
  ///
  /// 控制文本选择的对象，由该呈现对象使用
  ///
  /// for implementing cut, copy, and paste keyboard shortcuts.
  ///
  /// 用于实现剪切、复制和粘贴键盘快捷键。
  ///
  /// It must not be null. It will make cut, copy and paste functionality work
  ///
  /// 它不能为空。它将使剪切、复制和粘贴功能发挥作用
  ///
  /// with the most recently set [TextSelectionDelegate].
  ///
  /// 使用最近设置的[TextSelectionDelegate]。
  TextSelectionDelegate textSelectionDelegate;

  // 上次一个插入符矩形
  Rect _lastCaretRect;

  /// Track whether position of the start of the selected text is within the viewport.
  ///
  /// 跟踪选定文本的开始位置是否在视口中。
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "Hello", then scrolls so only "World" is visible, this will become false.
  /// If the user scrolls back so that the "H" is visible again, this will
  /// become true.
  ///
  /// 例如，如果文本包含“Hello World”，并且用户选择“Hello”，则滚动以仅显示“World”，
  /// 这将变为false。如果用户向后滚动以使“H”再次可见，则这将变为 true。
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ///
  /// 此bool指示是否滚动文本以使句柄位于“文本字段”视区内，而不是是否在屏幕上实际可见。
  ValueListenable<bool> get selectionStartInViewport =>
      _selectionStartInViewport;
  final ValueNotifier<bool> _selectionStartInViewport =
      ValueNotifier<bool>(true);

  /// Track whether position of the end of the selected text is within the viewport.
  ///
  /// 跟踪选定文本结尾的位置是否在视口中。
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "World", then scrolls so only "Hello" is visible, this will become
  /// 'false'. If the user scrolls back so that the "d" is visible again, this
  /// will become 'true'.
  ///
  /// 例如，如果文本包含“Hello World”，并且用户选择“World”，则滚动以使仅“Hello”可见，
  /// 这将变为“false”。如果用户向后滚动以使“d”再次可见，则这将变为“true”。
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ///
  /// 此bool指示是否滚动文本以使句柄位于“文本字段”视区内，而不是是否在屏幕上实际可见。
  ValueListenable<bool> get selectionEndInViewport => _selectionEndInViewport;
  final ValueNotifier<bool> _selectionEndInViewport = ValueNotifier<bool>(true);

  void _updateSelectionExtentsVisibility(Offset effectiveOffset) {
    final Rect visibleRegion = Offset.zero & size;

    final Offset startOffset = _textPainter.getOffsetForCaret(
      TextPosition(offset: _selection.start, affinity: _selection.affinity),
      _caretPrototype,
    );
    // TODO(justinmc): https://github.com/flutter/flutter/issues/31495
    // Check if the selection is visible with an approximation because a
    // difference between rounded and unrounded values causes the caret to be
    // reported as having a slightly (< 0.5) negative y offset. This rounding
    // happens in paragraph.cc's layout and TextPainer's
    // _applyFloatingPointHack. Ideally, the rounding mismatch will be fixed and
    // this can be changed to be a strict check instead of an approximation.
    // 检查选择是否以近似方式可见，因为舍入和舍入值之间的差异导致插入符号被报告为具有略微
    // （＜0.5）负y 偏移。这种舍入发生在一部分cc的布局和TextPainer的
    // applyFloatingPointHack上中。理想情况下，舍入失配将是固定的，这可以改变为严格的检查，而不是近似。
    const double visibleRegionSlop = 0.5;
    _selectionStartInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(startOffset + effectiveOffset);

    // 末端偏移
    final Offset endOffset = _textPainter.getOffsetForCaret(
      TextPosition(offset: _selection.end, affinity: _selection.affinity),
      _caretPrototype,
    );
    // 选择在视口中结束
    _selectionEndInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(endOffset + effectiveOffset);
  }

  /// Holds the last cursor location the user selected in the case the user tries
  /// to select vertically past the end or beginning of the field. If they do,
  /// then we need to keep the old cursor location so that we can go back to it
  /// if they change their minds. Only used for moving selection up and down in a
  /// multiline text field when selecting using the keyboard.
  /// 
  /// 当用户试图在轴向的结束或开始处，垂直选择时，保留用户选择的最后一个光标位置。
  /// 如果他们这样做了，那么我们需要保留旧的光标位置，这样，如果他们改变主意，
  /// 我们就可以回到原来的位置。仅用于在使用键盘进行选择时在多行文本相邻中上下移动所选内容。
  int _cursorResetLocation = -1;

  /// Whether we should reset the location of the cursor in the case the user
  /// tries to select vertically past the end or beginning of the field. If they
  /// do, then we need to keep the old cursor location so that we can go back to
  /// it if they change their minds. Only used for resetting selection up and
  /// down in a multiline text field when selecting using the keyboard.
  /// 
  /// 如果用户试图垂直选择超过分段的结束或开始，我们是否应该重置光标的位置。
  /// 如果他们初始化了，那么我们需要保留旧的光标位置，这样，如果他们改变主意，
  /// 我们就可以回到原来的位置。仅用于在使用键盘进行选择时在多行文本分段中上下重置选择。
  bool _wasSelectingVerticallyWithKeyboard = false;

  // Call through to onSelectionChanged.
  void _handleSelectionChange(
    TextSelection nextSelection,
    SelectionChangedCause cause,
  ) {
    // Changes made by the keyboard can sometimes be "out of band" for listening
    // components, so always send those events, even if we didn't think it
    // changed. Also, focusing an empty field is sent as a selection change even
    // if the selection offset didn't change.
    // 键盘所做的更改有时可能是监听组件的“带外”更改，因此始终发送这些事件，即使我们认为它没有更改。
    // 此外，即使选择偏移量没有改变，聚焦一个空字段也会作为选择更改发送。
    final bool focusingEmpty = nextSelection.baseOffset == 0 &&
        nextSelection.extentOffset == 0 &&
        !hasFocus;
    if (nextSelection == selection &&
        cause != SelectionChangedCause.keyboard &&
        !focusingEmpty) {
      return;
    }
    if (onSelectionChanged != null) {
      onSelectionChanged(nextSelection, this, cause);
    }
  }

  // 移动键
  static final Set<LogicalKeyboardKey> _movementKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  };

  // 删除键
  static final Set<LogicalKeyboardKey> _deleteKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.backspace,
  };

  // 快捷键
  static final Set<LogicalKeyboardKey> _shortcutKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyX,
    ..._deleteKeys,
  };

  // 非修饰键
  static final Set<LogicalKeyboardKey> _nonModifierKeys = <LogicalKeyboardKey>{
    ..._shortcutKeys,
    ..._movementKeys,
  };

  // 修饰键
  static final Set<LogicalKeyboardKey> _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.alt,
  };

  // macOs修改键
  static final Set<LogicalKeyboardKey> _macOsModifierKeys =
      <LogicalKeyboardKey>{
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.alt,
  };

  // 有趣的键
  static final Set<LogicalKeyboardKey> _interestingKeys = <LogicalKeyboardKey>{
    ..._modifierKeys,
    ..._macOsModifierKeys,
    ..._nonModifierKeys,
  };

  // TODO(goderbauer): doesn't handle extended grapheme clusters with more than one Unicode scalar value (https://github.com/flutter/flutter/issues/13404).
  // This is because some of this code depends upon counting the length of the
  // string using Unicode scalar values, rather than using the number of
  // extended grapheme clusters (a.k.a. "characters" in the end user's mind).
  // 这是因为有些代码依赖于使用Unicode标量值计算字符串的长度，
  // 而不是使用扩展的grapheme集群的数量（即最终用户心目中的“字符”）。
  void _handleKeyEvent(RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent || onSelectionChanged == null) return;
    final Set<LogicalKeyboardKey> keysPressed =
        LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed);
    final LogicalKeyboardKey key = keyEvent.logicalKey;

    final bool isMacOS = keyEvent.data is RawKeyEventDataMacOs;
    if (!_nonModifierKeys.contains(key) ||
        keysPressed
                .difference(isMacOS ? _macOsModifierKeys : _modifierKeys)
                .length >
            1 ||
        keysPressed.difference(_interestingKeys).isNotEmpty) {
      // If the most recently pressed key isn't a non-modifier key, or more than
      // one non-modifier key is down, or keys other than the ones we're interested in
      // are pressed, just ignore the keypress.
      // 如果最近按下的键不是非修改键，或者有多个非修改键关闭，或者按下了我们感兴趣的键以外的键，请忽略按键。
      return;
    }

    final bool isWordModifierPressed =
        isMacOS ? keyEvent.isAltPressed : keyEvent.isControlPressed;
    final bool isLineModifierPressed =
        isMacOS ? keyEvent.isMetaPressed : keyEvent.isAltPressed;
    final bool isShortcutModifierPressed =
        isMacOS ? keyEvent.isMetaPressed : keyEvent.isControlPressed;
    if (_movementKeys.contains(key)) {
      _handleMovement(key,
          wordModifier: isWordModifierPressed,
          lineModifier: isLineModifierPressed,
          shift: keyEvent.isShiftPressed);
    } else if (isShortcutModifierPressed && _shortcutKeys.contains(key)) {
      // _handleShortcuts depends on being started in the same stack invocation
      // as the _handleKeyEvent method
      // _handleShortcuts依赖于在与handleKeyEvent方法相同的堆栈调用中启动
      _handleShortcuts(key);
    } else if (_deleteKeys.contains(key)) {
      _handleDelete();
    }
  }

  // 手柄运动
  void _handleMovement(
    LogicalKeyboardKey key, {
    @required bool wordModifier,
    @required bool lineModifier,
    @required bool shift,
  }) {
    if (wordModifier && lineModifier) {
      // If both modifiers are down, nothing happens on any of the platforms.
      // 如果两个修改器都关闭，则任何平台上都不会发生任何事情。
      return;
    }

    // 新的选择
    TextSelection newSelection = selection;

    // 向右箭头
    final bool rightArrow = key == LogicalKeyboardKey.arrowRight;
    // 向左箭头
    final bool leftArrow = key == LogicalKeyboardKey.arrowLeft;
    // 向上箭头
    final bool upArrow = key == LogicalKeyboardKey.arrowUp;
    // 向下箭头
    final bool downArrow = key == LogicalKeyboardKey.arrowDown;

    // Find the previous non-whitespace character
    // 查找上一个非空白字符
    int previousNonWhitespace(int extent) {
      int result = math.max(extent - 1, 0);
      while (result > 0 && _isWhitespace(_plainText.codeUnitAt(result))) {
        result -= 1;
      }
      return result;
    }

    // 查找下一个非空白字符
    int nextNonWhitespace(int extent) {
      int result = math.min(extent + 1, _plainText.length);
      while (result < _plainText.length &&
          _isWhitespace(_plainText.codeUnitAt(result))) {
        result += 1;
      }
      return result;
    }

    if ((rightArrow || leftArrow) && !(rightArrow && leftArrow)) {
      // Jump to begin/end of word.
      // 跳到单词的开头/结尾。
      if (wordModifier) {
        // If control/option is pressed, we will decide which way to look for a
        // word based on which arrow is pressed.
        // 如果按control/option，我们将根据按哪个箭头来决定查找单词的方式。
        if (leftArrow) {
          // When going left, we want to skip over any whitespace before the word,
          // so we go back to the first non-whitespace before asking for the word
          // boundary, since _selectWordAtOffset finds the word boundaries without
          // including whitespace.
          // 向左时，我们希望跳过单词前面的任何空白，因此在要求单词边界之前，
          // 我们返回到第一个非空白，因为_selectWordAtOffset查找单词边界而不包含空白。
          final int startPoint =
              previousNonWhitespace(newSelection.extentOffset);
          final TextSelection textSelection =
              _selectWordAtOffset(TextPosition(offset: startPoint));
          newSelection =
              newSelection.copyWith(extentOffset: textSelection.baseOffset);
        } else {
          // When going right, we want to skip over any whitespace after the word,
          // so we go forward to the first non-whitespace character before asking
          // for the word bounds, since _selectWordAtOffset finds the word
          // boundaries without including whitespace.
          // 如果正确，我们希望跳过单词后面的任何空白，因此在要求单词边界之前，
          // 我们将前进到第一个非空白字符，因为_selectWordAtOffset查找单词边界而不包含空白。
          final int startPoint = nextNonWhitespace(newSelection.extentOffset);
          final TextSelection textSelection =
              _selectWordAtOffset(TextPosition(offset: startPoint));
          newSelection =
              newSelection.copyWith(extentOffset: textSelection.extentOffset);
        }
      } else if (lineModifier) {
        // If control/command is pressed, we will decide which way to expand to
        // the beginning/end of the line based on which arrow is pressed.
        // 如果按control/command，我们将根据所按的箭头决定扩展到行的开始/结束的方式。
        if (leftArrow) {
          // When going left, we want to skip over any whitespace before the line,
          // so we go back to the first non-whitespace before asking for the line
          // bounds, since _selectLineAtOffset finds the line boundaries without
          // including whitespace (like the newline).
          // 当向左时，我们想跳过行之前的任何空白，所以在要求行边界之前，我们回到第一个非空白，因为
          // _selectlinetoffset查找不包含空白的行边界（如换行符）。
          final int startPoint =
              previousNonWhitespace(newSelection.extentOffset);
          final TextSelection textSelection =
              _selectLineAtOffset(TextPosition(offset: startPoint));
          newSelection =
              newSelection.copyWith(extentOffset: textSelection.baseOffset);
        } else {
          // When going right, we want to skip over any whitespace after the line,
          // so we go forward to the first non-whitespace character before asking
          // for the line bounds, since _selectLineAtOffset finds the line
          // boundaries without including whitespace (like the newline).
          // 在右转时，我们希望跳过行后的任何空白，因此在请求行边界之前，我们将前进到第一个非空白字符，
          // 因为_selectlinetoffset查找不包含空白的行边界（如换行符）。
          final int startPoint = nextNonWhitespace(newSelection.extentOffset);
          final TextSelection textSelection =
              _selectLineAtOffset(TextPosition(offset: startPoint));
          newSelection =
              newSelection.copyWith(extentOffset: textSelection.extentOffset);
        }
      } else {
        if (rightArrow && newSelection.extentOffset < _plainText.length) {
          newSelection = newSelection.copyWith(
              extentOffset: newSelection.extentOffset + 1);
          if (shift) {
            _cursorResetLocation += 1;
          }
        } else if (leftArrow && newSelection.extentOffset > 0) {
          newSelection = newSelection.copyWith(
              extentOffset: newSelection.extentOffset - 1);
          if (shift) {
            _cursorResetLocation -= 1;
          }
        }
      }
    }

    // Handles moving the cursor vertically as well as taking care of the
    // case where the user moves the cursor to the end or beginning of the text
    // and then back up or down.
    // 处理垂直移动光标以及处理用户将光标移动到文本的结尾或开头，然后向上或向下移动光标的情况。
    if (downArrow || upArrow) {
      // The caret offset gives a location in the upper left hand corner of
      // the caret so the middle of the line above is a half line above that
      // point and the line below is 1.5 lines below that point.
      // 插入符号偏移在插入符号的左上角提供了一个位置，因此上面的线的中间是该点上方的半行，
      // 下面的线是该点下方的1.5行。
      final double preferredLineHeight = _textPainter.preferredLineHeight;
      final double verticalOffset =
          upArrow ? -0.5 * preferredLineHeight : 1.5 * preferredLineHeight;

      final Offset caretOffset = _textPainter.getOffsetForCaret(
          TextPosition(offset: newSelection.extentOffset), _caretPrototype);
      final Offset caretOffsetTranslated =
          caretOffset.translate(0.0, verticalOffset);
      final TextPosition position =
          _textPainter.getPositionForOffset(caretOffsetTranslated);

      // To account for the possibility where the user vertically highlights
      // all the way to the top or bottom of the text, we hold the previous
      // cursor location. This allows us to restore to this position in the
      // case that the user wants to unhighlight some text.
      // 为了考虑用户垂直高亮显示到文本顶部或底部的可能性，我们保留上一个光标位置。
      // 这允许我们在用户希望取消突出显示某些文本时恢复到该位置。
      if (position.offset == newSelection.extentOffset) {
        if (downArrow) {
          newSelection = newSelection.copyWith(extentOffset: _plainText.length);
        } else if (upArrow) {
          newSelection = newSelection.copyWith(extentOffset: 0);
        }
        _wasSelectingVerticallyWithKeyboard = shift;
      } else if (_wasSelectingVerticallyWithKeyboard && shift) {
        newSelection =
            newSelection.copyWith(extentOffset: _cursorResetLocation);
        _wasSelectingVerticallyWithKeyboard = false;
      } else {
        newSelection = newSelection.copyWith(extentOffset: position.offset);
        _cursorResetLocation = newSelection.extentOffset;
      }
    }

    // Just place the collapsed selection at the end or beginning of the region
    // if shift isn't down.
    // 如果按住shift键，只需将折叠的选定内容放在区域的末尾或开头。
    if (!shift) {
      // We want to put the cursor at the correct location depending on which
      // arrow is used while there is a selection.
      // 我们希望将光标放在正确的位置，这取决于在进行选择时使用的箭头。
      int newOffset = newSelection.extentOffset;
      if (!selection.isCollapsed) {
        if (leftArrow) {
          newOffset = newSelection.baseOffset < newSelection.extentOffset
              ? newSelection.baseOffset
              : newSelection.extentOffset;
        } else if (rightArrow) {
          newOffset = newSelection.baseOffset > newSelection.extentOffset
              ? newSelection.baseOffset
              : newSelection.extentOffset;
        }
      }
      newSelection =
          TextSelection.fromPosition(TextPosition(offset: newOffset));
    }

    // Update the text selection delegate so that the engine knows what we did.
    // 更新文本选择委托，以便引擎知道我们做了什么。
    textSelectionDelegate.textEditingValue = textSelectionDelegate
        .textEditingValue
        .copyWith(selection: newSelection);
    _handleSelectionChange(
      newSelection,
      SelectionChangedCause.keyboard,
    );
  }

  // Handles shortcut functionality including cut, copy, paste and select all
  // using control/command + (X, C, V, A).
  // 使用 control/command + (X, C, V, A) 处理快捷方式功能，包括剪切、复制、粘贴和全选。
  Future<void> _handleShortcuts(LogicalKeyboardKey key) async {
    assert(_shortcutKeys.contains(key), 'shortcut key $key not recognized.');
    if (key == LogicalKeyboardKey.keyC) {
      if (!selection.isCollapsed) {
        Clipboard.setData(
            ClipboardData(text: selection.textInside(_plainText)));
      }
      return;
    }
    if (key == LogicalKeyboardKey.keyX) {
      if (!selection.isCollapsed) {
        Clipboard.setData(
            ClipboardData(text: selection.textInside(_plainText)));
        textSelectionDelegate.textEditingValue = TextEditingValue(
          text: selection.textBefore(_plainText) +
              selection.textAfter(_plainText),
          selection: TextSelection.collapsed(offset: selection.start),
        );
      }
      return;
    }
    if (key == LogicalKeyboardKey.keyV) {
      // Snapshot the input before using `await`.
      // 在使用 "await" 之前对输入进行快照。
      // See https://github.com/flutter/flutter/issues/11427
      final TextEditingValue value = textSelectionDelegate.textEditingValue;
      final ClipboardData data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null) {
        textSelectionDelegate.textEditingValue = TextEditingValue(
          text: value.selection.textBefore(value.text) +
              data.text +
              value.selection.textAfter(value.text),
          selection: TextSelection.collapsed(
              offset: value.selection.start + data.text.length),
        );
      }
      return;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _handleSelectionChange(
        selection.copyWith(
          baseOffset: 0,
          extentOffset: textSelectionDelegate.textEditingValue.text.length,
        ),
        SelectionChangedCause.keyboard,
      );
      return;
    }
  }

  void _handleDelete() {
    if (selection.textAfter(_plainText).isNotEmpty) {
      textSelectionDelegate.textEditingValue = TextEditingValue(
        text: selection.textBefore(_plainText) +
            selection.textAfter(_plainText).substring(1),
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else {
      textSelectionDelegate.textEditingValue = TextEditingValue(
        text: selection.textBefore(_plainText),
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }
  }

  /// Marks the render object as needing to be laid out again and have its text
  /// metrics recomputed.
  ///
  /// 将呈现对象标记为需要重新布局并重新计算其文本度量。
  ///
  /// Implies [markNeedsLayout].
  @protected
  void markNeedsTextLayout() {
    _textLayoutLastMaxWidth = null;
    _textLayoutLastMinWidth = null;
    markNeedsLayout();
  }

  @override
  // 系统字体确实改变了
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _textPainter.markNeedsLayout();
    _textLayoutLastMaxWidth = null;
    _textLayoutLastMinWidth = null;
  }

  // Retuns a cached plain text version of the text in the painter.
  // 在画笔中重新运行缓存的纯文本文本版本。
  String _cachedPlainText;
  String get _plainText {
    _cachedPlainText ??= _textPainter.text.toPlainText();
    return _cachedPlainText;
  }

  /// The text to display.
  ///
  /// 要显示的文本。
  TextSpan get text => _textPainter.text as TextSpan;
  final TextPainter _textPainter;
  set text(TextSpan value) {
    if (_textPainter.text == value) return;
    _textPainter.text = value;
    _cachedPlainText = null;
    markNeedsTextLayout();
    markNeedsSemanticsUpdate();
  }

  /// How the text should be aligned horizontally.
  ///
  /// 文本应如何水平对齐。
  ///
  /// This must not be null.
  ///
  /// 不能为空。
  TextAlign get textAlign => _textPainter.textAlign;
  set textAlign(TextAlign value) {
    assert(value != null);
    if (_textPainter.textAlign == value) return;
    _textPainter.textAlign = value;
    markNeedsTextLayout();
  }

  /// The directionality of the text.
  ///
  /// 文本的方向性。
  ///
  /// This decides how the [TextAlign.start], [TextAlign.end], and
  /// [TextAlign.justify] values of [textAlign] are interpreted.
  ///
  /// 这决定了如何解释[TextAlign]的[TextAlign.start]、[TextAlign.end]和[TextAlign.justify]值。
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the [text] is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// 这也用于消除如何呈现双向文本的歧义。例如，如果[text]是英文短语，后跟希伯来语短语，
  /// 则在[TextDirection.ltr]上下文中，英文短语位于左侧，希伯来语短语位于右侧；
  /// 而在[TextDirection.rtl]上下文中，英文短语位于右侧，希伯来语短语位于左侧。
  ///
  /// This must not be null.
  ///
  /// 不能为空。
  TextDirection get textDirection => _textPainter.textDirection;
  set textDirection(TextDirection value) {
    assert(value != null);
    if (_textPainter.textDirection == value) return;
    _textPainter.textDirection = value;
    markNeedsTextLayout();
    markNeedsSemanticsUpdate();
  }

  /// Used by this renderer's internal [TextPainter] to select a locale-specific
  /// font.
  ///
  /// 此呈现程序的内部[textpainer]用于选择特定于区域设置的字体。
  ///
  /// In some cases the same Unicode character may be rendered differently depending
  /// on the locale. For example the '骨' character is rendered differently in
  /// the Chinese and Japanese locales. In these cases the [locale] may be used
  /// to select a locale-specific font.
  ///
  /// 在某些情况下，同一个Unicode字符的呈现方式可能因区域设置而异。
  /// 例如，“骨”字符在中文和日语地区的呈现方式不同。在这些情况下，[区域设置]可用于选择特定于区域设置的字体。
  ///
  /// If this value is null, a system-dependent algorithm is used to select
  /// the font.
  ///
  /// 如果该值为空，则使用系统相关算法选择字体。
  Locale get locale => _textPainter.locale;
  set locale(Locale value) {
    if (_textPainter.locale == value) return;
    _textPainter.locale = value;
    markNeedsTextLayout();
  }

  /// The [StrutStyle] used by the renderer's internal [TextPainter] to
  /// determine the strut to use.
  ///
  /// 渲染器的内部[textpainer]用于确定要使用的支柱的[StrutStyle]。
  StrutStyle get strutStyle => _textPainter.strutStyle;
  set strutStyle(StrutStyle value) {
    if (_textPainter.strutStyle == value) return;
    _textPainter.strutStyle = value;
    markNeedsTextLayout();
  }

  /// The color to use when painting the cursor.
  ///
  /// 绘制光标时要使用的颜色。
  Color get cursorColor => _cursorColor;
  Color _cursorColor;
  set cursorColor(Color value) {
    if (_cursorColor == value) return;
    _cursorColor = value;
    markNeedsPaint();
  }

  /// The color to use when painting the cursor aligned to the text while
  /// rendering the floating cursor.
  ///
  /// 在呈现浮动光标时，绘制与文本对齐的光标时要使用的颜色。
  ///
  /// The default is light grey.
  ///
  /// 默认为浅灰色。
  Color get backgroundCursorColor => _backgroundCursorColor;
  Color _backgroundCursorColor;
  set backgroundCursorColor(Color value) {
    if (backgroundCursorColor == value) return;
    _backgroundCursorColor = value;
    markNeedsPaint();
  }

  /// Whether to paint the cursor.
  ///
  /// 是否绘制光标。
  ValueNotifier<bool> get showCursor => _showCursor;
  ValueNotifier<bool> _showCursor;
  set showCursor(ValueNotifier<bool> value) {
    assert(value != null);
    if (_showCursor == value) return;
    if (attached) _showCursor.removeListener(markNeedsPaint);
    _showCursor = value;
    if (attached) _showCursor.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// Whether the editable is currently focused.
  ///
  /// 可编辑的当前是否聚焦。
  bool get hasFocus => _hasFocus;
  bool _hasFocus = false;
  bool _listenerAttached = false;
  set hasFocus(bool value) {
    assert(value != null);
    if (_hasFocus == value) return;
    _hasFocus = value;
    if (_hasFocus) {
      assert(!_listenerAttached);
      RawKeyboard.instance.addListener(_handleKeyEvent);
      _listenerAttached = true;
    } else {
      assert(_listenerAttached);
      RawKeyboard.instance.removeListener(_handleKeyEvent);
      _listenerAttached = false;
    }
    markNeedsSemanticsUpdate();
  }

  /// Whether this rendering object will take a full line regardless the text width.
  ///
  /// 无论文本宽度如何，此呈现对象是否将采用整行。
  bool get forceLine => _forceLine;
  bool _forceLine = false;
  set forceLine(bool value) {
    assert(value != null);
    if (_forceLine == value) return;
    _forceLine = value;
    markNeedsLayout();
  }

  /// Whether this rendering object is read only.
  ///
  /// 此呈现对象是否为只读。
  bool get readOnly => _readOnly;
  bool _readOnly = false;
  set readOnly(bool value) {
    assert(value != null);
    if (_readOnly == value) return;
    _readOnly = value;
    markNeedsSemanticsUpdate();
  }

  /// The maximum number of lines for the text to span, wrapping if necessary.
  ///
  /// 如果需要的话，文本行的最大行数，包装。
  ///
  /// If this is 1 (the default), the text will not wrap, but will extend
  /// indefinitely instead.
  ///
  /// 如果此值为1（默认值），则文本不会换行，而是无限期扩展。
  ///
  /// If this is null, there is no limit to the number of lines.
  ///
  /// 如果为空，则不限制行数。
  ///
  /// When this is not null, the intrinsic height of the render object is the
  /// height of one line of text multiplied by this value. In other words, this
  /// also controls the height of the actual editing widget.
  ///
  /// 如果该值不为空，则呈现对象的固有高度是一行文本的高度乘以该值。
  /// 换句话说，这还控制实际编辑小部件的高度。
  int get maxLines => _maxLines;
  int _maxLines;

  /// The value may be null. If it is not null, then it must be greater than zero.
  ///
  /// 该值可能为空。如果不为空，则必须大于零。
  set maxLines(int value) {
    assert(value == null || value > 0);
    if (maxLines == value) return;
    _maxLines = value;
    markNeedsTextLayout();
  }

  /// {@macro flutter.widgets.editableText.minLines}
  int get minLines => _minLines;
  int _minLines;

  /// The value may be null. If it is not null, then it must be greater than zero.
  ///
  /// 该值可能为空。如果不为空，则必须大于零。
  set minLines(int value) {
    assert(value == null || value > 0);
    if (minLines == value) return;
    _minLines = value;
    markNeedsTextLayout();
  }

  /// {@macro flutter.widgets.editableText.expands}
  bool get expands => _expands;
  bool _expands;
  set expands(bool value) {
    assert(value != null);
    if (expands == value) return;
    _expands = value;
    markNeedsTextLayout();
  }

  /// The color to use when painting the selection.
  ///
  /// 绘制所选内容时使用的颜色。
  Color get selectionColor => _selectionColor;
  Color _selectionColor;
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  /// The number of font pixels for each logical pixel.
  ///
  /// 每个逻辑像素的字体像素数。
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  ///
  /// 例如，如果文本比例因子为1.5，则文本将比指定的字体大小大50%。
  double get textScaleFactor => _textPainter.textScaleFactor;
  set textScaleFactor(double value) {
    assert(value != null);
    if (_textPainter.textScaleFactor == value) return;
    _textPainter.textScaleFactor = value;
    markNeedsTextLayout();
  }

  List<ui.TextBox> _selectionRects;

  /// The region of text that is selected, if any.
  ///
  /// 选定的文本区域（如果有）。
  TextSelection get selection => _selection;
  TextSelection _selection;
  set selection(TextSelection value) {
    if (_selection == value) return;
    _selection = value;
    _selectionRects = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// The offset at which the text should be painted.
  ///
  /// 应在其上绘制文本的偏移量。
  ///
  /// If the text content is larger than the editable line itself, the editable
  /// line clips the text. This property controls which part of the text is
  /// visible by shifting the text by the given offset before clipping.
  ///
  /// 如果文本内容大于可编辑行本身，则可编辑行将剪裁文本。
  /// 此属性通过在剪切前按给定偏移量移动文本来控制文本的哪个部分可见。
  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    assert(value != null);
    if (_offset == value) return;
    if (attached) _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached) _offset.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  /// How thick the cursor will be.
  ///
  /// 光标的厚度。
  double get cursorWidth => _cursorWidth;
  double _cursorWidth = 1.0;
  set cursorWidth(double value) {
    if (_cursorWidth == value) return;
    _cursorWidth = value;
    markNeedsLayout();
  }

  /// {@template flutter.rendering.editable.paintCursorOnTop}
  /// If the cursor should be painted on top of the text or underneath it.
  ///
  /// 如果光标应该画在文本的顶部或下面。
  ///
  /// By default, the cursor should be painted on top for iOS platforms and
  /// underneath for Android platforms.
  ///
  /// 默认情况下，光标应该绘制在iOS平台的顶部和Android平台的底部。
  /// {@endtemplate}
  bool get paintCursorAboveText => _paintCursorOnTop;
  bool _paintCursorOnTop;
  set paintCursorAboveText(bool value) {
    if (_paintCursorOnTop == value) return;
    _paintCursorOnTop = value;
    markNeedsLayout();
  }

  /// {@template flutter.rendering.editable.cursorOffset}
  /// The offset that is used, in pixels, when painting the cursor on screen.
  ///
  /// 在屏幕上绘制光标时使用的偏移量（像素）。
  ///
  /// By default, the cursor position should be set to an offset of
  /// (-[cursorWidth] * 0.5, 0.0) on iOS platforms and (0, 0) on Android
  /// platforms. The origin from where the offset is applied to is the arbitrary
  /// location where the cursor ends up being rendered from by default.
  ///
  /// 默认情况下，在iOS平台上，光标位置应设置为偏移量 (-[cursorWidth] * 0.5, 0.0) ，
  /// 在Android平台上，应设置为偏移量 (0, 0) . 默认情况下，应用偏移的原点是光标最终从中呈现的任意位置。
  ///
  /// {@endtemplate}
  Offset get cursorOffset => _cursorOffset;
  Offset _cursorOffset;
  set cursorOffset(Offset value) {
    if (_cursorOffset == value) return;
    _cursorOffset = value;
    markNeedsLayout();
  }

  /// How rounded the corners of the cursor should be.
  ///
  /// 光标的角应该是多圆的。
  Radius get cursorRadius => _cursorRadius;
  Radius _cursorRadius;
  set cursorRadius(Radius value) {
    if (_cursorRadius == value) return;
    _cursorRadius = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of start selection handle.
  ///
  /// 开始选择句柄的[LayerLink]。
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of start handle.
  ///
  /// [RenderEditable] 负责计算此 [LayerLink] 的 [Offset], 它将用作起始句柄的 [CompositedTransformTarget].
  LayerLink get startHandleLayerLink => _startHandleLayerLink;
  LayerLink _startHandleLayerLink;
  set startHandleLayerLink(LayerLink value) {
    if (_startHandleLayerLink == value) return;
    _startHandleLayerLink = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of end selection handle.
  ///
  /// 结束选择句柄的[LayerLink]。
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of end handle.
  ///
  /// [RenderEditable] 负责计算此 [LayerLink] 的 [Offset], 它将用作结束句柄的 [CompositedTransformTarget].
  LayerLink get endHandleLayerLink => _endHandleLayerLink;
  LayerLink _endHandleLayerLink;
  set endHandleLayerLink(LayerLink value) {
    if (_endHandleLayerLink == value) return;
    _endHandleLayerLink = value;
    markNeedsPaint();
  }

  /// The padding applied to text field. Used to determine the bounds when
  /// moving the floating cursor.
  ///
  /// 应用于文本字段的填充。用于确定移动浮动光标时的边界。
  ///
  /// Defaults to a padding with left, top and right set to 4, bottom to 5.
  ///
  /// 默认设置为"左"、"上"和"右"分别设置为4 "下"为 5 的内边距。
  EdgeInsets get floatingCursorAddedMargin => _floatingCursorAddedMargin;
  EdgeInsets _floatingCursorAddedMargin;
  set floatingCursorAddedMargin(EdgeInsets value) {
    if (_floatingCursorAddedMargin == value) return;
    _floatingCursorAddedMargin = value;
    markNeedsPaint();
  }

  /// 浮动光标
  bool _floatingCursorOn = false;

  /// 浮动光标偏移
  Offset _floatingCursorOffset;

  /// 浮动光标文本位置
  TextPosition _floatingCursorTextPosition;

  /// If false, [describeSemanticsConfiguration] will not set the
  /// configuration's cursor motion or set selection callbacks.
  ///
  /// 如果为false，[describeSemanticsConfiguration]将不会设置配置的光标移动或设置选择回调。
  ///
  /// True by default.
  /// 默认情况下为 true.
  bool get enableInteractiveSelection => _enableInteractiveSelection;
  bool _enableInteractiveSelection;
  set enableInteractiveSelection(bool value) {
    if (_enableInteractiveSelection == value) return;
    _enableInteractiveSelection = value;
    markNeedsTextLayout();
    markNeedsSemanticsUpdate();
  }

  /// {@template flutter.rendering.editable.selectionEnabled}
  /// True if interactive selection is enabled based on the values of
  /// [enableInteractiveSelection] and [obscureText].
  ///
  /// 如果基于[enableInteractiveSelection]和[ObsureText]的值启用交互选择，则为True。
  ///
  /// By default [enableInteractiveSelection] is null, obscureText is false,
  /// and this method returns true.
  ///
  /// 默认情况下[enableInteractiveSelection]为空，obscureText为false，并且此方法返回true。
  ///
  /// If [enableInteractiveSelection] is null and obscureText is true, then this
  /// method returns false. This is the common case for password fields.
  ///
  /// 如果[enableInteractiveSelection]为空，而obscureText为真，
  /// 则此方法返回false。这是密码字段的常见情况。
  ///
  /// If [enableInteractiveSelection] is non-null then its value is returned. An
  /// app might set it to true to enable interactive selection for a password
  /// field, or to false to unconditionally disable interactive selection.
  ///
  /// 如果[enableInteractiveSelection]为非空，则返回其值。
  /// 应用程序可以将其设置为true以启用密码字段的交互选择，或将其设置为false以无条件禁用交互选择。
  /// {@endtemplate}
  bool get selectionEnabled {
    return enableInteractiveSelection ?? !obscureText;
  }

  /// The maximum amount the text is allowed to scroll.
  ///
  /// 允许文本滚动的最大量。
  ///
  /// This value is only valid after layout and can change as additional
  /// text is entered or removed in order to accommodate expanding when
  /// [expands] is set to true.
  ///
  /// 此值仅在布局后有效，并且可以随着输入或删除其他文本而更改，以便在[展开]设置为true时适应展开。
  double get maxScrollExtent => _maxScrollExtent;
  double _maxScrollExtent = 0;

  // 插入符号边距
  double get _caretMargin => _kCaretGap + cursorWidth;

  @override
  // 描述语义配置
  void describeSemanticsConfiguration(
      // 语义配置
      SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config
      ..value =
          obscureText ? obscuringCharacter * _plainText.length : _plainText
      ..isObscured = obscureText
      ..isMultiline = _isMultiline
      ..textDirection = textDirection
      ..isFocused = hasFocus
      ..isTextField = true
      ..isReadOnly = readOnly;

    // 聚焦 选择开启
    if (hasFocus && selectionEnabled)
      config.onSetSelection = _handleSetSelection;

    if (selectionEnabled && _selection?.isValid == true) {
      config.textSelection = _selection;
      // 在之前获取偏移
      if (_textPainter.getOffsetBefore(_selection.extentOffset) != null) {
        config
          // 按字向后移动光标
          ..onMoveCursorBackwardByWord = _handleMoveCursorBackwardByWord
          // 按字符向后移动光标
          ..onMoveCursorBackwardByCharacter =
              _handleMoveCursorBackwardByCharacter;
      }
      // 在之后获取偏移
      if (_textPainter.getOffsetAfter(_selection.extentOffset) != null) {
        config
          // 按字向前移动光标
          ..onMoveCursorForwardByWord = _handleMoveCursorForwardByWord
          // 按字符向前移动光标
          ..onMoveCursorForwardByCharacter =
              _handleMoveCursorForwardByCharacter;
      }
    }
  }

  /// 控制柄集选择
  void _handleSetSelection(TextSelection selection) {
    _handleSelectionChange(selection, SelectionChangedCause.keyboard);
  }

  /// 句柄按字符向前移动光标
  void _handleMoveCursorForwardByCharacter(bool extentSelection) {
    final int extentOffset =
        // 之后获取偏移量
        _textPainter.getOffsetAfter(_selection.extentOffset);
    if (extentOffset == null) return;
    final int baseOffset =
        !extentSelection ? extentOffset : _selection.baseOffset;
    _handleSelectionChange(
      TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
      SelectionChangedCause.keyboard,
    );
  }

  /// 按字符向后移动光标的句柄
  void _handleMoveCursorBackwardByCharacter(bool extentSelection) {
    final int extentOffset =
        _textPainter.getOffsetBefore(_selection.extentOffset);
    if (extentOffset == null) return;
    final int baseOffset =
        !extentSelection ? extentOffset : _selection.baseOffset;
    _handleSelectionChange(
      TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
      SelectionChangedCause.keyboard,
    );
  }

  /// 按字向前移动光标的句柄
  void _handleMoveCursorForwardByWord(bool extentSelection) {
    // 当前字
    final TextRange currentWord =
        _textPainter.getWordBoundary(_selection.extent);
    if (currentWord == null) return;
    // 下一个字
    final TextRange nextWord = _getNextWord(currentWord.end);
    if (nextWord == null) return;
    final int baseOffset =
        extentSelection ? _selection.baseOffset : nextWord.start;
    _handleSelectionChange(
      TextSelection(
        baseOffset: baseOffset,
        extentOffset: nextWord.start,
      ),
      SelectionChangedCause.keyboard,
    );
  }

  /// 按字向后移动光标的句柄
  void _handleMoveCursorBackwardByWord(bool extentSelection) {
    // 当前字
    final TextRange currentWord =
        _textPainter.getWordBoundary(_selection.extent);
    if (currentWord == null) return;
    // 上一个字
    final TextRange previousWord = _getPreviousWord(currentWord.start - 1);
    if (previousWord == null) return;
    // 偏移量
    final int baseOffset =
        extentSelection ? _selection.baseOffset : previousWord.start;
    _handleSelectionChange(
      TextSelection(
        baseOffset: baseOffset,
        extentOffset: previousWord.start,
      ),
      SelectionChangedCause.keyboard,
    );
  }

  // 获得下一个字
  TextRange _getNextWord(int offset) {
    while (true) {
      final TextRange range =
          _textPainter.getWordBoundary(TextPosition(offset: offset));
      if (range == null || !range.isValid || range.isCollapsed) return null;
      if (!_onlyWhitespace(range)) return range;
      offset = range.end;
    }
  }

  // 获得上一个字
  TextRange _getPreviousWord(int offset) {
    while (offset >= 0) {
      final TextRange range =
          _textPainter.getWordBoundary(TextPosition(offset: offset));
      if (range == null || !range.isValid || range.isCollapsed) return null;
      if (!_onlyWhitespace(range)) return range;
      offset = range.start - 1;
    }
    return null;
  }

  // Check if the given text range only contains white space or separator
  // characters.
  // 检查给定的文本区域是否只包含空格或分隔符。
  //
  // Includes newline characters from ASCII and separators from the
  // [unicode separator category](https://www.compart.com/en/unicode/category/Zs)
  // 包括来自ASCII的换行符和来自[unicode分隔符类别]的分隔符 (https://www.compart.com/en/unicode/category/Zs)
  // TODO(jonahwilliams): replace when we expose this ICU information.
  // TODO(jonahwilliams): 当我们暴露这个ICU信息时替换。
  // 只有空白
  bool _onlyWhitespace(TextRange range) {
    for (int i = range.start; i < range.end; i++) {
      final int codeUnit = text.codeUnitAt(i);
      if (!_isWhitespace(codeUnit)) {
        return false;
      }
    }
    return true;
  }

  @override
  // 贴上
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // 轻敲手势识别器
    _tap = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = _handleTapDown
      ..onTap = _handleTap;
    _longPress = LongPressGestureRecognizer(debugOwner: this)
      ..onLongPress = _handleLongPress;
    // 获得偏移量
    _offset.addListener(markNeedsPaint);
    // 显示光标
    _showCursor.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    // 释放资源
    _tap.dispose();
    _longPress.dispose();
    _offset.removeListener(markNeedsPaint);
    _showCursor.removeListener(markNeedsPaint);
    if (_listenerAttached) RawKeyboard.instance.removeListener(_handleKeyEvent);
    super.detach();
  }

  /// 是否 多行
  bool get _isMultiline => maxLines != 1;

  /// 视口轴
  Axis get _viewportAxis => _isMultiline ? Axis.vertical : Axis.horizontal;

  /// 绘制偏移
  Offset get _paintOffset {
    switch (_viewportAxis) {
      case Axis.horizontal:
        return Offset(-offset.pixels, 0.0);
      case Axis.vertical:
        return Offset(0.0, -offset.pixels);
    }
    return null;
  }

  /// 视区范围
  double get _viewportExtent {
    assert(hasSize);
    switch (_viewportAxis) {
      case Axis.horizontal:
        return size.width;
      case Axis.vertical:
        return size.height;
    }
    return null;
  }

  /// 获取最大滚动范围
  double _getMaxScrollExtent(Size contentSize) {
    assert(hasSize);
    switch (_viewportAxis) {
      case Axis.horizontal:
        return math.max(0.0, contentSize.width - size.width);
      case Axis.vertical:
        return math.max(0.0, contentSize.height - size.height);
    }
    return null;
  }

  /// We need to check the paint offset here because during animation, the start of
  /// the text may position outside the visible region even when the text fits.
  ///
  /// 我们需要检查这里的绘制偏移量，因为在动画过程中，即使文本适合，文本的开头也可能位于可见区域之外。
  bool get _hasVisualOverflow =>
      _maxScrollExtent > 0 || _paintOffset != Offset.zero;

  /// Returns the local coordinates of the endpoints of the given selection.
  ///
  /// 返回给定选择的终结点的本地坐标。
  ///
  /// If the selection is collapsed (and therefore occupies a single point), the
  /// returned list is of length one. Otherwise, the selection is not collapsed
  /// and the returned list is of length two. In this case, however, the two
  /// points might actually be co-located (e.g., because of a bidirectional
  /// selection that contains some text but whose ends meet in the middle).
  ///
  /// 如果选择被折叠（因此占用一个点），则返回的列表长度为1。否则，选择不会折叠，
  /// 返回的列表长度为2。然而，在这种情况下，这两个点实际上可能位于同一位置
  /// （例如，因为双向选择包含一些文本，但其两端在中间相交）。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [getLocalRectForCaret], which is the equivalent but for
  ///    a [TextPosition] rather than a [TextSelection].
  ///
  ///  * [getLocalRectForCaret]，这与 [TextPosition] 而不是 [TextSelection] 等价。
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection) {
    assert(constraints != null);
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);

    final Offset paintOffset = _paintOffset;

    if (selection.isCollapsed) {
      // TODO(mpcomplete): This doesn't work well at an RTL/LTR boundary.
      // TODO(mpcomplete): 这在RTL/LTR边界上不太适用。
      // 插入符号的偏移
      final Offset caretOffset =
          // getOffsetForCaret 获取插入符号的偏移量
          _textPainter.getOffsetForCaret(selection.extent, _caretPrototype);
      final Offset start =
          Offset(0.0, preferredLineHeight) + caretOffset + paintOffset;
      return <TextSelectionPoint>[TextSelectionPoint(start, null)];
    } else {
      final List<ui.TextBox> boxes =
          _textPainter.getBoxesForSelection(selection);
      final Offset start =
          Offset(boxes.first.start, boxes.first.bottom) + paintOffset;
      final Offset end =
          Offset(boxes.last.end, boxes.last.bottom) + paintOffset;
      // 文本选择点
      return <TextSelectionPoint>[
        TextSelectionPoint(start, boxes.first.direction),
        TextSelectionPoint(end, boxes.last.direction),
      ];
    }
  }

  /// Returns the position in the text for the given global coordinate.
  ///
  /// 返回给定全局坐标在文本中的位置。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [getLocalRectForCaret], which is the reverse operation, taking
  ///    a [TextPosition] and returning a [Rect].
  ///
  ///  * [getLocalRectForCaret]，这是反向操作，取[TextPosition]并返回[Rect]。
  ///
  ///  * [TextPainter.getPositionForOffset], which is the equivalent method
  ///    for a [TextPainter] object.
  ///
  ///  * [textpainer.getPositionForOffset]，这是[textpainer]对象的等效方法。
  // 返回给定全局坐标在文本中的位置。
  TextPosition getPositionForPoint(Offset globalPosition) {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    globalPosition += -_paintOffset;
    return _textPainter.getPositionForOffset(globalToLocal(globalPosition));
  }

  /// Returns the [Rect] in local coordinates for the caret at the given text
  /// position.
  ///
  /// 返回给定文本位置处插入符号的局部坐标[Rect]。
  ///
  /// See also:
  ///
  ///  * [getPositionForPoint], which is the reverse operation, taking
  ///    an [Offset] in global coordinates and returning a [TextPosition].
  ///
  ///  * [getPositionForPoint]，这是反向操作，在全局坐标中取[Offset]并返回[TextPosition]。
  ///
  ///  * [getEndpointsForSelection], which is the equivalent but for
  ///    a selection rather than a particular text position.
  ///
  ///  * [getEndpointsForSelection]，这是等效的，但用于选择而不是特定的文本位置。
  ///
  ///  * [TextPainter.getOffsetForCaret], the equivalent method for a
  ///    [TextPainter] object.
  ///
  ///  * [textpainer.getOffsetForCaret]，一个[textpainer]对象的等效方法。
  // 返回给定文本位置处插入符号的局部坐标[Rect]。
  Rect getLocalRectForCaret(TextPosition caretPosition) {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    final Offset caretOffset =
        _textPainter.getOffsetForCaret(caretPosition, _caretPrototype);
    // This rect is the same as _caretPrototype but without the vertical padding.
    // 此矩形与caretPrototype相同，但没有垂直填充。
    Rect rect = Rect.fromLTWH(0.0, 0.0, cursorWidth, preferredLineHeight)
        .shift(caretOffset + _paintOffset);
    // Add additional cursor offset (generally only if on iOS).
    // 添加额外的光标偏移量（通常仅在iOS上）。
    if (_cursorOffset != null) rect = rect.shift(_cursorOffset);

    return rect.shift(_getPixelPerfectCursorOffset(rect));
  }

  /// 计算最小中心宽度
  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText(maxWidth: double.infinity);
    return _textPainter.minIntrinsicWidth;
  }

  /// 计算最大固有宽度
  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutText(maxWidth: double.infinity);
    return _textPainter.maxIntrinsicWidth + cursorWidth;
  }

  /// An estimate of the height of a line in the text. See [TextPainter.preferredLineHeight].
  /// This does not required the layout to be updated.
  ///
  /// 对文本中一行高度的估计。请参阅[textpainer.preferredLineHeight]。这不需要更新布局。
  double get preferredLineHeight => _textPainter.preferredLineHeight;

  /// 首选高度
  double _preferredHeight(double width) {
    // Lock height to maxLines if needed.
    // 如果需要，将高度锁定到最大值。
    final bool lockedMax = maxLines != null && minLines == null;
    final bool lockedBoth = minLines != null && minLines == maxLines;
    final bool singleLine = maxLines == 1;
    if (singleLine || lockedMax || lockedBoth) {
      return preferredLineHeight * maxLines;
    }

    // Clamp height to minLines or maxLines if needed.
    // 根据需要将高度钳制到最小或最大。
    final bool minLimited = minLines != null && minLines > 1;
    final bool maxLimited = maxLines != null;
    if (minLimited || maxLimited) {
      _layoutText(maxWidth: width);
      if (minLimited && _textPainter.height < preferredLineHeight * minLines) {
        return preferredLineHeight * minLines;
      }
      if (maxLimited && _textPainter.height > preferredLineHeight * maxLines) {
        return preferredLineHeight * maxLines;
      }
    }

    // Set the height based on the content.
    // 根据内容设置高度。
    if (width == double.infinity) {
      final String text = _plainText;
      int lines = 1;
      for (int index = 0; index < text.length; index += 1) {
        if (text.codeUnitAt(index) == 0x0A) // count explicit line breaks
          lines += 1;
      }
      return preferredLineHeight * lines;
    }
    _layoutText(maxWidth: width);
    return math.max(preferredLineHeight, _textPainter.height);
  }

  /// 计算最小中心高度
  @override
  double computeMinIntrinsicHeight(double width) {
    return _preferredHeight(width);
  }

  /// 计算最大中心高度
  @override
  double computeMaxIntrinsicHeight(double width) {
    return _preferredHeight(width);
  }

  /// 计算到实际基线的距离
  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  /// 命中测试自身
  @override
  bool hitTestSelf(Offset position) => true;

  // 轻触
  TapGestureRecognizer _tap;
  // 长按
  LongPressGestureRecognizer _longPress;

  /// 触发事件
  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (ignorePointer) return;
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent && onSelectionChanged != null) {
      _tap.addPointer(event);
      _longPress.addPointer(event);
    }
  }

  /// 最后一个轻敲位置
  Offset _lastTapDownPosition;

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [TapGestureRecognizer.onTapDown]
  /// callback.
  ///
  /// 如果[ignorePointer]为false（默认值），则内部手势识别器的
  /// [TapGestureRecognizer.onTapDown]回调将调用此方法。
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to tap
  /// down events by calling this method.
  ///
  /// 当[ignorePointer]为true时，祖先小部件必须通过调用此方法来响应tap down事件。
  void handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
  }

  void _handleTapDown(TapDownDetails details) {
    assert(!ignorePointer);
    handleTapDown(details);
  }

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [TapGestureRecognizer.onTap]
  /// callback.
  ///
  /// 如果[ignorePointer]为false（默认值），
  /// 则内部手势识别器的[TapGestureRecognizer.onTap]回调将调用此方法。
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to tap
  /// events by calling this method.
  ///
  /// 当[ignorePointer]为true时，祖先小部件必须通过调用此方法来响应tap事件。
  void handleTap() {
    selectPosition(cause: SelectionChangedCause.tap);
  }

  void _handleTap() {
    assert(!ignorePointer);
    handleTap();
  }

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [DoubleTapGestureRecognizer.onDoubleTap]
  /// callback.
  ///
  /// 如果[ignorePointer]为false（默认值），则内部手势识别器的
  /// [DoubleTapGestureRecognizer.onDoubleTap]回调调用此方法。
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to double
  /// tap events by calling this method.
  ///
  /// 当 [ignorePointer] 为true时，祖先小部件必须通过调用此方法响应双击事件。
  void handleDoubleTap() {
    selectWord(cause: SelectionChangedCause.doubleTap);
  }

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [LongPressGestureRecognizer.onLongPress]
  /// callback.
  ///
  /// 如果[ignorePointer]为false（默认值），则内部手势识别器的[LongPressGestureRecognizer.onLongPress]回调调用此方法。
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to long
  /// press events by calling this method.
  ///
  /// 当[ignorePointer]为true时，祖先小部件必须通过调用此方法来响应长按事件。
  void handleLongPress() {
    selectWord(cause: SelectionChangedCause.longPress);
  }

  void _handleLongPress() {
    assert(!ignorePointer);
    handleLongPress();
  }

  /// Move selection to the location of the last tap down.
  ///
  /// 将所选内容移动到最后一次点击的位置。
  ///
  /// {@template flutter.rendering.editable.select}
  /// This method is mainly used to translate user inputs in global positions
  /// into a [TextSelection]. When used in conjunction with a [EditableText],
  /// the selection change is fed back into [TextEditingController.selection].
  ///
  /// 此方法主要用于将全局位置的用户输入转换为[文本选择]。当与[EditableText]一起使用时，
  /// 选择更改将反馈到[TextEditingController.selection]中。
  ///
  /// If you have a [TextEditingController], it's generally easier to
  /// programmatically manipulate its `value` or `selection` directly.
  ///
  /// 如果您有一个[TextEditingController]，通常更容易通过编程直接操作
  /// 其“value”或“selection”。
  /// {@endtemplate}
  void selectPosition({@required SelectionChangedCause cause}) {
    selectPositionAt(from: _lastTapDownPosition, cause: cause);
  }

  /// Select text between the global positions [from] and [to].
  ///
  /// 选择全局位置 [from] 和 [to] 之间的文本。
  void selectPositionAt(
      {@required Offset from,
      Offset to,
      @required SelectionChangedCause cause}) {
    assert(cause != null);
    assert(from != null);
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return;
    }
    final TextPosition fromPosition =
        _textPainter.getPositionForOffset(globalToLocal(from - _paintOffset));
    final TextPosition toPosition = to == null
        ? null
        : _textPainter.getPositionForOffset(globalToLocal(to - _paintOffset));

    int baseOffset = fromPosition.offset;
    int extentOffset = fromPosition.offset;
    if (toPosition != null) {
      baseOffset = math.min(fromPosition.offset, toPosition.offset);
      extentOffset = math.max(fromPosition.offset, toPosition.offset);
    }

    final TextSelection newSelection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: fromPosition.affinity,
    );
    // Call [onSelectionChanged] only when the selection actually changed.
    // 仅当所选内容实际更改时才调用[onSelectionChanged]。
    _handleSelectionChange(newSelection, cause);
  }

  /// Select a word around the location of the last tap down.
  ///
  /// 在最后一次点击的位置周围选择一个单词。
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWord({@required SelectionChangedCause cause}) {
    selectWordsInRange(from: _lastTapDownPosition, cause: cause);
  }

  /// Selects the set words of a paragraph in a given range of global positions.
  ///
  /// 在给定的全局位置范围内选择段落的集合字。
  ///
  /// The first and last endpoints of the selection will always be at the
  /// beginning and end of a word respectively.
  ///
  /// 选择的第一个和最后一个端点将始终分别位于单词的开头和结尾。
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordsInRange(
      {@required Offset from,
      Offset to,
      @required SelectionChangedCause cause}) {
    assert(cause != null);
    assert(from != null);
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return;
    }
    final TextPosition firstPosition =
        _textPainter.getPositionForOffset(globalToLocal(from - _paintOffset));
    final TextSelection firstWord = _selectWordAtOffset(firstPosition);
    final TextSelection lastWord = to == null
        ? firstWord
        : _selectWordAtOffset(_textPainter
            .getPositionForOffset(globalToLocal(to - _paintOffset)));

    _handleSelectionChange(
      TextSelection(
        baseOffset: firstWord.base.offset,
        extentOffset: lastWord.extent.offset,
        affinity: firstWord.affinity,
      ),
      cause,
    );
  }

  /// Move the selection to the beginning or end of a word.
  ///
  /// 将所选内容移到单词的开头或结尾。
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordEdge({@required SelectionChangedCause cause}) {
    assert(cause != null);
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    assert(_lastTapDownPosition != null);
    if (onSelectionChanged == null) {
      return;
    }
    final TextPosition position = _textPainter.getPositionForOffset(
        globalToLocal(_lastTapDownPosition - _paintOffset));
    final TextRange word = _textPainter.getWordBoundary(position);
    if (position.offset - word.start <= 1) {
      _handleSelectionChange(
        TextSelection.collapsed(
            offset: word.start, affinity: TextAffinity.downstream),
        cause,
      );
    } else {
      _handleSelectionChange(
        TextSelection.collapsed(
            offset: word.end, affinity: TextAffinity.upstream),
        cause,
      );
    }
  }

  /// 在偏移处选择单词
  TextSelection _selectWordAtOffset(TextPosition position) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    final TextRange word = _textPainter.getWordBoundary(position);
    // When long-pressing past the end of the text, we want a collapsed cursor.
    // 当长时间压缩文本的末尾，我们想要一个压缩曲线。
    if (position.offset >= word.end)
      return TextSelection.fromPosition(position);
    // If text is obscured, the entire sentence should be treated as one word.
    // 如果文本被遮挡，整个句子就应该当作一个词来处理。
    if (obscureText) {
      return TextSelection(baseOffset: 0, extentOffset: _plainText.length);
    }
    return TextSelection(baseOffset: word.start, extentOffset: word.end);
  }

  // 选择偏移处的行
  TextSelection _selectLineAtOffset(TextPosition position) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    final TextRange line = _textPainter.getLineBoundary(position);
    if (position.offset >= line.end)
      return TextSelection.fromPosition(position);
    // If text is obscured, the entire string should be treated as one line.
    // 如果文本被遮挡，则整个字符串应被视为一行。
    if (obscureText) {
      return TextSelection(baseOffset: 0, extentOffset: _plainText.length);
    }
    return TextSelection(baseOffset: line.start, extentOffset: line.end);
  }

  // 插入符号原型
  Rect _caretPrototype;

  // 布局文本
  void _layoutText({double minWidth = 0.0, double maxWidth = double.infinity}) {
    assert(maxWidth != null && minWidth != null);
    if (_textLayoutLastMaxWidth == maxWidth &&
        _textLayoutLastMinWidth == minWidth) return;
    final double availableMaxWidth = math.max(0.0, maxWidth - _caretMargin);
    final double availableMinWidth = math.min(minWidth, availableMaxWidth);
    final double textMaxWidth =
        _isMultiline ? availableMaxWidth : double.infinity;
    final double textMinWidth =
        forceLine ? availableMaxWidth : availableMinWidth;
    _textPainter.layout(
      minWidth: textMinWidth,
      maxWidth: textMaxWidth,
    );
    _textLayoutLastMinWidth = minWidth;
    _textLayoutLastMaxWidth = maxWidth;
  }

  // TODO(garyq): This is no longer producing the highest-fidelity caret
  // heights for Android, especially when non-alphabetic languages
  // are involved. The current implementation overrides the height set
  // here with the full measured height of the text on Android which looks
  // superior (subjectively and in terms of fidelity) in _paintCaret. We
  // should rework this properly to once again match the platform. The constant
  // _kCaretHeightOffset scales poorly for small font sizes.
  //
  // Android的高度，特别是涉及非字母语言时。当前的实现使用Android上文本的完整测量
  // 高度覆盖此处设置的高度，该高度在paintCaret中看起来更优越（主观上和逼真度方面）。
  // 我们应该适当地修改它，以再次匹配平台。常数 _kCaretHeightOffset 对于小字体的缩放效果很差。
  //
  /// On iOS, the cursor is taller than the cursor on Android. The height
  /// of the cursor for iOS is approximate and obtained through an eyeball
  /// comparison.
  ///
  /// 在iOS上，光标比Android上的光标高。IOS光标的高度是近似的，并通过眼球比较获得。
  Rect get _getCaretPrototype {
    assert(defaultTargetPlatform != null);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Rect.fromLTWH(0.0, 0.0, cursorWidth, preferredLineHeight + 2);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return Rect.fromLTWH(0.0, _kCaretHeightOffset, cursorWidth,
            preferredLineHeight - 2.0 * _kCaretHeightOffset);
    }
    return null;
  }

  // 执行布局
  @override
  void performLayout() {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    _caretPrototype = _getCaretPrototype;
    _selectionRects = null;
    // We grab _textPainter.size here because assigning to `size` on the next
    // line will trigger us to validate our intrinsic sizes, which will change
    // _textPainter's layout because the intrinsic size calculations are
    // destructive, which would mean we would get different results if we later
    // used properties on _textPainter in this method.
    //
    // 我们在这里获取“textpainer.size”，因为在下一行指定“size”将触发我们验证我们的内部大小，
    // 这将更改“textpainer”的布局，因为内部大小计算是破坏性的，
    // 这意味着如果我们以后在此方法中使用“textpainer”的属性，我们将得到不同的结果。
    //
    // Other _textPainter state like didExceedMaxLines will also be affected,
    // though we currently don't use those here.
    // 其他像 didExceedMaxLines 这样的 _textPainter 状态也会受到影响，尽管我们目前不在这里使用它们。
    //
    // See also RenderParagraph which has a similar issue.
    // 另请参见具有类似问题的RenderParagraph。
    final Size textPainterSize = _textPainter.size;
    final double width = forceLine
        ? constraints.maxWidth
        : constraints.constrainWidth(_textPainter.size.width + _caretMargin);
    size = Size(width,
        constraints.constrainHeight(_preferredHeight(constraints.maxWidth)));
    final Size contentSize =
        Size(textPainterSize.width + _caretMargin, textPainterSize.height);
    _maxScrollExtent = _getMaxScrollExtent(contentSize);
    offset.applyViewportDimension(_viewportExtent);
    offset.applyContentDimensions(0.0, _maxScrollExtent);
  }

  /// 获取像素完美光标偏移
  Offset _getPixelPerfectCursorOffset(Rect caretRect) {
    final Offset caretPosition = localToGlobal(caretRect.topLeft);
    final double pixelMultiple = 1.0 / _devicePixelRatio;
    final int quotientX = (caretPosition.dx / pixelMultiple).round();
    final int quotientY = (caretPosition.dy / pixelMultiple).round();
    final double pixelPerfectOffsetX =
        quotientX * pixelMultiple - caretPosition.dx;
    final double pixelPerfectOffsetY =
        quotientY * pixelMultiple - caretPosition.dy;
    return Offset(pixelPerfectOffsetX, pixelPerfectOffsetY);
  }

  // 绘制插入符号
  void _paintCaret(
      Canvas canvas, Offset effectiveOffset, TextPosition textPosition) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');

    // If the floating cursor is enabled, the text cursor's color is [backgroundCursorColor] while
    // the floating cursor's color is _cursorColor;
    // 如果启用了浮动光标，则文本光标的颜色为[背景光标颜色]，而浮动光标的颜色为“光标颜色”；
    final Paint paint = Paint()
      ..color = _floatingCursorOn ? backgroundCursorColor : _cursorColor;
    final Offset caretOffset =
        _textPainter.getOffsetForCaret(textPosition, _caretPrototype) +
            effectiveOffset;
    Rect caretRect = _caretPrototype.shift(caretOffset);
    if (_cursorOffset != null) caretRect = caretRect.shift(_cursorOffset);

    final double caretHeight =
        _textPainter.getFullHeightForCaret(textPosition, _caretPrototype);
    if (caretHeight != null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          final double heightDiff = caretHeight - caretRect.height;
          // Center the caret vertically along the text.
          // 沿文本垂直居中插入符号。
          caretRect = Rect.fromLTWH(
            caretRect.left,
            caretRect.top + heightDiff / 2,
            caretRect.width,
            caretRect.height,
          );
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // Override the height to take the full height of the glyph at the TextPosition
          // when not on iOS. iOS has special handling that creates a taller caret.
          // 重写高度以获取不在iOS上时文本位置处标志符号的完整高度。
          // iOS具有特殊的处理方式，可以创建更高的插入符号。
          // TODO(garyq): See the TODO for _getCaretPrototype.
          caretRect = Rect.fromLTWH(
            caretRect.left,
            caretRect.top - _kCaretHeightOffset,
            caretRect.width,
            caretHeight,
          );
          break;
      }
    }

    caretRect = caretRect.shift(_getPixelPerfectCursorOffset(caretRect));

    if (cursorRadius == null) {
      canvas.drawRect(caretRect, paint);
    } else {
      final RRect caretRRect = RRect.fromRectAndRadius(caretRect, cursorRadius);
      canvas.drawRRect(caretRRect, paint);
    }

    if (caretRect != _lastCaretRect) {
      _lastCaretRect = caretRect;
      if (onCaretChanged != null) onCaretChanged(caretRect);
    }
  }

  /// Sets the screen position of the floating cursor and the text position
  /// closest to the cursor.
  ///
  /// 设置浮动光标的屏幕位置和最接近光标的文本位置。
  void setFloatingCursor(FloatingCursorDragState state, Offset boundedOffset,
      TextPosition lastTextPosition,
      {double resetLerpValue}) {
    assert(state != null);
    assert(boundedOffset != null);
    assert(lastTextPosition != null);
    if (state == FloatingCursorDragState.Start) {
      _relativeOrigin = const Offset(0, 0);
      _previousOffset = null;
      _resetOriginOnBottom = false;
      _resetOriginOnTop = false;
      _resetOriginOnRight = false;
      _resetOriginOnBottom = false;
    }
    _floatingCursorOn = state != FloatingCursorDragState.End;
    _resetFloatingCursorAnimationValue = resetLerpValue;
    if (_floatingCursorOn) {
      _floatingCursorOffset = boundedOffset;
      _floatingCursorTextPosition = lastTextPosition;
    }
    markNeedsPaint();
  }

  /// 绘制浮动插入符号
  void _paintFloatingCaret(Canvas canvas, Offset effectiveOffset) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    assert(_floatingCursorOn);

    // We always want the floating cursor to render at full opacity.
    // 我们总是希望浮动光标以完全不透明度渲染。
    final Paint paint = Paint()..color = _cursorColor.withOpacity(0.75);

    double sizeAdjustmentX = _kFloatingCaretSizeIncrease.dx;
    double sizeAdjustmentY = _kFloatingCaretSizeIncrease.dy;

    if (_resetFloatingCursorAnimationValue != null) {
      sizeAdjustmentX =
          ui.lerpDouble(sizeAdjustmentX, 0, _resetFloatingCursorAnimationValue);
      sizeAdjustmentY =
          ui.lerpDouble(sizeAdjustmentY, 0, _resetFloatingCursorAnimationValue);
    }

    final Rect floatingCaretPrototype = Rect.fromLTRB(
      _caretPrototype.left - sizeAdjustmentX,
      _caretPrototype.top - sizeAdjustmentY,
      _caretPrototype.right + sizeAdjustmentX,
      _caretPrototype.bottom + sizeAdjustmentY,
    );

    final Rect caretRect = floatingCaretPrototype.shift(effectiveOffset);
    const Radius floatingCursorRadius = Radius.circular(_kFloatingCaretRadius);
    final RRect caretRRect =
        RRect.fromRectAndRadius(caretRect, floatingCursorRadius);
    canvas.drawRRect(caretRRect, paint);
  }

  // The relative origin in relation to the distance the user has theoretically
  // dragged the floating cursor offscreen. This value is used to account for the
  // difference in the rendering position and the raw offset value.
  // 相对于用户理论上将浮动光标拖离屏幕的距离的相对原点。
  // 此值用于解释渲染位置和原始偏移值之间的差异。
  Offset _relativeOrigin = const Offset(0, 0);
  Offset _previousOffset;
  bool _resetOriginOnLeft = false;
  bool _resetOriginOnRight = false;
  bool _resetOriginOnTop = false;
  bool _resetOriginOnBottom = false;
  double _resetFloatingCursorAnimationValue;

  /// Returns the position within the text field closest to the raw cursor offset.
  ///
  /// 返回文本字段中最接近原始光标偏移的位置。
  Offset calculateBoundedFloatingCursorOffset(Offset rawCursorOffset) {
    Offset deltaPosition = const Offset(0, 0);
    final double topBound = -floatingCursorAddedMargin.top;
    final double bottomBound = _textPainter.height -
        preferredLineHeight +
        floatingCursorAddedMargin.bottom;
    final double leftBound = -floatingCursorAddedMargin.left;
    final double rightBound =
        _textPainter.width + floatingCursorAddedMargin.right;

    if (_previousOffset != null)
      deltaPosition = rawCursorOffset - _previousOffset;

    // If the raw cursor offset has gone off an edge, we want to reset the relative
    // origin of the dragging when the user drags back into the field.
    // 如果原始光标偏移偏离了一条边，我们希望在用户拖动回字段时重置拖动的相对原点。
    if (_resetOriginOnLeft && deltaPosition.dx > 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - leftBound, _relativeOrigin.dy);
      _resetOriginOnLeft = false;
    } else if (_resetOriginOnRight && deltaPosition.dx < 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - rightBound, _relativeOrigin.dy);
      _resetOriginOnRight = false;
    }
    if (_resetOriginOnTop && deltaPosition.dy > 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - topBound);
      _resetOriginOnTop = false;
    } else if (_resetOriginOnBottom && deltaPosition.dy < 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - bottomBound);
      _resetOriginOnBottom = false;
    }

    final double currentX = rawCursorOffset.dx - _relativeOrigin.dx;
    final double currentY = rawCursorOffset.dy - _relativeOrigin.dy;
    final double adjustedX =
        math.min(math.max(currentX, leftBound), rightBound);
    final double adjustedY =
        math.min(math.max(currentY, topBound), bottomBound);
    final Offset adjustedOffset = Offset(adjustedX, adjustedY);

    if (currentX < leftBound && deltaPosition.dx < 0)
      _resetOriginOnLeft = true;
    else if (currentX > rightBound && deltaPosition.dx > 0)
      _resetOriginOnRight = true;
    if (currentY < topBound && deltaPosition.dy < 0)
      _resetOriginOnTop = true;
    else if (currentY > bottomBound && deltaPosition.dy > 0)
      _resetOriginOnBottom = true;

    _previousOffset = rawCursorOffset;

    return adjustedOffset;
  }

  /// 绘画 选择
  void _paintSelection(Canvas canvas, Offset effectiveOffset) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    assert(_selectionRects != null);
    final Paint paint = Paint()..color = _selectionColor;
    for (final ui.TextBox box in _selectionRects)
      canvas.drawRect(box.toRect().shift(effectiveOffset), paint);
  }

  /// 绘画 内容
  void _paintContents(PaintingContext context, Offset offset) {
    assert(
        _textLayoutLastMaxWidth == constraints.maxWidth &&
            _textLayoutLastMinWidth == constraints.minWidth,
        'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    final Offset effectiveOffset = offset + _paintOffset;

    bool showSelection = false;
    bool showCaret = false;

    if (_selection != null && !_floatingCursorOn) {
      if (_selection.isCollapsed && _showCursor.value && cursorColor != null)
        showCaret = true;
      else if (!_selection.isCollapsed && _selectionColor != null)
        showSelection = true;
      _updateSelectionExtentsVisibility(effectiveOffset);
    }

    if (showSelection) {
      _selectionRects ??= _textPainter.getBoxesForSelection(_selection);
      _paintSelection(context.canvas, effectiveOffset);
    }

    // On iOS, the cursor is painted over the text, on Android, it's painted
    // under it.
    // 在iOS上，光标画在文本上，在Android上，光标画在文本下。
    if (paintCursorAboveText)
      _textPainter.paint(context.canvas, effectiveOffset);

    if (showCaret)
      _paintCaret(context.canvas, effectiveOffset, _selection.extent);

    if (!paintCursorAboveText)
      _textPainter.paint(context.canvas, effectiveOffset);

    if (_floatingCursorOn) {
      if (_resetFloatingCursorAnimationValue == null)
        _paintCaret(
            context.canvas, effectiveOffset, _floatingCursorTextPosition);
      _paintFloatingCaret(context.canvas, _floatingCursorOffset);
    }
  }

  /// 绘制控制柄层
  void _paintHandleLayers(
      PaintingContext context, List<TextSelectionPoint> endpoints) {
    Offset startPoint = endpoints[0].point;
    startPoint = Offset(
      startPoint.dx.clamp(0.0, size.width) as double,
      startPoint.dy.clamp(0.0, size.height) as double,
    );
    context.pushLayer(
      LeaderLayer(link: startHandleLayerLink, offset: startPoint),
      super.paint,
      Offset.zero,
    );
    if (endpoints.length == 2) {
      Offset endPoint = endpoints[1].point;
      endPoint = Offset(
        endPoint.dx.clamp(0.0, size.width) as double,
        endPoint.dy.clamp(0.0, size.height) as double,
      );
      context.pushLayer(
        LeaderLayer(link: endHandleLayerLink, offset: endPoint),
        super.paint,
        Offset.zero,
      );
    }
  }

  // 绘制
  @override
  void paint(PaintingContext context, Offset offset) {
    _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (_hasVisualOverflow)
      context.pushClipRect(
          needsCompositing, offset, Offset.zero & size, _paintContents);
    else
      _paintContents(context, offset);
    _paintHandleLayers(context, getEndpointsForSelection(selection));
  }

  // 描述近似的 绘制 修剪
  @override
  Rect describeApproximatePaintClip(RenderObject child) =>
      _hasVisualOverflow ? Offset.zero & size : null;

  // 调试填充属性
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('cursorColor', cursorColor));
    properties.add(
        DiagnosticsProperty<ValueNotifier<bool>>('showCursor', showCursor));
    properties.add(IntProperty('maxLines', maxLines));
    properties.add(IntProperty('minLines', minLines));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(ColorProperty('selectionColor', selectionColor));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor));
    properties
        .add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(DiagnosticsProperty<TextSelection>('selection', selection));
    properties.add(DiagnosticsProperty<ViewportOffset>('offset', offset));
  }

  // 调试描述子项
  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      text.toDiagnosticsNode(
        name: 'text',
        style: DiagnosticsTreeStyle.transition,
      ),
    ];
  }
}
