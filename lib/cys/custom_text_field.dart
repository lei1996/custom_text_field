// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

// import 'debug.dart';
// import 'feedback.dart';
// import 'input_decorator.dart';
// import 'material.dart';
// import 'material_localizations.dart';
// import 'selectable_text.dart' show iOSHorizontalOffset;
// import 'text_selection.dart';
// import 'theme.dart';

// export 'package:flutter/services.dart' show TextInputType, TextInputAction, TextCapitalization, SmartQuotesType, SmartDashesType;

/// Signature for the [TextField.buildCounter] callback.
/// 输入计数器小部件生成器
typedef InputCounterWidgetBuilder = Widget Function(
  /// The build context for the TextField
  BuildContext context, {

  /// The length of the string currently in the input.
  /// 当前长度
  @required int currentLength,

  /// The maximum string length that can be entered into the TextField.
  /// 最大长度
  @required int maxLength,

  /// Whether or not the TextField is currently focused.  Mainly provided for
  /// the [liveRegion] parameter in the [Semantics] widget for accessibility.
  /// 是否聚焦
  @required bool isFocused,
});

// 文本字段选择手势检测器生成器
class _TextFieldSelectionGestureDetectorBuilder
    // 文本选择手势检测器生成器
    extends TextSelectionGestureDetectorBuilder {
  _TextFieldSelectionGestureDetectorBuilder({
    @required _CustomTextFieldState state,
  })  : _state = state,
        super(delegate: state);

  final _CustomTextFieldState _state;

  @override
  // 强制启动开始
  void onForcePressStart(
      // 强制按详细信息
      ForcePressDetails details) {
    super.onForcePressStart(details);
    // 选择启用
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      // 显示工具栏
      editableText.showToolbar();
    }
  }

  @override
  // 强制启动结束
  void onForcePressEnd(ForcePressDetails details) {
    // Not required.
  }

  @override
  // 单长点击移动更新
  void onSingleLongTapMoveUpdate(
      // 长按移动更新详细信息
      LongPressMoveUpdateDetails details) {
    // 已启用选择
    if (delegate.selectionEnabled) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          // 选择位置
          renderEditable.selectPositionAt(
            // 全局位置
            from: details.globalPosition,
            // 原因: 长按
            cause: SelectionChangedCause.longPress,
          );
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // 选择范围内的单词
          renderEditable.selectWordsInRange(
            // 全局定位 - 与原点的偏移
            from: details.globalPosition - details.offsetFromOrigin,
            // 全局定位
            to: details.globalPosition,
            // 原因: 长按
            cause: SelectionChangedCause.longPress,
          );
          break;
      }
    }
  }

  @override
  // 一次轻敲
  void onSingleTapUp(
      // 轻敲详细信息
      TapUpDetails details) {
    // 隐藏工具条
    editableText.hideToolbar();
    // 已启用选择
    if (delegate.selectionEnabled) {
      // 从传入的state中获得 平台信息
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          // 选择字边缘
          renderEditable.selectWordEdge(cause: SelectionChangedCause.tap);
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // 选择位置
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
          break;
      }
    }
    // 请求键盘
    _state._requestKeyboard();
    if (_state.widget.onTap != null) _state.widget.onTap();
  }

  @override
  // 一次长按 开始
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          // 选择位置
          renderEditable.selectPositionAt(
            // 全局定位
            from: details.globalPosition,
            // 长按
            cause: SelectionChangedCause.longPress,
          );
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // 选择单词
          renderEditable.selectWord(cause: SelectionChangedCause.longPress);
          Feedback.forLongPress(_state.context);
          break;
      }
    }
  }
}

