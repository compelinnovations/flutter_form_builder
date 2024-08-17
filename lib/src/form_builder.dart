import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:realm/realm.dart';

/// A container for form fields.
class FormBuilder<T> extends StatefulWidget {
  /// Called when one of the form fields changes.
  ///
  /// In addition to this callback being invoked, all the form fields themselves
  /// will rebuild.
  final VoidCallback? onChanged;

  final bool? useEjson;

  /// DEPRECATED: Use [onPopInvokedWithResult] instead.
  final void Function(bool)? onPopInvoked;

  /// A callback triggered when the form is popped with a result.
  final PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult;

  /// Determines whether the form can be popped.
  final bool? canPop;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Used to enable/disable form fields auto validation and update their error
  /// text.
  final AutovalidateMode? autovalidateMode;

  /// An optional map of field initial values. Keys correspond to the field's
  /// name and values to the initial value of the field.
  final T? initialValue;

  /// Whether the form should ignore submitting values from fields where
  /// `enabled` is `false`.
  final bool skipDisabled;

  /// Whether the form is able to receive user input.
  final bool enabled;

  /// Whether to clear the internal value of a field when it is unregistered.
  final bool clearValueOnUnregister;

  /// Creates a container for form fields.
  ///
  /// The [child] argument must not be null.
  const FormBuilder({
    super.key,
    required this.child,
    this.onChanged,
    this.autovalidateMode,
    @Deprecated(
      'Use onPopInvokedWithResult instead. '
      'This feature was deprecated after v3.22.0-12.0.pre.',
    )
    this.onPopInvoked,
    this.onPopInvokedWithResult,
    this.useEjson = false,
    this.initialValue,
    this.skipDisabled = false,
    this.enabled = true,
    this.clearValueOnUnregister = false,
    this.canPop,
  });

  static FormBuilderState<T>? of<T>(BuildContext context) => context.findAncestorStateOfType<FormBuilderState<T>>();

  @override
  FormBuilderState<T> createState() => FormBuilderState<T>();
}

/// A type alias for a map of form fields.
typedef FormBuilderFields = Map<String, FormBuilderFieldState<FormBuilderField<dynamic>, dynamic>>;

