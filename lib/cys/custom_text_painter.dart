// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' show min, max;
import 'dart:ui' as ui show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle, PlaceholderAlignment, LineMetrics, TextHeightBehavior;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// import 'basic_types.dart';
// import 'inline_span.dart';
// import 'placeholder_span.dart';
// import 'strut_style.dart';
// import 'text_span.dart';

export 'package:flutter/services.dart' show TextRange, TextSelection;

/// Holds the [Size] and baseline required to represent the dimensions of
/// a placeholder in text.
/// 
/// 保留在文本中表示占位符维度所需的[大小]和基线。
///
/// Placeholders specify an empty space in the text layout, which is used
/// to later render arbitrary inline widgets into defined by a [WidgetSpan].
/// 
/// 占位符在文本布局中指定一个空空间，用于以后将任意内联小部件呈现到由[WidgetSpan]定义的中。
///
/// The [size] and [alignment] properties are required and cannot be null.
/// 
/// [size]和[alignment]属性是必需的，不能为空。
///
/// See also:
///
///  * [WidgetSpan], a subclass of [InlineSpan] and [PlaceholderSpan] that
///    represents an inline widget embedded within text. The space this
///    widget takes is indicated by a placeholder.
/// 
///  * [WidgetSpan]，[InlineSpan]和[PlaceholdSpan]的子类，表示嵌入在文本中的
///    内联小部件。这个小部件占用的空间由一个占位符表示。
/// 
///  * [RichText], a text widget that supports text inline widgets.
/// 
///  * [RichText]，一个支持文本内联小部件的文本小部件。
@immutable
class PlaceholderDimensions {
  /// Constructs a [PlaceholderDimensions] with the specified parameters.
  /// 使用指定的参数构造[PlaceholderDimensions]。
  ///
  /// The `size` and `alignment` are required as a placeholder's dimensions
  /// require at least `size` and `alignment` to be fully defined.
  /// 
  /// “size”和“alignment”是必需的，因为占位符的维度至少需要完全定义“size”和“alignment”。
  const PlaceholderDimensions({
    @required this.size,
    @required this.alignment,
    this.baseline,
    this.baselineOffset,
  }) : assert(size != null),
       assert(alignment != null);

  /// Width and height dimensions of the placeholder.
  /// 
  /// 占位符的宽度和高度尺寸。
  final Size size;

  /// How to align the placeholder with the text.
  /// 如何将占位符与文本对齐。
  ///
  /// See also:
  ///
  ///  * [baseline], the baseline to align to when using
  ///    [ui.PlaceholderAlignment.baseline],
  ///    [ui.PlaceholderAlignment.aboveBaseline],
  ///    or [ui.PlaceholderAlignment.underBaseline].
  /// 
  ///  * [baseline]，使用[ui.PlaceholderAlignment.baseline]、
  ///    [ui.PlaceholderAlignment.aboveBaseline]或
  ///    [ui.PlaceholderAlignment.underBaseline]时要对齐的基线。
  /// 
  ///  * [baselineOffset], the distance of the alphabetic baseline from the upper
  ///    edge of the placeholder.
  ///  * [baselineOffset], 字母基线到占位符上边缘的距离。
  final ui.PlaceholderAlignment alignment;

  /// Distance of the [baseline] from the upper edge of the placeholder.
  /// [baseline]与占位符上边缘的距离。
  ///
  /// Only used when [alignment] is [ui.PlaceholderAlignment.baseline].
  /// 仅当[alignment]为[ui.PlaceholderAlignment.baseline]时使用。
  final double baselineOffset;

  /// The [TextBaseline] to align to. Used with:
  /// 要对齐的[TextBaseline]。用于：
  ///
  ///  * [ui.PlaceholderAlignment.baseline]
  ///  * [ui.PlaceholderAlignment.aboveBaseline]
  ///  * [ui.PlaceholderAlignment.underBaseline]
  ///  * [ui.PlaceholderAlignment.middle]
  final TextBaseline baseline;

  @override
  String toString() {
    return 'PlaceholderDimensions($size, $baseline)';
  }
}

/// The different ways of measuring the width of one or more lines of text.
/// 测量一行或多行文字宽度的不同方法。
///
/// See [Text.textWidthBasis], for example.
enum TextWidthBasis {
  /// multiline text will take up the full width given by the parent. For single
  /// line text, only the minimum amount of width needed to contain the text
  /// will be used. A common use case for this is a standard series of
  /// paragraphs.
  /// 
  /// 多行文字将占据父文本给定的全宽。对于单行文本，只使用包含文本所需的最小宽
  /// 度。这方面的一个常见用例是一系列标准段落。
  parent,

  /// The width will be exactly enough to contain the longest line and no
  /// longer. A common use case for this is chat bubbles.
  /// 
  /// 宽度将足以容纳最长的行，而不再包含。一个常见的用例是聊天气泡。
  longestLine,
}

/// This is used to cache and pass the computed metrics regarding the
/// caret's size and position. This is preferred due to the expensive
/// nature of the calculation.
/// 
/// 这用于缓存和传递有关插入符号大小和位置的计算度量。这是首选的，因为计算成本高。
class _CaretMetrics {
  const _CaretMetrics({this.offset, this.fullHeight});
  /// The offset of the top left corner of the caret from the top left
  /// corner of the paragraph.
  /// 
  /// 插入符号左上角与段落左上角的偏移量。
  final Offset offset;

