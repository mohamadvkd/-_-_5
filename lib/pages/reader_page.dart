import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/ayah.dart';
import '../models/reciter.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    Key? key,
    required this.surahNumber,
    required this.surahName,
  }) : super(key: key);

  final int surahNumber;
  final String surahName;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<Ayah> _ayahs = [];
  bool _loading = true;
  String? _error;
  double _fontSize = 26.0;
  Reciter? _selectedReciter;

  // Scroll + حفظ آخر آية
  final ScrollController _scrollController = ScrollController();
  int _lastSavedAyah = 1;
  Timer? _saveDebouncer;

  // مشغل الصوت
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _stateSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _fontSize = StorageService.getQuranFontSize();

    final reciters = QuranApi.getReciters();
    final prefId = StorageService.getPreferredReciter();
    _selectedReciter = reciters.firstWhere(
      (r) => r.identifier == prefId,
      orElse: () => reciters.first,
    );

    _scrollController.addListener(_onScroll);
    _setupAudioListeners();
    _loadAyahs();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _stateSub?.cancel();
    _saveDebouncer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // تحميل الآيات
  // ============================================================
  Future<void> _loadAyahs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cached = StorageService.getAyahsCache(widget.surahNumber);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _ayahs = cached;
        _loading = false;
      });
      _restoreScroll();
      return;
    }

    try {
      final ayahs = await QuranApi.fetchAyahs(widget.surahNumber);
      await StorageService.saveAyahsCache(widget.surahNumber, ayahs);
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
        _loading = false;
      });
      _restoreScroll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل السورة. تأكد من الاتصال بالإنترنت.\n$e';
        _loading = false;
      });
    }
  }

  // ============================================================
  // التمرير + حفظ آخر آية
  // ============================================================
  void _restoreScroll() {
    final savedOffset = StorageService.getScrollPosition(widget.surahNumber);
    if (savedOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    _saveDebouncer?.cancel();
    _saveDebouncer = Timer(const Duration(milliseconds: 500), () {
      _saveScrollAndAyah();
    });
  }

  void _saveScrollAndAyah() {
    if (!_scrollController.hasClients) return;

    StorageService.saveScrollPosition(
      widget.surahNumber,
      _scrollController.offset,
    );

    if (_ayahs.isNotEmpty) {
      final totalScroll = _scrollController.position.maxScrollExtent;
      if (totalScroll <= 0) return;
      final progress = _scrollController.offset / totalScroll;
      final estimatedAyah =
          (progress * (_ayahs.length - 1)).round().clamp(0, _ayahs.length - 1);
      final ayahNumber = _ayahs[estimatedAyah].numberInSurah;

      if (ayahNumber != _lastSavedAyah) {
        _lastSavedAyah = ayahNumber;
        StorageService.updateLastReadAyah(
          surahNumber: widget.surahNumber,
          surahName: widget.surahName,
          ayahNumber: ayahNumber,
        );
      }
    }
  }

  // ============================================================
  // الصوت
  // ============================================================
  void _setupAudioListeners() {
    _positionSub = AudioService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = AudioService.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
    _playingSub = AudioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _stateSub = AudioService.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = state == ProcessingState.loading ||
              state == ProcessingState.buffering;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_selectedReciter == null) return;

    if (_isPlaying) {
      await AudioService.pause();
    } else {
      if (!AudioService.hasAudio) {
        setState(() => _isLoadingAudio = true);
        final success = await AudioService.playSurah(
          _selectedReciter!,
          widget.surahNumber,
        );
        if (!success && mounted) {
          setState(() => _isLoadingAudio = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل التلاوة')),
          );
        }
      } else {
        await AudioService.resume();
      }
    }
  }

  Future<void> _seekTo(double seconds) async {
    await AudioService.seek(Duration(seconds: seconds.round()));
  }

  Future<void> _openExternal() async {
    if (_selectedReciter == null) return;
    final ok = await AudioService.openExternal(
      _selectedReciter!,
      widget.surahNumber,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح التلاوة')),
      );
    }
  }

  Future<void> _changeReciter(Reciter reciter) async {
    await AudioService.stop();
    await StorageService.setPreferredReciter(reciter.identifier);
    setState(() {
      _selectedReciter = reciter;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  void _showRecitersDialog() {
    final reciters = QuranApi.getReciters();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر القارئ'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reciters.length,
            itemBuilder: (_, i) {
              final r = reciters[i];
              final isSelected = r.identifier == _selectedReciter?.identifier;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(r.name),
                subtitle: Text(r.englishName),
                onTap: () {
                  Navigator.pop(ctx);
                  _changeReciter(r);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // المفضلة
  // ============================================================
  Future<void> _toggleBookmark(Ayah ayah) async {
    final isMarked =
        StorageService.isBookmarked(widget.surahNumber, ayah.numberInSurah);
    if (isMarked) {
      await StorageService.removeBookmark(widget.surahNumber, ayah.numberInSurah);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إزالة الآية من المحفوظات')),
      );
    } else {
      await StorageService.addBookmark(
        surahNumber: widget.surahNumber,
        surahName: widget.surahName,
        ayahNumber: ayah.numberInSurah,
        ayahText: ayah.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الآية في المحفوظات')),
      );
    }
    setState(() {});
  }

  // ============================================================
  // تغيير حجم الخط
  // ============================================================
  void _changeFontSize(double newSize) {
    setState(() => _fontSize = newSize);
    StorageService.setQuranFontSize(newSize);
  }

  // ============================================================
  // بناء الواجهة
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.surahName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'اختر القارئ',
            onPressed: _showRecitersDialog,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'فتح في مشغل خارجي',
            onPressed: _openExternal,
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields_rounded),
            tooltip: 'حجم الخط',
            onSelected: _changeFontSize,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 20, child: Text('صغير')),
              PopupMenuItem(value: 26, child: Text('متوسط')),
              PopupMenuItem(value: 32, child: Text('كبير')),
              PopupMenuItem(value: 40, child: Text('كبير جداً')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(scheme)),
          _buildAudioPlayer(scheme),
        ],
      ),
    );
  }

  // ============================================================
  // جسم الصفحة (السورة)
  // ============================================================
  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: scheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadAyahs,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_ayahs.isEmpty) {
      return const Center(child: Text('لا توجد آيات'));
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          _buildHeader(scheme),
          const SizedBox(height: 18),
          if (widget.surahNumber != 9) _buildBismillah(scheme),
          _buildAyahsCard(scheme),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            'سُورَةُ ${widget.surahName}',
            style: TextStyle(
              color: scheme.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_ayahs.length} آية',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildBismillah(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _fontSize - 4,
          height: 2,
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAyahsCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _ayahs.map((ayah) {
          final isMarked = StorageService.isBookmarked(
            widget.surahNumber,
            ayah.numberInSurah,
          );
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 2.2,
                        color: scheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: ayah.text),
                        TextSpan(
                          text: ' (${_toArabicDigits(ayah.numberInSurah)}) ',
                          style: TextStyle(
                            fontSize: _fontSize - 4,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      iconSize: 20,
                      icon: Icon(
                        isMarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isMarked ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _toggleBookmark(ayah),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // مشغل الصوت السفلي
  // ============================================================
  Widget _buildAudioPlayer(ColorScheme scheme) {
    final reciterName = _selectedReciter?.name ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الصف الأول: القارئ + تغيير
            Row(
              children: [
                Icon(Icons.mic_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reciterName,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'تغيير القارئ',
                  onPressed: _showRecitersDialog,
                ),
              ],
            ),

            // الصف الثاني: شريط التقدم
            Row(
              children: [
                Text(
                  AudioService.formatDuration(_position),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds
                            .clamp(0, _duration.inSeconds)
                            .toDouble()
                        : 0,
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1,
                    onChanged: _duration.inSeconds > 0
                        ? (v) => _seekTo(v)
                        : null,
                  ),
                ),
                Text(
                  AudioService.formatDuration(_duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // الصف الثالث: أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.replay_10_rounded),
                  onPressed: _isLoadingAudio
                      ? null
                      : () async {
                          final target = _position.inSeconds - 10;
                          await _seekTo(target < 0 ? 0 : target.toDouble());
                        },
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoadingAudio ? null : _togglePlayPause,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: _isLoadingAudio
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.forward_10_rounded),
                  onPressed: _isLoadingAudio
                      ? null
                      : () async {
                          final target = _position.inSeconds + 10;
                          final max = _duration.inSeconds;
                          await _seekTo(
                              (target > max ? max : target).toDouble());
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // أدوات
  // ============================================================
  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }
}