/// A material design text field.
/// 材料设计文本字段。
///
/// A text field lets the user enter text, either with hardware keyboard or with
/// an onscreen keyboard.
/// 文本字段允许用户使用硬件键盘或屏幕键盘输入文本。
///
/// The text field calls the [onChanged] callback whenever the user changes the
/// text in the field. If the user indicates that they are done typing in the
/// field (e.g., by pressing a button on the soft keyboard), the text field
/// calls the [onSubmitted] callback.
/// 每当用户更改字段中的文本时，文本字段调用[onChanged]回调。如果用户指示他们已经在
/// 字段中输入完毕（例如，通过按下软键盘上的按钮），文本字段将调用[onSubmitted]回调。
///
/// To control the text that is displayed in the text field, use the
/// [controller]. For example, to set the initial value of the text field, use
/// a [controller] that already contains some text. The [controller] can also
/// control the selection and composing region (and to observe changes to the
/// text, selection, and composing region).
/// 要控制文本字段中显示的文本，请使用[控制器]。例如，要设置文本字段的初始值，请使用
/// 已经包含一些文本的[控制器]。[控制器]还可以控制选择和合成区域（并观察对文本、
/// 选择和合成区域的更改）。
///
/// By default, a text field has a [decoration] that draws a divider below the
/// text field. You can use the [decoration] property to control the decoration,
/// for example by adding a label or an icon. If you set the [decoration]
/// property to null, the decoration will be removed entirely, including the
/// extra padding introduced by the decoration to save space for the labels.
/// 默认情况下，文本字段有一个[装饰]在文本字段下面绘制分隔符。您可以使用[decoration]属性
/// 来控制装饰，例如添加标签或图标。如果将[decoration]属性设置为空，则装饰将被完全移除，
/// 包括装饰引入的额外填充，以节省标签空间。
///
/// If [decoration] is non-null (which is the default), the text field requires
/// one of its ancestors to be a [Material] widget.
/// 如果[decoration]为非空（这是默认值），则文本字段要求其祖先之一为[Material]小部件。
///
/// To integrate the [TextField] into a [Form] with other [FormField] widgets,
/// consider using [TextFormField].
/// 要将[TextField]与其他[FormField]小部件集成到[Form]中，请考虑使用[TextFormField]。
///
/// Remember to [dispose] of the [TextEditingController] when it is no longer needed.
/// This will ensure we discard any resources used by the object.
/// 当不再需要[TextEditingController]时，请记住[dispose]。这将确保丢弃该对象使用的任何资源。
///
/// {@tool snippet}
/// This example shows how to create a [TextField] that will obscure input. The
/// [InputDecoration] surrounds the field in a border using [OutlineInputBorder]
/// and adds a label.
/// 这个例子展示了如何创建一个隐藏输入的[TextField]。[InputDecoration]使用
/// [OutlineInputBorder]将字段包围在边框中并添加标签。
///
/// ![](https://flutter.github.io/assets-for-api-docs/assets/material/text_field.png)
///
/// ```dart
/// TextField(
///   obscureText: true,
///   decoration: InputDecoration(
///     border: OutlineInputBorder(),
///     labelText: 'Password',
///   ),
/// )
/// ```
/// {@end-tool}
///
/// ## Reading values
/// ## 读取值
///
/// A common way to read a value from a TextField is to use the [onSubmitted]
/// callback. This callback is applied to the text field's current value when
/// the user finishes editing.
/// 从文本字段读取值的一种常见方法是使用[onSubmitted]回调。当用户完成编辑时，
/// 此回调将应用于文本字段的当前值。
///
/// {@tool dartpad --template=stateful_widget_material}
///
/// This sample shows how to get a value from a TextField via the [onSubmitted]
/// callback.
/// 此示例显示如何通过[onSubmitted]回调从文本字段获取值。
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
///     body: Center(
///       child: TextField(
///         controller: _controller,
///         onSubmitted: (String value) async {
///           await showDialog<void>(
///             context: context,
///             builder: (BuildContext context) {
///               return AlertDialog(
///                 title: const Text('Thanks!'),
///                 content: Text ('You typed "$value".'),
///                 actions: <Widget>[
///                   FlatButton(
///                     onPressed: () { Navigator.pop(context); },
///                     child: const Text('OK'),
///                   ),
///                 ],
///               );
///             },
///           );
///         },
///       ),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// For most applications the [onSubmitted] callback will be sufficient for
/// reacting to user input.
/// 对于大多数应用程序，[onSubmitted]回调将足以对用户输入作出反应。
///
/// The [onEditingComplete] callback also runs when the user finishes editing.
/// It's different from [onSubmitted] because it has a default value which
/// updates the text controller and yields the keyboard focus. Applications that
/// require different behavior can override the default [onEditingComplete]
/// callback.
/// 当用户完成编辑时，[onEditingComplete]回调也会运行。它与[onSubmitted]不同，
/// 因为它有一个默认值，用于更新文本控制器并生成键盘焦点。需要不同行为的应用程序可以覆盖默
/// 认的[onEditingComplete]回调。
///
/// Keep in mind you can also always read the current string from a TextField's
/// [TextEditingController] using [TextEditingController.text].
/// 请记住，您也可以使用[TextEditingController.text]从文本字段
/// 的[TextEditingController]读取当前字符串。
///
/// See also:
///
///  * <https://material.io/design/components/text-fields.html>
///  * [TextFormField], which integrates with the [Form] widget.
///  * [TextFormField]，它与[Form]小部件集成。
/// 
///  * [InputDecorator], which shows the labels and other visual elements that
///    surround the actual text editing widget.
///  * [InputDecorator]，它显示实际文本编辑小部件周围的标签和其他视觉元素。
/// 
///  * [EditableText], which is the raw text editing control at the heart of a
///    [TextField]. The [EditableText] widget is rarely used directly unless
///    you are implementing an entirely different design language, such as
///    Cupertino.
///  * [可编辑文本]，这是位于[文本字段]中心的原始文本编辑控件。除非实现完全不同的设计语言，例如Cupertino，[EditableText]小部件很少直接使用。
/// 
///  * Learn how to use a [TextEditingController] in one of our
///    [cookbook recipe](https://flutter.dev/docs/cookbook/forms/text-field-changes#2-use-a-texteditingcontroller)s.
///  * 了解如何在[食谱]中使用[文本编辑控制器] (https://flutter.dev/docs/cookbook/forms/text-field-changes#2-use-a-texteditingcontroller)s.
class CustomTextField extends StatefulWidget {
  /// Creates a Material Design text field.
  /// 创建材质设计文本字段。
  ///
  /// If [decoration] is non-null (which is the default), the text field requires
  /// one of its ancestors to be a [Material] widget.
  /// 如果[decoration]为非空（这是默认值），则文本字段要求其祖先之一为[Material]小部件。
  ///
  /// To remove the decoration entirely (including the extra padding introduced
  /// by the decoration to save space for the labels), set the [decoration] to
  /// null.
  /// 若要完全移除装饰（包括装饰引入的额外填充以节省标签空间），请将[装饰]设置为空。
  ///
  /// The [maxLines] property can be set to null to remove the restriction on
  /// the number of lines. By default, it is one, meaning this is a single-line
  /// text field. [maxLines] must not be zero.
  /// [maxLines]属性可以设置为空，以删除对行数的限制。默认情况下，它是一个，
  /// 这意味着这是一个单行文本字段。[maxLines]不能为零。
  ///
  /// The [maxLength] property is set to null by default, which means the
  /// number of characters allowed in the text field is not restricted. If
  /// [maxLength] is set a character counter will be displayed below the
  /// field showing how many characters have been entered. If the value is
  /// set to a positive integer it will also display the maximum allowed
  /// number of characters to be entered.  If the value is set to
  /// [CustomTextField.noMaxLength] then only the current length is displayed.
  /// 默认情况下，[maxLength]属性设置为空，这意味着文本字段中允许的字符数不受限制。
  /// 如果设置了[maxLength]，字符计数器将显示在显示已输入多少字符的字段下方。
  /// 如果将该值设置为正整数，它还将显示允许输入的最大字符数。如果该值设置
  /// 为[CustomTextField.noMaxLength]，则只显示当前长度。
  ///
  /// After [maxLength] characters have been input, additional input
  /// is ignored, unless [maxLengthEnforced] is set to false. The text field
  /// enforces the length with a [LengthLimitingTextInputFormatter], which is
  /// evaluated after the supplied [inputFormatters], if any. The [maxLength]
  /// value must be either null or greater than zero.
  /// 
  /// 输入[maxLength]个字符后，将忽略其他输入，除非[maxlengthforced]设置为false。
  /// 文本字段使用[LengthLimitingTextInputFormatter]强制长度，该长度在提供的
  /// [inputFormatters]之后计算（如果有）。[maxLength]值必须为空或大于零。
  ///
  /// If [maxLengthEnforced] is set to false, then more than [maxLength]
  /// characters may be entered, and the error counter and divider will
  /// switch to the [decoration.errorStyle] when the limit is exceeded.
  /// 如果[MaxLengthForced]设置为false，则可以输入超过[maxLength]个字符，
  /// 当超过限制时，错误计数器和分隔符将切换到[decoration.errorStyle]。
  ///
  /// The text cursor is not shown if [showCursor] is false or if [showCursor]
  /// is null (the default) and [readOnly] is true.
  /// 如果[showCursor]为false或[showCursor]为null（默认值）
  /// 且[readOnly]为true，则不显示文本光标。
  ///
  /// The [textAlign], [autofocus], [obscureText], [readOnly], [autocorrect],
  /// [maxLengthEnforced], [scrollPadding], [maxLines], [maxLength],
  /// and [enableSuggestions] arguments must not be null.
  /// [文本对齐]、[自动聚焦]、[模糊文本]、[只读]、[自动更正]、[最大长度强制]、[滚动填充]、
  /// [最大行数]、[最大长度]和[启用建议]参数不能为空。
  ///
  /// See also:
  ///
  ///  * [maxLength], which discusses the precise meaning of "number of
  ///    characters" and how it may differ from the intuitive meaning.
  ///  * [最大长度]，它讨论了“字符数”的精确含义，以及它与直观含义的区别。
  const CustomTextField({
    Key key,
    // 控制器
    this.controller,
    // 聚焦节点
    this.focusNode,
    // 装饰
    this.decoration = const InputDecoration(),
    // 键盘类型
    TextInputType keyboardType,
    // 文本输入
    this.textInputAction,
    // 文本大写
    this.textCapitalization = TextCapitalization.none,
    // 样式
    this.style,
    // 结构样式
    this.strutStyle,
    // 文本对齐
    this.textAlign = TextAlign.start,
    // 文本垂直对齐
    this.textAlignVertical,
    // 文本方向
    this.textDirection,
    // 只读
    this.readOnly = false,
    // 工具栏配置项
    ToolbarOptions toolbarOptions,
    // 显示光标
    this.showCursor,
    // 自动聚焦
    this.autofocus = false,
    // 模糊文本
    this.obscureText = false,
    // 自动更正
    this.autocorrect = true,
    // 智能数据类型
    SmartDashesType smartDashesType,
    // 智能引号类型
    SmartQuotesType smartQuotesType,
    // 启用建议
    this.enableSuggestions = true,
    // 最大行
    this.maxLines = 1,
    // 最小行
    this.minLines,
    // 扩展
    this.expands = false,
    // 最大长度
    this.maxLength,
    // 最大限制长度
    this.maxLengthEnforced = true,
    // 更改时
    this.onChanged,
    // 完成一次编辑
    this.onEditingComplete,
    // 提交
    this.onSubmitted,
    // 输入格式化程序
    this.inputFormatters,
    // 启用
    this.enabled,
    // 光标宽度
    this.cursorWidth = 2.0,
    // 光标半径
    this.cursorRadius,
    // 光标颜色
    this.cursorColor,
    // 键盘外观
    this.keyboardAppearance,
    // 滚动条 内边距
    this.scrollPadding = const EdgeInsets.all(20.0),
    // 拖动开始行为
    this.dragStartBehavior = DragStartBehavior.start,
    // 启用交互式选择
    this.enableInteractiveSelection = true,
    // 轻击
    this.onTap,
    // 构建计数器
    this.buildCounter,
    // 滚动条控制器
    this.scrollController,
    // 滚动条 物理行为
    this.scrollPhysics,
  })  : assert(textAlign != null),
        assert(readOnly != null),
        assert(autofocus != null),
        assert(obscureText != null),
        assert(autocorrect != null),
        smartDashesType = smartDashesType ??
            (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ??
            (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        assert(enableSuggestions != null),
        assert(enableInteractiveSelection != null),
        assert(maxLengthEnforced != null),
        assert(scrollPadding != null),
        assert(dragStartBehavior != null),
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
        assert(maxLength == null ||
            maxLength == CustomTextField.noMaxLength ||
            maxLength > 0),
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        toolbarOptions = toolbarOptions ??
            (obscureText
                ? const ToolbarOptions(
                    selectAll: true,
                    paste: true,
                  )
                : const ToolbarOptions(
                    copy: true,
                    cut: true,
                    selectAll: true,
                    paste: true,
                  )),
        super(key: key);

  /// Controls the text being edited.
  /// 
  /// 控制正在编辑的文本。
  ///
  /// If null, this widget will create its own [TextEditingController].
  /// 
  /// 如果为空，这个小部件将创建自己的[TextEditingController]。
  /// 文本编辑控制器
  final TextEditingController controller;

  /// Defines the keyboard focus for this widget.
  /// 
  /// 定义此小部件的键盘焦点。
  ///
  /// The [focusNode] is a long-lived object that's typically managed by a
  /// [StatefulWidget] parent. See [FocusNode] for more information.
  /// 
  /// [focusNode]是一个长寿命对象，通常由[StatefulWidget]父级管理。有关详细信息，请参阅[FocusNode]。
  ///
  /// To give the keyboard focus to this widget, provide a [focusNode] and then
  /// use the current [FocusScope] to request the focus:
  /// 
  /// 要将键盘焦点赋予此小部件，请提供[FocusMode]，然后使用当前的[FocusScope]请求焦点：
  ///
  /// ```dart
  /// FocusScope.of(context).requestFocus(myFocusNode);
  /// ```
  ///
  /// This happens automatically when the widget is tapped.
  /// 
  /// 当点击小部件时，这会自动发生。
  ///
  /// To be notified when the widget gains or loses the focus, add a listener
  /// to the [focusNode]:
  /// 
  /// 要在小部件获得或失去焦点时得到通知，请将侦听器添加到[focusNode]：
  ///
  /// ```dart
  /// focusNode.addListener(() { print(myFocusNode.hasFocus); });
  /// ```
  ///
  /// If null, this widget will create its own [FocusNode].
  /// 
  /// 如果为空，这个小部件将创建自己的[FocusNode]。
  ///
  /// ## Keyboard
  ///
  /// Requesting the focus will typically cause the keyboard to be shown
  /// if it's not showing already.
  /// 
  /// 如果键盘尚未显示，请求焦点通常会导致键盘显示出来。
  ///
  /// On Android, the user can hide the keyboard - without changing the focus -
  /// with the system back button. They can restore the keyboard's visibility
  /// by tapping on a text field.  The user might hide the keyboard and
  /// switch to a physical keyboard, or they might just need to get it
  /// out of the way for a moment, to expose something it's
  /// obscuring. In this case requesting the focus again will not
  /// cause the focus to change, and will not make the keyboard visible.
  /// 
  /// 在Android上，用户可以使用系统后退按钮隐藏键盘，而不改变焦点。
  /// 他们可以通过点击文本字段来恢复键盘的可见性。用户可能会隐藏键盘并切换到物理键盘，
  /// 或者他们可能只需要让键盘暂时不受影响，就可以暴露它所隐藏的内容。在这种情况下，
  /// 再次请求焦点不会导致焦点更改，也不会使键盘可见。
  ///
  /// This widget builds an [EditableText] and will ensure that the keyboard is
  /// showing when it is tapped by calling [EditableTextState.requestKeyboard()].
  /// 
  /// 此小部件生成一个[EditableText]，并通过调用 [EditableTextState.requestKeyboard()] 确保键盘在被点击时显示出来。
  /// 聚焦节点
  final FocusNode focusNode;

  /// The decoration to show around the text field.
  /// 
  /// 显示在文本字段周围的装饰。
  ///
  /// By default, draws a horizontal line under the text field but can be
  /// configured to show an icon, label, hint text, and error text.
  /// 
  /// 默认情况下，在文本字段下绘制水平线，但可以配置为显示图标、标签、提示文本和错误文本。
  ///
  /// Specify null to remove the decoration entirely (including the
  /// extra padding introduced by the decoration to save space for the labels).
  /// 
  /// 指定null以完全移除装饰 (包括装饰引入的额外填充以节省标签空间).
  /// 输入装饰
  final InputDecoration decoration;

  /// {@macro flutter.widgets.editableText.keyboardType}
  /// 文本输入类型
  final TextInputType keyboardType;

  /// The type of action button to use for the keyboard.
  /// 
  /// 用于键盘的操作按钮的类型。
  ///
  /// Defaults to [TextInputAction.newline] if [keyboardType] is
  /// [TextInputType.multiline] and [TextInputAction.done] otherwise.
  /// 
  /// 如果[keyboardType]是[TextInputType.multiline]，则默认为
  /// [textinputtaction.newline]，否则默认为[textinputtaction.done]。
  /// 文本输入操作
  final TextInputAction textInputAction;

  /// {@macro flutter.widgets.editableText.textCapitalization}
  /// 文本大写
  final TextCapitalization textCapitalization;

  /// The style to use for the text being edited.
  /// 
  /// 要用于正在编辑的文本的样式。
  ///
  /// This text style is also used as the base style for the [decoration].
  /// 
  /// 此文本样式也用作[装饰]的基本样式。
  ///
  /// If null, defaults to the `subtitle1` text style from the current [Theme].
  /// 如果为空，则默认为当前[主题]中的 `subtitle1` 文本样式。
  /// 文本样式
  final TextStyle style;

  /// {@macro flutter.widgets.editableText.strutStyle}
  /// 结构样式
  final StrutStyle strutStyle;

  /// {@macro flutter.widgets.editableText.textAlign}
  /// 文本对齐
  final TextAlign textAlign;

  /// {@macro flutter.widgets.inputDecorator.textAlignVertical}
  /// 文本垂直对齐
  final TextAlignVertical textAlignVertical;

  /// {@macro flutter.widgets.editableText.textDirection}
  /// 文本方向
  final TextDirection textDirection;

  /// {@macro flutter.widgets.editableText.autofocus}
  /// 自动聚焦
  final bool autofocus;

  /// {@macro flutter.widgets.editableText.obscureText}
  /// 模糊文本
  final bool obscureText;

  /// {@macro flutter.widgets.editableText.autocorrect}
  /// 自动校正
  final bool autocorrect;

  /// {@macro flutter.services.textInput.smartDashesType}
  /// 智能数据提示
  final SmartDashesType smartDashesType;

  /// {@macro flutter.services.textInput.smartQuotesType}
  /// 智能引号类型
  final SmartQuotesType smartQuotesType;

  /// {@macro flutter.services.textInput.enableSuggestions}
  /// 启用建议
  final bool enableSuggestions;

  /// {@macro flutter.widgets.editableText.maxLines}
  /// 最大行
  final int maxLines;

  /// {@macro flutter.widgets.editableText.minLines}
  /// 最小行
  final int minLines;

  /// {@macro flutter.widgets.editableText.expands}
  /// 扩展
  final bool expands;

  /// {@macro flutter.widgets.editableText.readOnly}
  /// 只读
  final bool readOnly;

  /// Configuration of toolbar options.
  /// 
  /// 工具栏选项的配置。
  ///
  /// If not set, select all and paste will default to be enabled. Copy and cut
  /// will be disabled if [obscureText] is true. If [readOnly] is true,
  /// paste and cut will be disabled regardless.
  /// 
  /// 如果未设置，则全选并默认启用粘贴。如果[obseretext]为true，则将禁用复制和剪切。
  /// 如果[readOnly]为true，则不管如何，粘贴和剪切都将被禁用。
  /// 
  /// 工具栏选项
  final ToolbarOptions toolbarOptions;

  /// {@macro flutter.widgets.editableText.showCursor}
  /// 显示光标
  final bool showCursor;

  /// If [maxLength] is set to this value, only the "current input length"
  /// part of the character counter is shown.
  /// 如果[maxLength]设置为该值，则只显示字符计数器的“当前输入长度”部分。
  static const int noMaxLength = -1;

  /// The maximum number of characters (Unicode scalar values) to allow in the
  /// text field.
  /// 
  /// 允许在文本字段中的最大字符数（Unicode标量值）。
  ///
  /// If set, a character counter will be displayed below the
  /// field showing how many characters have been entered. If set to a number
  /// greater than 0, it will also display the maximum number allowed. If set
  /// to [CustomTextField.noMaxLength] then only the current character count is displayed.
  /// 
  /// 如果设置，字符计数器将显示在字段下方，显示已输入的字符数。如果设置为大于0的数字，它也将
  /// 显示允许的最大数目。如果设置为[CustomTextField.noMaxLength]，则只显示当前字符数。
  ///
  /// After [maxLength] characters have been input, additional input
  /// is ignored, unless [maxLengthEnforced] is set to false. The text field
  /// enforces the length with a [LengthLimitingTextInputFormatter], which is
  /// evaluated after the supplied [inputFormatters], if any.
  /// 
  /// 输入[maxLength]个字符后，将忽略其他输入，除非[maxlengthforced]设置为false。
  /// 文本字段使用[LengthLimitingTextInputFormatter]强制长度，该长度在提供
  /// 的[inputFormatters]之后计算（如果有）。
  ///
  /// This value must be either null, [CustomTextField.noMaxLength], or greater than 0.
  /// If null (the default) then there is no limit to the number of characters
  /// that can be entered. If set to [CustomTextField.noMaxLength], then no limit will
  /// be enforced, but the number of characters entered will still be displayed.
  /// 
  /// 此值必须为空，[CustomTextField.noMaxLength]，或大于0。如果为空（默认值），
  /// 则可以输入的字符数没有限制。如果设置为[CustomTextField.noMaxLength]，
  /// 则不会执行任何限制，但仍将显示输入的字符数。
  ///
  /// Whitespace characters (e.g. newline, space, tab) are included in the
  /// character count.
  /// 
  /// 空白字符（例如换行符、空格、制表符）包含在字符计数中。
  ///
  /// If [maxLengthEnforced] is set to false, then more than [maxLength]
  /// characters may be entered, but the error counter and divider will
  /// switch to the [decoration.errorStyle] when the limit is exceeded.
  /// 
  /// 如果[MaxLengthForced]设置为false，则可以输入超过[maxLength]个字符，
  /// 但当超过限制时，错误计数器和分隔符将切换到[decoration.errorStyle]。
  ///
  /// ## Limitations
  ///
  /// The text field does not currently count Unicode grapheme clusters (i.e.
  /// characters visible to the user), it counts Unicode scalar values, which
  /// leaves out a number of useful possible characters (like many emoji and
  /// composed characters), so this will be inaccurate in the presence of those
  /// characters. If you expect to encounter these kinds of characters, be
  /// generous in the maxLength used.
  /// 
  /// 文本字段当前不计算Unicode字形群集（即用户可见的字符），它计算Unicode标量值，
  /// 这会遗漏许多有用的可能字符（如许多表情符号和组合字符），因此在这些字符存在时这将
  /// 不准确。如果您希望遇到这些类型的字符，请在使用的maxLength中大方一些。
  ///
  /// For instance, the character "ö" can be represented as '\u{006F}\u{0308}',
  /// which is the letter "o" followed by a composed diaeresis "¨", or it can
  /// be represented as '\u{00F6}', which is the Unicode scalar value "LATIN
  /// SMALL LETTER O WITH DIAERESIS". In the first case, the text field will
  /// count two characters, and the second case will be counted as one
  /// character, even though the user can see no difference in the input.
  /// 
  /// 例如，字符"ö"可以表示为 '\u{006F}\u{0308}'，即字母“o”后跟组合分音符 "¨"，
  /// 也可以表示为 '\u{00F6}'，即Unicode标量值“带分音符的拉丁文小写字母o”。在第一种
  /// 情况下，文本字段将计算两个字符，而第二种情况将计算为一个字符，即使用户在输入中
  /// 看不到任何差异。
  ///
  /// Similarly, some emoji are represented by multiple scalar values. The
  /// Unicode "THUMBS UP SIGN + MEDIUM SKIN TONE MODIFIER", "👍🏽", should be
  /// counted as a single character, but because it is a combination of two
  /// Unicode scalar values, '\u{1F44D}\u{1F3FD}', it is counted as two
  /// characters.
  /// 
  /// 类似地，一些emoji由多个标量值表示。Unicode“拇指向上符号+中等肤色修饰符”“”应计为单个字符，
  /// 但由于它是两个Unicode标量值“\u{1F44D}\u{1F3FD}”的组合，因此计为两个字符。
  ///
  /// See also:
  ///
  ///  * [LengthLimitingTextInputFormatter] for more information on how it
  ///    counts characters, and how it may differ from the intuitive meaning.
  ///  * [LengthLimitingTextInputFormatter] 了解有关它如何计算字符数以及它如何与直观含义不同的更多信息。
  /// 最大长度
  final int maxLength;

  /// If true, prevents the field from allowing more than [maxLength]
  /// characters.
  /// 
  /// 如果为true，则阻止字段允许超过[maxLength]个字符。
  ///
  /// If [maxLength] is set, [maxLengthEnforced] indicates whether or not to
  /// enforce the limit, or merely provide a character counter and warning when
  /// [maxLength] is exceeded.
  /// 
  /// 如果设置了[maxLength]，则[maxlengthforced]指示是否强制执行限制，
  /// 或者仅在超过[maxLength]时提供字符计数器和警告。
  /// 最大长度限制
  final bool maxLengthEnforced;

  /// {@macro flutter.widgets.editableText.onChanged}
  ///
  /// See also:
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [inputFormatters]，在[onChanged]运行之前调用，可以验证和更改 ("format") 输入值。
  /// 
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]:
  ///    which are more specialized input change notifications.
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]: 
  ///    它们是更专门的输入更改通知。
  /// 更改时
  final ValueChanged<String> onChanged;

