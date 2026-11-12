import 'package:share_plus/share_plus.dart';

import '../../../../core/logging/app_log.dart';
import '../../domain/emergency_models.dart';

String _mapLink(double latitude, double longitude) =>
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

/// The message sent to family: where the patient is, which ambulance, and
/// where it is now.
///
/// The server has no live tracking page, so the ambulance's position is the
/// one known when sharing.
String tripShareText(EmergencyRequestModel request) {
  final ambulance = request.ambulance;
  final plate = ambulance?.plateNumber;
  final driver = request.assignedDriver?.name;
  final vehicle = ['ambulans CariAmbulan', ?plate].join(' ');
  final withDriver = driver == null ? '' : ' (driver $driver)';
  final pickup = request.pickup;
  final hospital = request.hospital;
  final eta = request.etaMinutes;

  final lines = <String>[];
  switch (request.status) {
    case EmergencyRequestStatus.arriveAtPickup:
      lines.add(
        '${_capitalise(vehicle)}$withDriver sudah tiba di '
        '${pickup.address}.',
      );
    case EmergencyRequestStatus.enRouteToHospital:
      lines.add(
        hospital == null
            ? 'Saya sedang dibawa $vehicle$withDriver ke rumah sakit.'
            : 'Saya sedang dibawa $vehicle$withDriver ke ${hospital.name}.',
      );
      if (hospital != null) {
        lines.add(
          'Rumah sakit: '
          '${_mapLink(hospital.latitude, hospital.longitude)}',
        );
      }
    default:
      lines.add(
        'Saya sedang menunggu $vehicle$withDriver di '
        '${pickup.address}.'
        '${eta == null ? '' : ' Perkiraan tiba $eta menit lagi.'}',
      );
      lines.add(
        'Lokasi jemput: '
        '${_mapLink(pickup.latitude, pickup.longitude)}',
      );
  }

  final at = ambulance?.location;
  if (at != null && request.status != EmergencyRequestStatus.arriveAtPickup) {
    lines.add(
      'Posisi ambulans saat ini: '
      '${_mapLink(at.latitude, at.longitude)}',
    );
  }
  return lines.join('\n');
}

String _capitalise(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Opens the phone's share sheet with [tripShareText].
Future<void> shareTrip(EmergencyRequestModel request) async {
  try {
    await SharePlus.instance.share(ShareParams(text: tripShareText(request)));
  } catch (e) {
    AppLog.warn('SHARE', 'Share sheet failed', e);
    rethrow;
  }
}
