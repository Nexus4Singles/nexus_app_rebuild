import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool showCounter;
  final EdgeInsetsGeometry? contentPadding;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.showCounter = false,
    this.contentPadding,
  });

  /// Multi-line text area
  const AppTextField.multiline({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLength,
    this.onTap,
    this.onChanged,
    this.validator,
    this.inputFormatters,
    this.showCounter = true,
    this.contentPadding,
    this.minLines = 3,
    this.maxLines = 6,
  })  : keyboardType = TextInputType.multiline,
        textInputAction = TextInputAction.newline,
        textCapitalization = TextCapitalization.sentences,
        obscureText = false,
        prefixIcon = null,
        suffixIcon = null,
        onSubmitted = null;

  /// Search input field
  const AppTextField.search({
    super.key,
    this.hint = 'Search...',
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
  })  : label = null,
        helperText = null,
        errorText = null,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        textCapitalization = TextCapitalization.none,
        obscureText = false,
        readOnly = false,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        prefixIcon = const Icon(Icons.search, size: 20),
        suffixIcon = null,
        validator = null,
        inputFormatters = null,
        showCounter = false,
        contentPadding = null;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: Theme.of(context).textTheme.bodyLarge,
          buildCounter: widget.showCounter ? null : (context, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            contentPadding: widget.contentPadding,
          ),
        ),
      ],
    );
  }
}

/// Password field with visibility toggle
class PasswordTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  const PasswordTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.focusNode,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: widget.textInputAction,
          obscureText: _obscureText,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Enter password',
            errorText: widget.errorText,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
