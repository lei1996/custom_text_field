// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui hide TextStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;

// import 'automatic_keep_alive.dart';
// import 'basic.dart';
// import 'binding.dart';
// import 'constants.dart';
// import 'debug.dart';
// import 'focus_manager.dart';
// import 'focus_scope.dart';
// import 'framework.dart';
// import 'localizations.dart';
// import 'media_query.dart';
// import 'scroll_controller.dart';
// import 'scroll_physics.dart';
// import 'scrollable.dart';
// import 'text_selection.dart';
// import 'ticker_provider.dart';

export 'package:flutter/services.dart'
    show
        TextEditingValue,
        TextSelection,
        TextInputType,
        SmartQuotesType,
        SmartDashesType;
export 'package:flutter/rendering.dart' show SelectionChangedCause;

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
/// 选择更改 回调函数
typedef SelectionChangedCallback = void Function(
    TextSelection selection, SelectionChangedCause cause);

// The time it takes for the cursor to fade from fully opaque to fully
// transparent and vice versa. A full cursor blink, from transparent to opaque
// to transparent, is twice this duration.
// 光标从完全不透明变为完全透明所需的时间，反之亦然。
// 从透明到不透明再到透明的完整光标闪烁是此持续时间的两倍。
// Duration 持续时间
const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

// The time the cursor is static in opacity before animating to become
// transparent.
// 在动画变为透明之前，光标在不透明度中保持静止的时间。
// 中间停顿时间
const Duration _kCursorBlinkWaitForStart = Duration(milliseconds: 150);

// Number of cursor ticks during which the most recently entered character
// is shown in an obscured text field.
// 光标刻度的数目，在此期间，最近输入的字符显示在模糊文本字段中。
const int _kObscureShowLatestCharCursorTicks = 3;

/// A controller for an editable text field.
/// 可编辑文本字段的控制器。
///
/// Whenever the user modifies a text field with an associated
/// [TextEditingController], the text field updates [value] and the controller
/// notifies its listeners. Listeners can then read the [text] and [selection]
/// properties to learn what the user has typed or how the selection has been
/// updated.
/// 每当用户使用关联的[TextEditingController]修改文本字段时，
/// 文本字段会更新[value]，控制器会通知其侦听器。
/// 然后，监听器可以读取[text]和[selection]属性，以了解用户键入的内容或更新选择的方式。
///
/// Similarly, if you modify the [text] or [selection] properties, the text
/// field will be notified and will update itself appropriately.
/// 类似地，如果修改[text]或[selection]属性，
/// 文本字段将得到通知，并将相应地更新自身。
///
/// A [TextEditingController] can also be used to provide an initial value for a
/// text field. If you build a text field with a controller that already has
/// [text], the text field will use that text as its initial value.
/// [TextEditingController]也可用于为文本字段提供初始值。
/// 如果使用已具有[文本]的控制器生成文本字段，
/// 则文本字段将使用该文本作为其初始值。
///
/// The [text] or [selection] properties can be set from within a listener
/// added to this controller. If both properties need to be changed then the
/// controller's [value] should be set instead.
/// 可以从添加到此控制器的侦听器中设置[文本]或[选择]属性。
/// 如果两个属性都需要更改，则应改为设置控制器的[值]。
///
/// Remember to [dispose] of the [TextEditingController] when it is no longer needed.
/// This will ensure we discard any resources used by the object.
/// {@tool sample --template=stateful_widget_material}
/// This example creates a [TextField] with a [TextEditingController] whose
/// change listener forces the entered text to be lower case and keeps the
/// cursor at the end of the input.
/// 当不再需要[TextEditingController]时，请记住[dispose]。
/// 这将确保丢弃该对象使用的任何资源。
/// {@tool sample--template=stateful_widget_material}这个例子创建了
/// 一个带有[textedittingcontroller]的[TextField]，
/// 其更改侦听器强制输入的文本为小写，并将光标保持在输入的末尾。
///
/// ```dart
/// final _controller = TextEditingController();
///
/// void initState() {
///   _controller.addListener(() {
///     final text = _controller.text.toLowerCase();
///     _controller.value = _controller.value.copyWith(
///       text: text,
///       selection: TextSelection(baseOffset: text.length, extentOffset: text.length),
///       composing: TextRange.empty,
///     );
///   });
///   super.initState();
/// }
///
/// void dispose() {
///   _controller.dispose();
///   super.dispose();
/// }
///
/// Widget build(BuildContext context) {
///   return Scaffold(
///     body: Container(
///      alignment: Alignment.center,
///       padding: const EdgeInsets.all(6),
///       child: TextFormField(
///         controller: _controller,
///         decoration: InputDecoration(border: OutlineInputBorder()),
///       ),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [TextField], which is a Material Design text field that can be controlled
///    with a [TextEditingController].
///  * [EditableText], which is a raw region of editable text that can be
///    controlled with a [TextEditingController].
///  * Learn how to use a [TextEditingController] in one of our [cookbook recipe]s.(https://flutter.dev/docs/cookbook/forms/text-field-changes#2-use-a-texteditingcontroller)
///  *[text field]，这是一个可以用[TextEditingController]控制的材料设计文本字段。
///  *[EditableText]，这是可编辑文本的原始区域，可以用[TextEditingController]控制。
///  *了解如何在我们的[食谱]中使用[文本编辑控制器]（https://flutter.dev/docs/cookbook/forms/text field changes#2-use-a-textedittingcontroller）

// 文本编辑控制器  继承了 ValueNotifier泛型 里面传入 TextEditingValue
class TextEditingController extends ValueNotifier<TextEditingValue> {
  /// Creates a controller for an editable text field.
  /// 为可编辑文本字段创建控制器。
  ///
  /// This constructor treats a null [text] argument as if it were the empty
  /// string.
  /// 此构造函数将空[文本]参数视为空字符串。
  TextEditingController({String text})
      : super(text == null
            ? TextEditingValue.empty
            : TextEditingValue(text: text));

  /// Creates a controller for an editable text field from an initial [TextEditingValue].
  /// 从初始[TextEditingValue]为可编辑文本字段创建控制器。
  ///
  /// This constructor treats a null [value] argument as if it were
  /// [TextEditingValue.empty].
  /// 此构造函数将空的[value]参数视为[TextEditingValue.empty]。
  TextEditingController.fromValue(TextEditingValue value)
      : super(value ?? TextEditingValue.empty);

  /// The current string the user is editing.
  /// 用户正在编辑的当前字符串。
  String get text => value.text;

  /// Setting this will notify all the listeners of this [TextEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  /// 设置此项将通知此[TextEditingController]的所有侦听器它们需要更新（它调用[notifyListeners]）。
  /// 因此，该值只应在帧之间设置，例如响应用户操作，而不应在构建、布局或绘制阶段设置。
  ///
  /// This property can be set from a listener added to this
  /// [TextEditingController]; however, one should not also set [selection]
  /// in a separate statement. To change both the [text] and the [selection]
  /// change the controller's [value].
  /// 此属性可以从添加到此[TextEditingController]的侦听器设置；
  /// 但是，也不应在单独的语句中设置[selection]。
  /// 要同时更改[文本]和[选择]，请更改控制器的[值]。
  set text(String newText) {
    value = value.copyWith(
      text: newText,
      selection: const TextSelection.collapsed(offset: -1),
      composing: TextRange.empty,
    );
  }

  /// Builds [TextSpan] from current editing value.
  /// 从当前编辑值生成[TextSpan]。
  ///
  /// By default makes text in composing range appear as underlined.
  /// Descendants can override this method to customize appearance of text.
  /// 默认情况下，使组成范围内的文本显示为下划线。
  /// 子体可以重写此方法以自定义文本的外观。
  TextSpan buildTextSpan({TextStyle style, bool withComposing}) {
    if (!value.composing.isValid || !withComposing) {
      return TextSpan(style: style, text: text);
    }
    final TextStyle composingStyle = style.merge(
      // underline: 下划线
      const TextStyle(decoration: TextDecoration.underline),
    );
    return TextSpan(style: style, children: <TextSpan>[
      // 之前的文本
      TextSpan(text: value.composing.textBefore(value.text)),
      // 文本内部
      TextSpan(
        style: composingStyle,
        text: value.composing.textInside(value.text),
      ),
      // 之后的文本
      TextSpan(text: value.composing.textAfter(value.text)),
    ]);
  }

  /// The currently selected [text].
  /// 当前选定的[文本]。
  ///
  /// If the selection is collapsed, then this property gives the offset of the
  /// cursor within the text.
  /// 如果所选内容已折叠，则此属性提供文本中光标的偏移量。
  TextSelection get selection => value.selection;

  /// Setting this will notify all the listeners of this [TextEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  /// 设置此项将通知此[TextEditingController]的所有侦听器它们需要更新（它调用[notifyListeners]）。
  /// 因此，该值只应在帧之间设置，例如响应用户操作，而不应在构建、布局或绘制阶段设置。
  ///
  /// This property can be set from a listener added to this
  /// [TextEditingController]; however, one should not also set [text]
  /// in a separate statement. To change both the [text] and the [selection]
  /// change the controller's [value].
  /// 可以从添加到此[TextEditingController]的侦听器设置此属性；
  /// 但是，也不应在单独的语句中设置[text]。要同时更改[文本]和[选择]，请更改控制器的[值]。
  set selection(TextSelection newSelection) {
    if (newSelection.start > text.length || newSelection.end > text.length)
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('invalid text selection: $newSelection')
      ]);
    value = value.copyWith(selection: newSelection, composing: TextRange.empty);
  }

  /// Set the [value] to empty.
  /// 将[值]设置为空。
  ///
  /// After calling this function, [text] will be the empty string and the
  /// selection will be invalid.
  /// 调用此函数后，[文本]将是空字符串，所选内容将无效。
  ///
  /// Calling this will notify all the listeners of this [TextEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  /// 调用此函数将通知此[TextEditingController]的所有侦听器它们需要更新（它调用[notifyListeners]）。
  /// 因此，此方法只应在帧之间调用，例如响应用户操作，而不应在构建、布局或绘制阶段调用。
  void clear() {
    value = TextEditingValue.empty;
  }

  /// Set the composing region to an empty range.
  /// 将合成区域设置为空范围。
  ///
  /// The composing region is the range of text that is still being composed.
  /// Calling this function indicates that the user is done composing that
  /// region.
  /// 合成区域是仍在合成的文本范围。调用此函数表示用户已完成该区域的组合。
  ///
  /// Calling this will notify all the listeners of this [TextEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  /// 调用此函数将通知此[TextEditingController]的所有侦听器它们需要更新（它调用[notifyListeners]）。
  /// 因此，此方法只应在帧之间调用，例如响应用户操作，而不应在构建、布局或绘制阶段调用。
  void clearComposing() {
    value = value.copyWith(composing: TextRange.empty);
  }
}

/// Toolbar configuration for [EditableText].
/// [EditableText]的工具栏配置。
///
/// Toolbar is a context menu that will show up when user right click or long
/// press the [EditableText]. It includes several options: cut, copy, paste,
/// and select all.
/// 工具栏是一个上下文菜单，当用户右键单击或长按[EditableText]时将显示。
/// 它包括几个选项：剪切、复制、粘贴和全选。
///
/// [EditableText] and its derived widgets have their own default [ToolbarOptions].
/// Create a custom [ToolbarOptions] if you want explicit control over the toolbar
/// option.
/// [可编辑文本]及其派生的小部件有自己的默认[工具栏选项]。
/// 如果您想要对工具栏选项进行显式控制，请创建自定义的[ToolbarOptions]。
class ToolbarOptions {
  /// Create a toolbar configuration with given options.
  /// 使用给定的选项创建工具栏配置。
  ///
  /// All options default to false if they are not explicitly set.
  /// 如果未显式设置所有选项，则默认为false。
  const ToolbarOptions({
    this.copy = false,
    this.cut = false,
    this.paste = false,
    this.selectAll = false,
  })  : assert(copy != null),
        assert(cut != null),
        assert(paste != null),
        assert(selectAll != null);

  /// Whether to show copy option in toolbar.
  /// 是否在工具栏中显示复制选项。
  ///
  /// Defaults to false. Must not be null.
  /// 默认为false。不能为空。
  final bool copy;

  /// Whether to show cut option in toolbar.
  /// 是否在工具栏中显示剪切选项。
  ///
  /// If [EditableText.readOnly] is set to true, cut will be disabled regardless.
  /// 如果[EditableText.readOnly]设置为true，则无论如何都将禁用剪切。
  ///
  /// Defaults to false. Must not be null.
  /// 默认为false。不能为空。
  final bool cut;

  /// Whether to show paste option in toolbar.
  /// 是否在工具栏中显示粘贴选项。
  ///
  /// If [EditableText.readOnly] is set to true, paste will be disabled regardless.
  /// 如果[EditableText.readOnly]设置为true，粘贴将被禁用。
  ///
  /// Defaults to false. Must not be null.
  /// 默认为false。不能为空。
  final bool paste;

