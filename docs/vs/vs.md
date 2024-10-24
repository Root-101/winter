## Docs for Validation Service (vs)

The *Validation Service* is designed to provide a foundation for validating objects, aiming to
integrate as seamlessly as possible with the server.

**NOTE:** All examples and all possibles use cases are in the test folder of this project, so for more
details (all possibles details), go take a look at those test/examples

### Creating an instance:

The most generic class, `ValidationService`, implements a method `validate`, which takes the object
to be validated as a parameter. The server provides a fairly complete default implementation of this
method.

Let's take this object as an example:

```dart
class Tool {
  String name;

  Tool({required this.name});

  @override
  String toString() {
    return 'Tool{name: $name}';
  }
}
```

We create an instance of `ValidationService`, instantiate the object (in this case, `Tool`), and
send it
for validation:

```dart

ValidationService vs = ValidationServiceImpl();

Tool object = Tool(name: 'hammer');

List<ConstrainViolation> violations = vs.validate(object);
```

In this case, `vs.validate(object)` returns an empty list because there are no configured
validations, meaning the object is valid.

### Configuring Validations (@Valid)

Validations are configured by placing the `@Valid` annotation (or a derived one) on a field or
class. There are several built-in validations, although it's also possible to implement custom
ones (
explained below).

Let's modify the object to add a validation to prevent the name from being empty:

```dart
class Tool {
  @NotEmpty() //is the same as: `@Valid([notEmpty])`
  String name;

  Tool({required this.name});

  @override
  String toString() {
    return 'Tool{name: $name}';
  }
}
```

Now let's create an instance with an empty name to see how the validation fails:

```dart

Tool object = Tool(name: ''); //empty name

List<ConstrainViolation> violations = vs.validate(object);
```

In this case, `List<ConstrainViolation> violations` contains one element representing the failed
validation, indicating that the name is empty. The validation would look like:

```dart

List<ConstrainViolation> correctValidations = [
  ConstrainViolation(
    value: '',
    fieldName: 'root.name',
    message: 'Text can\'t be empty',
  ),
];
```

### ConstrainViolation

`ConstrainViolation` is the class that contains a failed validation for a specific object.
The method `vs.validate(object)` returns a `List<ConstrainViolation>` containing all the failed
validations.

Continuing from the previous example:

```dart

ConstrainViolation notEmptyViolation = ConstrainViolation(
  value: '',
  fieldName: 'root.name',
  message: 'Text can\'t be empty',
);
```

- **value**: Represents the value of the field that failed validation. In this case, an empty
  string.
- **fieldName**: Represents the name of the field that failed validation. Since the validation
  failed on
  an internal object field, `root.name` is used (`root.` indicates it’s part of the parent object
  passed
  to `vs.validate`, this is explained id details bellow).
- **message**: Represents the message explaining the validation failure. In this case, explaining
  that
  the text cannot be empty.

#### Field Name

Each field name in a validation represents the full path from the object passed into `vs.validate`
down to the specific field that failed validation.

- Nested Objects: If validation fails within a nested object, the name will be: `root.failedField`,
  as shown in the example above.
- Lists: If validation fails on an object inside a list, the field name will
  be `root[n].failedField`, where `n` represents the index of the element that failed.

  Example:

```dart

List<Tool> list = [Tool(name: 'drill'), Tool(name: ''), Tool(name: 'hammer')];
```

```dart

List<ConstrainViolation> listViolation = [
  ConstrainViolation(
    value: '',
    fieldName: 'root[1].name',
    message: 'Text can\'t be empty',
  )
];
```

This means the element at position 1 in the list has an empty name.

- Maps: If validation fails on an object inside a map, the field name will
  be `root[key].failedField`.

  Example:

```dart

Map<String, Tool> list = {
  'first': Tool(name: 'drill'),
  'second': Tool(name: ''),
  'n': Tool(name: 'hammer')
};
```

```dart

List<ConstrainViolation> listViolation = [
  ConstrainViolation(
    value: '',
    fieldName: 'root[second].name',
    message: 'Text can\'t be empty',
  )
];
```

#### Custom Field Name

If you want the field name to be different, you can annotate it with: `@JsonProperty('FIELD_NAME')`

Taking this object as an example:

```dart
class Car {
  @NotEmpty()
  @JsonProperty('BRAND')
  String? brand;

  Car({required this.brand});

  @override
  String toString() {
    return 'Car{brand: $brand}';
  }
}
```

We create an instance and validate it, the result is:

```dart

Car car = Car(
  brand: '',
);

List<ConstrainViolation> violations = vs.validate(car);
//  violations is same:
// violations ===>>> [
//   ConstrainViolation(
//     value: '',
//     fieldName: 'this.BRAND',
//     message: 'Text can\'t be empty',
//   ),
// ];
```

### Custom Validations

You can also create custom validations. To do so, you have two options:

1 - A constant method/function that performs the validation inside `@Valid`:

```dart
bool customTool(dynamic prop, ConstraintValidatorContext cvc) {
  if (prop is! Tool) {
    cvc.addViolation(
      value: prop,
      fieldName: 'root',
      message: 'Value is no a Tool',
    );
    return false;
  }
  Tool tool = prop as Tool;
  if (tool.name == 'hammer') {
    cvc.addTemplateViolation('Cant be a hammer');
  }
  return cvc.isValid();
}
```