  /// {@macro flutter.widgets.editableText.onEditingComplete}
  /// 编辑完成
  final VoidCallback onEditingComplete;

  /// {@macro flutter.widgets.editableText.onSubmitted}
  ///
  /// See also:
  ///
  ///  * [EditableText.onSubmitted] for an example of how to handle moving to
  ///    the next/previous field when using [TextInputAction.next] and
  ///    [TextInputAction.previous] for [textInputAction].
  ///  * [EditableText.onSubmitted]举例说明如何处理在为[TextInputAction]使用
  ///    [TextInputAction.next]和[TextInputAction.previous]时移动到下一个/上一个字段。
  /// 
  /// 提交
  final ValueChanged<String> onSubmitted;

  /// {@macro flutter.widgets.editableText.inputFormatters}
  /// 输入格式化程序
  final List<TextInputFormatter> inputFormatters;

  /// If false the text field is "disabled": it ignores taps and its
  /// [decoration] is rendered in grey.
  /// 
  /// 如果为false，则文本字段为“disabled”：它忽略taps，其[装饰]呈现为灰色。
  ///
  /// If non-null this property overrides the [decoration]'s
  /// [Decoration.enabled] property.
  /// 
  /// 如果非空，则此属性重写[decoration]的[decoration.enabled]属性。
  /// 启用
  final bool enabled;