  /// Whether to show select all option in toolbar.
  /// 是否在工具栏中显示全选选项。
  ///
  /// Defaults to false. Must not be null.
  /// 默认为false。不能为空。
  final bool selectAll;
}

/// A basic text input field.
/// 基本文本输入字段。
///
/// This widget interacts with the [TextInput] service to let the user edit the
/// text it contains. It also provides scrolling, selection, and cursor
/// movement. This widget does not provide any focus management (e.g.,
/// tap-to-focus).
/// 这个小部件与[TextInput]服务交互，让用户编辑它包含的文本。
/// 它还提供滚动、选择和光标移动。此小部件不提供任何焦点管理（例如，点击焦点）。
///
/// ## Input Actions
/// ## 输入操作
///
/// A [TextInputAction] can be provided to customize the appearance of the
/// action button on the soft keyboard for Android and iOS. The default action
/// is [TextInputAction.done].
/// 可以提供[textinputation]来定制Android和iOS软键盘上操作按钮的外观。
/// 默认操作是[textinputation.done]。
///
/// Many [TextInputAction]s are common between Android and iOS. However, if an
/// [inputAction] is provided that is not supported by the current
/// platform in debug mode, an error will be thrown when the corresponding
/// EditableText receives focus. For example, providing iOS's "emergencyCall"
/// action when running on an Android device will result in an error when in
/// debug mode. In release mode, incompatible [TextInputAction]s are replaced
/// either with "unspecified" on Android, or "default" on iOS. Appropriate
/// [inputAction]s can be chosen by checking the current platform and then
/// selecting the appropriate action.
/// 许多[textinputation]在Android和iOS之间很常见。
/// 但是，如果在调试模式下提供了当前平台不支持的[inputation]，则当相应的EditableText收到焦点时将引发错误。
/// 例如，在Android设备上运行时提供iOS的“emergencyccall”操作将在调试模式下导致错误。
/// 在发布模式下，不兼容的[textinputation]在Android上被替换为“unspecified”，在iOS上被替换为“default”。
/// 通过检查当前平台，然后选择适当的操作，可以选择适当的[inputation]。
///
/// ## Lifecycle
/// ## 生命周期
///
/// Upon completion of editing, like pressing the "done" button on the keyboard,
/// two actions take place:
/// 编辑完成后，如按键盘上的“完成”按钮，将执行两个操作：
///
///   1st: Editing is finalized. The default behavior of this step includes
///   an invocation of [onChanged]. That default behavior can be overridden.
///   See [onEditingComplete] for details.
///   第一：编辑完成。此步骤的默认行为包括调用[onChanged]。
///   默认行为可以被重写。有关详细信息，请参阅[onEditingComplete]。
///
///   2nd: [onSubmitted] is invoked with the user's input value.
///   第二个：[onSubmitted]是用用户的输入值调用的。
///
/// [onSubmitted] can be used to manually move focus to another input widget
/// when a user finishes with the currently focused input widget.
/// [onSubmitted]可用于在用户完成当前聚焦的输入小部件时手动将焦点移动到另一个输入小部件。
///
/// Rather than using this widget directly, consider using [TextField], which
/// is a full-featured, material-design text input field with placeholder text,
/// labels, and [Form] integration.
/// 与其直接使用这个小部件，不如考虑使用[text field]，
/// 它是一个功能齐全的、具有占位符文本、标签和[Form]集成的材料设计文本输入字段。
///
/// ## Gesture Events Handling
/// ## 手势事件处理
///
/// This widget provides rudimentary, platform-agnostic gesture handling for
/// user actions such as tapping, long-pressing and scrolling when
/// [rendererIgnoresPointer] is false (false by default). To tightly conform
/// to the platform behavior with respect to input gestures in text fields, use
/// [TextField] or [CupertinoTextField]. For custom selection behavior, call
/// methods such as [RenderEditable.selectPosition],
/// [RenderEditable.selectWord], etc. programmatically.
/// 当[renderignorespointer]为false（默认为false）时，
/// 此小部件为用户操作（如轻敲、长按和滚动）提供了基本的、与平台无关的手势处理。
/// 要严格遵守与文本字段中的输入手势相关的平台行为，请使用[TextField]或[CupertinoTextField]。
/// 对于自定义选择行为，请调用方法，例如[RenderEditable.selectPosition]，[可编辑。选择字]等。
///
/// See also:
/// 另见：
///
///  * [TextField], which is a full-featured, material-design text input field
///    with placeholder text, labels, and [Form] integration.
///  * [TextField]，这是一个功能齐全的材料设计文本输入字段，包含占位符文本、标签和[Form]集成。
class EditableText extends StatefulWidget {
  /// Creates a basic text input control.
  /// 创建基本文本输入控件。
  ///
  /// The [maxLines] property can be set to null to remove the restriction on
  /// the number of lines. By default, it is one, meaning this is a single-line
  /// text field. [maxLines] must be null or greater than zero.
  /// [maxLines]属性可以设置为空，以删除对行数的限制。
  /// 默认情况下，它是一个，这意味着这是一个单行文本字段。[maxLines]必须为空或大于零。
  ///
  /// If [keyboardType] is not set or is null, it will default to
  /// [TextInputType.text] unless [maxLines] is greater than one, when it will
  /// default to [TextInputType.multiline].
  /// 如果[keyboardType]未设置或为空，则默认为[TextInputType.text]除非[maxLines]大于1，
  /// 否则默认为[TextInputType.multiline]。
  ///
  /// The text cursor is not shown if [showCursor] is false or if [showCursor]
  /// is null (the default) and [readOnly] is true.
  /// 如果[showCursor]为false或[showCursor]为null（默认值）且[readOnly]为true，则不显示文本光标。
  ///
  /// The [controller], [focusNode], [obscureText], [autocorrect], [autofocus],
  /// [showSelectionHandles], [enableInteractiveSelection], [forceLine],
  /// [style], [cursorColor], [cursorOpacityAnimates],[backgroundCursorColor],
  /// [enableSuggestions], [paintCursorAboveText], [textAlign],
  /// [dragStartBehavior], [scrollPadding], [dragStartBehavior],
  /// [toolbarOptions], [rendererIgnoresPointer], and [readOnly] arguments must
  /// not be null.
  /// [控制器]，[焦点模式]，[模糊文本]，[自动更正]，[自动聚焦]，[显示选择句柄]，
  /// [启用交互选择]，[强制线]，[样式]，[光标颜色]，[光标容量动画]，[背景光标颜色]，
  /// [启用建议]，[paintCursorAboveText]，[文本对齐]，[dragStartBehavior]，[滚动填充]，
  /// [dragStartBehavior]，[工具栏选项]、[renderignorespoint]和[只读]参数不能为空。
  EditableText({
    Key key,
    // 控制器
    @required this.controller,
    // 聚焦节点
    @required this.focusNode,
    // 只读
    this.readOnly = false,
    // 模糊文本
    this.obscureText = false,
    // 自动校正
    this.autocorrect = true,
    // 智能数据类型
    SmartDashesType smartDashesType,
    // 智能引号类型
    SmartQuotesType smartQuotesType,
    // 开启建议
    this.enableSuggestions = true,
    // 样式
    @required this.style,
    // 结构样式
    StrutStyle strutStyle,
    // 光标颜色
    @required this.cursorColor,
    // 背景光标颜色
    @required this.backgroundCursorColor,
    // 文本对齐
    this.textAlign = TextAlign.start,
    // 文本方向
    this.textDirection,
    // 本地
    this.locale,
    // 文本比例
    this.textScaleFactor,
    // 最大行
    this.maxLines = 1,
    // 最小行
    this.minLines,
    // 扩展
    this.expands = false,
    // 强制线
    this.forceLine = true,
    // 文本宽度
    this.textWidthBasis = TextWidthBasis.parent,
    // 自动聚焦
    this.autofocus = false,
    // 显示光标
    bool showCursor,
    // 显示选择句柄
    this.showSelectionHandles = false,
    // 选择 颜色
    this.selectionColor,
    // 选择控件
    this.selectionControls,
    // 键盘类型
    TextInputType keyboardType,
    // 文本输入操作
    this.textInputAction,
    // 文本大写
    this.textCapitalization = TextCapitalization.none,
    // 更改时
    this.onChanged,
    // 编辑完成时
    this.onEditingComplete,
    // 提交
    this.onSubmitted,
    // 选择更改时
    this.onSelectionChanged,
    // 点击选择手柄
    this.onSelectionHandleTapped,
    // 输入格式化程序
    List<TextInputFormatter> inputFormatters,
    // 渲染器忽略指针
    this.rendererIgnoresPointer = false,
    // 光标宽度
    this.cursorWidth = 2.0,
    // 光标半径
    this.cursorRadius,
    // 光标不透明度动画
    this.cursorOpacityAnimates = false,
    // 光标 偏移量
    this.cursorOffset,
    // 在文本上方绘制光标
    this.paintCursorAboveText = false,
    // 滚动条内边距
    this.scrollPadding = const EdgeInsets.all(20.0),
    // 键盘外观
    this.keyboardAppearance = Brightness.light,
    // 拖动开始行为
    this.dragStartBehavior = DragStartBehavior.start,
    // 启用交互式选择
    this.enableInteractiveSelection = true,
    // 滚动条控制器
    this.scrollController,
    // 滚动条 物理行为
    this.scrollPhysics,
    // 工具栏 选项
    this.toolbarOptions = const ToolbarOptions(
      copy: true,
      cut: true,
      paste: true,
      selectAll: true,
    ),
  })  : assert(controller != null),
        assert(focusNode != null),
        assert(obscureText != null),
        assert(autocorrect != null),
        smartDashesType = smartDashesType ??
            (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ??
            (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        assert(enableSuggestions != null),
        assert(showSelectionHandles != null),
        assert(enableInteractiveSelection != null),
        assert(readOnly != null),
        assert(forceLine != null),
        assert(style != null),
        assert(cursorColor != null),
        assert(cursorOpacityAnimates != null),
        assert(paintCursorAboveText != null),
        assert(backgroundCursorColor != null),
        assert(textAlign != null),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          'minLines can\'t be greater than maxLines',
        ),
        assert(expands != null),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1,
            'Obscured fields cannot be multiline.'),
        assert(autofocus != null),
        assert(rendererIgnoresPointer != null),
        assert(scrollPadding != null),
        assert(dragStartBehavior != null),
        assert(toolbarOptions != null),
        _strutStyle = strutStyle,
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        inputFormatters = maxLines == 1
            ? <TextInputFormatter>[
                BlacklistingTextInputFormatter.singleLineFormatter,
                ...inputFormatters ??
                    const Iterable<TextInputFormatter>.empty(),
              ]
            : inputFormatters,
        showCursor = showCursor ?? !readOnly,
        super(key: key);

  /// Controls the text being edited.
  /// 控制正在编辑的文本。
  final TextEditingController controller;

  /// Controls whether this widget has keyboard focus.
  /// 控制此小部件是否具有键盘焦点。
  final FocusNode focusNode;

  /// {@template flutter.widgets.editableText.obscureText}
  /// Whether to hide the text being edited (e.g., for passwords).
  /// {@template flutter.widgets.editableText.obseretext}
  /// 是否隐藏正在编辑的文本（例如，用于密码）。
  ///
  /// When this is set to true, all the characters in the text field are
  /// replaced by U+2022 BULLET characters (•).
  /// 当设置为true时，文本字段中的所有字符都将替换为U+2022项目符号字符（•）。
  ///
  /// Defaults to false. Cannot be null.
  /// {@endtemplate}
  /// 默认为false。不能为空。{@endtemplate}
  final bool obscureText;

  /// {@macro flutter.widgets.text.DefaultTextStyle.textWidthBasis}
  /// 文本宽度
  final TextWidthBasis textWidthBasis;

  /// {@template flutter.widgets.editableText.readOnly}
  /// Whether the text can be changed.
  /// {@template flutter.widgets.editableText.readOnly}
  /// 是否可以更改文本。
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  /// 如果设置为true，则无法通过任何快捷方式或键盘操作修改文本。文本仍然可以选择。
  ///
  /// Defaults to false. Must not be null.
  /// {@endtemplate}
  /// 默认为false。不能为空。{@endtemplate}
  final bool readOnly;

  /// Whether the text will take the full width regardless of the text width.
  /// 无论文本宽度如何，文本是否采用全宽度。
  ///
  /// When this is set to false, the width will be based on text width, which
  /// will also be affected by [textWidthBasis].
  /// 当设置为false时，宽度将基于文本宽度，这也会受到[textWidthBasis]的影响。
  ///
  /// Defaults to true. Must not be null.
  /// 默认为true。不能为空。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [textWidthBasis], which controls the calculation of text width.
  ///  * [textWidthBasis]，控制文本宽度的计算。
  final bool forceLine;

