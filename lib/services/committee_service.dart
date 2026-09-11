import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/committee_assignment_model.dart';
import '../models/committee_member_model.dart';
import '../models/committee_media_model.dart';
import '../models/committee_term_model.dart';
import '../models/user_directory_model.dart';

class CommitteeDataException implements Exception {
  final String message;
  const CommitteeDataException(this.message);

  @override
  String toString() => message;
}

class CommitteeRoster {
  final CommitteeTermModel term;
  final List<CommitteeMemberModel> members;
  final List<CommitteeMediaModel> gallery;

  const CommitteeRoster({
    required this.term,
    required this.members,
    required this.gallery,
  });
}

class CommitteeService {
  static const termsCollection = 'committee_terms';
  static const assignmentsCollection = 'committee_assignments';
  static const directoryCollection = 'user_directory';
  static const mediaCollection = 'committee_media';
  static const _directoryQueryLimit = 30;

  final FirebaseFirestore _firestore;

  CommitteeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<CommitteeTermModel?> getCurrentTerm() async {
    final snapshot = await _firestore
        .collection(termsCollection)
        .where('active', isEqualTo: true)
        .limit(2)
        .get();
    final terms = snapshot.docs
        .map((doc) => CommitteeTermModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);
    return selectCurrentTerm(terms);
  }

  Future<List<CommitteeTermModel>> getPastTerms() async {
    final snapshot = await _firestore
        .collection(termsCollection)
        .where('active', isEqualTo: false)
        .orderBy('end_year', descending: true)
        .get();
    final terms = snapshot.docs
        .map((doc) => CommitteeTermModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);
    return orderPastTerms(terms);
  }

  Future<List<CommitteeAssignmentModel>> getActiveAssignmentsForTerm(
    String termId,
  ) async {
    _requireDocumentId(termId, 'term');
    final snapshot = await _firestore
        .collection(assignmentsCollection)
        .where('term_id', isEqualTo: termId)
        .where('active', isEqualTo: true)
        .get();
    final assignments = snapshot.docs
        .map((doc) => CommitteeAssignmentModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);
    validateActiveAssignments(termId, assignments);
    return assignments;
  }

  Future<List<CommitteeAssignmentModel>> getHistoricalAssignmentsForTerm(
    String termId,
  ) async {
    _requireDocumentId(termId, 'term');
    final snapshot = await _firestore
        .collection(assignmentsCollection)
        .where('term_id', isEqualTo: termId)
        .get();
    final assignments = snapshot.docs
        .map((doc) => CommitteeAssignmentModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);
    if (assignments.any((assignment) => assignment.termId != termId)) {
      throw const CommitteeDataException(
        'Historical assignment query returned another term.',
      );
    }
    return assignments;
  }

  Future<List<CommitteeMediaModel>> getActiveMediaForTerm(String termId) async {
    _requireDocumentId(termId, 'term');
    final snapshot = await _firestore
        .collection(mediaCollection)
        .where('term_id', isEqualTo: termId)
        .where('active', isEqualTo: true)
        .orderBy('sort_order')
        .orderBy(FieldPath.documentId)
        .get();
    final media = snapshot.docs
        .map((doc) => CommitteeMediaModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);
    return validateGallery(termId, media);
  }

  Future<CommitteeRoster> getCurrentRoster(CommitteeTermModel term) async {
    if (!term.active) {
      throw const CommitteeDataException('Current committee term is inactive.');
    }
    final assignments = await getActiveAssignmentsForTerm(term.id);
    return _buildRoster(term, assignments);
  }

  Future<CommitteeRoster> getHistoricalRoster(CommitteeTermModel term) async {
    if (term.active) {
      throw const CommitteeDataException(
        'Historical committee term must be inactive.',
      );
    }
    final assignments = await getHistoricalAssignmentsForTerm(term.id);
    return _buildRoster(term, assignments);
  }

