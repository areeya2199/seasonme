import 'package:flutter/material.dart';
import 'package:frontend/screens/photoguide.dart';
import '../data/season_palette.dart';
import '../services/analysis_history.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import 'select_screen.dart';
import 'result_screen.dart';
import 'profile_screen.dart';
import 'clothing_screen.dart';
import 'photoguide.dart';

// Warm brown gradient reused by the "personal color" card here and on the
// Result screen, so the two match.
const List<Color> _personalColorGradient = [
  Color(0xFF6B4E36),
  Color(0xFF8A6A47),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AnalysisHistoryEntry> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await AnalysisHistoryService.getAll();
    if (!mounted) return;
    setState(() {
      _history = history;
      _loadingHistory = false;
    });
  }

  Future<void> _startAnalysis() async {
    await showFacePhotoGuide(context);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectScreen()),
    );
    if (mounted) _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHistory) {
      return const GradientScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _history.isEmpty
        ? _buildNewUser(context)
        : _buildReturningUser(context);
  }

  // ---------------- shared top bar ----------------

  Widget _buildTopBar(BuildContext context) {
    final user = AuthService.currentUser;
    final photoUrl = user?.photoURL;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'SeasonMe',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xffecd5f1),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, color: Color(0xff543f59), size: 20)
                : null,
          ),
        ),
      ],
    );
  }

  String _firstName() {
    final user = AuthService.currentUser;
    final name = user?.displayName;
    if (name == null || name.isEmpty) return 'GUEST';
    return name.split(' ').first.toUpperCase();
  }

  // ---------------- returning user (Image 1) ----------------

  Widget _buildReturningUser(BuildContext context) {
    final latest = _history.first;
    final profile = SeasonPaletteData.getProfile(latest.season);
    final chroma = ColorUtils.chromaLabel(
      profile.topsPool.map((s) => s.color).toList(),
    );
    final swatchColors = [
      profile.topsPool.first,
      profile.bottoms.first,
      profile.hair.first,
      profile.eyeMakeup.first,
      profile.blush.first,
    ];

    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 22),
            Text(
              'WELCOME BACK, ${_firstName()}',
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.blush,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A little color,\na little more you.',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 20),

            // ---- personal color card ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _personalColorGradient,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR PERSONAL COLOR',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _pillTag(
                        profile.undertone.replaceAll(
                          ' undertone',
                          ' undertone',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pillTag(chroma),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: swatchColors
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c.color,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6B4E36),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(
                            season: latest.season,
                            recordToHistory: false,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text(
                        'View My Result',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- "Check Your Outfit" card — compares against the SAME
            // season shown above (latest.season) ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2F3A2E),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checkroom_outlined,
                        size: 16,
                        color: Color(0xFFBFD6B6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'STYLE IN HARMONY',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFBFD6B6).withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Does it suit you?',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Find out how your outfit fits your season.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFFD7E3D2)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClothingScreen(season: latest.season),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text(
                        'Check Your Outfit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- latest analysis row ----
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    season: latest.season,
                    recordToHistory: false,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.mid),
                  const SizedBox(width: 8),
                  Text(
                    'Your latest analysis',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${profile.displayName} · ${_formatDate(latest.analyzedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.mid,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- prominent "Start New Analysis" button ----
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C3935),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _startAnalysis,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text(
                  'Start New Analysis',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static const List<String> _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String _formatDate(DateTime dt) =>
      '${_monthAbbr[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';

  // ---------------- new user (Image 2) ----------------

  Widget _buildNewUser(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 22),
            Text(
              'WELCOME, ${_firstName()}',
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.blush,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find your\nbeautiful colors.',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const _ColorFanIcon(),
                  const SizedBox(height: 28),
                  const Text(
                    'Your season\nstarts here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'A photo and a few questions.\nA palette made for you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.mid,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startAnalysis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          233,
                          172,
                          187,
                        ),
                        foregroundColor: const Color(0xFF4C3935),
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: const Text(
                        'Begin Analysis',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple decorative "fan of color tags" — five rounded, rotated tag
// shapes with a small punch-hole, matching the icon in the empty state.
class _ColorFanIcon extends StatelessWidget {
  const _ColorFanIcon();

  static const List<Color> _tagColors = [
    Color(0xFF8FD3A6), // green
    Color(0xFF9FC9E8), // blue
    Color(0xFFF3DE7B), // yellow
    Color(0xFFF0AE8B), // peach
    Color(0xFFC6A8E0), // purple
  ];

  Widget _tag(Color color, double angleDeg) {
    return Transform.rotate(
      angle: angleDeg * 3.1415926535 / 180,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 34,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      width: 190,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(bottom: 0, child: _tag(_tagColors[0], -32)),
          Positioned(bottom: 0, child: _tag(_tagColors[1], -16)),
          Positioned(bottom: 0, child: _tag(_tagColors[2], 0)),
          Positioned(bottom: 0, child: _tag(_tagColors[3], 16)),
          Positioned(bottom: 0, child: _tag(_tagColors[4], 32)),
        ],
      ),
    );
  }
}