  /// The full height of the glyph at the caret position.
  /// 
  /// 符号在插入符号位置的全高。
  final double fullHeight;
}

/// An object that paints a [TextSpan] tree into a [Canvas].
/// 将[TextSpan]树绘制到[Canvas]中的对象。
///
/// To use a [TextPainter], follow these steps:
/// 要使用[TextPainter]，请执行以下步骤：
///
/// 1. Create a [TextSpan] tree and pass it to the [TextPainter]
///    constructor.
/// 1. 创建一个[TextSpan]树并将其传递给[TextPainter]构造函数。
///
/// 2. Call [layout] to prepare the paragraph.
/// 2. 调用[layout]准备段落。
///
/// 3. Call [paint] as often as desired to paint the paragraph.
/// 3. 根据需要随时调用[绘制]来绘制段落。
///
/// If the width of the area into which the text is being painted
/// changes, return to step 2. If the text to be painted changes,
/// return to step 1.
/// 如果正在绘制文本的区域的宽度发生更改，请返回步骤2。
/// 如果要绘制的文本更改，请返回步骤1。
///
/// The default text style is white. To change the color of the text,
/// pass a [TextStyle] object to the [TextSpan] in `text`.
/// 
/// 默认文本样式为白色。若要更改文本的颜色，请将[TextStyle]对象传递给
/// [TextSpan] 中的 `text`。
class TextPainter {
  /// Creates a text painter that paints the given text.
  /// 
  /// 创建绘制给定文本的文本绘制器。
  ///
  /// The `text` and `textDirection` arguments are optional but [text] and
  /// [textDirection] must be non-null before calling [layout].
  /// 
  /// “text”和“textDirection”参数是可选的，但在调用[layout]之前，
  /// [text]和[textDirection]必须非空。
  ///
  /// The [textAlign] property must not be null.
  /// [textAlign]属性不能为空。
  ///
  /// The [maxLines] property, if non-null, must be greater than zero.
  /// 如果非空，[maxLines]属性必须大于零。
  TextPainter({
    InlineSpan text,
    TextAlign textAlign = TextAlign.start,
    TextDirection textDirection,
    double textScaleFactor = 1.0,
    int maxLines,
    String ellipsis,
    Locale locale,
    StrutStyle strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior textHeightBehavior,
  }) : assert(text == null || text.debugAssertIsValid()),
       assert(textAlign != null),
       assert(textScaleFactor != null),
       assert(maxLines == null || maxLines > 0),
       assert(textWidthBasis != null),
       _text = text,
       _textAlign = textAlign,
       _textDirection = textDirection,
       _textScaleFactor = textScaleFactor,
       _maxLines = maxLines,
       _ellipsis = ellipsis,
       _locale = locale,
       _strutStyle = strutStyle,
       _textWidthBasis = textWidthBasis,
       _textHeightBehavior = textHeightBehavior;

  ui.Paragraph _paragraph;
  bool _needsLayout = true;

  /// Marks this text painter's layout information as dirty and removes cached
  /// information.
  /// 将此文本绘制程序的布局信息标记为脏并删除缓存的信息。
  ///
  /// Uses this method to notify text painter to relayout in the case of
  /// layout changes in engine. In most cases, updating text painter properties
  /// in framework will automatically invoke this method.
  /// 
  /// 使用此方法通知文本绘制程序在引擎中发生布局更改时重新布局。
  /// 在大多数情况下，更新框架中的文本绘制器属性将自动调用此方法。
  void markNeedsLayout() {
    _paragraph = null;
    _needsLayout = true;
    _previousCaretPosition = null;
    _previousCaretPrototype = null;
  }

  /// The (potentially styled) text to paint.
  /// 要绘制的（潜在样式）文本。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// This and [textDirection] must be non-null before you call [layout].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  /// 在调用[layout]之前，此和[textDirection]必须非空。
  ///
  /// The [InlineSpan] this provides is in the form of a tree that may contain
  /// multiple instances of [TextSpan]s and [WidgetSpan]s. To obtain a plain text
  /// representation of the contents of this [TextPainter], use [InlineSpan.toPlainText]
  /// to get the full contents of all nodes in the tree. [TextSpan.text] will
  /// only provide the contents of the first node in the tree.
  /// 
  /// 这提供的[InlineSpan]是一个树的形式，它可能包含[TextSpan]s和
  /// [WidgetSpan]s的多个实例。若要获取此[textpainer]内容的纯文本表示形式，
  /// 请使用[InlineSpan.To plain text]获取树中所有节点的全部内容。
  /// [TextSpan.text]将只提供树中第一个节点的内容。
  InlineSpan get text => _text;
  InlineSpan _text;
  set text(InlineSpan value) {
    assert(value == null || value.debugAssertIsValid());
    if (_text == value)
      return;
    if (_text?.style != value?.style)
      _layoutTemplate = null;
    _text = value;
    markNeedsLayout();
  }

