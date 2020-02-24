// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show hashValues, TextAffinity, TextPosition, TextRange;

import 'package:flutter/foundation.dart';

export 'dart:ui' show TextAffinity, TextPosition, TextRange;

/// A range of text that represents a selection.
/// 表示选定内容的文本范围。
@immutable
class TextSelection extends TextRange {
  /// Creates a text selection.
  /// 创建文本选择。
  ///
  /// The [baseOffset] and [extentOffset] arguments must not be null.
  /// [baseOffset]和[extentOffset]参数不能为空。
  const TextSelection({
    @required this.baseOffset,
    @required this.extentOffset,
    this.affinity = TextAffinity.downstream,
    this.isDirectional = false,
  }) : super(
         start: baseOffset < extentOffset ? baseOffset : extentOffset,
         end: baseOffset < extentOffset ? extentOffset : baseOffset,
       );

  /// Creates a collapsed selection at the given offset.
  /// 
  /// 在给定偏移处创建折叠的选择。
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  /// 
  /// 折叠的选定内容以相同的偏移量开始和结束，这意味着它包含零个字符，但作为文本中的插入点。
  ///
  /// The [offset] argument must not be null.
  /// [offset]参数不能为空。
  const TextSelection.collapsed({
    @required int offset,
    this.affinity = TextAffinity.downstream,
  }) : baseOffset = offset,
       extentOffset = offset,
       isDirectional = false,
       super.collapsed(offset);

  /// Creates a collapsed selection at the given text position.
  /// 
  /// 在给定的文本位置创建折叠的选定内容。
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  /// 
  /// 折叠的选定内容以相同的偏移量开始和结束，这意味着它包含零个字符，但作为文本中的插入点。
  TextSelection.fromPosition(TextPosition position)
    : baseOffset = position.offset,
      extentOffset = position.offset,
      affinity = position.affinity,
      isDirectional = false,
      super.collapsed(position.offset);

  /// The offset at which the selection originates.
  /// 
  /// 选择开始的偏移量。
  ///
  /// Might be larger than, smaller than, or equal to extent.
  /// 
  /// 可能大于、小于或等于范围。
  final int baseOffset;

  /// The offset at which the selection terminates.
  /// 
  /// 选择终止的偏移量。
  ///
  /// When the user uses the arrow keys to adjust the selection, this is the
  /// value that changes. Similarly, if the current theme paints a caret on one
  /// side of the selection, this is the location at which to paint the caret.
  /// 
  /// 当用户使用箭头键调整选择时，这是更改的值。类似地，如果当前主题在所选内容的一侧绘制插入符号，则这是绘制插入符号的位置。
  ///
  /// Might be larger than, smaller than, or equal to base.
  /// 可能大于、小于或等于基。
  final int extentOffset;

  /// If the text range is collapsed and has more than one visual location
  /// (e.g., occurs at a line break), which of the two locations to use when
  /// painting the caret.
  /// 
  /// 如果文本区域折叠并且有多个可视位置（例如，在换行符处出现），则在绘制插入符号时使用这两个位置中的哪一个。
  final TextAffinity affinity;

  /// Whether this selection has disambiguated its base and extent.
  /// 
  /// 这个选择是否消除了它的基础和范围的歧义。
  ///
  /// On some platforms, the base and extent are not disambiguated until the
  /// first time the user adjusts the selection. At that point, either the start
  /// or the end of the selection becomes the base and the other one becomes the
  /// extent and is adjusted.
  /// 
  /// 在某些平台上，直到用户第一次调整所选内容时，才会消除基数和范围的歧义。
  /// 在这一点上，选择的开始或结束成为基础，另一个成为范围并进行调整。
  final bool isDirectional;

  /// The position at which the selection originates.
  /// 开始选择的位置。
  ///
  /// Might be larger than, smaller than, or equal to extent.
  /// 可能大于、小于或等于范围。
  TextPosition get base => TextPosition(offset: baseOffset, affinity: affinity);

  /// The position at which the selection terminates.
  /// 选择终止的位置。
  ///
  /// When the user uses the arrow keys to adjust the selection, this is the
  /// value that changes. Similarly, if the current theme paints a caret on one
  /// side of the selection, this is the location at which to paint the caret.
  /// 
  /// 当用户使用箭头键调整选择时，这是更改的值。类似地，如果当前主题在所选内容的一侧绘制插入符号，则这是绘制插入符号的位置。
  ///
  /// Might be larger than, smaller than, or equal to base.
  /// 可能大于、小于或等于基。
  TextPosition get extent => TextPosition(offset: extentOffset, affinity: affinity);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'TextSelection')}(baseOffset: $baseOffset, extentOffset: $extentOffset, affinity: $affinity, isDirectional: $isDirectional)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    return other is TextSelection
        && other.baseOffset == baseOffset
        && other.extentOffset == extentOffset
        && other.affinity == affinity
        && other.isDirectional == isDirectional;
  }

  @override
  int get hashCode => hashValues(
    baseOffset.hashCode,
    extentOffset.hashCode,
    affinity.hashCode,
    isDirectional.hashCode,
  );

  /// Creates a new [TextSelection] based on the current selection, with the
  /// provided parameters overridden.
  /// 
  /// 基于当前选择创建新的[TextSelection]，并覆盖提供的参数。
  TextSelection copyWith({
    int baseOffset,
    int extentOffset,
    TextAffinity affinity,
    bool isDirectional,
  }) {
    return TextSelection(
      baseOffset: baseOffset ?? this.baseOffset,
      extentOffset: extentOffset ?? this.extentOffset,
      affinity: affinity ?? this.affinity,
      isDirectional: isDirectional ?? this.isDirectional,
    );
  }
}
