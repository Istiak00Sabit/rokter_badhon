import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/donor_model.dart';

class DonorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // নতুন রক্তদাতা যোগ করো
  Future<Map<String, dynamic>> addDonor(DonorModel donor) async {
    try {
      await _firestore
          .collection(AppConstants.donorsCollection)
          .add(donor.toMap());
      return {'success': true, 'message': 'রক্তদাতা সফলভাবে যোগ করা হয়েছে!'};
    } catch (e) {
      return {'success': false, 'message': 'যোগ করতে সমস্যা হয়েছে: $e'};
    }
  }

  // সব রক্তদাতা আনো
  Future<List<DonorModel>> getAllDonors() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true)
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) =>
              DonorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // রক্তের গ্রুপ দিয়ে খোঁজো
  Future<List<DonorModel>> getDonorsByBloodGroup(String bloodGroup) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(AppConstants.donorsCollection)
          .where('active', isEqualTo: true)
          .where('blood_group', isEqualTo: bloodGroup)
          .get();
      return snapshot.docs
          .map((doc) =>
              DonorModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }
}