  /// {@macro flutter.widgets.editableText.cursorWidth}
  /// 光标宽度
  final double cursorWidth;

  /// {@macro flutter.widgets.editableText.cursorRadius}
  /// 光标半径
  final Radius cursorRadius;

  /// The color to use when painting the cursor.
  /// 
  /// 绘制光标时要使用的颜色。
  ///
  /// Defaults to [ThemeData.cursorColor] or [CupertinoTheme.primaryColor]
  /// depending on [ThemeData.platform].
  /// 默认为[ThemeData.cursorColor] 或 [CupertinoTheme.primaryColor]，具体取决于[ThemeData.platform]。
  /// 光标颜色
  final Color cursorColor;

  /// The appearance of the keyboard.
  /// 
  /// 键盘的外观。
  ///
  /// This setting is only honored on iOS devices.
  /// 
  /// 此设置仅在iOS设备上使用。
  ///
  /// If unset, defaults to the brightness of [ThemeData.primaryColorBrightness].
  /// 
  /// 如果未设置，则默认为 [ThemeData.primaryColorBrightness] 的亮度。
  /// 键盘外观
  final Brightness keyboardAppearance;

  /// {@macro flutter.widgets.editableText.scrollPadding}
  /// 滚动条内边距
  final EdgeInsets scrollPadding;