  /// How the text should be aligned horizontally.
  /// 文本应如何水平对齐。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  ///
  /// The [textAlign] property must not be null. It defaults to [TextAlign.start].
  /// [textAlign]属性不能为空。它默认为[TextAlign.start].
  TextAlign get textAlign => _textAlign;
  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    assert(value != null);
    if (_textAlign == value)
      return;
    _textAlign = value;
    markNeedsLayout();
  }

  /// The default directionality of the text.
  /// 文本的默认方向性。
  ///
  /// This controls how the [TextAlign.start], [TextAlign.end], and
  /// [TextAlign.justify] values of [textAlign] are resolved.
  /// 这控制如何解析[TextAlign]的[TextAlign.start]、
  /// [TextAlign.end]和[TextAlign.justify]值。
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the [text] is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  /// 
  /// 这也用于消除如何呈现双向文本的歧义。例如，如果[text]是英文短语，后跟希伯来
  /// 语短语，则在[TextDirection.ltr]上下文中，英文短语位于左侧，希伯来语短语
  /// 位于右侧；而在[TextDirection.rtl]上下文中，英文短语位于右侧，希伯来语短
  /// 语位于左侧。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  ///
  /// This and [text] must be non-null before you call [layout].
  /// 在调用[layout]之前，此和[text]必须为非空。
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value)
      return;
    _textDirection = value;
    markNeedsLayout();
    _layoutTemplate = null; // Shouldn't really matter, but for strict correctness... 其实不重要，但为了严格的正确性。。。
  }

  /// The number of font pixels for each logical pixel.
  /// 每个逻辑像素的字体像素数。
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  /// 
  /// 例如，如果文本比例因子为1.5，则文本将比指定的字体大小大50%。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  double get textScaleFactor => _textScaleFactor;
  double _textScaleFactor;
  set textScaleFactor(double value) {
    assert(value != null);
    if (_textScaleFactor == value)
      return;
    _textScaleFactor = value;
    markNeedsLayout();
    _layoutTemplate = null;
  }

  /// The string used to ellipsize overflowing text. Setting this to a non-empty
  /// string will cause this string to be substituted for the remaining text
  /// if the text can not fit within the specified maximum width.
  /// 
  /// 用于省略号溢出文本的字符串。如果文本不能满足指定的最大宽度，则将此设置为非
  /// 空字符串将导致该字符串替换剩余文本。
  ///
  /// Specifically, the ellipsis is applied to the last line before the line
  /// truncated by [maxLines], if [maxLines] is non-null and that line overflows
  /// the width constraint, or to the first line that is wider than the width
  /// constraint, if [maxLines] is null. The width constraint is the `maxWidth`
  /// passed to [layout].
  /// 
  /// 具体来说，如果[maxLines]为非空且行溢出宽度约束，则省略号应用于被[maxLines]截
  /// 断的行之前的最后一行；如果[maxLines]为空，则省略号应用于比宽度约束更宽的第
  /// 一行。宽度约束是传递给[layout]的“maxWidth”。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  ///
  /// The higher layers of the system, such as the [Text] widget, represent
  /// overflow effects using the [TextOverflow] enum. The
  /// [TextOverflow.ellipsis] value corresponds to setting this property to
  /// U+2026 HORIZONTAL ELLIPSIS (…).
  /// 
  /// 系统的更高层，如[Text]小部件，使用[TextOverflow]枚举表示溢出效果。
  /// [textwoverflow.ellipsis]值对应于将此属性设置为U+2026水平省略号（…）。
  String get ellipsis => _ellipsis;
  String _ellipsis;
  set ellipsis(String value) {
    assert(value == null || value.isNotEmpty);
    if (_ellipsis == value)
      return;
    _ellipsis = value;
    markNeedsLayout();
  }

  /// The locale used to select region-specific glyphs.
  /// 用于选择区域特定标志符号的区域设置。
  Locale get locale => _locale;
  Locale _locale;
  set locale(Locale value) {
    if (_locale == value)
      return;
    _locale = value;
    markNeedsLayout();
  }

  /// An optional maximum number of lines for the text to span, wrapping if
  /// necessary.
  /// 一个可选的最大行数的文本跨度，包装，如果必要的话。
  ///
  /// If the text exceeds the given number of lines, it is truncated such that
  /// subsequent lines are dropped.
  /// 如果文本超过给定的行数，则将截断该文本，以便删除后续行。
  ///
  /// After this is set, you must call [layout] before the next call to [paint].
  /// 设置好后，必须在下次调用[paint]之前调用[layout]。
  int get maxLines => _maxLines;
  int _maxLines;
  /// The value may be null. If it is not null, then it must be greater than zero.
  /// 该值可能为空。如果不为空，则必须大于零。
  set maxLines(int value) {
    assert(value == null || value > 0);
    if (_maxLines == value)
      return;
    _maxLines = value;
    markNeedsLayout();
  }

  /// {@template flutter.painting.textPainter.strutStyle}
  /// The strut style to use. Strut style defines the strut, which sets minimum
  /// vertical layout metrics.
  /// 要使用的支柱样式。支柱样式定义支柱，设置最小垂直布局度量。
  ///
  /// Omitting or providing null will disable strut.
  /// 省略或提供空值将禁用支柱。
  ///
  /// Omitting or providing null for any properties of [StrutStyle] will result in
  /// default values being used. It is highly recommended to at least specify a
  /// [fontSize].
  /// 
  /// 省略或为[StrutStyle]的任何属性提供空值将导致使用默认值。强烈建议至少指定一个[fontSize]。
  ///
  /// See [StrutStyle] for details.
  /// 详情请参见[StrutStyle]。
  /// {@endtemplate}
  StrutStyle get strutStyle => _strutStyle;
  StrutStyle _strutStyle;
  set strutStyle(StrutStyle value) {
    if (_strutStyle == value)
      return;
    _strutStyle = value;
    markNeedsLayout();
  }

  /// {@template flutter.painting.textPainter.textWidthBasis}
  /// Defines how to measure the width of the rendered text.
  /// 定义如何测量呈现文本的宽度。
  /// {@endtemplate}
  TextWidthBasis get textWidthBasis => _textWidthBasis;
  TextWidthBasis _textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    assert(value != null);
    if (_textWidthBasis == value)
      return;
    _textWidthBasis = value;
    markNeedsLayout();
  }

  /// {@macro flutter.dart:ui.textHeightBehavior}
  ui.TextHeightBehavior get textHeightBehavior => _textHeightBehavior;
  ui.TextHeightBehavior _textHeightBehavior;
  set textHeightBehavior(ui.TextHeightBehavior value) {
    assert(value != null);
    if (_textHeightBehavior == value)
      return;
    _textHeightBehavior = value;
    markNeedsLayout();
  }

  ui.Paragraph _layoutTemplate;

  /// An ordered list of [TextBox]es that bound the positions of the placeholders
  /// in the paragraph.
  /// [TextBox]的有序列表，用于绑定段落中占位符的位置。
  ///
  /// Each box corresponds to a [PlaceholderSpan] in the order they were defined
  /// in the [InlineSpan] tree.
  /// 每个框都对应一个[PlaceholderSpan]，其顺序是在[InlineSpan]树中定义的。
  List<TextBox> get inlinePlaceholderBoxes => _inlinePlaceholderBoxes;
  List<TextBox> _inlinePlaceholderBoxes;

  /// An ordered list of scales for each placeholder in the paragraph.
  /// 段落中每个占位符的比例的有序列表。
  ///
  /// The scale is used as a multiplier on the height, width and baselineOffset of
  /// the placeholder. Scale is primarily used to handle accessibility scaling.
  /// 比例用作占位符的高度、宽度和基线偏移的乘数。缩放主要用于处理可访问性缩放。
  ///
  /// Each scale corresponds to a [PlaceholderSpan] in the order they were defined
  /// in the [InlineSpan] tree.
  /// 每个比例尺都对应一个[PlaceholderSpan]，其顺序是在[InlineSpan]树中定义的。
  List<double> get inlinePlaceholderScales => _inlinePlaceholderScales;
  List<double> _inlinePlaceholderScales;

  /// Sets the dimensions of each placeholder in [text].
  /// 设置[text]中每个占位符的尺寸。
  ///
  /// The number of [PlaceholderDimensions] provided should be the same as the
  /// number of [PlaceholderSpan]s in text. Passing in an empty or null `value`
  /// will do nothing.
  /// 
  /// 提供的[PlaceholdDimensions]数量应与文本中的[PlaceholdSpan]数量相同。
  /// 传入空的或空的“value”将不起任何作用。
  ///
  /// If [layout] is attempted without setting the placeholder dimensions, the
  /// placeholders will be ignored in the text layout and no valid
  /// [inlinePlaceholderBoxes] will be returned.
  /// 
  /// 如果尝试在不设置占位符维度的情况下使用[layout]，则文本布局中将忽略占位
  /// 符，并且不会返回有效的[InlinePlaceholderBox]。
  void setPlaceholderDimensions(List<PlaceholderDimensions> value) {
    if (value == null || value.isEmpty || listEquals(value, _placeholderDimensions)) {
      return;
    }
    assert(() {
      int placeholderCount = 0;
      text.visitChildren((InlineSpan span) {
        if (span is PlaceholderSpan) {
          placeholderCount += 1;
        }
        return true;
      });
      return placeholderCount;
    }() == value.length);
    _placeholderDimensions = value;
    markNeedsLayout();
  }
  List<PlaceholderDimensions> _placeholderDimensions;

  ui.ParagraphStyle _createParagraphStyle([ TextDirection defaultTextDirection ]) {
    // The defaultTextDirection argument is used for preferredLineHeight in case
    // textDirection hasn't yet been set.
    // defaultTextDirection参数用于preferredLineHeight，以防尚未设置textDirection。
    assert(textAlign != null);
    assert(textDirection != null || defaultTextDirection != null, 'TextPainter.textDirection must be set to a non-null value before using the TextPainter.');
    return _text.style?.getParagraphStyle(
      textAlign: textAlign,
      textDirection: textDirection ?? defaultTextDirection,
      textScaleFactor: textScaleFactor,
      maxLines: _maxLines,
      textHeightBehavior: _textHeightBehavior,
      ellipsis: _ellipsis,
      locale: _locale,
      strutStyle: _strutStyle,
    ) ?? ui.ParagraphStyle(
      textAlign: textAlign,
      textDirection: textDirection ?? defaultTextDirection,
      maxLines: maxLines,
      textHeightBehavior: _textHeightBehavior,
      ellipsis: ellipsis,
      locale: locale,
    );
  }

  /// The height of a space in [text] in logical pixels.
  /// [text]中空格的高度（逻辑像素）。
  ///
  /// Not every line of text in [text] will have this height, but this height
  /// is "typical" for text in [text] and useful for sizing other objects
  /// relative a typical line of text.
  /// 
  /// 并非[text]中的每一行文本都具有此高度，但此高度对于[text]中的文本是“典型”的，
  /// 对于相对于典型文本行调整其他对象的大小非常有用。
  ///
  /// Obtaining this value does not require calling [layout].
  /// 获取此值不需要调用[layout]。
  ///
  /// The style of the [text] property is used to determine the font settings
  /// that contribute to the [preferredLineHeight]. If [text] is null or if it
  /// specifies no styles, the default [TextStyle] values are used (a 10 pixel
  /// sans-serif font).
  /// 
  /// [text]属性的样式用于确定有助于[preferredLineHeight]的字体设置。
  /// 如果[文本]为空或未指定样式，则使用默认的[文本样式]值（10像素无衬线字体）。
  double get preferredLineHeight {
    if (_layoutTemplate == null) {
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        _createParagraphStyle(TextDirection.rtl),
      ); // direction doesn't matter, text is just a space
      if (text?.style != null)
        builder.pushStyle(text.style.getTextStyle(textScaleFactor: textScaleFactor));
      builder.addText(' ');
      _layoutTemplate = builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
    }
    return _layoutTemplate.height;
  }

  // Unfortunately, using full precision floating point here causes bad layouts
  // because floating point math isn't associative. If we add and subtract
  // padding, for example, we'll get different values when we estimate sizes and
  // when we actually compute layout because the operations will end up associated
  // differently. To work around this problem for now, we round fractional pixel
  // values up to the nearest whole pixel value. The right long-term fix is to do
  // layout using fixed precision arithmetic.
  // 不幸的是，在这里使用全精度浮点会导致布局错误，因为浮点数学不是关联的。
  // 例如，如果我们加上和减去padding，我们在估计大小和实际计算布局时会得到不同
  // 的值，因为这些操作最终会以不同的方式关联起来。为了暂时解决这个问题，我们将分数像素值
  // 舍入到最接近的整个像素值。正确的长期定位是使用固定精度的算法进行布局。
  double _applyFloatingPointHack(double layoutValue) {
    return layoutValue.ceilToDouble();
  }

  /// The width at which decreasing the width of the text would prevent it from
  /// painting itself completely within its bounds.
  /// 
  /// 减小文本宽度的宽度将阻止它在其范围内完全绘制自身。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[layout]后有效。
  double get minIntrinsicWidth {
    assert(!_needsLayout);
    return _applyFloatingPointHack(_paragraph.minIntrinsicWidth);
  }

  /// The width at which increasing the width of the text no longer decreases the height.
  /// 增加文本宽度不再降低高度的宽度。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用 [layout] 后有效。
  double get maxIntrinsicWidth {
    assert(!_needsLayout);
    return _applyFloatingPointHack(_paragraph.maxIntrinsicWidth);
  }

  /// The horizontal space required to paint this text.
  /// 绘制此文本所需的水平间距。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[layout]后有效。
  double get width {
    assert(!_needsLayout);
    return _applyFloatingPointHack(
      textWidthBasis == TextWidthBasis.longestLine ? _paragraph.longestLine : _paragraph.width,
    );
  }

  /// The vertical space required to paint this text.
  /// 绘制此文本所需的垂直空间。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[layout]后有效。
  double get height {
    assert(!_needsLayout);
    return _applyFloatingPointHack(_paragraph.height);
  }

  /// The amount of space required to paint this text.
  /// 绘制此文本所需的空间量。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用 [layout] 后有效。
  Size get size {
    assert(!_needsLayout);
    return Size(width, height);
  }

  /// Returns the distance from the top of the text to the first baseline of the
  /// given type.
  /// 返回从文本顶部到给定类型的第一条基线的距离。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用 [layout] 后有效。
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!_needsLayout);
    assert(baseline != null);
    switch (baseline) {
      case TextBaseline.alphabetic:
        return _paragraph.alphabeticBaseline;
      case TextBaseline.ideographic:
        return _paragraph.ideographicBaseline;
    }
    return null;
  }

  /// Whether any text was truncated or ellipsized.
  /// 是否有文本被截断或省略。
  ///
  /// If [maxLines] is not null, this is true if there were more lines to be
  /// drawn than the given [maxLines], and thus at least one line was omitted in
  /// the output; otherwise it is false.
  /// 
  /// 如果[maxLines]不为空，则如果要绘制的行比给定的[maxLines]多，
  /// 则为真，因此输出中至少省略了一行；否则为假。
  ///
  /// If [maxLines] is null, this is true if [ellipsis] is not the empty string
  /// and there was a line that overflowed the `maxWidth` argument passed to
  /// [layout]; otherwise it is false.
  /// 
  /// 如果[maxLines]为空，如果[ellipsis]不是空字符串，并且有一行溢出传递
  /// 给[layout]的“maxWidth”参数，则为真；否则为假。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用 [layout] 后有效。
  bool get didExceedMaxLines {
    assert(!_needsLayout);
    return _paragraph.didExceedMaxLines;
  }

  double _lastMinWidth;
  double _lastMaxWidth;

  /// Computes the visual position of the glyphs for painting the text.
  /// 计算用于绘制文本的图示符的视觉位置。
  ///
  /// The text will layout with a width that's as close to its max intrinsic
  /// width as possible while still being greater than or equal to `minWidth` and
  /// less than or equal to `maxWidth`.
  /// 
  /// 文本将以尽可能接近其最大内在宽度的宽度进行布局，同时仍大于或等于“minWidth”
  /// 且小于或等于“max width”。
  ///
  /// The [text] and [textDirection] properties must be non-null before this is
  /// called.
  /// 调用此属性之前，[text]和[textDirection]属性必须为非空。
  void layout({ double minWidth = 0.0, double maxWidth = double.infinity }) {
    assert(text != null, 'TextPainter.text must be set to a non-null value before using the TextPainter.');
    assert(textDirection != null, 'TextPainter.textDirection must be set to a non-null value before using the TextPainter.');
    if (!_needsLayout && minWidth == _lastMinWidth && maxWidth == _lastMaxWidth)
      return;
    _needsLayout = false;
    if (_paragraph == null) {
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(_createParagraphStyle());
      _text.build(builder, textScaleFactor: textScaleFactor, dimensions: _placeholderDimensions);
      _inlinePlaceholderScales = builder.placeholderScales;
      _paragraph = builder.build();
    }
    _lastMinWidth = minWidth;
    _lastMaxWidth = maxWidth;
    _paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    if (minWidth != maxWidth) {
      final double newWidth = maxIntrinsicWidth.clamp(minWidth, maxWidth) as double;
      if (newWidth != width) {
        _paragraph.layout(ui.ParagraphConstraints(width: newWidth));
      }
    }
    _inlinePlaceholderBoxes = _paragraph.getBoxesForPlaceholders();
  }

  /// Paints the text onto the given canvas at the given offset.
  /// 在给定的画布上以给定的偏移量绘制文本。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[布局]后有效。
  ///
  /// If you cannot see the text being painted, check that your text color does
  /// not conflict with the background on which you are drawing. The default
  /// text color is white (to contrast with the default black background color),
  /// so if you are writing an application with a white background, the text
  /// will not be visible by default.
  /// 
  /// 如果看不到正在绘制的文本，请检查文本颜色是否与正在绘制的背景不冲突。
  /// 默认的文本颜色是白色（与默认的黑色背景颜色形成对比），因此，如果您使用白色
  /// 背景编写应用程序，默认情况下文本将不可见。
  ///
  /// To set the text style, specify a [TextStyle] when creating the [TextSpan]
  /// that you pass to the [TextPainter] constructor or to the [text] property.
  /// 
  /// 要设置文本样式，请在创建传递给[textpainer]构造函数或[text]属性的[TextSpan]时指定[text style]。
  void paint(Canvas canvas, Offset offset) {
    assert(() {
      if (_needsLayout) {
        throw FlutterError(
          'TextPainter.paint called when text geometry was not yet calculated.\n'
          'Please call layout() before paint() to position the text before painting it.'
        );
      }
      return true;
    }());
    canvas.drawParagraph(_paragraph, offset);
  }

  // Complex glyphs can be represented by two or more UTF16 codepoints. This
  // checks if the value represents a UTF16 glyph by itself or is a 'surrogate'.
  // 复杂字形可以由两个或多个UTF16码位表示。这将检查该值是否单独表示UTF16标志符号或是否为“代理项”。
  bool _isUtf16Surrogate(int value) {
    return value & 0xF800 == 0xD800;
  }

  /// Returns the closest offset after `offset` at which the input cursor can be
  /// positioned.
  /// 返回“offset”之后的最接近偏移量，输入光标可以位于该偏移量处。
  int getOffsetAfter(int offset) {
    final int nextCodeUnit = _text.codeUnitAt(offset);
    if (nextCodeUnit == null)
      return null;
    // TODO(goderbauer): doesn't handle extended grapheme clusters with more than one Unicode scalar value (https://github.com/flutter/flutter/issues/13404).
    return _isUtf16Surrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  /// Returns the closest offset before `offset` at which the input cursor can
  /// be positioned.
  /// 返回“offset”之前的最接近偏移量，输入光标可以位于该偏移量处。
  int getOffsetBefore(int offset) {
    final int prevCodeUnit = _text.codeUnitAt(offset - 1);
    if (prevCodeUnit == null)
      return null;
    // TODO(goderbauer): doesn't handle extended grapheme clusters with more than one Unicode scalar value (https://github.com/flutter/flutter/issues/13404).
    return _isUtf16Surrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  // Unicode value for a zero width joiner character.
  // 零宽度连接符的Unicode值。
  static const int _zwjUtf16 = 0x200d;

  // Get the Rect of the cursor (in logical pixels) based off the near edge
  // of the character upstream from the given string offset.
  // 从给定的字符串偏移量获取光标的矩形（以逻辑像素为单位）。
  // TODO(garyq): Use actual extended grapheme cluster length instead of
  // an increasing cluster length amount to achieve deterministic performance.
  // 增加集群长度以实现确定性性能。
  Rect _getRectFromUpstream(int offset, Rect caretPrototype) {
    final String flattenedText = _text.toPlainText(includePlaceholders: false);
    final int prevCodeUnit = _text.codeUnitAt(max(0, offset - 1));
    if (prevCodeUnit == null)
      return null;

    // Check for multi-code-unit glyphs such as emojis or zero width joiner
    // 检查多代码单位标志符号，如emojis或零宽度连接符
    final bool needsSearch = _isUtf16Surrogate(prevCodeUnit) || _text.codeUnitAt(offset) == _zwjUtf16;
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<TextBox> boxes = <TextBox>[];
    while (boxes.isEmpty && flattenedText != null) {
      final int prevRuneOffset = offset - graphemeClusterLength;
      boxes = _paragraph.getBoxesForRange(prevRuneOffset, offset);
      // When the range does not include a full cluster, no boxes will be returned.
      // 当范围不包含完整群集时，将不返回任何框。
      if (boxes.isEmpty) {
        // When we are at the beginning of the line, a non-surrogate position will
        // return empty boxes. We break and try from downstream instead.
        // 当我们在行首时，非代理位置将返回空框。我们从下游开始尝试。
        if (!needsSearch) {
          break; // Only perform one iteration if no search is required. 如果不需要搜索，只执行一次迭代。
        }
        if (prevRuneOffset < -flattenedText.length) {
          break; // Stop iterating when beyond the max length of the text. 超过文本的最大长度时停止迭代。
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        // 乘以2可记录（n）整个文本范围的时间。这允许更快地发现非常长的集群，
        // 并减少了某些大型集群比其他集群花费更长时间的可能性，这可能会导致jank。
        graphemeClusterLength *= 2;
        continue;
      }
      final TextBox box = boxes.first;

      // If the upstream character is a newline, cursor is at start of next line
      // 如果上游字符是换行符，则光标位于下一行的开头
      const int NEWLINE_CODE_UNIT = 10;
      if (prevCodeUnit == NEWLINE_CODE_UNIT) {
        return Rect.fromLTRB(_emptyOffset.dx, box.bottom, _emptyOffset.dx, box.bottom + box.bottom - box.top);
      }

      final double caretEnd = box.end;
      final double dx = box.direction == TextDirection.rtl ? caretEnd - caretPrototype.width : caretEnd;
      return Rect.fromLTRB(min(dx, _paragraph.width), box.top, min(dx, _paragraph.width), box.bottom);
    }
    return null;
  }

  // Get the Rect of the cursor (in logical pixels) based off the near edge
  // of the character downstream from the given string offset.
  // 根据给定字符串偏移量下游字符的近边缘获取光标的矩形（逻辑像素）。
  // TODO(garyq): Use actual extended grapheme cluster length instead of
  // an increasing cluster length amount to achieve deterministic performance.
  // 增加集群长度以实现确定性性能。
  Rect _getRectFromDownstream(int offset, Rect caretPrototype) {
    final String flattenedText = _text.toPlainText(includePlaceholders: false);
    // We cap the offset at the final index of the _text.
    // 我们将偏移量限制在文本的最终索引处。
    final int nextCodeUnit = _text.codeUnitAt(min(offset, flattenedText == null ? 0 : flattenedText.length - 1));
    if (nextCodeUnit == null)
      return null;
    // Check for multi-code-unit glyphs such as emojis or zero width joiner
    // 检查多代码单位标志符号，如emojis或零宽度连接符
    final bool needsSearch = _isUtf16Surrogate(nextCodeUnit) || nextCodeUnit == _zwjUtf16;
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<TextBox> boxes = <TextBox>[];
    while (boxes.isEmpty && flattenedText != null) {
      final int nextRuneOffset = offset + graphemeClusterLength;
      boxes = _paragraph.getBoxesForRange(offset, nextRuneOffset);
      // When the range does not include a full cluster, no boxes will be returned.
      // 当范围不包含完整群集时，将不返回任何框。
      if (boxes.isEmpty) {
        // When we are at the end of the line, a non-surrogate position will
        // return empty boxes. We break and try from upstream instead.
        // 当我们在行的末尾时，非代理位置将返回空框。我们从上游开始尝试。
        if (!needsSearch) {
          break; // Only perform one iteration if no search is required. 如果不需要搜索，只执行一次迭代。
        }
        if (nextRuneOffset >= flattenedText.length << 1) {
          break; // Stop iterating when beyond the max length of the text. 超过文本的最大长度时停止迭代。
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        // 乘以2可记录（n）整个文本范围的时间。这允许更快地发现非常长的集群，并减少了
        // 某些大型集群比其他集群花费更长时间的可能性，这可能会导致jank。
        graphemeClusterLength *= 2;
        continue;
      }
      final TextBox box = boxes.last;
      final double caretStart = box.start;
      final double dx = box.direction == TextDirection.rtl ? caretStart - caretPrototype.width : caretStart;
      return Rect.fromLTRB(min(dx, _paragraph.width), box.top, min(dx, _paragraph.width), box.bottom);
    }
    return null;
  }

  Offset get _emptyOffset {
    assert(!_needsLayout); // implies textDirection is non-null
    assert(textAlign != null);
    switch (textAlign) {
      case TextAlign.left:
        return Offset.zero;
      case TextAlign.right:
        return Offset(width, 0.0);
      case TextAlign.center:
        return Offset(width / 2.0, 0.0);
      case TextAlign.justify:
      case TextAlign.start:
        assert(textDirection != null);
        switch (textDirection) {
          case TextDirection.rtl:
            return Offset(width, 0.0);
          case TextDirection.ltr:
            return Offset.zero;
        }
        return null;
      case TextAlign.end:
        assert(textDirection != null);
        switch (textDirection) {
          case TextDirection.rtl:
            return Offset.zero;
          case TextDirection.ltr:
            return Offset(width, 0.0);
        }
        return null;
    }
    return null;
  }

  /// Returns the offset at which to paint the caret.
  /// 返回绘制插入符号的偏移量。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[layout]后有效。
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    _computeCaretMetrics(position, caretPrototype);
    return _caretMetrics.offset;
  }

  /// Returns the tight bounded height of the glyph at the given [position].
  /// 返回给定[position]处标志符号的紧边界高度。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[layout]后有效。
  double getFullHeightForCaret(TextPosition position, Rect caretPrototype) {
    _computeCaretMetrics(position, caretPrototype);
    return _caretMetrics.fullHeight;
  }

  // Cached caret metrics. This allows multiple invokes of [getOffsetForCaret] and
  // [getFullHeightForCaret] in a row without performing redundant and expensive
  // get rect calls to the paragraph.
  // 缓存插入符号度量。这允许在一行中多次调用[getOffsetForCaret]和[getFullHeightForCaret]，
  // 而不必对段落执行多余且昂贵的get rect调用。
  _CaretMetrics _caretMetrics;

  // Holds the TextPosition and caretPrototype the last caret metrics were
  // computed with. When new values are passed in, we recompute the caret metrics.
  // only as necessary.
  // 保留上次计算插入符号度量时使用的TextPosition和caretPrototype。
  // 当传入新值时，我们重新计算插入符号度量。仅在必要时。
  TextPosition _previousCaretPosition;
  Rect _previousCaretPrototype;

  // Checks if the [position] and [caretPrototype] have changed from the cached
  // version and recomputes the metrics required to position the caret.
  // 检查[position]和[caretPrototype]是否已从缓存版本更改，并重新计算定位插入符号所需的度量。
  void _computeCaretMetrics(TextPosition position, Rect caretPrototype) {
    assert(!_needsLayout);
    if (position == _previousCaretPosition && caretPrototype == _previousCaretPrototype)
      return;
    final int offset = position.offset;
    assert(position.affinity != null);
    Rect rect;
    switch (position.affinity) {
      case TextAffinity.upstream: {
        rect = _getRectFromUpstream(offset, caretPrototype) ?? _getRectFromDownstream(offset, caretPrototype);
        break;
      }
      case TextAffinity.downstream: {
        rect = _getRectFromDownstream(offset, caretPrototype) ??  _getRectFromUpstream(offset, caretPrototype);
        break;
      }
    }
    _caretMetrics = _CaretMetrics(
      offset: rect != null ? Offset(rect.left, rect.top) : _emptyOffset,
      fullHeight: rect != null ? rect.bottom - rect.top : null,
    );

    // Cache the input parameters to prevent repeat work later.
    // 缓存输入参数以防止以后重复工作。
    _previousCaretPosition = position;
    _previousCaretPrototype = caretPrototype;
  }

  /// Returns a list of rects that bound the given selection.
  /// 返回绑定给定选择的矩形列表。
  ///
  /// A given selection might have more than one rect if this text painter
  /// contains bidirectional text because logically contiguous text might not be
  /// visually contiguous.
  /// 如果此文本刷包含双向文本，则给定的选择可能有多个矩形，因为逻辑上相邻的
  /// 文本可能在视觉上不相邻。
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    assert(!_needsLayout);
    return _paragraph.getBoxesForRange(selection.start, selection.end);
  }

  /// Returns the position within the text for the given pixel offset.
  /// 返回给定像素偏移量在文本中的位置。
  TextPosition getPositionForOffset(Offset offset) {
    assert(!_needsLayout);
    return _paragraph.getPositionForOffset(offset);
  }

  /// Returns the text range of the word at the given offset. Characters not
  /// part of a word, such as spaces, symbols, and punctuation, have word breaks
  /// on both sides. In such cases, this method will return a text range that
  /// contains the given text position.
  /// 
  /// 返回给定偏移量处单词的文本范围。不是单词一部分的字符，如空格、符号和标点符号，
  /// 两边都有分词符。在这种情况下，此方法将返回包含给定文本位置的文本范围。
  ///
  /// Word boundaries are defined more precisely in Unicode Standard Annex #29
  /// 在Unicode标准附件29中，单词边界的定义更加精确
  /// <http://www.unicode.org/reports/tr29/#Word_Boundaries>.
  TextRange getWordBoundary(TextPosition position) {
    assert(!_needsLayout);
    return _paragraph.getWordBoundary(position);
  }

  /// Returns the text range of the line at the given offset.
  /// 返回给定偏移处的行的文本范围。
  ///
  /// The newline, if any, is included in the range.
  /// 换行符（如果有的话）包含在范围内。
  TextRange getLineBoundary(TextPosition position) {
    assert(!_needsLayout);
    return _paragraph.getLineBoundary(position);
  }

  /// Returns the full list of [LineMetrics] that describe in detail the various
  /// metrics of each laid out line.
  /// 返回[LineMetrics]的完整列表，该列表详细描述了每行的各种度量。
  ///
  /// The [LineMetrics] list is presented in the order of the lines they represent.
  /// For example, the first line is in the zeroth index.
  /// [LineMetrics]列表按它们所代表的行的顺序显示。例如，第一行在第零个索引中。
  ///
  /// [LineMetrics] contains measurements such as ascent, descent, baseline, and
  /// width for the line as a whole, and may be useful for aligning additional
  /// widgets to a particular line.
  /// [LineMetrics]包含整个行的测量值，如上升、下降、基线和宽度，
  /// 对于将其他小部件与特定行对齐可能很有用。
  ///
  /// Valid only after [layout] has been called.
  /// 仅在调用[布局]后有效。
  ///
  /// This can potentially return a large amount of data, so it is not recommended
  /// to repeatedly call this. Instead, cache the results. The cached results
  /// should be invalidated upon the next successful [layout].
  /// 这可能会返回大量数据，因此不建议重复调用此函数。而是缓存结果。
  /// 下次成功的[布局]时，缓存的结果应无效。
  List<ui.LineMetrics> computeLineMetrics() {
    assert(!_needsLayout);
    return _paragraph.computeLineMetrics();
  }
}
