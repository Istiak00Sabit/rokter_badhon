import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/models/auth_link_model.dart';
import 'package:rokter_badhon/models/auth_session.dart';
import 'package:rokter_badhon/models/registration_request_model.dart';
import 'package:rokter_badhon/models/user_model.dart';
import 'package:rokter_badhon/services/auth_services.dart';

void main() {
  final time = Timestamp.fromDate(DateTime.utc(2026, 10, 10));
  const uid = 'applicant-firebase-uid';
  const identity = RegistrationIdentity(
    uid: uid,
    authEmail: 'p01700000001@auth.rokterbadhon.internal',
  );
  const applicant = RegistrationApplicantInput(
    name: 'Synthetic Ghatail Applicant',
    phone: '01700000001',
    email: null,
    bloodGroup: 'O+',
    profession: 'Student',
    address: 'Synthetic',
    union: 'ঘাটাইল',
    village: 'নরজনা',
  );

  test('registration -> pending -> operator-approved link -> admitted login gate', () async {
    Map<String, dynamic>? written;
    var signOuts = 0;

    final submitted = await RegistrationWorkflow.createAndSubmit(
      applicant: applicant,
      createIdentity: () async => identity,
      writeRequest: (_, payload) async => written = payload,
      signOut: () async => signOuts++,
    );
    expect(submitted.requestSubmitted, isTrue);
    expect(signOuts, 1);
    expect(written!['status'], 'pending');
    expect(written!['auth_uid'], uid);

    // Simulate the committed server timestamp when reading Firestore.
    final data = {...written!, 'requested_at': time};
    final pending = RegistrationRequestModel.fromMap(data, uid);
    expect(
      UnlinkedRegistrationPolicy.evaluate(pending),
      AuthSessionState.registrationPending,
    );
    expect(
      AuthSessionResult(UnlinkedRegistrationPolicy.evaluate(pending)).isAdmitted,
      isFalse,
    );

    // A rejected request also remains outside all protected application UI.
    final rejected = RegistrationRequestModel.fromMap({
      ...data,
      'status': 'rejected',
      'rejected_by': 'reviewer-user',
      'rejected_at': time,
    }, uid);
    expect(
      UnlinkedRegistrationPolicy.evaluate(rejected),
      AuthSessionState.registrationRejected,
    );

    // A request's approved flag alone cannot open the dashboard.
    final approved = RegistrationRequestModel.fromMap({
      ...data,
      'status': 'approved',
      'approved_by': 'reviewer-user',
      'approved_at': time,
      'linked_user_id': 'new-user',
    }, uid);
    expect(
      UnlinkedRegistrationPolicy.evaluate(approved),
      AuthSessionState.registrationApprovedUnlinked,
    );

    // The trusted operator must commit matching auth_links and users records.
    final link = AuthLinkModel.fromMap({
      'user_id': 'new-user',
      'active': true,
      'created_at': time,
      'created_by': 'reviewer-user',
    }, uid);
    final user = UserModel.fromMap({
      'name': applicant.name,
      'phone': applicant.phone,
      'email': applicant.email,
      'blood_group': applicant.bloodGroup,
      'profession': applicant.profession,
      'address': applicant.address,
      'photo_url': null,
      'access_role': 'member',
      'active': true,
      'login_enabled': true,
      'preferred_language': null,
      'created_at': time,
      'created_by': 'reviewer-user',
      'updated_at': time,
      'updated_by': 'reviewer-user',
    }, 'new-user');
    final admitted = AuthSessionPolicy.evaluate(
      authenticated: true,
      linkDocumentExists: true,
      link: link,
      userDocumentExists: true,
      user: user,
    );
    expect(admitted, AuthSessionState.admitted);
    expect(
      AuthSessionResult(admitted, user: user).isAdmitted,
      isTrue,
    );

    final linkRevoked = AuthLinkModel.fromMap({
      'user_id': 'new-user',
      'active': false,
      'created_at': time,
      'created_by': 'reviewer-user',
    }, uid);
    expect(
      AuthSessionPolicy.evaluate(
        authenticated: true,
        linkDocumentExists: true,
        link: linkRevoked,
        userDocumentExists: true,
        user: user,
      ),
      AuthSessionState.linkInactive,
    );
  });
}
