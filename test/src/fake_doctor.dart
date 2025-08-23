import 'package:flutterpi_tool/src/fltool/common.dart' as fl;
import 'package:test/fake.dart';

class FakeAndroidLicenseValidator extends Fake
    implements fl.AndroidLicenseValidator {
  @override
  Future<fl.LicensesAccepted> get licensesAccepted async =>
      fl.LicensesAccepted.all;
}

class FakeDoctor extends fl.Doctor {
  FakeDoctor(fl.Logger logger, {super.clock = const fl.SystemClock()})
      : super(logger: logger);

  @override
  bool canListAnything = true;

  @override
  bool canLaunchAnything = true;

  @override
  late List<fl.DoctorValidator> validators =
      super.validators.map<fl.DoctorValidator>((v) {
    if (v is fl.AndroidLicenseValidator) {
      return FakeAndroidLicenseValidator();
    }
    return v;
  }).toList();
}
