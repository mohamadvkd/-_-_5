import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reciter.dart';

/// خدمة التلاوة الصوتية
/// - تشغيل داخل التطبيق باستخدام just_audio
/// - فتح خارجي كخيار بديل
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  // ============================================================
  // التحكم الأساسي
  // ============================================================

  /// تشغيل تلاوة سورة
  static Future<bool> playSurah(Reciter reciter, int surahNumber) async {
    try {
      final url = reciter.getAudioUrl(surahNumber);
      await _player.setUrl(url);
      _player.play();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إيقاف مؤقت
  static Future<void> pause() async {
    await _player.pause();
  }

  /// استئناف التشغيل
  static Future<void> resume() async {
    _player.play();
  }

  /// إيقاف كامل وتفريغ
  static Future<void> stop() async {
    await _player.stop();
  }

  /// بحث عن موضع معين
  static Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// الانتقال للبداية
  static Future<void> replay() async {
    await _player.seek(Duration.zero);
    _player.play();
  }

  // ============================================================
  // الحالة
  // ============================================================

  /// هل يعمل الآن؟
  static bool get isPlaying => _player.playing;

  /// المدة الكلية
  static Duration? get duration => _player.duration;

  /// الموضع الحالي
  static Duration get position => _player.position;

  /// هل هناك شيء محمّل؟
  static bool get hasAudio => _player.duration != null;

  // ============================================================
  // Streams للمراقبة
  // ============================================================

  /// بث حالة التشغيل (play / pause)
  static Stream<bool> get playingStream => _player.playingStream;

  /// بث الموضع الحالي
  static Stream<Duration> get positionStream => _player.positionStream;

  /// بث المدة الكلية
  static Stream<Duration?> get durationStream => _player.durationStream;

  /// بث حالة المعالجة (loading / buffering / ready)
  static Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// الوصول للمشغل مباشرة (لو احتجناه)
  static AudioPlayer get player => _player;

  // ============================================================
  // بديل: فتح خارجي
  // ============================================================

  /// فتح رابط التلاوة في تطبيق خارجي (VLC / مشغل الموسيقى)
  static Future<bool> openExternal(Reciter reciter, int surahNumber) async {
    try {
      final url = reciter.getAudioUrl(surahNumber);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// رابط السورة النصي (للعرض)
  static String getSurahAudioUrl(Reciter reciter, int surahNumber) {
    return reciter.getAudioUrl(surahNumber);
  }

  // ============================================================
  // أدوات مساعدة
  // ============================================================

  /// تنسيق مدة → "mm:ss"
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// إغلاق نهائي عند الخروج من التطبيق
  static Future<void> dispose() async {
    await _player.dispose();
  }
}