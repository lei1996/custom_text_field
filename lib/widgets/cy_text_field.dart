import 'package:custom_textfield/cys/custom_text_field.dart';
import 'package:flutter/material.dart';

class CyTextField extends StatefulWidget {
  @override
  _CyTextFieldState createState() => _CyTextFieldState();
}

class _CyTextFieldState extends State<CyTextField> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomTextField(
        controller: _messageController,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (_messageController.text.isEmpty) return;
          // _sendMessage(
          //   to: widget.id,
          //   type: 'text',
          //   content: _messageController.text,
          // );
          _messageController.text = '';
        },
        // collapsed 去除input 下面的线
        decoration: InputDecoration.collapsed(
          hintText: '代码写完了吗?',
        ),
      ),
    );
  }
}