  /// Configuration of toolbar options.
  /// 工具栏选项的配置。
  ///
  /// By default, all options are enabled. If [readOnly] is true,
  /// paste and cut will be disabled regardless.
  /// 默认情况下，启用所有选项。如果[只读]为真，粘贴和剪切将被禁用。
  final ToolbarOptions toolbarOptions;

  /// Whether to show selection handles.
  /// 是否显示选择手柄。
  ///
  /// When a selection is active, there will be two handles at each side of
  /// boundary, or one handle if the selection is collapsed. The handles can be
  /// dragged to adjust the selection.
  /// 当选择处于活动状态时，边界的每一侧将有两个控制柄，
  /// 如果选择已折叠，则有一个控制柄。可以拖动控制柄来调整选择。
  ///
  /// See also:
  /// 另见:
  ///
  ///  * [showCursor], which controls the visibility of the cursor..
  ///  * [显示光标]，它控制光标的可见性。
  final bool showSelectionHandles;

  /// {@template flutter.widgets.editableText.showCursor}
  /// Whether to show cursor.
  /// 是否显示光标。
  ///
  /// The cursor refers to the blinking caret when the [EditableText] is focused.
  /// 当[可编辑文本]聚焦时，光标指的是闪烁的插入符号。
  /// {@endtemplate}
  ///
  /// See also:
  /// 另见:
  ///
  ///  * [showSelectionHandles], which controls the visibility of the selection handles.
  ///  * [showSelectionHandles]，用于控制选择句柄的可见性。
  final bool showCursor;

  /// {@template flutter.widgets.editableText.autocorrect}
  /// Whether to enable autocorrection.
  /// 是否启用自动更正。
  ///
  /// Defaults to true. Cannot be null.
  /// 默认为true。不能为空。
  /// {@endtemplate}
  final bool autocorrect;

  /// {@macro flutter.services.textInput.smartDashesType}
  /// 智能数据类型
  final SmartDashesType smartDashesType;

  /// {@macro flutter.services.textInput.smartQuotesType}
  /// 智能引号类型
  final SmartQuotesType smartQuotesType;

  /// {@macro flutter.services.textInput.enableSuggestions}
  /// 开启建议
  final bool enableSuggestions;

  /// The text style to use for the editable text.
  /// 用于可编辑文本的文本样式。
  final TextStyle style;

  /// {@template flutter.widgets.editableText.strutStyle}
  /// The strut style used for the vertical layout.
  /// 用于垂直布局的支柱样式。
  ///
  /// [StrutStyle] is used to establish a predictable vertical layout.
  /// Since fonts may vary depending on user input and due to font
  /// fallback, [StrutStyle.forceStrutHeight] is enabled by default
  /// to lock all lines to the height of the base [TextStyle], provided by
  /// [style]. This ensures the typed text fits within the allotted space.
  /// [StrutStyle]用于建立可预测的垂直布局。由于字体可能因用户输入和字体回退而变化，
  /// [StrutStyle.forceStrutHeight]默认情况下启用，
  /// 以将所有行锁定到[style]提供的底部[TextStyle]的高度。
  /// 这样可以确保键入的文本适合分配的空间。
  ///
  /// If null, the strut used will is inherit values from the [style] and will
  /// have [StrutStyle.forceStrutHeight] set to true. When no [style] is
  /// passed, the theme's [TextStyle] will be used to generate [strutStyle]
  /// instead.
  /// 如果为空，则使用的支柱将继承[style]的值，并将[StrutStyle.forceStrutHeight]设置为true。
  /// 当没有[style]被传递时，主题的[TextStyle]将被用来生成[strutStyle]。
  ///
  /// To disable strut-based vertical alignment and allow dynamic vertical
  /// layout based on the glyphs typed, use [StrutStyle.disabled].
  /// 要禁用基于支柱的垂直对齐并允许基于键入的图示符的动态垂直布局，
  /// 请使用[StrutStyle.disabled]。
  ///
  /// Flutter's strut is based on [typesetting strut](https://en.wikipedia.org/wiki/Strut_(typesetting))
  /// and CSS's [line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height).
  /// 颤振支柱基于[typesetting strut]（https://en.wikipedia.org/wiki/Strut_(typesetting)）
  /// 和CSS的[line-height]（https://www.w3.org/TR/CSS2/visudet.html#line-height）。
  /// {@endtemplate}
  ///
  /// Within editable text and text fields, [StrutStyle] will not use its standalone
  /// default values, and will instead inherit omitted/null properties from the
  /// [TextStyle] instead. See [StrutStyle.inheritFromTextStyle].
  /// 在可编辑文本和文本字段中，[StrutStyle]将不使用其独立的默认值，
  /// 而是从[TextStyle]继承省略/空属性。请参阅[StrutStyle.inheritFromTextStyle]。
  StrutStyle get strutStyle {
    if (_strutStyle == null) {
      return style != null
          ? StrutStyle.fromTextStyle(style, forceStrutHeight: true)
          : StrutStyle.disabled;
    }
    return _strutStyle.inheritFromTextStyle(style);
  }

  final StrutStyle _strutStyle;

  /// {@template flutter.widgets.editableText.textAlign}
  /// How the text should be aligned horizontally.
  /// 文本应如何水平对齐。
  ///
  /// Defaults to [TextAlign.start] and cannot be null.
  /// 默认为[TextAlign.start]，不能为空。
  /// {@endtemplate}
  final TextAlign textAlign;

  /// {@template flutter.widgets.editableText.textDirection}
  /// The directionality of the text.
  /// 文本的方向性。
  ///
  /// This decides how [textAlign] values like [TextAlign.start] and
  /// [TextAlign.end] are interpreted.
  /// 这决定了如何解释[textAlign.start]和[textAlign.end]等[textAlign]值。
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the text is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  /// 这也用于消除如何呈现双向文本的歧义。
  /// 例如，如果文本是英文短语后跟希伯来语短语，则在[TextDirection.ltr]上下文中，
  /// 英文短语位于左侧，希伯来语短语位于右侧；
  /// 而在[TextDirection.rtl]上下文中，英文短语位于右侧，希伯来语短语位于左侧。
  ///
  /// Defaults to the ambient [Directionality], if any.
  /// 默认为环境[方向性]（如果有）。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * {@macro flutter.gestures.monodrag.dragStartExample}
  ///
  /// {@endtemplate}
  /// 文本方向
  final TextDirection textDirection;

  /// {@template flutter.widgets.editableText.textCapitalization}
  /// Configures how the platform keyboard will select an uppercase or
  /// lowercase keyboard.
  /// 配置平台键盘如何选择大写或小写键盘。
  ///
  /// Only supports text keyboards, other keyboard types will ignore this
  /// configuration. Capitalization is locale-aware.
  /// 仅支持文本键盘，其他键盘类型将忽略此配置。大写可以识别区域设置。
  ///
  /// Defaults to [TextCapitalization.none]. Must not be null.
  /// 默认为[TextCapitalization.none]。不能为空。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [TextCapitalization], for a description of each capitalization behavior.
  ///  * [TextCapitalization]，用于描述每个大写行为。
  ///
  /// {@endtemplate}
  /// 文本大写
  final TextCapitalization textCapitalization;

  /// Used to select a font when the same Unicode character can
  /// be rendered differently, depending on the locale.
  /// 用于在同一个Unicode字符可以根据区域设置以不同方式呈现时选择字体。
  ///
  /// It's rarely necessary to set this property. By default its value
  /// is inherited from the enclosing app with `Localizations.localeOf(context)`.
  /// 很少有必要设置此属性。默认情况下，它的值继承自包含“Localizations.localeOf（context）”的应用程序。
  ///
  /// See [RenderEditable.locale] for more information.
  /// 有关详细信息，请参阅[RenderEditable.locale]。
  final Locale locale;

  /// The number of font pixels for each logical pixel.
  /// 每个逻辑像素的字体像素数。
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  /// 例如，如果文本比例因子为1.5，则文本将比指定的字体大小大50%。
  ///
  /// Defaults to the [MediaQueryData.textScaleFactor] obtained from the ambient
  /// [MediaQuery], or 1.0 if there is no [MediaQuery] in scope.
  /// 默认为从环境[MediaQuery]获取的[MediaQueryData.textScaleFactor]，
  /// 如果作用域中没有[MediaQuery]，则为1.0。
  ///
  /// 文本缩放因子
  final double textScaleFactor;

  /// The color to use when painting the cursor.
  /// 绘制光标时要使用的颜色。
  ///
  /// Cannot be null.
  /// 不能为空.
  final Color cursorColor;

  /// The color to use when painting the background cursor aligned with the text
  /// while rendering the floating cursor.
  /// 在呈现浮动光标时，绘制与文本对齐的背景光标时要使用的颜色。
  ///
  /// Cannot be null. By default it is the disabled grey color from
  /// CupertinoColors.
  /// 不能为空。默认情况下，它是禁用的灰色。
  final Color backgroundCursorColor;

  /// {@template flutter.widgets.editableText.maxLines}
  /// The maximum number of lines for the text to span, wrapping if necessary.
  /// 如果需要的话，文本行的最大行数，包装。
  ///
  /// If this is 1 (the default), the text will not wrap, but will scroll
  /// horizontally instead.
  /// 如果该值为1（默认值），则文本不会���������������������������������������������行，而是水平滚动。
  ///
  /// If this is null, there is no limit to the number of lines, and the text
  /// container will start with enough vertical space for one line and
  /// automatically grow to accommodate additional lines as they are entered.
  /// 如果该值为空，则对行数没有限制，文本容器将以一行足够的垂直空间开始，
  /// 并在输入时自动增长以容纳其他行。
  ///
  /// If this is not null, the value must be greater than zero, and it will lock
  /// the input to the given number of lines and take up enough horizontal space
  /// to accommodate that number of lines. Setting [minLines] as well allows the
  /// input to grow between the indicated range.
  /// 如果该值不为空，则该值必须大于零，并且它将锁定给定行数的输入，
  /// 并占用足够的水平空间来容纳该行数。设置[minLines]也允许输入在指定范围内增长。
  ///
  /// The full set of behaviors possible with [minLines] and [maxLines] are as
  /// follows. These examples apply equally to `TextField`, `TextFormField`, and
  /// `EditableText`.
  /// [minLines]和[maxLines]的完整行为集如下所示。
  /// 这些示例同样适用于“TextField”、“TextFormField”和“EditableText”。
  ///
  /// Input that occupies a single line and scrolls horizontally as needed.
  /// 占据一行并根据需要水平滚动的输入。
  /// ```dart
  /// TextField()
  /// ```
  ///
  /// Input whose height grows from one line up to as many lines as needed for
  /// the text that was entered. If a height limit is imposed by its parent, it
  /// will scroll vertically when its height reaches that limit.
  /// 其高度从一行增加到输入文本所需的行数的输入。
  /// 如果其父级设置了高度限制，则当其高度达到该限制时，它将垂直滚动。
  /// ```dart
  /// TextField(maxLines: null)
  /// ```
  ///
  /// The input's height is large enough for the given number of lines. If
  /// additional lines are entered the input scrolls vertically.
  /// 输入的高度对于给定的行数足够大。如果输入了其他行，则输入将垂直滚动。
  /// ```dart
  /// TextField(maxLines: 2)
  /// ```
  ///
  /// Input whose height grows with content between a min and max. An infinite
  /// max is possible with `maxLines: null`.
  /// 其高度随内容在最小值和最大值之间增长的输入。使用“maxLines:null”可以实现无限大。
  /// ```dart
  /// TextField(minLines: 2, maxLines: 4)
  /// ```
  /// {@endtemplate}
  final int maxLines;

  /// {@template flutter.widgets.editableText.minLines}
  /// The minimum number of lines to occupy when the content spans fewer lines.
  /// 当内容跨越较少行时要占用的最小行数。

