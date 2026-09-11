#!/usr/bin/env node
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';

import { approveRegistration, rejectRegistration } from './src/admission.js';
import { bootstrapDeveloperAdmin, recoverDeveloperAdmin } from './src/developer_admin.js';
import { assignCommitteePosition, endCommitteeAssignment } from './src/committee.js';
import {
  addCommitteeMedia,
  deactivateCommitteeMedia,
  editCommitteeMediaCaption,
  setCommitteeGroupPhoto,
  setCommitteeMediaOrder,
} from './src/committee_media.js';
import { AdmissionError } from './src/policy.js';
import { rolloverCommitteeTerm } from './src/committee_term.js';
import { deactivateDonor } from './src/donor.js';
import { correctDonation, recordDonation } from './src/donation.js';
import { cancelBloodRequest, editBloodRequest, fulfillBloodRequest } from './src/blood_request.js';
import {
  addEventMedia,
  createEvent,
  editEventMediaCaption,
  hideEvent,
  hideEventMedia,
  setEventCover,
  setEventMediaOrder,
  updateEvent,
} from './src/event.js';
import { assertSafeTarget } from './src/safety.js';

function parseArguments(values) {
  const [command, ...rest] = values;
  const options = {};
  for (let index = 0; index < rest.length; index += 2) {
    const key = rest[index];
    const value = rest[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new AdmissionError('invalid_argument', 'Arguments must use --name value pairs.');
    }
    options[key.slice(2)] = value;
  }
  return { command, options };
}

