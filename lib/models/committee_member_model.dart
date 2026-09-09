import 'committee_assignment_model.dart';
import 'user_directory_model.dart';

class CommitteeMemberModel {
  final CommitteeAssignmentModel assignment;
  final UserDirectoryModel? directory;

  const CommitteeMemberModel({
    required this.assignment,
    required this.directory,
  });

  String get position => assignment.position;
  bool get directoryAvailable => directory != null;
}