In this case, we are validating that the object (`prop`) is of type `Tool`. If it is not, we add a
violation and terminate the validation. If the object is a valid `Tool`, the next validation checks
if
the tool’s name is *"hammer"*, in which case another violation is added.

Notice there are two ways to create a violation. The first, `cvc.addViolation`, can be used to
create
fully customized validations, while the second, `cvc.addTemplateViolation`, creates a template that
automatically fills in the other fields (`value` and `fieldName`).

Finally, we apply the custom validation to the object:

```dart
@Valid([customTool])
class Tool {
  String? name;

  Tool({required this.name});

  @override
  String toString() {
    return 'Tool{name: $name}';
  }
}
```

```dart

Tool tool = Tool(name: 'hammer');

List<ConstrainViolation> violations = vs.validate(tool);
```

2 - You can go further by creating a custom annotation, (this example simplifies the `@Size`
annotation):

Note that the annotation has to extend `Valid` for it to work:

```dart

class Size extends Valid {
  final int min;
  final int max;

  const Size({
    required this.min,
    required this.max,
  }) : super(const [size]);
}

bool size(dynamic property, ConstraintValidatorContext cvc) {
  if (cvc.parent is! Size) {
    throw StateError(
        'size validation called inside a non Size annotation (@Size)');
  }
  Size rawAnnotation = cvc.parent as Size;

  int? length;
  if (property == null) {
    cvc.addTemplateViolation('Property can\'t be null');
  } else if (property is! String) {
    cvc.addTemplateViolation('Property is not a String');
  } else if (property is String) {
    length = property.length;
  }

  if (length != null && length < rawAnnotation.min) {
    cvc.addTemplateViolation(
      'Length must be greater than ${rawAnnotation.min}',
    );
  }
  if (length != null && length > rawAnnotation.max) {
    cvc.addTemplateViolation(
      'Length must be less than ${rawAnnotation.max}',
    );
  }
  return cvc.isValid();
}
```

Note that using `cvc.parent`, you can access the annotation itself.

Now we can use it like this:

```dart
class Tool {
  @Size(min: 5, max: 50)
  String? name;

  Tool({required this.name});

  @override
  String toString() {
    return 'Tool{name: $name}';
  }
}
```

```dart

Tool tool = Tool(name: 'axe');

List<ConstrainViolation> violations = vs.validate(tool);
```

This will provide the validation:

```dart

List<ConstrainViolation> correctValidations = [
  ConstrainViolation(
    value: '',
    fieldName: 'root.name',
    message: 'Text length must be greater than 5',
  ),
];
```

### Custom Personalizations

You can also customize the behavior of the validation service in the following ways:

#### - Base name:

By default, when a validation fails on the object passed into validate, the fieldName begins with
root. to represent the `root` object. This name can be changed in two ways:
1 - By passing the property `String? parentFieldName` when calling validate. However, this requires
manually setting it every time you call validate.
2 - If a 'global' config is needed, then by configuring it globally during the service
initialization:

```dart

ValidationService vs = ValidationServiceImpl(baseName: 'this');
```

Both configurations give the same result:

```dart

ValidationService vs = ValidationServiceImpl(baseName: 'this');
Tool tool = Tool(
  name: '',
);
List<ConstrainViolation> violations = vs.validate(address);
List<ConstrainViolation> correctValidations = [
  ConstrainViolation(
    value: '',
    fieldName: 'this.name', //notar que aqui en vez del default `root.` aparece `this.`
    message: 'Text can\'t be empty',
  ),
];
```

#### - Field name separator:

By default, when a validation fails for a nested object, fields are separated by a dot (`.`). This
can
be configured in two ways:
1 - By passing the property `String? fieldNameSeparator` when calling validate. However, this
requires
manually setting it every time you call validate.
2 - If a 'global' config is needed, then by configuring it globally during the service
initialization:

```dart

ValidationService vs = ValidationServiceImpl(defaultFieldSeparator: ' -> ');
```

Now the result will be:

```dart

ValidationService vs = ValidationServiceImpl(defaultFieldSeparator: ' -> ');
Tool tool = Tool(
  name: '',
);
List<ConstrainViolation> violations = vs.validate(address);
List<ConstrainViolation> correctValidations = [
  ConstrainViolation(
    value: '',
    fieldName: 'this -> name', //notar que aqui en vez del default `.` aparece ` -> `
    message: 'Text can\'t be empty',
  ),
];
```

That's all, If you need more examples, you can go to the unit tests of this service,
where you will find ALL possible use cases with their example.

If there is something wrong or a bug, feel free to create an issue (and even it's PR)

#### Throw ValidationException

The default behaviour when validating an object is return a `List<ConstrainViolation>`, but some times it's easy to just
throw an exception.

Imagine this scenario:

```dart
example() {
  Tool object = Tool(name: 'hammer');

  List<ConstrainViolation> violations = vs.validate(object);

  if (violations.isNotEmpty) {
    ///some validation failed, do something
  } else {
    ///everything oka
  }
}
```

But you can also do:

```dart
example() {
  Tool object = Tool(name: 'hammer');

  try {
    vs.validate(object);

    ///continue doing normal stuff
  } on ValidationException catch (exc) {
    ///some validation failed, do something
  }
}
```

**NOTE:** the real use of this validation throwing is to integrate this validations with the exception handler, this way
if a validations fails the developer will not have to do anything and a 422 response will be automatically sent.
More details of this in the exception-handling docs.

### Extra notes:

- Map keys are not validated: To do this you will need to implement your own validation