  Future<CommitteeRoster> _buildRoster(
    CommitteeTermModel term,
    List<CommitteeAssignmentModel> assignments,
  ) async {
    final results = await Future.wait<dynamic>([
      _getActiveDirectoryEntries(
        assignments.map((assignment) => assignment.userId).toSet(),
      ),
      getActiveMediaForTerm(term.id),
    ]);
    final directory = results[0] as Map<String, UserDirectoryModel>;
    return CommitteeRoster(
      term: term,
      members: mapDirectoryPresentation(assignments, directory),
      gallery: results[1] as List<CommitteeMediaModel>,
    );
  }

  Future<Map<String, UserDirectoryModel>> _getActiveDirectoryEntries(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    final ids = userIds.toList(growable: false);
    final entries = <String, UserDirectoryModel>{};
    for (var start = 0; start < ids.length; start += _directoryQueryLimit) {
      final end = start + _directoryQueryLimit < ids.length
          ? start + _directoryQueryLimit
          : ids.length;
      final snapshot = await _firestore
          .collection(directoryCollection)
          .where('active', isEqualTo: true)
          .where(FieldPath.documentId, whereIn: ids.sublist(start, end))
          .get();
      for (final doc in snapshot.docs) {
        final entry = UserDirectoryModel.fromMap(doc.data(), doc.id);
        if (!entry.active || !userIds.contains(entry.id)) {
          throw const CommitteeDataException(
            'Directory query returned an unapproved entry.',
          );
        }
        entries[entry.id] = entry;
      }
    }
    return entries;
  }

  static CommitteeTermModel? selectCurrentTerm(
    Iterable<CommitteeTermModel> terms,
  ) {
    final activeTerms = terms.where((term) => term.active).toList();
    if (activeTerms.length > 1) {
      throw const CommitteeDataException(
        'Multiple active committee terms require trusted repair.',
      );
    }
    return activeTerms.isEmpty ? null : activeTerms.single;
  }

  static List<CommitteeTermModel> orderPastTerms(
    Iterable<CommitteeTermModel> terms,
  ) {
    final past = terms.where((term) => !term.active).toList();
    past.sort((left, right) {
      final endComparison = right.endYear.compareTo(left.endYear);
      return endComparison != 0
          ? endComparison
          : right.startYear.compareTo(left.startYear);
    });
    return past;
  }

  static void validateActiveAssignments(
    String termId,
    Iterable<CommitteeAssignmentModel> assignments,
  ) {
    if (assignments.any(
      (assignment) => !assignment.active || assignment.termId != termId,
    )) {
      throw const CommitteeDataException(
        'Active assignment query returned an unapproved record.',
      );
    }
  }

  static List<CommitteeMemberModel> mapDirectoryPresentation(
    Iterable<CommitteeAssignmentModel> assignments,
    Map<String, UserDirectoryModel> directory,
  ) {
    final members = assignments
        .map(
          (assignment) => CommitteeMemberModel(
            assignment: assignment,
            directory: _visibleDirectory(directory[assignment.userId]),
          ),
        )
        .toList();
    members.sort((left, right) {
      final position = left.position.compareTo(right.position);
      if (position != 0) return position;
      return (left.directory?.name ?? '').compareTo(
        right.directory?.name ?? '',
      );
    });
    return members;
  }

  static List<CommitteeMediaModel> validateGallery(
    String termId,
    Iterable<CommitteeMediaModel> media,
  ) {
    final gallery = media.toList(growable: false);
    if (gallery.any((item) => !item.active || item.termId != termId)) {
      throw const CommitteeDataException(
        'Gallery query returned hidden media or another term.',
      );
    }
    final ordered = [...gallery]
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
    return List.unmodifiable(ordered);
  }

  static UserDirectoryModel? _visibleDirectory(UserDirectoryModel? entry) {
    return entry != null && entry.active ? entry : null;
  }

  static void _requireDocumentId(String value, String label) {
    if (value.isEmpty || value.contains('/')) {
      throw CommitteeDataException('Invalid $label document ID.');
    }
  }
}
