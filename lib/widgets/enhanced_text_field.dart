import 'package:flutter/material.dart';

class EnhancedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? errorText;
  final String? helperText;
  final bool showValidationIcon;
  final TextInputType? keyboardType;
  final bool enabled;

  const EnhancedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.isPassword = false,
    this.validator,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.showValidationIcon = true,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

class _EnhancedTextFieldState extends State<EnhancedTextField> {
  bool _isPasswordVisible = false;
  bool _isValid = false;
  bool _hasBeenTouched = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasBeenTouched && widget.controller.text.isNotEmpty) {
      setState(() {
        _hasBeenTouched = true;
      });
    }

    if (widget.validator != null) {
      final validationResult = widget.validator!(widget.controller.text);
      setState(() {
        _isValid =
            validationResult == null && widget.controller.text.isNotEmpty;
      });
    }

    if (widget.onChanged != null) {
      widget.onChanged!(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && !_isPasswordVisible,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _hasBeenTouched
                ? (_isValid ? Colors.green : Colors.grey)
                : Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _hasBeenTouched
                ? (_isValid ? Colors.green : Theme.of(context).primaryColor)
                : Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: Icon(
          widget.prefixIcon,
          color: _hasBeenTouched
              ? (_isValid ? Colors.green : Colors.grey)
              : Colors.grey,
        ),
        suffixIcon: _buildSuffixIcon(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 3,
      ),
      validator: widget.validator,
      onChanged: (value) {
        if (!_hasBeenTouched) {
          setState(() {
            _hasBeenTouched = true;
          });
        }
        if (widget.onChanged != null) {
          widget.onChanged!(value);
        }
      },
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.isPassword) {
      return IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      );
    }

    if (widget.showValidationIcon &&
        _hasBeenTouched &&
        widget.controller.text.isNotEmpty) {
      return Icon(
        _isValid ? Icons.check_circle : Icons.error,
        color: _isValid ? Colors.green : Colors.red,
      );
    }

    return null;
  }
}
