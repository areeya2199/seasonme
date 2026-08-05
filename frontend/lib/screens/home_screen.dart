import 'package:flutter/material.dart';
import '../data/season_palette.dart';
import '../services/analysis_history.dart';
import '../theme/app_theme.dart';
import 'select_screen.dart';
import 'result_screen.dart';
import 'profile_screen.dart';

//Home
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AnalysisHistoryEntry> _history = [];
  bool _loadingHistory = true;
  bool _deleteMode = false;

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

  void _toggleDeleteMode() {
    setState(() => _deleteMode = !_deleteMode);
  }

  Future<void> _removeHistoryItem(int index) async {
    setState(() {
  _history.removeAt(index);
    });
    await AnalysisHistoryService.removeAt(index);
    if (_history.isEmpty && mounted) {
      setState(() => _deleteMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 28),
            _buildHeroCard(context),
            const SizedBox(height: 16),
            const SizedBox(height: 28),
            _buildHistorySection(context),
          ],
        ),
      ),
    );
  }

  //find the color
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.sunny,
                  color: Color.fromARGB(255, 228, 169, 86),
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'Find the color that makes you shine.',
                  style: TextStyle(fontSize: 13, color: AppColors.mid),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          child: CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xffecd5f1),
            child: const Icon(Icons.person, color: Color(0xff543f59)),
          ),
        ),
      ],
    );
  }

        Widget _buildHeroCard(BuildContext context) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xfffee8f2),
                  Color(0xffffebe9),
                  Color(0xffffede0),
                  Color(0xfffbecee),
                  Color(0xfff4eafd),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload a photo to analyze your personal color',
            style: TextStyle(
              color: Color(0xffde939c),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start New Analysis',
            style: TextStyle(
              color: Color(0xff4c3935),
              fontFamily: 'Lora',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 233, 172, 187),
              foregroundColor: const Color.fromARGB(255, 255, 194, 196),
              shadowColor: const Color.fromARGB(255, 205, 150, 182),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: AppColors.white,
                ),
                SizedBox(width: 8),
                Text(
                  'Begin Analysis',
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontFamily: 'Nunito',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //Analysis History
  Widget _buildHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xffde939c), size: 16),

            const SizedBox(width: 5),
            const Text(
              'Analysis History',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const Spacer(),

            TextButton(
              onPressed: _history.isEmpty ? null : _toggleDeleteMode,
              child: Text(
                _deleteMode ? 'Done' : 'Delete',
                style: TextStyle(
                  color: _deleteMode ? AppColors.gold : AppColors.gold,
                  fontSize: 14,
                  fontWeight: _deleteMode ? FontWeight.w700 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(),
            child: Text(
              'No analyses yet.',
              style: TextStyle(fontSize: 13, color: AppColors.mid),
            ),
          )
        else
          ..._history.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            //icon
            final groupColor = SeasonPaletteData.groupColorOf(item.season);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                onTap: _deleteMode
                    ? () => _removeHistoryItem(index)
                    : () => Navigator.push(
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
                        color: groupColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            _formatAnalyzedDate(item.analyzedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _deleteMode
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.blush,
                              size: 20,
                            ),
                            onPressed: () => _removeHistoryItem(index),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.mid,
                            size: 20,
                          ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  static const List<String> _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  String _formatAnalyzedDate(DateTime dt) {
    return 'Analyzed ${_monthAbbr[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}';
  }
}
