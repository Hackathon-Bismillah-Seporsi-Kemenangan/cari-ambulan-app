/// App string constants for CariAmbulan
class AppStrings {
  AppStrings._();

  static const String appName = 'CariAmbulan';
  static const String driverAppName = 'CariAmbulan Driver';

  // Role Selection
  static const String roleSelectionTitle = 'Pilih peran Anda';
  static const String roleSelectionSubtitle =
      'Pilih peran untuk menyesuaikan layanan dengan kebutuhan Anda.';

  static const String rolePatient = 'Pasien atau keluarga';
  static const String rolePatientDesc =
      'Cari ambulans untuk diri sendiri atau orang terdekat.';

  static const String roleDriver = 'Pengemudi ambulans';
  static const String roleDriverDesc =
      'Terima panggilan dan antar pasien ke rumah sakit.';

  static const String continueAsPatient = 'Lanjut sebagai pasien / keluarga';
  static const String continueAsDriver = 'Lanjut sebagai pengemudi ambulans';

  // Logging out keeps the role; the back arrow on Masuk leads here.
  static const String roleSelectionNote =
      'Anda bisa mengganti peran dari halaman Masuk.';

  // Patient onboarding
  static const String patientOnboard1Title =
      'Satu tombol untuk bantuan darurat';
  static const String patientOnboard1Desc =
      'Tekan & tahan PANGGIL AMBULANS, lalu pilih kondisi pasien. Lokasi Anda langsung terkirim, tanpa perlu menjelaskan panjang lebar.';

  static const String patientOnboard2Title =
      'Ambulans terdekat dicarikan otomatis';
  static const String patientOnboard2Desc =
      'Sistem kami menghubungi ambulans siaga terdekat dan rumah sakit tujuan diberi tahu lebih dulu.';

  static const String patientOnboard3Title =
      'Pantau kedatangan secara real-time';
  static const String patientOnboard3Desc =
      'Lihat posisi ambulans di peta, estimasi waktu tiba, dan hubungi driver kapan saja.';

  // Driver onboarding
  static const String driverOnboard1Title =
      'Terima order darurat di sekitar Anda';
  static const String driverOnboard1Desc =
      'Notifikasi berbunyi keras saat ada pasien di dekat Anda. Terima atau tolak dalam 30 detik.';

  static const String driverOnboard2Title =
      'Rute tercepat ke pasien & rumah sakit';
  static const String driverOnboard2Desc =
      'Navigasi langsung terhubung dengan lokasi pasien dan IGD tujuan yang sudah diberi tahu.';

  // Common
  static const String next = 'Lanjut';
  static const String skip = 'Lewati';
  static const String start = 'Mulai';
  static const String getStarted = 'Mulai Sekarang';
  static const String done = 'Selesai';
}
