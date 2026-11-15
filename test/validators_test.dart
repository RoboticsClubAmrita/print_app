import 'package:flutter_test/flutter_test.dart';
import 'package:print_service_app/utils/validators.dart';

void main() {
  group('staff signup email', () {
    test('accepts a staff Amrita address', () {
      expect(Validators.isAmritaEmail('a_b@cb.amrita.edu'), isTrue);
      expect(Validators.isStudentEmail('a_b@cb.amrita.edu'), isFalse);
    });

    test('flags a student mailbox', () {
      expect(Validators.isStudentEmail('cb.sc.u4cse23311@cb.students.amrita.edu'), isTrue);
      expect(Validators.isStudentEmail('X@STUDENTS.AMRITA.EDU'), isTrue);
    });

    test('rejects non-Amrita addresses', () {
      expect(Validators.isAmritaEmail('someone@gmail.com'), isFalse);
      expect(Validators.isAmritaEmail('x@notamrita.edu'), isFalse);
    });
  });
}
