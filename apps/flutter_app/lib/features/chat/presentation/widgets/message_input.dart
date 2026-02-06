import 'package:flutter/material.dart';

class MessageInputField extends StatefulWidget {
  final Function(String) onSendText;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onVoicePressed;
  final bool isSending;
  final String? hintText;

  const MessageInputField({
    super.key,
    required this.onSendText,
    this.onAttachmentPressed,
    this.onVoicePressed,
    this.isSending = false,
    this.hintText,
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    
    widget.onSendText(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.onAttachmentPressed != null)
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                onPressed: widget.onAttachmentPressed,
              ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? '输入消息...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.outline,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSendButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    if (widget.isSending) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }
    
    if (_hasText) {
      return IconButton(
        icon: Icon(
          Icons.send,
          color: theme.colorScheme.primary,
        ),
        onPressed: _handleSend,
      );
    }
    
    if (widget.onVoicePressed != null) {
      return IconButton(
        icon: Icon(
          Icons.mic,
          color: theme.colorScheme.primary,
        ),
        onPressed: widget.onVoicePressed,
      );
    }
    
    return IconButton(
      icon: Icon(
        Icons.send,
        color: theme.colorScheme.outline,
      ),
      onPressed: null,
    );
  }
}
