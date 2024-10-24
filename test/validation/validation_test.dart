@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'models.dart';

late ValidationService vs;

///TODO: test for
///- premade: Size

void main() {
  setUpAll(() {
    // Global config for all tests
    vs = ValidationServiceImpl();
  });

  test('Manual validation - CustomValidatableObject', () async {
    CustomValidatableObject object = CustomValidatableObject(name: 'abc');

    List<ConstrainViolation> violations = vs.validate(object);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: 'abc',
        fieldName: 'base-object.name',
        message: 'Name can\'t have 3 letters',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Class Level Validation - Tool', () async {
    Tool object = Tool(name: 'hammer');

    List<ConstrainViolation> violations = vs.validate(object);
    List<ConstrainViolation> correctValidations = [
      ConstrainViolation(
        value: object,
        fieldName: 'root',
        message: 'Cant be a hammer',
      ),
    ];
    expect(violations, correctValidations);
  });

  test('Throw exception on fail - Tool', () async {
    Tool object = Tool(name: 'hammer');

    try {
      vs.validate(
        object,
        throwExceptionOnFail: true,
      );
    } on ValidationException catch (exc) {
      List<ConstrainViolation> correctValidations = [
        ConstrainViolation(
          value: object,
          fieldName: 'root',
          message: 'Cant be a hammer',
        ),
      ];
      expect(exc.violations, correctValidations);
    }
  });

  test('Field Level validation - Address', () async {
    Address address = Address(
      streetName: '',
      houseNumber: null,
    );
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root.streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.houseNumber',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Custom fieldName - Car', () async {
    Car car = Car(brand: '');

    List<ConstrainViolation> violations = vs.validate(car);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root.BRAND',
        message: 'Text can\'t be empty',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Custom baseName - Address', () async {
    ValidationService vs = ValidationServiceImpl(baseName: 'this');
    Address address = Address(
      streetName: '',
      houseNumber: null,
    );
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'this.streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'this.houseNumber',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Custom field separator - Address', () async {
    ValidationService vs = ValidationServiceImpl(defaultFieldSeparator: ' -> ');
    Address address = Address(
      streetName: '',
      houseNumber: null,
    );
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root -> streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root -> houseNumber',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Naming Strategy - Address', () async {
    Address address = Address(
      streetName: '',
      houseNumber: null,
    );
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root.streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.houseNumber',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Naming Strategy + Custom field separator + Custom baseName - Address',
      () async {
    ValidationService vs = ValidationServiceImpl(
      baseName: 'this',
      defaultFieldSeparator: ' -> ',
      namingStrategy: NamingStrategies.snakeCase,
    );
    Address address = Address(
      streetName: '',
      houseNumber: null,
    );
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'this -> street_name',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'this -> house_number',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Field Level Validation - Car', () async {
    Car object = Car(brand: '');

    List<ConstrainViolation> violations = vs.validate(object);

    expect(violations.length, 1);
  });

  test('List - List<Address>', () async {
    List<Address> address = [
      Address(
        streetName: '',
        houseNumber: null,
      ),
      Address(
        streetName: '',
        houseNumber: 456,
      ),
      Address(
        streetName: 'Third Street',
        houseNumber: 789,
      ),
    ];
    List<ConstrainViolation> violations = vs.validate(address);
    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root[0].streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root[0].houseNumber',
        message: 'Value can\'t be null',
      ),
      const ConstrainViolation(
        value: '',
        fieldName: 'root[1].streetName',
        message: 'Text can\'t be empty',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Map - Map<Address>', () async {
    Map<String, Address> address = {
      'first': Address(
        streetName: '',
        houseNumber: null,
      ),
      'second': Address(
        streetName: '',
        houseNumber: 456,
      ),
      'third': Address(
        streetName: 'Third Street',
        houseNumber: 789,
      ),
    };
    List<ConstrainViolation> violations = vs.validate(address);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root[first].streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root[first].houseNumber',
        message: 'Value can\'t be null',
      ),
      const ConstrainViolation(
        value: '',
        fieldName: 'root[second].streetName',
        message: 'Text can\'t be empty',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Full object - User', () async {
    User object = User(
      userName: null,
      userId: 0,
      duration: const Duration(days: 365),
      isActive: true,
      addresses: [
        Address(
          streetName: '',
          houseNumber: null,
        ),
        Address(
          streetName: 'Second Street',
          houseNumber: 456,
        ),
      ],
      singleAddress: Address(
        streetName: null,
        houseNumber: 789,
      ),
      additionalAttributes: {
        'key1': 'value1',
        'key2': 42,
        'key3': Address(
          streetName: null,
          houseNumber: null,
        ),
      },
    );

    List<ConstrainViolation> violations = vs.validate(object);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: 'User{userName: null, userId: 0}',
        fieldName: 'root',
        message: 'Can\'t have a cero id',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.userName',
        message: 'Value can\'t be null',
      ),
      const ConstrainViolation(
        value: '',
        fieldName: 'root.addresses[0].streetName',
        message: 'Text can\'t be empty',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.addresses[0].houseNumber',
        message: 'Value can\'t be null',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.singleAddress.streetName',
        message: 'Error validating field',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.additionalAttributes[key3].streetName',
        message: 'Error validating field',
      ),
      const ConstrainViolation(
        value: null,
        fieldName: 'root.additionalAttributes[key3].houseNumber',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Custom validation - Laptop', () async {
    Laptop object = Laptop(gbSpace: 256, ram: 16);

    List<ConstrainViolation> violations = vs.validate(object);

    List<ConstrainViolation> correctValidations = [
      ConstrainViolation(
        value: object,
        fieldName: 'root',
        message: 'need more ram',
      ),
      const ConstrainViolation(
        value: 256,
        fieldName: 'root.hard_drive_space',
        message: 'need more hd space',
      ),
    ];

    expect(violations, correctValidations);
  });

  test('Pre-made Validation: NotBlank', () async {
    ///--------- Fail Validation ---------\\\
    NotBlankTestModel object1 = NotBlankTestModel('    ');
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '    ',
        fieldName: 'root.notBlankParam',
        message: 'Value can\'t be blank',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotBlankTestModel object2 = NotBlankTestModel('Hi world');
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: NotNull', () async {
    ///--------- Fail Validation ---------\\\
    NotNullTestModel object1 = NotNullTestModel(null);
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: null,
        fieldName: 'root.notNullParam',
        message: 'Value can\'t be null',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotNullTestModel object2 = NotNullTestModel('Hi world');
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: NotEmpty - String', () async {
    ///--------- Fail Validation ---------\\\
    NotEmptyStringTestModel object1 = NotEmptyStringTestModel('');
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root.notEmptyParam',
        message: 'Text can\'t be empty',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotEmptyStringTestModel object2 = NotEmptyStringTestModel('Hi world');
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: NotEmpty - List', () async {
    ///--------- Fail Validation ---------\\\
    NotEmptyListTestModel object1 = NotEmptyListTestModel([]);
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: [],
        fieldName: 'root.notEmptyParam',
        message: 'List can\'t be empty',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotEmptyListTestModel object2 = NotEmptyListTestModel(['Hi world']);
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: NotEmpty - Map', () async {
    ///--------- Fail Validation ---------\\\
    NotEmptyMapTestModel object1 = NotEmptyMapTestModel({});
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: {},
        fieldName: 'root.notEmptyParam',
        message: 'Map can\'t be empty',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotEmptyMapTestModel object2 = NotEmptyMapTestModel({'hi': 'Hi world'});
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: NotEmpty - Set', () async {
    ///--------- Fail Validation ---------\\\
    NotEmptySetTestModel object1 = NotEmptySetTestModel({});
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: {},
        fieldName: 'root.notEmptyParam',
        message: 'Set can\'t be empty',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    NotEmptySetTestModel object2 = NotEmptySetTestModel({'Hi world'});
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: Size - String', () async {
    ///--------- Fail Validation ---------\\\
    SizedTestModel object1 = SizedTestModel('');
    List<ConstrainViolation> violations1 = vs.validate(object1);

    List<ConstrainViolation> correctValidations = [
      const ConstrainViolation(
        value: '',
        fieldName: 'root.sizedParam',
        message: 'Text length must be greater than 5',
      ),
    ];

    expect(violations1, correctValidations);

    ///--------- Working Validation ---------\\\
    SizedTestModel object2 = SizedTestModel('Hi world');
    List<ConstrainViolation> violations2 = vs.validate(object2);
    expect(violations2, []);
  });

  test('Pre-made Validation: Size (Min/Max Order) -  String', () async {
    ///--------- Fail Validation ---------\\\
    SizedTestMinMaxOrderModel object1 = SizedTestMinMaxOrderModel('');

    try {
      vs.validate(object1);
    } on StateError catch (e) {
      expect(e.message, 'Min size must be less than Max (min <= max)');
    }
  });
}
