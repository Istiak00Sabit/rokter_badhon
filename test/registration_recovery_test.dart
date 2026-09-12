import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';
import 'package:rokter_badhon/services/auth_services.dart';

void main() {
  const identity = RegistrationIdentity(
    uid: 'auth-id',
    email: 'firebase@example.test',
  );
  const applicant = RegistrationApplicantInput(
    name: 'Applicant',
    phone: '01900000000',
    email: 'typed@example.test',
  );
  const boundApplicant = RegistrationApplicantInput(
    name: 'Applicant',
    phone: '01900000000',
    email: 'firebase@example.test',
  );

  test(
    'Auth creation failure creates no Firestore request or sign-out',
    () async {
      var writes = 0;
      var signOuts = 0;
      final result = await RegistrationWorkflow.createAndSubmit(
        applicant: applicant,
        createIdentity: () async => throw StateError('synthetic Auth failure'),
        sendVerification: (_) async {},
        writeRequest: (_, _) async => writes += 1,
        signOut: () async => signOuts += 1,
      );

      expect(result.state, RegistrationSubmissionState.failed);
      expect(result.authAccountCreated, isFalse);
      expect(writes, 0);
      expect(signOuts, 0);
    },
  );

  test(
    'verification delivery failure still submits a recoverable request',
    () async {
      Map<String, dynamic>? written;
      final result = await RegistrationWorkflow.createAndSubmit(
        applicant: applicant,
        createIdentity: () async => identity,
        sendVerification: (_) async =>
            throw StateError('synthetic email failure'),
        writeRequest: (_, payload) async => written = payload,
        signOut: () async {},
      );

      expect(
        result.state,
        RegistrationSubmissionState.submittedVerificationEmailFailed,
      );
      expect(result.requestSubmitted, isTrue);
      expect(result.emailVerificationSent, isFalse);
      expect(written?['auth_uid'], identity.uid);
      expect(written?['email'], identity.email);
    },
  );

  test(
    'Firestore failure keeps account recoverable and exact retry succeeds',
    () async {
      var failWrite = true;
      var signOuts = 0;
      Map<String, dynamic>? written;

      Future<void> write(
        RegistrationIdentity value,
        Map<String, dynamic> payload,
      ) async {
        if (failWrite) throw StateError('synthetic Firestore failure');
        expect(value, identity);
        written = payload;
      }

      final failed = await RegistrationWorkflow.submitExisting(
        identity: identity,
        applicant: boundApplicant,
        writeRequest: write,
        signOut: () async => signOuts += 1,
      );
      expect(
        failed.state,
        RegistrationSubmissionState.authCreatedRequestFailed,
      );
      expect(failed.authAccountCreated, isTrue);
      expect(failed.requestSubmitted, isFalse);
      expect(signOuts, 0);

      failWrite = false;
      final retried = await RegistrationWorkflow.submitExisting(
        identity: identity,
        applicant: boundApplicant,
        writeRequest: write,
        signOut: () async => signOuts += 1,
      );
      expect(retried.state, RegistrationSubmissionState.submitted);
      expect(retried.requestSubmitted, isTrue);
      expect(signOuts, 1);
      expect(written?.keys.toSet(), RegistrationRequestModel.fields);
      expect(written?['auth_uid'], identity.uid);
      expect(written?['email'], identity.email);
      expect(written?['status'], 'pending');
    },
  );

  test(
    'post-commit sign-out failure never misreports request failure',
    () async {
      var writes = 0;
      final result = await RegistrationWorkflow.submitExisting(
        identity: identity,
        applicant: boundApplicant,
        writeRequest: (_, _) async => writes += 1,
        signOut: () async => throw StateError('synthetic sign-out failure'),
      );

      expect(result.state, RegistrationSubmissionState.submittedSignOutFailed);
      expect(result.requestSubmitted, isTrue);
      expect(writes, 1);
    },
  );

  test(
    'new-account payload binds returned Auth email, not typed casing',
    () async {
      Map<String, dynamic>? written;
      final result = await RegistrationWorkflow.createAndSubmit(
        applicant: applicant,
        createIdentity: () async => identity,
        sendVerification: (_) async {},
        writeRequest: (_, payload) async => written = payload,
        signOut: () async {},
      );

      expect(result.state, RegistrationSubmissionState.submitted);
      expect(written?['email'], identity.email);
      expect(written?['email'], isNot(applicant.email));
    },
  );
}
