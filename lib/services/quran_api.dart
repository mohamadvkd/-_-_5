import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/surah.dart';
import '../models/ayah.dart';
import '../models/reciter.dart';

/// خدمة التعامل مع alquran.cloud API
/// مجاني تماماً، بدون API key.
class QuranApi {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';

  /// جلب قائمة السور الـ 114
  static Future<List<Surah>> fetchSurahs() async {
    final url = Uri.parse('$_baseUrl/surah');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السور: ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    final List<dynamic> data = json['data'] as List<dynamic>;
    return data
        .map((item) => Surah.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// جلب سورة كاملة (بالنص العثماني)
  /// [edition] افتراضياً "quran-uthmani" للنص العثماني
  static Future<Map<String, dynamic>> fetchSurahWithAyahs(
    int surahNumber, {
    String edition = 'quran-uthmani',
  }) async {
    final url = Uri.parse('$_baseUrl/surah/$surahNumber/$edition');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السورة: ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    return json['data'] as Map<String, dynamic>;
  }

  /// جلب السورة كـ List<Ayah> جاهزة للعرض
  static Future<List<Ayah>> fetchAyahs(int surahNumber) async {
    final data = await fetchSurahWithAyahs(surahNumber);
    final List<dynamic> ayahsJson = data['ayahs'] as List<dynamic>? ?? [];
    return ayahsJson
        .map((item) => Ayah.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// جلب سورة مع الصوت (نص + روابط صوتية)
  static Future<Map<String, dynamic>> fetchSurahWithAudio(
    int surahNumber,
    String reciterIdentifier,
  ) async {
    final url = Uri.parse('$_baseUrl/surah/$surahNumber/$reciterIdentifier');
    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب السورة بالصوت: ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['status'] != 'OK') {
      throw Exception('استجابة غير متوقعة من API');
    }

    return json['data'] as Map<String, dynamic>;
  }

  /// جلب قائمة القراء المتاحين
  /// نستخدم نسخة ثابتة لأن alquran.cloud لا يوفر endpoint مباشر للقراء.
  static List<Reciter> getReciters() {
    return const [
      Reciter(
        identifier: 'ar.alafasy',
        name: 'مشاري العفاسي',
        englishName: 'Mishary Alafasy',
        server: 'https://server8.mp3quran.net/afs/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.abdulbasitmurattal',
        name: 'عبد الباسط عبد الصمد',
        englishName: 'Abdul Basit',
        server: 'https://server7.mp3quran.net/basit/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.abdurrahmaansudais',
        name: 'عبد الرحمن السديس',
        englishName: 'Abdurrahman As-Sudais',
        server: 'https://server11.mp3quran.net/sds/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.husary',
        name: 'محمود خليل الحصري',
        englishName: 'Mahmoud Khalil Al-Husary',
        server: 'https://server13.mp3quran.net/husr/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.minshawi',
        name: 'محمد صديق المنشاوي',
        englishName: 'Muhammad Siddiq Al-Minshawi',
        server: 'https://server10.mp3quran.net/minsh/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.mahermuaiqly',
        name: 'ماهر المعيقلي',
        englishName: 'Maher Al Muaiqly',
        server: 'https://server12.mp3quran.net/maher/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.hudhaify',
        name: 'علي الحذيفي',
        englishName: 'Ali Al-Hudhaify',
        server: 'https://server9.mp3quran.net/hthfi/',
        surahPath: '',
      ),
      Reciter(
        identifier: 'ar.shaatree',
        name: 'أبو بكر الشاطري',
        englishName: 'Abu Bakr Ash-Shaatree',
        server: 'https://server11.mp3quran.net/shatri/',
        surahPath: '',
      ),
    ];
  }

  /// البحث في السور (محلي - سريع)
  static List<Surah> searchSurahs(List<Surah> surahs, String query) {
    if (query.trim().isEmpty) return surahs;
    final q = query.trim().toLowerCase();
    return surahs.where((s) {
      return s.name.contains(query) ||
          s.englishName.toLowerCase().contains(q) ||
          s.number.toString() == q ||
          s.name.replaceAll('سُورَةُ ', '').contains(query);
    }).toList();
  }
}