class FormBuilderState<T> extends State<FormBuilder<T>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FormBuilderFields _fields = {};
  T? _instantValue;
  final Map<String, dynamic> _instantValueMap = {};
  T? _savedValue;
  Map<String, dynamic> _savedValueMap = {};
  final Map<String, Function> _transformers = {};
  bool _focusOnInvalid = true;

  /// Will be true if will focus on invalid field when validate
  bool get focusOnInvalid => _focusOnInvalid;

  bool get enabled => widget.enabled;

  /// Verify if all fields on form are valid.
  bool get isValid => fields.values.every((field) => field.isValid);

  /// Will be true if some field on form are dirty.
  bool get isDirty => fields.values.any((field) => field.isDirty);

  /// Will be true if some field on form are touched.
  bool get isTouched => fields.values.any((field) => field.isTouched);

  /// Get a map of errors
  Map<String, String> get errors => {
        for (var element in fields.entries.where((element) => element.value.hasError)) element.key.toString(): element.value.errorText ?? ''
      };

  /// Get initialValue.
  dynamic get initialValue => widget.initialValue;

  /// Get initialValueMap, handling the case where T might not be a map.
  dynamic get initialValueMap {
    if (widget.initialValue is Map<String, dynamic>) {
      return Map<String, dynamic>.from(widget.initialValue as Map<String, dynamic>);
    }
    return widget.initialValue;
  }

  /// Get all fields of form.
  FormBuilderFields get fields => _fields;

  T? get instantValue => _applyTransformers(_instantValue);

  /// Returns the saved value only
  T? get value => _applyTransformers(_savedValue);

  T? _applyTransformers(T? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, dynamic val) => MapEntry(
              key,
              _transformers[key]?.call(val) ?? val,
            )),
      ) as T;
    }
    return value;
  }

  dynamic transformValue(String name, T? v) {
    final t = _transformers[name];
    return t != null ? t.call(v) : v;
  }

  dynamic getTransformedValue(String name, {bool fromSaved = false}) {
    return transformValue(name, getRawValue(name, fromSaved: fromSaved));
  }

  T? getRawValue(String name, {bool fromSaved = false}) {
    if (widget.initialValue is Map<String, dynamic>) {
      return (fromSaved ? _savedValueMap[name] : _instantValueMap[name]) ?? (widget.initialValue as Map<String, dynamic>)[name];
    }
    return fromSaved ? _savedValueMap[name] : _instantValueMap[name];
  }

  void setInternalFieldValue(String name, T? value) {
    _instantValueMap[name] = value;
    widget.onChanged?.call();
  }

  void removeInternalFieldValue(String name) {
    _instantValueMap.remove(name);
  }

  void registerField(String name, FormBuilderFieldState field) {
    final oldField = _fields[name];
    assert(() {
      if (oldField != null) {
        debugPrint('Warning! Replacing duplicate Field for $name'
            ' -- this is OK to ignore as long as the field was intentionally replaced');
      }
      return true;
    }());

    _fields[name] = field;
    field.registerTransformer(_transformers);

    if (widget.clearValueOnUnregister || _instantValueMap[name] == null) {
      if (field.initialValue != null) {
        _instantValueMap[name] = field.initialValue;
      } else if (widget.initialValue is Map<String, dynamic>) {
        _instantValueMap[name] = (widget.initialValue as Map<String, dynamic>)[name];
      }
    }

    field.setValue(
      _instantValueMap[name],
      populateForm: false,
    );
  }

  void unregisterField(String name, FormBuilderFieldState field) {
    assert(
      _fields.containsKey(name),
      'Failed to unregister a field. Make sure that all field names in a form are unique.',
    );

    if (field == _fields[name]) {
      _fields.remove(name);
      _transformers.remove(name);
      if (widget.clearValueOnUnregister) {
        _instantValueMap.remove(name);
        _savedValueMap.remove(name);
      }
    } else {
      assert(() {
        debugPrint('Warning! Ignoring Field unregistration for $name'
            ' -- this is OK to ignore as long as the field was intentionally replaced');
        return true;
      }());
    }
  }

  void save() {
    _formKey.currentState!.save();
    _savedValue = _instantValue;
    _savedValueMap = _instantValueMap;
  }

  bool validate({
    bool focusOnInvalid = true,
    bool autoScrollWhenFocusOnInvalid = false,
  }) {
    _focusOnInvalid = focusOnInvalid;
    final hasError = !_formKey.currentState!.validate();
    if (hasError) {
      final wrongFields = fields.values.where((element) => element.hasError).toList();
      if (wrongFields.isNotEmpty) {
        if (focusOnInvalid) {
          wrongFields.first.focus();
        }
        if (autoScrollWhenFocusOnInvalid) {
          wrongFields.first.ensureScrollableVisibility();
        }
      }
    }
    return !hasError;
  }

  bool saveAndValidate({
    bool focusOnInvalid = true,
    bool autoScrollWhenFocusOnInvalid = false,
  }) {
    save();
    return validate(
      focusOnInvalid: focusOnInvalid,
      autoScrollWhenFocusOnInvalid: autoScrollWhenFocusOnInvalid,
    );
  }

  void reset() {
    _formKey.currentState?.reset();
  }

  void patchValue(T val) {
    if (val is Map<String, dynamic> && _instantValue is Map<String, dynamic>) {
      val.forEach((key, dynamic value) {
        _fields[key]?.didChange(value);
      });
    } else if (widget.useEjson == true) {
      final mapVal = (val)?.toEjson() as Map<String, dynamic>;
      mapVal.forEach((key, dynamic value) {
        _fields[key]?.didChange(value);
      });
    } else {
      throw UnsupportedError("patchValue is not supported for type $T");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: widget.autovalidateMode,
      onPopInvokedWithResult: widget.onPopInvokedWithResult,
      onPopInvoked: widget.onPopInvoked,
      canPop: widget.canPop,
      child: _FormBuilderScope(
        formState: this,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: widget.child,
        ),
      ),
    );
  }
}

class _FormBuilderScope extends InheritedWidget {
  const _FormBuilderScope({
    required super.child,
    required FormBuilderState formState,
  }) : _formState = formState;

  final FormBuilderState _formState;

  FormBuilder get form => _formState.widget;

  @override
  bool updateShouldNotify(_FormBuilderScope oldWidget) => oldWidget._formState != _formState;
}
