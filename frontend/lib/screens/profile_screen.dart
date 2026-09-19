import 'package:flutter/material.dart';
import 'package:frontend/screens/splash_screen.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/analysis_history.dart';
import '../data/season_palette.dart';
import 'result_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _nameOverride;
  bool _notificationsEnabled = true;
  bool _isThaiLanguage = true;

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

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _nameOverride = result);
      // NOTE: หากต้องการให้ชื่อนี้ผูกกับบัญชีผู้ใช้จริงถาวร ให้เรียก
      // AuthService ที่มีอยู่ในโปรเจกต์เพื่ออัปเดตค่านี้ตรงนี้เพิ่มเติม
    }
  }

  void _openFullHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullHistoryScreen(history: _history, onChanged: _loadHistory),
      ),
    );
  }

  void _openHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Help & Support',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '• Analyze your skin tone from the "Begin Analysis" menu on the main screen',
                style: TextStyle(fontSize: 13, color: AppColors.mid),
              ),
              SizedBox(height: 6),
              Text(
                '• Switch between Day / Night modes on the results screen to see different color palettes',
                style: TextStyle(fontSize: 13, color: AppColors.mid),
              ),
              SizedBox(height: 6),
              Text(
                '• Tap the icon in the top right corner of the results screen to select colors based on location',
                style: TextStyle(fontSize: 13, color: AppColors.mid),
              ),
              SizedBox(height: 6),
              Text(
                '• Use "Check an Outfit" to see how well your clothing choices match your season',
                style: TextStyle(fontSize: 13, color: AppColors.mid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'SeasonMe',
      applicationVersion: '1.0.0',
      children: const [Text('Personal Color Analysis Application')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final displayName =
        _nameOverride ??
        ((user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!
            : 'Guest');
    final email = user?.email ?? 'Not signed in';
    final photoUrl = user?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final latest = _history.isNotEmpty ? _history.first : null;

    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GradientBackButton(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _editName(displayName),
              child: Stack(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 233, 172, 187),
                          Color.fromARGB(255, 255, 194, 196),
                          Color.fromARGB(255, 205, 150, 182),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                initial,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 14,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(fontSize: 12, color: AppColors.mid),
            ),
            const SizedBox(height: 20),

            if (!_loadingHistory) _buildSeasonCard(latest),

            const SizedBox(height: 24),
            _ProfileTile(
              icon: Icons.access_time,
              label: 'Full Analysis History',
              onTap: _openFullHistory,
            ),

            _ProfileTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: _openHelp,
            ),
            _ProfileTile(
              icon: Icons.info_outline,
              label: 'About the App',
              onTap: _openAbout,
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blush,
                  side: BorderSide(
                    color: const Color.fromARGB(
                      255,
                      143,
                      63,
                      63,
                    ).withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  await AuthService.signOut();
                  await AppPrefs.setLoggedIn(false);
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: Color.fromARGB(255, 176, 90, 90),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonCard(AnalysisHistoryEntry? latest) {
    if (latest == null) {
      return SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.palette_outlined, color: AppColors.gold),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No color analysis available yet. Try starting on the main screen.',
                style: TextStyle(fontSize: 13, color: AppColors.mid),
              ),
            ),
          ],
        ),
      );
    }
    final groupColor = SeasonPaletteData.groupColorOf(latest.season);
    return SoftCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(season: latest.season, recordToHistory: false),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: groupColor.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your latest Analysis Result',
                  style: TextStyle(fontSize: 11, color: AppColors.mid),
                ),
                Text(
                  SeasonPaletteData.labelOf(latest.season),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mid, size: 20),
        ],
      ),
    );
  }
}

class _FullHistoryScreen extends StatefulWidget {
  final List<AnalysisHistoryEntry> history;
  final VoidCallback onChanged;
  const _FullHistoryScreen({required this.history, required this.onChanged});

  @override
  State<_FullHistoryScreen> createState() => _FullHistoryScreenState();
}

class _FullHistoryScreenState extends State<_FullHistoryScreen> {
  late List<AnalysisHistoryEntry> _items = List.of(widget.history);

  Future<void> _remove(int index) async {
    setState(() => _items.removeAt(index));
    await AnalysisHistoryService.removeAt(index);
    widget.onChanged();
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
      'Analyzed ${_monthAbbr[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradientBackButton(onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  const Text(
                    'Analysis History',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No analysis history available yet.',
                          style: TextStyle(color: AppColors.mid),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final groupColor = SeasonPaletteData.groupColorOf(
                            item.season,
                          );
                          return SoftCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultScreen(
                                  season: item.season,
                                  recordToHistory: false,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: groupColor.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(60),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        SeasonPaletteData.labelOf(item.season),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.charcoal,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(item.analyzedAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mid,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.blush,
                                    size: 20,
                                  ),
                                  onPressed: () => _remove(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blush.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.charcoal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.charcoal,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}
