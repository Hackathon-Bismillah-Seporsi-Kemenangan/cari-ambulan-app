import 'package:cari_ambulan/features/user/domain/user_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const contact = EmergencyContact(
    name: 'Ahmad',
    relation: 'Suami',
    phone: '081234500000',
  );

  test('sends the emergency contact in the API fields', () {
    final json = const MedicalProfile(emergencyContact: contact).toJson();

    expect(json['emergency_contact_name'], 'Ahmad');
    expect(json['emergency_contact_relation'], 'Suami');
    expect(json['emergency_contact_phone'], '081234500000');
  });

  test('reads the emergency contact the API returns', () {
    final profile = MedicalProfile.fromJson({
      'blood_type': 'O+',
      'emergency_contact_name': 'Ahmad',
      'emergency_contact_relation': 'Suami',
      'emergency_contact_phone': '081234500000',
    });

    expect(profile.emergencyContact?.name, 'Ahmad');
    expect(profile.emergencyContact?.relation, 'Suami');
    expect(profile.emergencyContact?.phone, '081234500000');
  });

  test('removing the contact clears it on the server', () {
    final json = const MedicalProfile().toJson();

    expect(json.containsKey('emergency_contact_name'), isTrue);
    expect(json['emergency_contact_name'], isNull);
    expect(MedicalProfile.fromJson(json).emergencyContact, isNull);
  });

  test('keeps a contact saved on the phone by an older version', () {
    final profile = MedicalProfile.fromJson({
      'emergency_contact': {
        'name': 'Ahmad',
        'relation': 'Suami',
        'phone': '081234500000',
      },
    });

    expect(profile.emergencyContact?.name, 'Ahmad');
  });
}