function parseNullableTimestamp(value, label) {
  if (value === undefined || value === 'null') return null;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
    throw new AdmissionError('invalid_argument', `${label} must be an ISO-8601 timestamp with timezone or null.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) throw new AdmissionError('invalid_argument', `${label} is invalid.`);
  return Timestamp.fromDate(parsed);
}

async function main() {
  const { command, options } = parseArguments(process.argv.slice(2));
  const projectId = options['project-id'];
  console.log(`Target Firebase project: ${projectId ?? '(missing)'}`);
  assertSafeTarget({
    projectId,
    firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    authEmulatorHost: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  });

  const appOptions = { projectId };
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    appOptions.credential = applicationDefault();
  }
  const app = initializeApp(appOptions);
  const dependencies = {
    db: getFirestore(app),
    auth: getAuth(app),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    operatorUid: options['operator-uid'],
    applicantUid: options['applicant-uid'],
    operationId: options['operation-id'],
    reason: options.reason,
  };

  let result;
  if (command === 'approve') {
    result = await approveRegistration({
      ...dependencies,
      targetRole: options['target-role'],
    });
  } else if (command === 'reject') {
    result = await rejectRegistration(dependencies);
  } else if (command === 'bootstrap-developer-admin' || command === 'recover-developer-admin') {
    const protectedDependencies = {
      db: dependencies.db,
      auth: dependencies.auth,
      serverTimestamp: dependencies.serverTimestamp,
      authUid: options['auth-uid'],
      operationId: options['operation-id'],
      reason: options.reason,
      identity: {
        name: options.name,
        phone: options.phone,
        email: options.email,
        blood_group: options['blood-group'],
        profession: options.profession,
        address: options.address,
        preferred_language: options['preferred-language'],
      },
    };
    result = command === 'bootstrap-developer-admin'
      ? await bootstrapDeveloperAdmin(protectedDependencies)
      : await recoverDeveloperAdmin({
        ...protectedDependencies,
        oldUserId: options['old-user-id'],
      });
  } else if (command === 'assign-committee-position') {
    result = await assignCommitteePosition({
      ...dependencies,
      targetUserId: options['target-user-id'],
      termId: options['term-id'],
      position: options.position,
    });
  } else if (command === 'end-committee-assignment') {
    result = await endCommitteeAssignment({
      ...dependencies,
      assignmentId: options['assignment-id'],
    });
  } else if (command === 'add-committee-media') {
    result = await addCommitteeMedia({
      ...dependencies,
      termId: options['term-id'],
      imageUrl: options['image-url'],
      caption: options.caption,
      sortOrder: Number(options['sort-order']),
      provider: options.provider,
      providerPublicId: options['provider-public-id'],
    });
  } else if (command === 'deactivate-committee-media') {
    result = await deactivateCommitteeMedia({
      ...dependencies,
      mediaId: options['media-id'],
    });
  } else if (command === 'edit-committee-media-caption') {
    result = await editCommitteeMediaCaption({
      ...dependencies,
      mediaId: options['media-id'],
      caption: options.caption === 'null' ? null : options.caption,
    });
  } else if (command === 'set-committee-media-order') {
    result = await setCommitteeMediaOrder({
      ...dependencies,
      mediaId: options['media-id'],
      sortOrder: Number(options['sort-order']),
    });
  } else if (command === 'set-committee-group-photo') {
    result = await setCommitteeGroupPhoto({
      ...dependencies,
      termId: options['term-id'],
      imageUrl: options['image-url'] === 'null' ? null : options['image-url'],
    });
  } else if (command === 'rollover-committee-term') {
    result = await rolloverCommitteeTerm({
      ...dependencies,
      currentTermId: !options['current-term-id'] || options['current-term-id'] === 'none'
        ? null
        : options['current-term-id'],
      name: options.name,
      startYear: Number(options['start-year']),
      endYear: Number(options['end-year']),
      startDate: parseNullableTimestamp(options['start-date'], 'start-date'),
      endDate: parseNullableTimestamp(options['end-date'], 'end-date'),
      groupPhotoUrl: options['group-photo-url'] === undefined || options['group-photo-url'] === 'null'
        ? null
        : options['group-photo-url'],
    });
  } else if (command === 'deactivate-donor') {
    result = await deactivateDonor({
      ...dependencies,
      donorId: options['donor-id'],
    });
  } else if (command === 'record-donation') {
    result = await recordDonation({
      ...dependencies,
      donorId: options['donor-id'],
      donationDate: parseNullableTimestamp(options['donation-date'], 'donation-date'),
      location: options.location === 'null' ? null : options.location,
      hospital: options.hospital === 'null' ? null : options.hospital,
      recipientName: options['recipient-name'] === 'null' ? null : options['recipient-name'],
      recipientContact: options['recipient-contact'] === 'null' ? null : options['recipient-contact'],
    });
  } else if (command === 'correct-donation') {
    result = await correctDonation({
      ...dependencies,
      donationId: options['donation-id'],
      donationDate: options['donation-date'] === undefined ? undefined : parseNullableTimestamp(options['donation-date'], 'donation-date'),
      location: options.location === undefined ? undefined : options.location === 'null' ? null : options.location,
      hospital: options.hospital === undefined ? undefined : options.hospital === 'null' ? null : options.hospital,
      recipientName: options['recipient-name'] === undefined ? undefined : options['recipient-name'] === 'null' ? null : options['recipient-name'],
      recipientContact: options['recipient-contact'] === undefined ? undefined : options['recipient-contact'] === 'null' ? null : options['recipient-contact'],
    });
  } else if (command === 'edit-blood-request') {
    result = await editBloodRequest({
      ...dependencies, requestId: options['request-id'], bloodGroup: options['blood-group'],
      patientName: options['patient-name'] === undefined ? undefined : options['patient-name'] === 'null' ? null : options['patient-name'],
      hospital: options.hospital, location: options.location, contactName: options['contact-name'],
      contactPhone: options['contact-phone'],
      requiredAt: options['required-at'] === undefined ? undefined : parseNullableTimestamp(options['required-at'], 'required-at'),
    });
  } else if (command === 'fulfill-blood-request') {
    result = await fulfillBloodRequest({ ...dependencies, requestId: options['request-id'] });
  } else if (command === 'cancel-blood-request') {
    result = await cancelBloodRequest({ ...dependencies, requestId: options['request-id'] });
  } else if (command === 'create-event') {
    result = await createEvent({
      ...dependencies,
      title: options.title,
      description: options.description === 'null' ? null : options.description,
      eventType: options['event-type'],
      eventDate: parseNullableTimestamp(options['event-date'], 'event-date'),
      location: options.location === 'null' ? null : options.location,
      coverImageUrl: options['cover-image-url'] === 'null' ? null : options['cover-image-url'],
    });
  } else if (command === 'edit-event') {
    result = await updateEvent({
      ...dependencies,
      eventId: options['event-id'],
      title: options.title,
      description: options.description === undefined ? undefined : options.description === 'null' ? null : options.description,
      eventType: options['event-type'],
      eventDate: options['event-date'] === undefined ? undefined : parseNullableTimestamp(options['event-date'], 'event-date'),
      location: options.location === undefined ? undefined : options.location === 'null' ? null : options.location,
    });
  } else if (command === 'hide-event') {
    result = await hideEvent({ ...dependencies, eventId: options['event-id'] });
  } else if (command === 'set-event-cover') {
    result = await setEventCover({
      ...dependencies,
      eventId: options['event-id'],
      coverImageUrl: options['cover-image-url'] === 'null' ? null : options['cover-image-url'],
    });
  } else if (command === 'add-event-media') {
    result = await addEventMedia({
      ...dependencies,
      eventId: options['event-id'],
      imageUrl: options['image-url'],
      caption: options.caption === 'null' ? null : options.caption,
      sortOrder: Number(options['sort-order']),
      provider: options.provider === 'null' ? null : options.provider,
      providerPublicId: options['provider-public-id'] === 'null' ? null : options['provider-public-id'],
    });
  } else if (command === 'edit-event-media-caption') {
    result = await editEventMediaCaption({
      ...dependencies,
      mediaId: options['media-id'],
      caption: options.caption === 'null' ? null : options.caption,
    });
  } else if (command === 'set-event-media-order') {
    result = await setEventMediaOrder({
      ...dependencies,
      mediaId: options['media-id'],
      sortOrder: Number(options['sort-order']),
    });
  } else if (command === 'hide-event-media') {
    result = await hideEventMedia({ ...dependencies, mediaId: options['media-id'] });
  } else {
    throw new AdmissionError(
      'invalid_argument',
      'Unknown command. Use an explicitly reviewed registration, organization, donor, or event operation.',
    );
  }
  console.log(`${result.action}; operation_id=${result.operationId}${result.userId ? `; user_id=${result.userId}` : ''}${result.assignmentId ? `; assignment_id=${result.assignmentId}` : ''}${result.mediaId ? `; media_id=${result.mediaId}` : ''}${result.termId ? `; term_id=${result.termId}` : ''}${result.donorId ? `; donor_id=${result.donorId}` : ''}${result.eventId ? `; event_id=${result.eventId}` : ''}${result.donationId ? `; donation_id=${result.donationId}` : ''}${result.requestId ? `; request_id=${result.requestId}` : ''}`);
}

main().catch((error) => {
  const code = error instanceof AdmissionError ? error.code : 'operation_failed';
  console.error(`${code}: ${error.message}`);
  process.exitCode = 1;
});