  /// When [maxLines] is set as well, the height will grow between the indicated
  /// range of lines. When [maxLines] is null, it will grow as high as needed,
  /// starting from [minLines].
  /// 当[maxLines]也被设置时，高度将在指定的行范围之间增长。
  /// 当[maxLines]为空时，它将根据需要从[minLines]开始增长。
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines]
  /// and [minLines] interact to produce various behaviors.
  /// 有关[maxLines]和[minLines]如何交互以产生各种行为的完整图片，请参阅[maxLines]中的示例。
  ///
  /// Defaults to null.
  /// 默认为空。
  /// {@endtemplate}
  final int minLines;

  /// {@template flutter.widgets.editableText.expands}
  /// Whether this widget's height will be sized to fill its parent.
  /// 是否将调整此小部件的高度以填充其父级。
  ///
  /// If set to true and wrapped in a parent widget like [Expanded] or
  /// [SizedBox], the input will expand to fill the parent.
  /// 如果设置为true并包装在父窗口小部件（如[Expanded]或[SizedBox]）中，
  /// 则输入将展开以填充父窗口小部件。
  ///
  /// [maxLines] and [minLines] must both be null when this is set to true,
  /// otherwise an error is thrown.
  /// 当设置为true时，[maxLines]和[minLines]都必须为空，否则将引发错误。
  ///
  /// Defaults to false.
  /// 默认为false。
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines],
  /// [minLines], and [expands] interact to produce various behaviors.
  /// 有关[maxLines]、[minLines]和[expands]如何交互以产生各种行为的完整图片，
  /// 请参阅[maxLines]中的示例。
  ///
  /// Input that matches the height of its parent
  /// 与其父级高度匹配的输入
  /// ```dart
  /// Expanded(
  ///   child: TextField(maxLines: null, expands: true),
  /// )
  /// ```
  /// {@endtemplate}
  /// 扩展
  final bool expands;

  /// {@template flutter.widgets.editableText.autofocus}
  /// Whether this text field should focus itself if nothing else is already
  /// focused.
  ///
  /// 如果没有其他内容已经聚焦，则此文本字段是否应聚焦自身。
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the text field.
  ///
  /// 如果为true，则此文本字段获得焦点后键盘将立即打开。否则，只有在用户点击文本字段后才会显示键盘。
  ///
  /// Defaults to false. Cannot be null.
  ///
  /// 默认为false。不能为空。
  /// {@endtemplate}
  // See https://github.com/flutter/flutter/issues/7035 for the rationale for this
  // keyboard behavior.
  // 请参阅 https://github.com/flutter/flutter/issues/7035 以了解此键盘行为的基本原理。
  final bool autofocus;

  /// The color to use when painting the selection.
  ///
  /// 绘制选定内容时要使用的颜色。
  final Color selectionColor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// 用于生成文本选择句柄和工具栏的可选委托。
  ///
  /// The [EditableText] widget used on its own will not trigger the display
  /// of the selection toolbar by itself. The toolbar is shown by calling
  /// [EditableTextState.showToolbar] in response to an appropriate user event.
  ///
  /// 单独使用的[EditableText]小部件本身不会触发选择工具栏的显示。
  /// 通过调用[EditableTextState.showToolbar]响应适当的用户事件来显示工具栏。
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [CupertinoTextField], which wraps an [EditableText] and which shows the
  ///    selection toolbar upon user events that are appropriate on the iOS
  ///    platform.
  ///
  ///  * [CupertinoTextField]，它包装了一个[EditableText]，并在iOS平台上适当的用户事件上显示选择工具栏。
  ///
  ///  * [TextField], a Material Design themed wrapper of [EditableText], which
  ///    shows the selection toolbar upon appropriate user events based on the
  ///    user's platform set in [ThemeData.platform].
  ///
  ///  * [TextField]，[EditableText]的一个以材料设计为主题的包装器，
  ///    它基于[madedata.platform]中设置的用户平台，在适当的用户事件上显示选择工具栏。
  final TextSelectionControls selectionControls;

  /// {@template flutter.widgets.editableText.keyboardType}
  /// The type of keyboard to use for editing the text.
  /// 用于编辑文本的键盘类型。
  ///
  /// Defaults to [TextInputType.text] if [maxLines] is one and
  /// [TextInputType.multiline] otherwise.
  /// 如果[maxLines]是1，则默认为[TextInputType.text]，
  /// 否则默认为[TextInputType.multiline]。
  /// {@endtemplate}
  final TextInputType keyboardType;

  /// The type of action button to use with the soft keyboard.
  /// 要与软键盘一起使用的操作按钮的类型。
  final TextInputAction textInputAction;

  /// {@template flutter.widgets.editableText.onChanged}
  /// Called when the user initiates a change to the TextField's
  /// value: when they have inserted or deleted text.
  /// ��������������始更改文本字段的值时调用：当他们插入或删除文本时。
  ///
  /// This callback doesn't run when the TextField's text is changed
  /// programmatically, via the TextField's [controller]. Typically it
  /// isn't necessary to be notified of such changes, since they're
  /// initiated by the app itself.
  /// 当通过TextField的[controller]以编程方式更改TextField的文本时，
  /// 不会运行此回调。通常不需要通知这些更改，因为它们是由应用程序本身启动的。
  ///
  /// To be notified of all changes to the TextField's text, cursor,
  /// and selection, one can add a listener to its [controller] with
  /// [TextEditingController.addListener].
  /// 要获得对文本字段的文本、光标和选择的所有更改的通知，
  /// 可以使用[TextEditingController.add listener]将侦听器添加到其[controller]中。
  ///
  /// {@tool dartpad --template=stateful_widget_material}
  ///
  /// This example shows how onChanged could be used to check the TextField's
  /// current value each time the user inserts or deletes a character.
  /// 此示例显示了如何使用onChanged在每次用户插入或删除字符时检查TextField的当前值。
  ///
  /// ```dart
  /// TextEditingController _controller;
  ///
  /// void initState() {
  ///   super.initState();
  ///   _controller = TextEditingController();
  /// }
  ///
  /// void dispose() {
  ///   _controller.dispose();
  ///   super.dispose();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: Column(
  ///       mainAxisAlignment: MainAxisAlignment.center,
  ///       children: <Widget>[
  ///         const Text('What number comes next in the sequence?'),
  ///         const Text('1, 1, 2, 3, 5, 8...?'),
  ///         TextField(
  ///           controller: _controller,
  ///           onChanged: (String value) async {
  ///             if (value != '13') {
  ///               return;
  ///             }
  ///             await showDialog<void>(
  ///               context: context,
  ///               builder: (BuildContext context) {
  ///                 return AlertDialog(
  ///                   title: const Text('Thats correct!'),
  ///                   content: Text ('13 is the right answer.'),
  ///                   actions: <Widget>[
  ///                     FlatButton(
  ///                       onPressed: () { Navigator.pop(context); },
  ///                       child: const Text('OK'),
  ///                     ),
  ///                   ],
  ///                 );
  ///               },
  ///             );
  ///           },
  ///         ),
  ///       ],
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  ///
  /// See also:
  /// 另见：
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [inputFormatters]，在[onChanged]运行之前调用，可以验证和更改（“format”）输入值。
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]:
  ///    which are more specialized input change notifications.
  ///  * [onEditingComplete]、[onSubmitted]、[onSelectionChanged]：这是更专门的输入更改通知。
  final ValueChanged<String> onChanged;

  /// {@template flutter.widgets.editableText.onEditingComplete}
  /// Called when the user submits editable content (e.g., user presses the "done"
  /// button on the keyboard).
  /// 当用户提交可编辑内容时调用（例如，用户按下键盘上的“完成”按钮）。
  ///
  /// The default implementation of [onEditingComplete] executes 2 different
  /// behaviors based on the situation:
  /// [onEditingComplete]的默认实现根据情况执行两种不同的行为：
  ///
  ///  - When a completion action is pressed, such as "done", "go", "send", or
  ///    "search", the user's content is submitted to the [controller] and then
  ///    focus is given up.
  ///  - 当一个完成动作被按下时，例如“完成”、“开始”、“发送”或“搜索”，
  ///    用户的内容被提交到[controller]，然后焦点被放弃。
  ///
  ///  - When a non-completion action is pressed, such as "next" or "previous",
  ///    the user's content is submitted to the [controller], but focus is not
  ///    given up because developers may want to immediately move focus to
  ///    another input widget within [onSubmitted].
  ///  - 当按下“下一步”或“上一步”等未完成操作时，用户的内容将提交给[controller]，
  ///    但不会放弃焦点，因为开发人员可能希望立即将焦点移到[onSubmitted]中的另一个输入小部件。
  ///
  /// Providing [onEditingComplete] prevents the aforementioned default behavior.
  /// 提供[onEditingComplete]可防止上述默认行为。
  /// {@endtemplate}
  final VoidCallback onEditingComplete;

  /// {@template flutter.widgets.editableText.onSubmitted}
  /// Called when the user indicates that they are done editing the text in the
  /// field.
  /// 当用户指示已完成编辑字段中的文本时调用。
  /// {@endtemplate}
  ///
  /// {@tool sample --template=stateful_widget_material}
  /// When a non-completion action is pressed, such as "next" or "previous", it
  /// is often desirable to move the focus to the next or previous field.  To do
  /// this, handle it as in this example, by calling [FocusNode.focusNext] in
  /// the [TextFormField.onFieldSubmitted] callback ([TextFormField] wraps
  /// [EditableText] internally, and uses the value of `onFieldSubmitted` as its
  /// [onSubmitted]).
  /// 当按下“下一个”或“上一个”等未完成动作时，通常需要将焦点移到下一个或上一个字段。
  /// 为此，请像本例中一样处理它，方法是在[TextFormField.onFieldSubmitted]回调函数
  /// （[TextFormField]在内部包装[EditableText]，并将“onFieldSubmitted”的值用作
  /// 其[onSubmitted]）中调用[FocusNode.focusNext]。
  ///
  /// ```dart
  /// FocusScopeNode _focusScopeNode = FocusScopeNode();
  /// final _controller1 = TextEditingController();
  /// final _controller2 = TextEditingController();
  ///
  /// void dispose() {
  ///   _focusScopeNode.dispose();
  ///   _controller1.dispose();
  ///   _controller2.dispose();
  ///   super.dispose();
  /// }
  ///
  /// void _handleSubmitted(String value) {
  ///   _focusScopeNode.nextFocus();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: FocusScope(
  ///       node: _focusScopeNode,
  ///       child: Column(
  ///         mainAxisAlignment: MainAxisAlignment.center,
  ///         children: <Widget>[
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller1,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller2,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  final ValueChanged<String> onSubmitted;

  /// Called when the user changes the selection of text (including the cursor
  /// location).
  /// ������������本选择（包括光标位置）时调用。
  final SelectionChangedCallback onSelectionChanged;

  /// {@macro flutter.widgets.textSelection.onSelectionHandleTapped}
  /// 点击选择手柄
  final VoidCallback onSelectionHandleTapped;

  /// {@template flutter.widgets.editableText.inputFormatters}
  /// Optional input validation and formatting overrides.
  /// 可选的输入验证和格式覆盖。
  ///
  /// Formatters are run in the provided order when the text input changes.
  /// 当文本输入更改时，格式化程序按提供的顺序运行。
  /// {@endtemplate}
  final List<TextInputFormatter> inputFormatters;

  /// If true, the [RenderEditable] created by this widget will not handle
  /// pointer events, see [renderEditable] and [RenderEditable.ignorePointer].
  /// 如果为true，则此小部件创建的[RenderEditable]将不会处理指针事件，
  /// 请参阅[RenderEditable]和[RenderEditable.ignorePointer]。
  ///
  /// This property is false by default.
  /// 默认情况下，此属性为false。
  final bool rendererIgnoresPointer;

  /// {@template flutter.widgets.editableText.cursorWidth}
  /// How thick the cursor will be.
  /// 光标的宽度。
  ///
  /// Defaults to 2.0
  /// 默认值 为 2.0
  ///
  /// The cursor will draw under the text. The cursor width will extend
  /// to the right of the boundary between characters for left-to-right text
  /// and to the left for right-to-left text. This corresponds to extending
  /// downstream relative to the selected position. Negative values may be used
  /// to reverse this behavior.
  /// 光标将在文本下绘制。光标宽度将延伸到从左到右文本字符之间的边界右侧，
  /// 从左到右文本字符之间的边界左侧。这对应于相对于选定位置向下游延伸。负值可用于反转此行为。
  /// {@endtemplate}
  /// 光标宽度
  final double cursorWidth;

  /// {@template flutter.widgets.editableText.cursorRadius}
  /// How rounded the corners of the cursor should be.
  /// 光标的圆角。
  ///
  /// By default, the cursor has no radius.
  /// 默认情况下，光标没有圆角。
  /// {@endtemplate}
  final Radius cursorRadius;

  /// Whether the cursor will animate from fully transparent to fully opaque
  /// during each cursor blink.
  /// 在每次光标闪烁期间，光标是否从完全透明设置为完全不透明。
  ///
  /// By default, the cursor opacity will animate on iOS platforms and will not
  /// animate on Android platforms.
  /// 默认情况下，光标不透明度将在iOS平台上设置动画，而不会在Android平台上设置动画。
  final bool cursorOpacityAnimates;

  ///{@macro flutter.rendering.editable.cursorOffset}
  /// 光标偏移量
  final Offset cursorOffset;

  ///{@macro flutter.rendering.editable.paintCursorOnTop}
  /// 在文本上方绘制光标
  final bool paintCursorAboveText;

  /// The appearance of the keyboard.
  /// 键盘的外观。
  ///
  /// This setting is only honored on iOS devices.
  /// 此设置仅在iOS设备上使用。
  ///
  /// Defaults to [Brightness.light].
  /// 默认为[Brightness.light]。
  final Brightness keyboardAppearance;

  /// {@template flutter.widgets.editableText.scrollPadding}
  /// Configures padding to edges surrounding a [Scrollable] when the Textfield scrolls into view.
  /// 当文本字段滚动到视图中时，配置[可滚动]周围边缘的填充。
  ///
  /// When this widget receives focus and is not completely visible (for example scrolled partially
  /// off the screen or overlapped by the keyboard)
  /// then it will attempt to make itself visible by scrolling a surrounding [Scrollable], if one is present.
  /// This value controls how far from the edges of a [Scrollable] the TextField will be positioned after the scroll.
  /// 当这个小部件接收到焦点并且不完全可见时（例如部分地从屏幕上滚下或被键盘重叠），
  /// 它将试图通过滚动一个周围的[可滚动的]（如果有）使自己可见。此值控制文本字段距[可滚动]边缘的距离。
  ///
  /// Defaults to EdgeInsets.all(20.0).
  /// 默认为 EdgeInsets.all(20.0).
  /// {@endtemplate}
  final EdgeInsets scrollPadding;

  /// {@template flutter.widgets.editableText.enableInteractiveSelection}
  /// If true, then long-pressing this TextField will select text and show the
  /// cut/copy/paste menu, and tapping will move the text caret.
  /// 如果为真，则长按此文本字段将选择文本并显示“剪切/复制/粘贴”菜单，单击将移动文本插入符号。
  ///
  /// True by default.
  /// 默认情况下为True。
  ///
  /// If false, most of the accessibility support for selecting text, copy
  /// and paste, and moving the caret will be disabled.
  /// 如果为false，则大多数用于选择文本、复制和粘贴以及移动插入符号的辅助功能支持将被禁用。
  /// {@endtemplate}
  final bool enableInteractiveSelection;

  /// Setting this property to true makes the cursor stop blinking or fading
  /// on and off once the cursor appears on focus. This property is useful for
  /// testing purposes.
  /// 如果将此属性设置为true，则当光标出现在焦点上时，光标将停止闪烁或褪色。此属性可用于测试目的。
  ///
  /// It does not affect the necessity to focus the EditableText for the cursor
  /// to appear in the first place.
  /// 它不影响将可编辑文本作为焦点以使光标首先出现的必要性。
  ///
  /// Defaults to false, resulting in a typical blinking cursor.
  /// 默认为false，导致典型的光标闪烁。
  static bool debugDeterministicCursor = false;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  /// 拖动开始行为
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.editableText.scrollController}
  /// The [ScrollController] to use when vertically scrolling the input.
  /// 垂直滚动输入时使用的[ScrollController]。
  ///
  /// If null, it will instantiate a new ScrollController.
  /// 如果为空，它将实例化一个新的scroll控制器。
  ///
  /// See [Scrollable.controller].
  /// 详见 [Scrollable.controller].
  /// {@endtemplate}
  final ScrollController scrollController;

  /// {@template flutter.widgets.editableText.scrollPhysics}
  /// The [ScrollPhysics] to use when vertically scrolling the input.
  /// 垂直滚动输入时使用的[ScrollPhysics]。
  ///
  /// If not specified, it will behave according to the current platform.
  /// 如果没有指定，它将根据当前平台进行操作。
  ///
  /// See [Scrollable.physics].
  /// 详见 [Scrollable.physics].
  /// {@endtemplate}
  final ScrollPhysics scrollPhysics;

  /// {@macro flutter.rendering.editable.selectionEnabled}
  /// 启用交互式选择
  bool get selectionEnabled => enableInteractiveSelection;

  @override
  EditableTextState createState() => EditableTextState();

  @override
  // 调试填充属性
  void debugFillProperties(
      // 诊断属性生成器   properties 属性
      DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<TextEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText,
        defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    properties.add(EnumProperty<SmartDashesType>(
        'smartDashesType', smartDashesType,
        defaultValue:
            obscureText ? SmartDashesType.disabled : SmartDashesType.enabled));
    properties.add(EnumProperty<SmartQuotesType>(
        'smartQuotesType', smartQuotesType,
        defaultValue:
            obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled));
    properties.add(DiagnosticsProperty<bool>(
        'enableSuggestions', enableSuggestions,
        defaultValue: true));
    style?.debugFillProperties(properties);
    properties.add(
        EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(
        DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
  }
}

/// State for a [EditableText].
///
/// [EditableText] 的状态。
class EditableTextState extends State<EditableText>
    with
        AutomaticKeepAliveClientMixin<EditableText>,
        WidgetsBindingObserver,
        TickerProviderStateMixin<EditableText>
    implements TextInputClient, TextSelectionDelegate {
  /// 光标计时器
  Timer _cursorTimer;

  /// 目标光标可见性
  bool _targetCursorVisibility = false;

  /// 光标可见性通知程序
  final ValueNotifier<bool> _cursorVisibilityNotifier =
      ValueNotifier<bool>(true);

  /// 可编辑 key
  final GlobalKey _editableKey = GlobalKey();

  /// 文本输入连接 输入法
  TextInputConnection _textInputConnection;

  /// 选择覆盖
  TextSelectionOverlay _selectionOverlay;

  /// 滚动控制器
  ScrollController _scrollController;

  /// 光标闪烁不透明度控制器
  AnimationController _cursorBlinkOpacityController;

  /// 工具栏层链接
  final LayerLink _toolbarLayerLink = LayerLink();

  /// 开始句柄层链接
  final LayerLink _startHandleLayerLink = LayerLink();

  /// 结束句柄层链接
  final LayerLink _endHandleLayerLink = LayerLink();

  /// 自动对焦
  bool _didAutoFocus = false;

  /// 焦点 附属物 ([FocusNode]的连接点)。
  FocusAttachment _focusAttachment;

  // This value is an eyeball estimation of the time it takes for the iOS cursor
  // to ease in and out.
  // 这个值是对iOS光标进入和退出所需时间的眼球估计。
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  // 用户完成放置后，浮动光标捕捉到文本对齐光标位置所需的时间。
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  // 浮动光标复位控制器
  AnimationController _floatingCursorResetController;

  @override
  // 保持生命周期
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  // 获取 光标颜色
  Color get _cursorColor =>
      widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);

  @override
  // 剪切启用
  bool get cutEnabled => widget.toolbarOptions.cut && !widget.readOnly;

  @override
  // 复制启用
  bool get copyEnabled => widget.toolbarOptions.copy;

  @override
  // 粘贴启用
  bool get pasteEnabled => widget.toolbarOptions.paste && !widget.readOnly;

  @override
  // 选择全部启用
  bool get selectAllEnabled => widget.toolbarOptions.selectAll;

  // State lifecycle:
  // 状态生命周期：

  @override
  void initState() {
    super.initState();
    // 是否更改了文本编辑值
    widget.controller.addListener(_didChangeTextEditingValue);
    // 焦点附属物
    _focusAttachment = widget.focusNode.attach(context);
    // 处理焦点已更改
    widget.focusNode.addListener(_handleFocusChanged);
    // 滚动条控制器
    _scrollController = widget.scrollController ?? ScrollController();
    // 更新滚动条
    _scrollController.addListener(() {
      _selectionOverlay?.updateForScroll();
    });
    // 光标闪烁不透明度控制器
    _cursorBlinkOpacityController =
        AnimationController(vsync: this, duration: _fadeDuration);
    // 光标颜色刻度
    _cursorBlinkOpacityController.addListener(_onCursorColorTick);
    // 浮动光标复位控制器
    _floatingCursorResetController = AnimationController(vsync: this);
    // 浮动光标重置刻度
    _floatingCursorResetController.addListener(_onFloatingCursorResetTick);
    // 是否显示光标
    _cursorVisibilityNotifier.value = widget.showCursor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      // 自动获取焦点
      FocusScope.of(context).autofocus(widget.focusNode);
      _didAutoFocus = true;
    }
  }

  @override
  // 更新Widget
  void didUpdateWidget(
      // 可编辑文本
      EditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      // 移除oldWidget controller 监听
      oldWidget.controller.removeListener(_didChangeTextEditingValue);
      // 增加新的监听
      widget.controller.addListener(_didChangeTextEditingValue);
      // 如果需要，更新远程编辑值
      _updateRemoteEditingValueIfNeeded();
    }
    // 选择
    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(_value);
    }
    _selectionOverlay?.handlesVisible = widget.showSelectionHandles;
    if (widget.focusNode != oldWidget.focusNode) {
      // 移除旧的监听，绑定新的监听
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      _focusAttachment?.detach();
      _focusAttachment = widget.focusNode.attach(context);
      widget.focusNode.addListener(_handleFocusChanged);
      updateKeepAlive();
    }
    if (widget.readOnly) {
      // 如果需要，关闭输入连接
      _closeInputConnectionIfNeeded();
    } else {
      // 打开输入连接
      if (oldWidget.readOnly && _hasFocus) _openInputConnection();
    }
    if (widget.style != oldWidget.style) {
      // 样式
      final TextStyle style = widget.style;
      // The _textInputConnection will pick up the new style when it attaches in
      // _openInputConnection.
      // textInputConnection在附加到openInputConnection时将采用新样式。
      if (_textInputConnection != null && _textInputConnection.attached) {
        _textInputConnection.setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: _textDirection,
          textAlign: widget.textAlign,
        );
      }
    }
  }

  @override
  void dispose() {
    // widget销毁的时候释放资源
    widget.controller.removeListener(_didChangeTextEditingValue);
    _cursorBlinkOpacityController.removeListener(_onCursorColorTick);
    _floatingCursorResetController.removeListener(_onFloatingCursorResetTick);
    _closeInputConnectionIfNeeded();
    assert(!_hasInputConnection);
    _stopCursorTimer();
    assert(_cursorTimer == null);
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    _focusAttachment.detach();
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  // TextInputClient implementation:
  // TextInputClient 实现:

  // 文本编辑值       最后已知的远程文本编辑值
  TextEditingValue _lastKnownRemoteTextEditingValue;

  @override
  // ���������������辑值
  TextEditingValue get currentTextEditingValue => _value;

  @override
  // 更新文本编辑值
  void updateEditingValue(TextEditingValue value) {
    // Since we still have to support keyboard select, this is the best place
    // to disable text updating.
    // 因为我们仍然需要支持键盘选择，所以这是禁用文本更新的最佳位置。
    if (widget.readOnly) {
      return;
    }
    if (value.text != _value.text) {
      // 隐藏工具栏
      hideToolbar();
      // 在屏幕上显示插入符号
      _showCaretOnScreen();
      // 模糊文本为真
      if (widget.obscureText && value.text.length == _value.text.length + 1) {
        // 模糊显示挂起的字符标记 = 模糊显示最新字符光标标记
        _obscureShowCharTicksPending = _kObscureShowLatestCharCursorTicks;
        // 模糊最新字符索引     基偏移
        _obscureLatestCharIndex = _value.selection.baseOffset;
      }
    }
    // 上次已知的远程文本编辑值
    _lastKnownRemoteTextEditingValue = value;
    // 格式和设置值
    _formatAndSetValue(value);

    // To keep the cursor from blinking while typing, we want to restart the
    // cursor timer every time a new character is typed.
    // 为了防止光标在键入时闪烁，我们希望在每次键入新字符时重新启动光标计时器。
    _stopCursorTimer(resetCharTicks: false);
    // 停止 启动光标计时器
    _startCursorTimer();
  }

  @override
  // 执行操作
  void performAction(
      // 文本输入操作
      TextInputAction action) {
    switch (action) {
      // 新的一行
      case TextInputAction.newline:
        // If this is a multiline EditableText, do nothing for a "newline"
        // action; The newline is already inserted. Otherwise, finalize
        // editing.
        // 如果这是一个多行可编辑文本，则不要对“换行”操作执行任何操作；换行已经插入。否则，完成编辑。
        if (!_isMultiline) _finalizeEditing(true);
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.send:
      case TextInputAction.search:
        _finalizeEditing(true);
        break;
      default:
        // Finalize editing, but don't give up focus because this keyboard
        //  action does not imply the user is done inputting information.
        // 完成编辑，但不要放弃焦点，因为此键盘操作并不意味着用户已完成输入信息。
        _finalizeEditing(false);
        break;
    }
  }

  // The original position of the caret on FloatingCursorDragState.start.
  // FloatingCursorDragState.start上插入符号的原始位置。
  Rect _startCaretRect;

  // The most recent text position as determined by the location of the floating
  // cursor.
  // 由浮动光标位置确定的最新文本位置。
  TextPosition _lastTextPosition;

  // The offset of the floating cursor as determined from the first update call.
  // 从第一次更新调用确定的浮动光标偏移量。
  Offset _pointOffsetOrigin;

  // The most recent position of the floating cursor.
  // 浮动光标的最新位置。
  Offset _lastBoundedOffset;

  // Because the center of the cursor is preferredLineHeight / 2 below the touch
  // origin, but the touch origin is used to determine which line the cursor is
  // on, we need this offset to correctly render and move the cursor.
  // 由于光标的中心优先位于触摸原点下方的 redlineheight / 2 处，
  // 但触摸原点用于确定光标位于哪一行，因此我们需要此偏移量来正确渲染和移动光标。
  Offset get _floatingCursorOffset =>
      Offset(0, renderEditable.preferredLineHeight / 2);

  @override
  // 更新浮动光标
  void updateFloatingCursor(
      // 原始浮动光标点
      RawFloatingCursorPoint point) {
    // 光标状态
    switch (point.state) {
      // 浮动光标拖动状态
      case FloatingCursorDragState.Start:
        // 正在设置动画
        if (_floatingCursorResetController.isAnimating) {
          _floatingCursorResetController.stop();
          _onFloatingCursorResetTick();
        }
        // 当前文本位置
        final TextPosition currentTextPosition =
            TextPosition(offset: renderEditable.selection.baseOffset);
        // 开始插入符号矩形
        _startCaretRect =
            // getLocalRectForCaret 获取插入符号的本地Rect
            renderEditable.getLocalRectForCaret(currentTextPosition);
        // 设置浮动光标
        renderEditable.setFloatingCursor(
            point.state,
            _startCaretRect.center - _floatingCursorOffset,
            currentTextPosition);
        break;
      case FloatingCursorDragState.Update:
        // We want to send in points that are centered around a (0,0) origin, so we cache the
        // position on the first update call.
        // 我们希望发送以（0,0）原点为中心的点，因此在第一次更新调用时缓存位置。
        if (_pointOffsetOrigin != null) {
          // 中心点
          final Offset centeredPoint = point.offset - _pointOffsetOrigin;
          // 原始光标偏移
          final Offset rawCursorOffset =
              _startCaretRect.center + centeredPoint - _floatingCursorOffset;
          // 上次边界偏移
          _lastBoundedOffset = renderEditable
              // 计算有界浮动光标偏移量
              .calculateBoundedFloatingCursorOffset(rawCursorOffset);
          // 上次文本位置
          _lastTextPosition =
              // 获取点的位置
              renderEditable.getPositionForPoint(renderEditable
                  // 本地到全局
                  .localToGlobal(_lastBoundedOffset + _floatingCursorOffset));
          // 设置浮动光标
          renderEditable.setFloatingCursor(
              point.state, _lastBoundedOffset, _lastTextPosition);
        } else {
          // 点偏移原点
          _pointOffsetOrigin = point.offset;
        }
        break;
      // 浮动光标拖动状态
      case FloatingCursorDragState.End:
        // We skip animation if no update has happened.
        // 如果没有更新，我们将跳过动画。
        if (_lastTextPosition != null && _lastBoundedOffset != null) {
          // 浮动光标复位控制器
          _floatingCursorResetController.value = 0.0;
          _floatingCursorResetController.animateTo(1.0,
              duration: _floatingCursorResetTime, curve: Curves.decelerate);
        }
        break;
    }
  }

  // 浮动光标重置刻度
  void _onFloatingCursorResetTick() {
    // 最终位置
    final Offset finalPosition =
        // 获取插入符号的本地Rect
        renderEditable.getLocalRectForCaret(_lastTextPosition).centerLeft -
            _floatingCursorOffset;
    // 已完成
    if (_floatingCursorResetController.isCompleted) {
      // 设置浮动光标
      renderEditable.setFloatingCursor(
          FloatingCursorDragState.End, finalPosition, _lastTextPosition);
      if (_lastTextPosition.offset != renderEditable.selection.baseOffset)
        // The cause is technically the force cursor, but the cause is listed as tap as the desired functionality is the same.
        // 从技术上讲，原因是force cursor，但由于所需功能相同，因此原因被列为tap。
        // 句柄选择已更改
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _lastTextPosition.offset),
            renderEditable,
            SelectionChangedCause.forcePress);
      _startCaretRect = null;
      _lastTextPosition = null;
      _pointOffsetOrigin = null;
      _lastBoundedOffset = null;
    } else {
      final double lerpValue = _floatingCursorResetController.value;
      final double lerpX =
          ui.lerpDouble(_lastBoundedOffset.dx, finalPosition.dx, lerpValue);
      final double lerpY =
          ui.lerpDouble(_lastBoundedOffset.dy, finalPosition.dy, lerpValue);

      // 设置浮动光标
      renderEditable.setFloatingCursor(FloatingCursorDragState.Update,
          Offset(lerpX, lerpY), _lastTextPosition,
          // 重置 LerpValue
          resetLerpValue: lerpValue);
    }
  }

  // 完成编辑
  void _finalizeEditing(bool shouldUnfocus) {
    // Take any actions necessary now that the user has completed editing.
    // 用户完成编辑后，立即执行任何必要的操作。
    if (widget.onEditingComplete != null) {
      widget.onEditingComplete();
    } else {
      // Default behavior if the developer did not provide an
      // onEditingComplete callback: Finalize editing and remove focus.
      // 如果开发人员未提供onEditingComplete回调，则默认行为：完成编辑并移除焦点。
      widget.controller.clearComposing();
      if (shouldUnfocus) widget.focusNode.unfocus();
    }

    // Invoke optional callback with the user's submitted content.
    // 使用用户提交的内容调用可选回调。
    if (widget.onSubmitted != null) widget.onSubmitted(_value.text);
  }

  /// 如果需要，更新远程编辑值
  void _updateRemoteEditingValueIfNeeded() {
    if (!_hasInputConnection) return;
    // 本地值
    final TextEditingValue localValue = _value;
    if (localValue == _lastKnownRemoteTextEditingValue) return;
    // 同步值
    _lastKnownRemoteTextEditingValue = localValue;
    _textInputConnection.setEditingState(localValue);
  }

  // 获得值
  TextEditingValue get _value => widget.controller.value;
  // 设置值
  set _value(TextEditingValue value) {
    widget.controller.value = value;
  }

  // 获得是否聚焦
  bool get _hasFocus => widget.focusNode.hasFocus;
  // 获得 是否多行
  bool get _isMultiline => widget.maxLines != 1;

  // Calculate the new scroll offset so the cursor remains visible.
  // 计算新的滚动偏移，使光标保持可见。
  double _getScrollOffsetForCaret(Rect caretRect) {
    // 插入符号开始
    double caretStart;
    // 插入符号结束
    double caretEnd;
    if (_isMultiline) {
      // The caret is vertically centered within the line. Expand the caret's
      // height so that it spans the line because we're going to ensure that the entire
      // expanded caret is scrolled into view.
      // 插入符号在直线内垂直居中。展开插入符号的高度，使其跨行，因为我们将确保整个展开的插入符号滚动到视图中。
      final double lineHeight = renderEditable.preferredLineHeight;
      final double caretOffset = (lineHeight - caretRect.height) / 2;
      caretStart = caretRect.top - caretOffset;
      caretEnd = caretRect.bottom + caretOffset;
    } else {
      // Scrolls horizontally for single-line fields.
      // 水平滚动单行字段。
      caretStart = caretRect.left;
      caretEnd = caretRect.right;
    }

    // 滚动条偏移量
    double scrollOffset = _scrollController.offset;
    // 视区范围
    final double viewportExtent = _scrollController.position.viewportDimension;
    if (caretStart < 0.0) {
      // cursor before start of bounds
      // 边界开始前的光标
      scrollOffset += caretStart;
    } else if (caretEnd >= viewportExtent) {
      // cursor after end of bounds
      // 边界结束后的光标
      scrollOffset += caretEnd - viewportExtent;
    }

    if (_isMultiline) {
      // Clamp the final results to prevent programmatically scrolling to
      // out-of-paragraph-bounds positions when encountering tall fonts/scripts that
      // extend past the ascent.
      // 固定最终结果，以防止遇到超过上升的高字体/脚本时以编程方式滚动到超出段落边界的位置。
      scrollOffset =
          scrollOffset.clamp(0.0, renderEditable.maxScrollExtent) as double;
    }
    return scrollOffset;
  }

  /// Calculates where the `caretRect` would be if `_scrollController.offset` is set to `scrollOffset`.
  ///
  /// 计算 "scrollController.offset" 设置为 "scrollproset" 时 "caretRect" 的位置。
  Rect _getCaretRectAtScrollOffset(Rect caretRect, double scrollOffset) {
    // 偏移差
    final double offsetDiff = _scrollController.offset - scrollOffset;
    return _isMultiline
        ? caretRect.translate(0.0, offsetDiff)
        : caretRect.translate(offsetDiff, 0.0);
  }

  /// 获得 has Input连接
  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection.attached;

  /// 打开输入连接
  void _openInputConnection() {
    if (widget.readOnly) {
      return;
    }
    // 有输入连接
    if (!_hasInputConnection) {
      // 本地value
      final TextEditingValue localValue = _value;
      // 最后已知的远程文本编辑值
      _lastKnownRemoteTextEditingValue = localValue;
      // 文本输入连接
      _textInputConnection = TextInput.attach(
        this,
        // 文本输入配置
        TextInputConfiguration(
          inputType: widget.keyboardType,
          // 模糊文本
          obscureText: widget.obscureText,
          // 自动校正
          autocorrect: widget.autocorrect,
          // 智能数据类型
          smartDashesType: widget.smartDashesType ??
              (widget.obscureText
                  ? SmartDashesType.disabled
                  : SmartDashesType.enabled),
          // 智能引号类型
          smartQuotesType: widget.smartQuotesType ??
              (widget.obscureText
                  ? SmartQuotesType.disabled
                  : SmartQuotesType.enabled),
          // 启用建议
          enableSuggestions: widget.enableSuggestions,
          // 输入动作
          inputAction: widget.textInputAction ??
              (widget.keyboardType == TextInputType.multiline
                  ? TextInputAction.newline
                  : TextInputAction.done),
          // 文本大写
          textCapitalization: widget.textCapitalization,
          // 键盘外观
          keyboardAppearance: widget.keyboardAppearance,
        ),
      );
      // 文本输入连接 显示
      _textInputConnection.show();
      // 更新大小和转换
      _updateSizeAndTransform();
      // 样式
      final TextStyle style = widget.style;
      // 设置样式
      _textInputConnection
        ..setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: _textDirection,
          textAlign: widget.textAlign,
        )
        // 设置编辑状态
        ..setEditingState(localValue);
    } else {
      // 文本输入连接 显示
      _textInputConnection.show();
    }
  }

  /// 如果需要，关闭输入连接
  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection.close();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
    }
  }

  /// 必要时打开或关闭输入连接
  void _openOrCloseInputConnectionIfNeeded() {
    // consumeKeyboardToken 使用键盘令牌
    if (_hasFocus && widget.focusNode.consumeKeyboardToken()) {
      // 打开连接
      _openInputConnection();
    } else if (!_hasFocus) {
      // 关闭连接
      _closeInputConnectionIfNeeded();
      // 将合成区域设置为空范围。
      widget.controller.clearComposing();
    }
  }

  @override

  /// 连接关闭
  void connectionClosed() {
    if (_hasInputConnection) {
      _textInputConnection.connectionClosedReceived();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
      _finalizeEditing(true);
    }
  }

  /// Express interest in interacting with the keyboard.
  ///
  /// 表达与键盘交互的兴趣。
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  ///
  /// 如果此控件已附加到键盘，则此函数将请求键盘变为可见。
  /// 否则，该功能将要求调焦系统将其调焦。如果获取焦点成功，控件将附加到键盘并请求键盘变为可见。
  void requestKeyboard() {
    if (_hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  /// 必要时，更新或释放选择覆盖
  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay.update(_value);
      } else {
        _selectionOverlay.dispose();
        _selectionOverlay = null;
      }
    }
  }

  /// 句柄选择已更改
  void _handleSelectionChanged(
      // 选择
      TextSelection selection,
      // 渲染可编辑
      RenderEditable renderObject,
      SelectionChangedCause cause) {
    widget.controller.selection = selection;

    // This will show the keyboard for all selection changes on the
    // EditableWidget, not just changes triggered by user gestures.
    // 这将显示可编辑小部件上所有选择更改的键盘，而不仅仅是由用户手势触发的更改。
    requestKeyboard();

    _selectionOverlay?.hide();
    _selectionOverlay = null;

    if (widget.selectionControls != null) {
      // 文本选择覆盖
      _selectionOverlay = TextSelectionOverlay(
        context: context,
        value: _value,
        // debugRequiredFor 需要调试
        debugRequiredFor: widget,
        // 工具栏层链接
        toolbarLayerLink: _toolbarLayerLink,
        // 开始句柄层链接
        startHandleLayerLink: _startHandleLayerLink,
        // 结束句柄层链接
        endHandleLayerLink: _endHandleLayerLink,
        // 渲染对象
        renderObject: renderObject,
        // 选择控件
        selectionControls: widget.selectionControls,
        // 选择委托
        selectionDelegate: this,
        // 拖动开始行为
        dragStartBehavior: widget.dragStartBehavior,
        // 点击选择手柄
        onSelectionHandleTapped: widget.onSelectionHandleTapped,
      );
      // 手柄可见
      _selectionOverlay.handlesVisible = widget.showSelectionHandles;
      // 展示Handles
      _selectionOverlay.showHandles();
      // 当选时已更改
      if (widget.onSelectionChanged != null)
        widget.onSelectionChanged(selection, cause);
    }
  }

  /// 自上次插入符号更新后文本已更改
  bool _textChangedSinceLastCaretUpdate = false;

  /// 当前插入符号矩形
  Rect _currentCaretRect;

  // 句柄插入符号已更改
  void _handleCaretChanged(
      // 插入符号矩形
      Rect caretRect) {
    _currentCaretRect = caretRect;
    // If the caret location has changed due to an update to the text or
    // selection, then scroll the caret into view.
    // 如果插入符号位置因文本或所选内容的更新而更改，请将插入符号滚动到视图中。
    if (_textChangedSinceLastCaretUpdate) {
      // 自上次插入符号更新后文本已更改
      _textChangedSinceLastCaretUpdate = false;
      // 在屏幕上显示插入符号
      _showCaretOnScreen();
    }
  }

  // Animation configuration for scrolling the caret back on screen.
  // 用于在屏幕上滚动插入符号的动画配置。
  /// 插入符号动画持续时间
  static const Duration _caretAnimationDuration = Duration(milliseconds: 100);

  /// 插入符号动画曲线
  static const Curve _caretAnimationCurve = Curves.fastOutSlowIn;

  /// 计划在屏幕上显示插入符号
  bool _showCaretOnScreenScheduled = false;

  /// 在屏幕上显示插入符号
  void _showCaretOnScreen() {
    if (_showCaretOnScreenScheduled) {
      return;
    }
    _showCaretOnScreenScheduled = true;
    // 计划程序绑定  添加后帧回调
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;
      if (_currentCaretRect == null || !_scrollController.hasClients) {
        return;
      }
      // 插入符号的滚动偏移量
      final double scrollOffsetForCaret =
          _getScrollOffsetForCaret(_currentCaretRect);
      _scrollController.animateTo(
        scrollOffsetForCaret,
        duration: _caretAnimationDuration,
        curve: _caretAnimationCurve,
      );
      final Rect newCaretRect =
          _getCaretRectAtScrollOffset(_currentCaretRect, scrollOffsetForCaret);
      // Enlarge newCaretRect by scrollPadding to ensure that caret is not
      // positioned directly at the edge after scrolling.
      // 通过滚动填充放大newCaretRect，以确保插入符号在滚动后不直接位于边缘。
      double bottomSpacing = widget.scrollPadding.bottom;
      if (_selectionOverlay?.selectionControls != null) {
        // 手柄高度
        final double handleHeight = _selectionOverlay.selectionControls
            .getHandleSize(renderEditable.preferredLineHeight)
            .height;
        // 交互手柄高度
        final double interactiveHandleHeight = math.max(
          handleHeight,
          kMinInteractiveDimension,
        );
        // 锚点
        final Offset anchor =
            // 获取句柄锚点
            _selectionOverlay.selectionControls.getHandleAnchor(
          TextSelectionHandleType.collapsed,
          // 首选线条高度
          renderEditable.preferredLineHeight,
        );
        // 手柄中心
        final double handleCenter = handleHeight / 2 - anchor.dy;
        // 底部间距
        bottomSpacing = math.max(
          // interactiveHandleHeight 交互手柄高度
          handleCenter + interactiveHandleHeight / 2,
          bottomSpacing,
        );
      }
      // 扁平矩形
      final Rect inflatedRect = Rect.fromLTRB(
        newCaretRect.left - widget.scrollPadding.left,
        newCaretRect.top - widget.scrollPadding.top,
        newCaretRect.right + widget.scrollPadding.right,
        newCaretRect.bottom + bottomSpacing,
      );
      // findRenderObject 查找渲染对象      showOnScreen 在屏幕上显示
      _editableKey.currentContext.findRenderObject().showOnScreen(
            rect: inflatedRect,
            duration: _caretAnimationDuration,
            curve: _caretAnimationCurve,
          );
    });
  }

  /// 上次底部视图插入
  double _lastBottomViewInset;

  @override
  // 是否改变了指标
  void didChangeMetrics() {
    if (_lastBottomViewInset <
        WidgetsBinding.instance.window.viewInsets.bottom) {
      // 在屏幕上显示插入符号
      _showCaretOnScreen();
    }
    _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
  }

  /// 格式化和设置值
  void _formatAndSetValue(TextEditingValue value) {
    // 文本已更改
    final bool textChanged = _value?.text != value?.text;
    if (textChanged &&
        widget.inputFormatters != null &&
        widget.inputFormatters.isNotEmpty) {
      for (final TextInputFormatter formatter in widget.inputFormatters)
        value = formatter.formatEditUpdate(_value, value);
      _value = value;
      _updateRemoteEditingValueIfNeeded();
    } else {
      _value = value;
    }
    if (textChanged && widget.onChanged != null) widget.onChanged(value.text);
  }

  /// 光标颜色刻度
  void _onCursorColorTick() {
    renderEditable.cursorColor =
        widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);
    _cursorVisibilityNotifier.value =
        widget.showCursor && _cursorBlinkOpacityController.value > 0;
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  ///
  /// 在这个精确的时刻，闪烁的光标是否真的可见（因为它闪烁，���以���隐�����������时间��。
  @visibleForTesting
  bool get cursorCurrentlyVisible => _cursorBlinkOpacityController.value > 0;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  ///
  /// 光标闪烁间隔（光标处于“开”或“关”状态的时间量）。
  /// 一个完整的光标闪烁周期是这个值的两倍（半开半关）。
  @visibleForTesting
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;

  /// The current status of the text selection handles.
  ///
  /// 文本选择句柄的当前状态。
  @visibleForTesting
  TextSelectionOverlay get selectionOverlay => _selectionOverlay;

  /// 隐藏显示字符标记挂起
  int _obscureShowCharTicksPending = 0;

  /// 模糊最新字符索引
  int _obscureLatestCharIndex;

  /// 光标刻度
  void _cursorTick(Timer timer) {
    // 目标光标可见性
    _targetCursorVisibility = !_targetCursorVisibility;
    final double targetOpacity = _targetCursorVisibility ? 1.0 : 0.0;
    if (widget.cursorOpacityAnimates) {
      // If we want to show the cursor, we will animate the opacity to the value
      // of 1.0, and likewise if we want to make it disappear, to 0.0. An easing
      // curve is used for the animation to mimic the aesthetics of the native
      // iOS cursor.
      // 如果我们想显示光标，我们将设置不透明度为1.0的动画，同样如果我们想让它消失，
      // 设置为0.0。动画使用缓和曲线来模拟本机iOS光标的美学效果。
      //
      // These values and curves have been obtained through eyeballing, so are
      // likely not exactly the same as the values for native iOS.
      // 这些值和曲线是通过目测获得的，因此可能与本地iOS的值不完全相同。
      _cursorBlinkOpacityController.animateTo(targetOpacity,
          curve: Curves.easeOut);
    } else {
      _cursorBlinkOpacityController.value = targetOpacity;
    }

    if (_obscureShowCharTicksPending > 0) {
      setState(() {
        _obscureShowCharTicksPending--;
      });
    }
  }

  /// 光标等待开始
  void _cursorWaitForStart(Timer timer) {
    assert(_kCursorBlinkHalfPeriod > _fadeDuration);
    _cursorTimer?.cancel();
    // 光标计时器
    _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  /// 启动光标计时器
  void _startCursorTimer() {
    // 目标光标可见性
    _targetCursorVisibility = true;
    // 光标闪烁不透明度控制器
    _cursorBlinkOpacityController.value = 1.0;
    // 调试确定性游标
    if (EditableText.debugDeterministicCursor) return;
    if (widget.cursorOpacityAnimates) {
      _cursorTimer =
          Timer.periodic(_kCursorBlinkWaitForStart, _cursorWaitForStart);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    }
  }

  /// 停止光标计时器
  void _stopCursorTimer({bool resetCharTicks = true}) {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    // 目标光标可见性
    _targetCursorVisibility = false;
    _cursorBlinkOpacityController.value = 0.0;
    if (EditableText.debugDeterministicCursor) return;
    if (resetCharTicks) _obscureShowCharTicksPending = 0;
    if (widget.cursorOpacityAnimates) {
      _cursorBlinkOpacityController.stop();
      _cursorBlinkOpacityController.value = 0.0;
    }
  }

  /// 必要时，启动或停止光标计时器
  void _startOrStopCursorTimerIfNeeded() {
    if (_cursorTimer == null && _hasFocus && _value.selection.isCollapsed)
      _startCursorTimer();
    else if (_cursorTimer != null &&
        (!_hasFocus || !_value.selection.isCollapsed)) _stopCursorTimer();
  }

  /// 是否更改了文本编辑值
  void _didChangeTextEditingValue() {
    _updateRemoteEditingValueIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    _textChangedSinceLastCaretUpdate = true;
    // TODO(abarth): Teach RenderEditable about ValueNotifier<TextEditingValue>
    // to avoid this setState().
    setState(() {/* We use widget.controller.value in build(). */});
  }

  /// 处理焦点已更改
  void _handleFocusChanged() {
    // 必要时打开或关闭输入连接
    _openOrCloseInputConnectionIfNeeded();
    // 必要时，启动或停止光标计时器
    _startOrStopCursorTimerIfNeeded();
    // 必要时，更新或释放选择覆盖
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      // 收听更改视图插入，这表示键盘出现。
      WidgetsBinding.instance.addObserver(this);
      // 上次底部视图插入
      _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
      // 在屏幕上显示插入符号
      _showCaretOnScreen();
      if (!_value.selection.isValid) {
        // Place cursor at the end if the selection is invalid when we receive focus.
        // 如果接收焦点时选择无效，请将光标放在末尾。
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _value.text.length),
            renderEditable,
            null);
      }
    } else {
      // 移除Observer
      WidgetsBinding.instance.removeObserver(this);
      // Clear the selection and composition state if this widget lost focus.
      // 如果此小部件失去焦点，请清除选择和合成状态。
      _value = TextEditingValue(text: _value.text);
    }
    // 更新保持活动
    updateKeepAlive();
  }

  /// 更新大小和转换
  void _updateSizeAndTransform() {
    if (_hasInputConnection) {
      final Size size = renderEditable.size;
      final Matrix4 transform = renderEditable.getTransformTo(null);
      // setEditableSizeAndTransform 设置可编辑大小和转换
      _textInputConnection.setEditableSizeAndTransform(size, transform);
      // 添加后帧回调
      SchedulerBinding.instance
          .addPostFrameCallback((Duration _) => _updateSizeAndTransform());
    }
  }

  /// 文本方向
  TextDirection get _textDirection {
    final TextDirection result =
        widget.textDirection ?? Directionality.of(context);
    assert(result != null,
        '$runtimeType created without a textDirection and with no ambient Directionality.');
    return result;
  }

  /// The renderer for this widget's [Editable] descendant.
  ///
  /// 此小部件的[可编辑]子体的呈现程序。
  ///
  /// This property is typically used to notify the renderer of input gestures
  /// when [ignorePointer] is true. See [RenderEditable.ignorePointer].
  ///
  /// 此属性通常用于在[ignorePointer]为true时通知渲染器输入手势。请参阅[RenderEditable.ignorePointer]。
  RenderEditable get renderEditable =>
      _editableKey.currentContext.findRenderObject() as RenderEditable;

  @override
  // 文本编辑值
  TextEditingValue get textEditingValue => _value;

  /// 设备像素比率
  double get _devicePixelRatio =>
      MediaQuery.of(context).devicePixelRatio ?? 1.0;

  @override

  /// 设置文本编辑值
  set textEditingValue(TextEditingValue value) {
    _selectionOverlay?.update(value);
    _formatAndSetValue(value);
  }

  @override

  /// 进入视野
  void bringIntoView(TextPosition position) {
    _scrollController.jumpTo(_getScrollOffsetForCaret(
        // 获取插入符号的本地Rect
        renderEditable.getLocalRectForCaret(position)));
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// 在当前光标的位置显示选择工具栏。
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  ///
  /// 如果无法显示工具栏，例如工具栏已经显示，或者当前没有文本选择时返回“false”。
  bool showToolbar() {
    // Web is using native dom elements to enable clipboard functionality of the
    // toolbar: copy, paste, select, cut. It might also provide additional
    // functionality depending on the browser (such as translate). Due to this
    // we should not show a Flutter toolbar for the editable text elements.
    // Web使用本地dom元素来启用工具栏的剪贴板功能：复制、粘贴、选择、剪切。
    // 它还可以根据浏览器提供其他功能（例如translate）。
    // 因此，我们不应该为可编辑文本元素显示Flutter工具栏。
    if (kIsWeb) {
      return false;
    }

    // toolbarIsVisible 工具栏可见
    if (_selectionOverlay == null || _selectionOverlay.toolbarIsVisible) {
      return false;
    }

    _selectionOverlay.showToolbar();
    return true;
  }

  @override
  // 隐藏工具栏
  void hideToolbar() {
    _selectionOverlay?.hide();
  }

  /// Toggles the visibility of the toolbar.
  ///
  /// 切换工具栏的可见性。
  void toggleToolbar() {
    assert(_selectionOverlay != null);
    // 工具栏可见
    if (_selectionOverlay.toolbarIsVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  // 复制语义
  VoidCallback _semanticsOnCopy(
      // 文本选择控件
      TextSelectionControls controls) {
    // 已启用选择
    return widget.selectionEnabled &&
            copyEnabled &&
            _hasFocus &&
            controls?.canCopy(this) == true
        ? () => controls.handleCopy(this)
        : null;
  }

  // 切分语义
  VoidCallback _semanticsOnCut(
      // 文本选择控件
      TextSelectionControls controls) {
    // 已启用选择
    return widget.selectionEnabled &&
            cutEnabled &&
            _hasFocus &&
            controls?.canCut(this) == true
        ? () => controls.handleCut(this)
        : null;
  }

  // 粘贴语义
  VoidCallback _semanticsOnPaste(TextSelectionControls controls) {
    // 已启用选择
    return widget.selectionEnabled &&
            // 已启用粘贴
            pasteEnabled &&
            // 有焦点
            _hasFocus &&
            controls?.canPaste(this) == true
        ? () => controls.handlePaste(this)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    // 调试检查有媒体查询
    assert(debugCheckHasMediaQuery(context));
    // 重定父级
    _focusAttachment.reparent();
    super.build(context); // See AutomaticKeepAliveClientMixin.

    // 选择控件
    final TextSelectionControls controls = widget.selectionControls;
    // 可滚动
    return Scrollable(
      // 从语义中排除
      excludeFromSemantics: true,
      // 轴线方向
      axisDirection: _isMultiline ? AxisDirection.down : AxisDirection.right,
      // 控制器
      controller: _scrollController,
      // 物理行为
      physics: widget.scrollPhysics,
      // 拖动开始行为
      dragStartBehavior: widget.dragStartBehavior,
      // 视区生成器
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        // 合成变换目标
        return CompositedTransformTarget(
          // 工具栏层链接
          link: _toolbarLayerLink,
          // 语义
          child: Semantics(
            // 复制语义
            onCopy: _semanticsOnCopy(controls),
            // 剪切语义
            onCut: _semanticsOnCut(controls),
            // 粘贴语义
            onPaste: _semanticsOnPaste(controls),
            // 可编辑
            child: _Editable(
              key: _editableKey,
              // 开始句柄层链接
              startHandleLayerLink: _startHandleLayerLink,
              // 结束句柄层链接
              endHandleLayerLink: _endHandleLayerLink,
              textSpan: buildTextSpan(),
              value: _value,
              // 光标颜色
              cursorColor: _cursorColor,
              // 背景光标颜色
              backgroundCursorColor: widget.backgroundCursorColor,
              // 显示光标
              showCursor: EditableText.debugDeterministicCursor
                  ? ValueNotifier<bool>(widget.showCursor)
                  : _cursorVisibilityNotifier,
              // 强制线
              forceLine: widget.forceLine,
              // 只读
              readOnly: widget.readOnly,
              // 聚焦
              hasFocus: _hasFocus,
              // 最大行
              maxLines: widget.maxLines,
              // 最小行
              minLines: widget.minLines,
              // 扩展
              expands: widget.expands,
              // 结构样式
              strutStyle: widget.strutStyle,
              // 选择颜色
              selectionColor: widget.selectionColor,
              // 文本比例因子
              textScaleFactor: widget.textScaleFactor ??
                  MediaQuery.textScaleFactorOf(context),
              // 文本对齐
              textAlign: widget.textAlign,
              // 文本方向
              textDirection: _textDirection,
              // 本地化
              locale: widget.locale,
              // 文本宽度因子
              textWidthBasis: widget.textWidthBasis,
              // 模糊文本
              obscureText: widget.obscureText,
              // 自动校正
              autocorrect: widget.autocorrect,
              // 智能数据类型
              smartDashesType: widget.smartDashesType,
              // 智能引号类型
              smartQuotesType: widget.smartQuotesType,
              // 开启建议
              enableSuggestions: widget.enableSuggestions,
              // 偏移量
              offset: offset,
              // 选择改变
              onSelectionChanged: _handleSelectionChanged,
              // 插入符号更改时
              onCaretChanged: _handleCaretChanged,
              // 渲染器忽略指针
              rendererIgnoresPointer: widget.rendererIgnoresPointer,
              // 光标宽度
              cursorWidth: widget.cursorWidth,
              // 光标半径
              cursorRadius: widget.cursorRadius,
              // 光标偏移量
              cursorOffset: widget.cursorOffset,
              // 在文本上方绘制光标
              paintCursorAboveText: widget.paintCursorAboveText,
              // 启用交互式选择
              enableInteractiveSelection: widget.enableInteractiveSelection,
              // 文本选择委托
              textSelectionDelegate: this,
              // 设备像素比
              devicePixelRatio: _devicePixelRatio,
            ),
          ),
        );
      },
    );
  }

  /// Builds [TextSpan] from current editing value.
  ///
  /// 从当前编辑值生成[TextSpan]。
  ///
  /// By default makes text in composing range appear as underlined.
  /// Descendants can override this method to customize appearance of text.
  ///
  /// 默认情况下，使组成范围内的文本显示为下划线。子体可以重写此方法以自定义文本的外观。
  TextSpan buildTextSpan() {
    // 模糊文本
    if (widget.obscureText) {
      String text = _value.text;
      // 模糊字符
      text = RenderEditable.obscuringCharacter * text.length;
      final int o =
          _obscureShowCharTicksPending > 0 ? _obscureLatestCharIndex : null;
      if (o != null && o >= 0 && o < text.length)
        text = text.replaceRange(o, o + 1, _value.text.substring(o, o + 1));
      return TextSpan(style: widget.style, text: text);
    }
    // Read only mode should not paint text composing.
    // 只读模式不应绘制文本合成。
    return widget.controller.buildTextSpan(
      style: widget.style,
      withComposing: !widget.readOnly,
    );
  }
}

class _Editable extends LeafRenderObjectWidget {
  const _Editable({
    Key key,
    // 文本范围
    this.textSpan,
    // 值
    this.value,
    // 开始句柄层链接
    this.startHandleLayerLink,
    // 结束句柄层链接
    this.endHandleLayerLink,
    // 光标颜色
    this.cursorColor,
    // 背景光标颜色
    this.backgroundCursorColor,
    // 显示光标
    this.showCursor,
    // 强制线
    this.forceLine,
    // 只读
    this.readOnly,
    // 文本宽度因子
    this.textWidthBasis,
    // 聚焦
    this.hasFocus,
    // 最大行
    this.maxLines,
    // 最小行
    this.minLines,
    // 扩展
    this.expands,
    // 结构样式
    this.strutStyle,
    // 选择颜色
    this.selectionColor,
    // 文本缩放因子
    this.textScaleFactor,
    // 文本对齐
    this.textAlign,
    // 文本方向
    @required this.textDirection,
    // 本地化
    this.locale,
    // 模糊文本
    this.obscureText,
    // 自动校正
    this.autocorrect,
    // 智能数据类型
    this.smartDashesType,
    // 智能引号类型
    this.smartQuotesType,
    // 开启建议
    this.enableSuggestions,
    // 偏移量
    this.offset,
    // 选择更改时
    this.onSelectionChanged,
    // 插入符号更改时
    this.onCaretChanged,
    // 渲染器忽略指针
    this.rendererIgnoresPointer = false,
    // 光标宽度
    this.cursorWidth,
    // 光标半径
    this.cursorRadius,
    // 光标偏移量
    this.cursorOffset,
    // 启用交互式选择
    this.enableInteractiveSelection = true,
    // 文本选择委托
    this.textSelectionDelegate,
    // 在文本上方绘制光标
    this.paintCursorAboveText,
    // 设备像素比率
    this.devicePixelRatio,
  })  : assert(textDirection != null),
        assert(rendererIgnoresPointer != null),
        super(key: key);

  /// 文本范围
  final TextSpan textSpan;

  /// 值
  final TextEditingValue value;

  /// 光标颜色
  final Color cursorColor;

  /// 开始句柄层链接
  final LayerLink startHandleLayerLink;

  /// 结束句柄层链接
  final LayerLink endHandleLayerLink;

  /// 背景光标颜色
  final Color backgroundCursorColor;

  /// 显示光标
  final ValueNotifier<bool> showCursor;

  /// 强制线
  final bool forceLine;

  /// 只读
  final bool readOnly;

  /// 聚焦
  final bool hasFocus;

  /// 最大行
  final int maxLines;

  /// 最小行
  final int minLines;

  /// 扩展
  final bool expands;

  /// 结构样式
  final StrutStyle strutStyle;

  /// 选择颜色
  final Color selectionColor;

  /// 文本缩放因子
  final double textScaleFactor;

  /// 文本对齐
  final TextAlign textAlign;

  /// 文本方向
  final TextDirection textDirection;

  /// 本地化
  final Locale locale;

  /// 模糊文本
  final bool obscureText;

  /// 文本宽度基
  final TextWidthBasis textWidthBasis;

  /// 自动校正
  final bool autocorrect;

  /// 智能数据类型
  final SmartDashesType smartDashesType;

  /// 智能引号类型
  final SmartQuotesType smartQuotesType;

  /// 开启建议
  final bool enableSuggestions;

  /// 偏移量
  final ViewportOffset offset;

  /// 选择更改时
  final SelectionChangedHandler onSelectionChanged;

  /// 插入符号更改时
  final CaretChangedHandler onCaretChanged;

  /// 渲染器忽略指针
  final bool rendererIgnoresPointer;

  /// 光标宽度
  final double cursorWidth;

  /// 光标半径
  final Radius cursorRadius;

  /// 光标偏移量
  final Offset cursorOffset;

  /// 启用交互式选择
  final bool enableInteractiveSelection;

  /// 文本选择委托
  final TextSelectionDelegate textSelectionDelegate;

  /// 设备像素比率
  final double devicePixelRatio;

  /// 在文本上方绘制光标
  final bool paintCursorAboveText;

  @override
  // 创建渲染对象
  RenderEditable createRenderObject(BuildContext context) {
    // 渲染可编辑
    return RenderEditable(
      text: textSpan,
      cursorColor: cursorColor,
      // 开始句柄层链接
      startHandleLayerLink: startHandleLayerLink,
      // 结束句柄层链接
      endHandleLayerLink: endHandleLayerLink,
      // 背景光标颜色
      backgroundCursorColor: backgroundCursorColor,
      showCursor: showCursor,
      forceLine: forceLine,
      readOnly: readOnly,
      hasFocus: hasFocus,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      strutStyle: strutStyle,
      selectionColor: selectionColor,
      textScaleFactor: textScaleFactor,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale ?? Localizations.localeOf(context, nullOk: true),
      selection: value.selection,
      offset: offset,
      onSelectionChanged: onSelectionChanged,
      onCaretChanged: onCaretChanged,
      ignorePointer: rendererIgnoresPointer,
      obscureText: obscureText,
      textWidthBasis: textWidthBasis,
      cursorWidth: cursorWidth,
      cursorRadius: cursorRadius,
      cursorOffset: cursorOffset,
      // 在文本上方绘制光标
      paintCursorAboveText: paintCursorAboveText,
      // 启用交互式选择
      enableInteractiveSelection: enableInteractiveSelection,
      // 文本选择委托
      textSelectionDelegate: textSelectionDelegate,
      // 设备像素比率
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  // 更新渲染对象
  void updateRenderObject(BuildContext context, RenderEditable renderObject) {
    renderObject
      ..text = textSpan
      ..cursorColor = cursorColor
      // 开始句柄层链接
      ..startHandleLayerLink = startHandleLayerLink
      // 结束句柄层链接
      ..endHandleLayerLink = endHandleLayerLink
      ..showCursor = showCursor
      ..forceLine = forceLine
      ..readOnly = readOnly
      ..hasFocus = hasFocus
      ..maxLines = maxLines
      ..minLines = minLines
      ..expands = expands
      ..strutStyle = strutStyle
      ..selectionColor = selectionColor
      ..textScaleFactor = textScaleFactor
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..locale = locale ?? Localizations.localeOf(context, nullOk: true)
      ..selection = value.selection
      ..offset = offset
      ..onSelectionChanged = onSelectionChanged
      ..onCaretChanged = onCaretChanged
      // 渲染器忽略指针
      ..ignorePointer = rendererIgnoresPointer
      ..textWidthBasis = textWidthBasis
      ..obscureText = obscureText
      ..cursorWidth = cursorWidth
      ..cursorRadius = cursorRadius
      ..cursorOffset = cursorOffset
      // 文本选择委托
      ..textSelectionDelegate = textSelectionDelegate
      // 设备像素比率
      ..devicePixelRatio = devicePixelRatio
      // 在文本上方绘制光标
      ..paintCursorAboveText = paintCursorAboveText;
  }
}