  /// {@macro flutter.widgets.editableText.enableInteractiveSelection}
  /// 启用交互式选择
  final bool enableInteractiveSelection;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  /// 拖动开始行为
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.rendering.editable.selectionEnabled}
  /// 启用交互式选择
  bool get selectionEnabled => enableInteractiveSelection;

  /// {@template flutter.material.textfield.onTap}
  /// Called for each distinct tap except for every second tap of a double tap.
  /// 
  /// 为每个不同的点击调用，除了双点击的每一秒。
  ///
  /// The text field builds a [GestureDetector] to handle input events like tap,
  /// to trigger focus requests, to move the caret, adjust the selection, etc.
  /// Handling some of those events by wrapping the text field with a competing
  /// GestureDetector is problematic.
  /// 
  /// 文本字段构建一个[GestureDetector]来处理输入事件，如点击、触发焦点请求、移动插入符号、
  /// 调整选择等。通过用竞争的GestureDetector包装文本字段来处理其中一些事件是有问题的。
  ///
  /// To unconditionally handle taps, without interfering with the text field's
  /// internal gesture detector, provide this callback.
  /// 
  /// 要无条件地处理抽头，而不干扰文本字段的内部手势检测器，请提供此回调。
  ///
  /// If the text field is created with [enabled] false, taps will not be
  /// recognized.
  /// 
  /// 如果用[enabled]false创建文本字段，则无法识别点击。
  ///
  /// To be notified when the text field gains or loses the focus, provide a
  /// [focusNode] and add a listener to that.
  /// 
  /// 要在文本字段获得或失去焦点时得到通知，请提供[focusNode]并向其添加侦听器。
  ///
  /// To listen to arbitrary pointer events without competing with the
  /// text field's internal gesture detector, use a [Listener].
  /// 
  /// 要在不与文本字段的内部手势检测器竞争的情况下侦听任意指针事件，请使用[侦听器]。
  /// {@endtemplate}
  /// 轻击
  final GestureTapCallback onTap;

  /// Callback that generates a custom [InputDecorator.counter] widget.
  /// 
  /// 生成自定义[InputDecorator.counter]小部件的回调。
  ///
  /// See [InputCounterWidgetBuilder] for an explanation of the passed in
  /// arguments.  The returned widget will be placed below the line in place of
  /// the default widget built when [counterText] is specified.
  /// 
  /// 有关传入参数的解释，请参阅[InputCounterWidgetBuilder]。返回的小部件将放置在行
  /// 的下方，以代替指定[counterText]时生成的默认小部件。
  ///
  /// The returned widget will be wrapped in a [Semantics] widget for
  /// accessibility, but it also needs to be accessible itself.  For example,
  /// if returning a Text widget, set the [semanticsLabel] property.
  /// 
  /// 返回的小部件将包装在一个[Semantics]小部件中以便于访问，但它本身也需要是可访问的。
  /// 例如，如果返回文本小部件，请设置[semanticsLabel]属性。
  ///
  /// {@tool snippet}
  /// ```dart
  /// Widget counter(
  ///   BuildContext context,
  ///   {
  ///     int currentLength,
  ///     int maxLength,
  ///     bool isFocused,
  ///   }
  /// ) {
  ///   return Text(
  ///     '$currentLength of $maxLength characters',
  ///     semanticsLabel: 'character count',
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// If buildCounter returns null, then no counter and no Semantics widget will
  /// be created at all.
  /// 
  /// 如果 buildCounter 返回 null，那么将根本不会创建任何计数器和语义小部件。
  /// 构建计数器
  final InputCounterWidgetBuilder buildCounter;

  /// {@macro flutter.widgets.editableText.scrollPhysics}
  /// 滚动条 物理行为
  final ScrollPhysics scrollPhysics;

  /// {@macro flutter.widgets.editableText.scrollController}
  /// 滚动条控制器
  final ScrollController scrollController;

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();

  @override
  // 调试填充属性
  void debugFillProperties(
      // 诊断属性生成器   properties 属性
      DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // 诊断属性
    properties.add(DiagnosticsProperty<TextEditingController>(
        'controller', controller,
        defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<bool>('enabled', enabled, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecoration>(
        'decoration', decoration,
        defaultValue: const InputDecoration()));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: TextInputType.text));
    properties.add(
        DiagnosticsProperty<TextStyle>('style', style, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
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
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(IntProperty('maxLength', maxLength, defaultValue: null));
    properties.add(FlagProperty('maxLengthEnforced',
        value: maxLengthEnforced,
        defaultValue: true,
        ifFalse: 'maxLength not enforced'));
    properties.add(EnumProperty<TextInputAction>(
        'textInputAction', textInputAction,
        defaultValue: null));
    properties.add(EnumProperty<TextCapitalization>(
        'textCapitalization', textCapitalization,
        defaultValue: TextCapitalization.none));
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign,
        defaultValue: TextAlign.start));
    properties.add(DiagnosticsProperty<TextAlignVertical>(
        'textAlignVertical', textAlignVertical,
        defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties
        .add(DoubleProperty('cursorWidth', cursorWidth, defaultValue: 2.0));
    properties.add(DiagnosticsProperty<Radius>('cursorRadius', cursorRadius,
        defaultValue: null));
    properties
        .add(ColorProperty('cursorColor', cursorColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Brightness>(
        'keyboardAppearance', keyboardAppearance,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'scrollPadding', scrollPadding,
        defaultValue: const EdgeInsets.all(20.0)));
    properties.add(FlagProperty('selectionEnabled',
        value: selectionEnabled,
        defaultValue: true,
        ifFalse: 'selection disabled'));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
  }
}

// 自定义文本字段状态
class _CustomTextFieldState extends State<CustomTextField>
    implements
        // 文本选择手势检测器生成器委托
        TextSelectionGestureDetectorBuilderDelegate {
  // 文本编辑控制器
  TextEditingController _controller;
  TextEditingController get _effectiveController =>
      widget.controller ?? _controller;

  // 焦点节点
  FocusNode _focusNode;
  // 有效聚焦节点
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode());

  // 是否悬停
  bool _isHovering = false;

  // 需要计数器
  bool get needsCounter =>
      widget.maxLength != null &&
      // decoration 装饰
      widget.decoration != null &&
      // counterText 计数器文本
      widget.decoration.counterText == null;

  // 显示选择手柄
  bool _showSelectionHandles = false;

  // 文本字段选择手势检测器生成器
  _TextFieldSelectionGestureDetectorBuilder _selectionGestureDetectorBuilder;

  // API for TextSelectionGestureDetectorBuilderDelegate.
  @override
  // 强制按下已启用
  bool forcePressEnabled;

  @override
  // GlobalKey 全局密钥
  final GlobalKey<EditableTextState> editableTextKey =
      // EditableTextState 可编辑文本状态
      GlobalKey<EditableTextState>();

  @override
  // 已启用选择
  bool get selectionEnabled => widget.selectionEnabled;
  // End of API for TextSelectionGestureDetectorBuilderDelegate.

  // 已启用
  bool get _isEnabled => widget.enabled ?? widget.decoration?.enabled ?? true;

  // 当前长度
  int get _currentLength => _effectiveController.value.text.runes.length;

  // 获得有效的装饰
  InputDecoration _getEffectiveDecoration() {
    // Material 本地化
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    // 主题数据
    final ThemeData themeData = Theme.of(context);
    // 有效的装饰
    final InputDecoration effectiveDecoration =
        // InputDecoration 输入装饰
        (widget.decoration ?? const InputDecoration())
            // applyDefaults 应用默认值  inputDecorationTheme 输入装饰主题
            .applyDefaults(themeData.inputDecorationTheme)
            // 复制
            .copyWith(
              enabled: widget.enabled,
              // hintMaxLines 提示最大行数
              hintMaxLines: widget.decoration?.hintMaxLines ?? widget.maxLines,
            );

    // No need to build anything if counter or counterText were given directly.
    // 有效的装饰的 计数器和计数器文本不为null 时，返回 effectiveDecoration
    if (effectiveDecoration.counter != null ||
        effectiveDecoration.counterText != null) return effectiveDecoration;

    // If buildCounter was provided, use it to generate a counter widget.
    // 计数器
    Widget counter;
    // 当前长度
    final int currentLength = _currentLength;
    // 有效装饰 计数器
    if (effectiveDecoration.counter == null &&
        // 有效装饰 计数器文本
        effectiveDecoration.counterText == null &&
        // 构建计数器
        widget.buildCounter != null) {
      // effectiveFocusNode 有效焦点节点 是否聚焦
      final bool isFocused = _effectiveFocusNode.hasFocus;
      // builtCounter 内置计数器 buildCounter 生成计数器
      final Widget builtCounter = widget.buildCounter(
        context,
        // 当前长度
        currentLength: currentLength,
        // 最大长度
        maxLength: widget.maxLength,
        // 是否聚焦
        isFocused: isFocused,
      );
      // If buildCounter returns null, don't add a counter widget to the field.
      // builtCounter 内置计数器
      if (builtCounter != null) {
        // Semantics 含义(用于给浏览器或者其他东西识别用的, 有50多的属性)
        counter = Semantics(
          // 容器
          container: true,
          // 活动区域： 是否聚焦
          liveRegion: isFocused,
          // 子类: 内建计数器
          child: builtCounter,
        );
      }
      // 有效装饰
      return effectiveDecoration.copyWith(counter: counter);
    }

    if (widget.maxLength == null)
      // 返回没有计数器的widget
      return effectiveDecoration; // No counter widget

    // 计数器文本: 当前长度
    String counterText = '$currentLength';
    // 含义 计数器文本: ''
    String semanticCounterText = '';

    // Handle a real maxLength (positive number)
    if (widget.maxLength > 0) {
      // Show the maxLength in the counter
      counterText += '/${widget.maxLength}';
      // remaining 剩下的
      final int remaining =
          // 最大长度 - 当前长度 取 0 - 最大值的有效值
          (widget.maxLength - currentLength).clamp(0, widget.maxLength) as int;
      // 含义 计数器文本
      semanticCounterText =
          // localizations 本地化   remainingTextFieldCharacterCount： 剩余文本字段字符计数
          localizations.remainingTextFieldCharacterCount(remaining);

      // Handle length exceeds maxLength
      // _effectiveController 有效控制器 runes 符文
      // 如果 控制器的符文最大长度大于 maxLength
      if (_effectiveController.value.text.runes.length > widget.maxLength) {
        return effectiveDecoration.copyWith(
          errorText: effectiveDecoration.errorText ?? '',
          counterStyle: effectiveDecoration.errorStyle ??
              // caption 标题
              themeData.textTheme.caption.copyWith(color: themeData.errorColor),
          // 计数器文本
          counterText: counterText,
          // 含义 计数器文本
          semanticCounterText: semanticCounterText,
        );
      }
    }

    // 有效装饰
    return effectiveDecoration.copyWith(
      // 计数器文本
      counterText: counterText,
      // 含义 计数器文本
      semanticCounterText: semanticCounterText,
    );
  }

  @override
  void initState() {
    super.initState();
    print(this);
    // 选择手势检测器生成器
    _selectionGestureDetectorBuilder =
        // 文本字段选择手势检测器生成器
        _TextFieldSelectionGestureDetectorBuilder(state: this);
    if (widget.controller == null) {
      // 文本编辑控制器
      _controller = TextEditingController();
    }
    // _effectiveFocusNode: 有效焦点节点   canRequestFocus: 可以请求焦点
    _effectiveFocusNode.canRequestFocus = _isEnabled;
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果控制器为null, 旧widget 的控制器不为null
    if (widget.controller == null && oldWidget.controller != null)
      // 控制器��取旧widget controller的 value
      _controller = TextEditingController.fromValue(oldWidget.controller.value);
    // 控制器不为null， 并且 旧widget 的控制器为null
    else if (widget.controller != null && oldWidget.controller == null)
      // 控制器 至null
      _controller = null;
    // 有效聚焦节点的 可以请求焦点 = _isEnabled
    _effectiveFocusNode.canRequestFocus = _isEnabled;
    // hasFocus 为 true 并且 widget 的 readOnly 属性不等于 oldWidget 的 readOnly 属性
    if (_effectiveFocusNode.hasFocus && widget.readOnly != oldWidget.readOnly) {
      // selection 选择  isCollapsed 是否折叠
      if (_effectiveController.selection.isCollapsed) {
        // 文本字段选择手势检测器生成器 = !readOnly
        _showSelectionHandles = !widget.readOnly;
      }
    }
  }

  @override
  void dispose() {
    // 释放资源
    _focusNode?.dispose();
    super.dispose();
  }

  // 可编辑文本的当前状态
  EditableTextState get _editableText => editableTextKey.currentState;

  // 请求键盘
  void _requestKeyboard() {
    _editableText?.requestKeyboard();
  }

  // _shouldShowSelectionHandles: 应显示选择句柄   SelectionChangedCause: 选择更改原因
  bool _shouldShowSelectionHandles(SelectionChangedCause cause) {
    // When the text field is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    // 当文本字段被不触发选择覆盖的东西激活时，我们也不应该显示句柄。
    // _selectionGestureDetectorBuilder: 选择手势检测器生成器  shouldShowSelectionToolbar: 显示选择工具栏
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar)
      return false;

    if (cause == SelectionChangedCause.keyboard) return false;

    // _effectiveController 有效控制器
    if (widget.readOnly && _effectiveController.selection.isCollapsed)
      return false;

    // 长按
    if (cause == SelectionChangedCause.longPress) return true;

    // 不为空
    if (_effectiveController.text.isNotEmpty) return true;

    return false;
  }

  // 手势选择已更改
  void _handleSelectionChanged(
      // TextSelection 文本选择
      TextSelection selection,
      // SelectionChangedCause 选择更改原因
      SelectionChangedCause cause) {
    // 将显示选择句柄 通过cause 拿到 bool 值
    final bool willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    // willShowSelectionHandles 将显示选择句柄  _showSelectionHandles 显示选择手柄
    // 当值不同的时候， 同步_showSelectionHandles的值 = willShowSelectionHandles的值
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    // 查看平台
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // 长按
        if (cause == SelectionChangedCause.longPress) {
          // 根据 selection.base 文本位置 滚动条滚动至相应位置
          _editableText?.bringIntoView(selection.base);
        }
        return;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      // Do nothing.
    }
  }

  /// Toggle the toolbar when a selection handle is tapped.
  /// 点击选择手柄时切换工具栏。
  void _handleSelectionHandleTapped() {
    // 是否折叠
    if (_effectiveController.selection.isCollapsed) {
      // 切换工具栏的可见性
      _editableText.toggleToolbar();
    }
  }

  // 手柄悬停  hovering 悬停
  void _handleHover(bool hovering) {
    // 如果传入的状态与 本地状态不一致
    if (hovering != _isHovering) {
      setState(() {
        // 同步本地状态到 传入的状态
        _isHovering = hovering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 调试检查 Material 的上下文
    assert(debugCheckHasMaterial(context));
    // TODO(jonahwilliams): uncomment out this check once we have migrated tests.
    // 一旦迁移了测试，就取消对该检查的注释。
    // assert(debugCheckHasMaterialLocalizations(context));
    // 调试检查具有方向性
    assert(debugCheckHasDirectionality(context));
    assert(
      !(widget.style != null &&
          widget.style.inherit == false &&
          (widget.style.fontSize == null || widget.style.textBaseline == null)),
      'inherit false style must supply fontSize and textBaseline',
    );

    // 主题数据
    final ThemeData themeData = Theme.of(context);
    // merge 合并
    final TextStyle style = themeData.textTheme.subtitle1.merge(widget.style);
    // keyboardAppearance 键盘外观
    final Brightness keyboardAppearance =
        // primaryColorBrightness 原色亮度
        widget.keyboardAppearance ?? themeData.primaryColorBrightness;
    // 控制器
    final TextEditingController controller = _effectiveController;
    // 焦点节点
    final FocusNode focusNode = _effectiveFocusNode;
    // 格式程序
    final List<TextInputFormatter> formatters =
        // 输入格式化程序    TextInputFormatter 文本输入格式化程序
        // inputFormatters 为 null 时, 初始化 formatters 为 一个空[]
        widget.inputFormatters ?? <TextInputFormatter>[];
    // maxLengthEnforced 最大限制长度
    if (widget.maxLength != null && widget.maxLengthEnforced)
      formatters.add(LengthLimitingTextInputFormatter(widget.maxLength));

    // 文本选择控件
    TextSelectionControls textSelectionControls;
    // 在文本上方绘制光标
    bool paintCursorAboveText;
    // 光标不透明度动画
    bool cursorOpacityAnimates;
    // 光标偏移量
    Offset cursorOffset;
    // 光标颜色
    Color cursorColor = widget.cursorColor;
    // 光标半径
    Radius cursorRadius = widget.cursorRadius;

    // 根据平台
    switch (themeData.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // 强制按下已启用
        forcePressEnabled = true;
        // cupertino文本选择控件
        textSelectionControls = cupertinoTextSelectionControls;
        // 在文本上方绘制光标
        paintCursorAboveText = true;
        // 光标不透明度动画
        cursorOpacityAnimates = true;
        // 光标颜色
        cursorColor ??= CupertinoTheme.of(context).primaryColor;
        // 光标半径
        cursorRadius ??= const Radius.circular(2.0);
        // 光标偏移量
        cursorOffset = Offset(
            // iOS水平偏移 / 设备像素比率
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio,
            0);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        // 强制按下已启用
        forcePressEnabled = false;
        // cupertino文本选择控件
        textSelectionControls = materialTextSelectionControls;
        // 在文本上方绘制光标
        paintCursorAboveText = false;
        // 光标不透明度动画
        cursorOpacityAnimates = false;
        // 光标颜色
        cursorColor ??= themeData.cursorColor;
        break;
    }

    // RepaintBoundary 重新绘制边界
    Widget child = RepaintBoundary(
      child: EditableText(
        // 可编辑文本 key
        key: editableTextKey,
        // 只读
        readOnly: widget.readOnly,
        // 工具栏选项
        toolbarOptions: widget.toolbarOptions,
        // 显示光标
        showCursor: widget.showCursor,
        // 显示选择句柄
        showSelectionHandles: _showSelectionHandles,
        // 控制器
        controller: controller,
        // 聚焦节点
        focusNode: focusNode,
        // 键盘类型
        keyboardType: widget.keyboardType,
        // 文本输入操��
        textInputAction: widget.textInputAction,
        // 文本大写
        textCapitalization: widget.textCapitalization,
        style: style,
        // 结构风格
        strutStyle: widget.strutStyle,
        // 文本对齐
        textAlign: widget.textAlign,
        // 文本方向
        textDirection: widget.textDirection,
        // 自动聚焦
        autofocus: widget.autofocus,
        // 模糊文本
        obscureText: widget.obscureText,
        // 自动校正
        autocorrect: widget.autocorrect,
        // 智能数据类型
        smartDashesType: widget.smartDashesType,
        // 智能引号类型
        smartQuotesType: widget.smartQuotesType,
        // 启用建议
        enableSuggestions: widget.enableSuggestions,
        // 最大行
        maxLines: widget.maxLines,
        // 最小行
        minLines: widget.minLines,
        // 扩展
        expands: widget.expands,
        // 选择颜色
        selectionColor: themeData.textSelectionColor,
        // 选择控件
        selectionControls:
            widget.selectionEnabled ? textSelectionControls : null,
        // 改变
        onChanged: widget.onChanged,
        // 选择更改时
        onSelectionChanged: _handleSelectionChanged,
        // 编辑完成时
        onEditingComplete: widget.onEditingComplete,
        // 提交
        onSubmitted: widget.onSubmitted,
        // 点击选择手柄
        onSelectionHandleTapped: _handleSelectionHandleTapped,
        // 输入格式化程序
        inputFormatters: formatters,
        // 渲染器忽略指针
        rendererIgnoresPointer: true,
        // 光标宽度
        cursorWidth: widget.cursorWidth,
        // 光标半径
        cursorRadius: cursorRadius,
        // 光标颜色
        cursorColor: cursorColor,
        // 光标不透明度 动画
        cursorOpacityAnimates: cursorOpacityAnimates,
        // 光标偏移量
        cursorOffset: cursorOffset,
        // 在文本上方绘制光标
        paintCursorAboveText: paintCursorAboveText,
        // 背景光标颜色
        backgroundCursorColor: CupertinoColors.inactiveGray,
        // 滚动 padding
        scrollPadding: widget.scrollPadding,
        // 键盘外观
        keyboardAppearance: keyboardAppearance,
        // 启用交互式选择
        enableInteractiveSelection: widget.enableInteractiveSelection,
        // 拖动开始行为
        dragStartBehavior: widget.dragStartBehavior,
        // 滚动控制器
        scrollController: widget.scrollController,
        // 滚动条 物理学
        scrollPhysics: widget.scrollPhysics,
      ),
    );

    // 装饰不为空的时候
    if (widget.decoration != null) {
      // 动画生成器
      child = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[focusNode, controller]),
        builder: (BuildContext context, Widget child) {
          // 输入装饰器
          return InputDecorator(
            // 装饰
            decoration: _getEffectiveDecoration(),
            // 基本样式
            baseStyle: widget.style,
            // 文本对齐
            textAlign: widget.textAlign,
            // 文本垂直对齐
            textAlignVertical: widget.textAlignVertical,
            // 是否悬停
            isHovering: _isHovering,
            // 是否聚焦
            isFocused: focusNode.hasFocus,
            // 控制器文本 是否为空
            isEmpty: controller.value.text.isEmpty,
            // 扩展
            expands: widget.expands,
            // 子类
            child: child,
          );
        },
        // 子类
        child: child,
      );
    }
    // IgnorePointer 忽略指针
    return IgnorePointer(
      // ignoring 忽略
      ignoring: !_isEnabled,
      // 鼠标区域
      child: MouseRegion(
        // PointerEnterEvent 指针输入事件    _handleHover 手柄悬停
        // 进入时
        onEnter: (PointerEnterEvent event) => _handleHover(true),
        // 离开时
        onExit: (PointerExitEvent event) => _handleHover(false),
        // 动画生成器
        child: AnimatedBuilder(
          // 动画 controller
          animation: controller, // changes the _currentLength
          builder: (BuildContext context, Widget child) {
            // 含义
            return Semantics(
              // 最大值长度   maxLengthEnforced 最大限制长度
              maxValueLength: widget.maxLengthEnforced &&
                      widget.maxLength != null &&
                      widget.maxLength > 0
                  ? widget.maxLength
                  : null,
              // 当前text的长度
              currentValueLength: _currentLength,
              onTap: () {
                // isValid 有效的 为 false时
                if (!_effectiveController.selection.isValid)
                  // collapsed 折叠
                  _effectiveController.selection = TextSelection.collapsed(
                      offset: _effectiveController.text.length);
                // 请求键盘
                _requestKeyboard();
              },
              child: child,
            );
          },
          // _selectionGestureDetectorBuilder: 选择手势检测器生成器  buildGestureDetector: 建立手势检测器
          child: _selectionGestureDetectorBuilder.buildGestureDetector(
            // behavior 行为   translucent 半透明的
            behavior: HitTestBehavior.translucent,
            child: child,
          ),
        ),
      ),
    );
  }
}
