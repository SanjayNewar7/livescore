import 'package:flutter/material.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/helpers.dart';
import 'package:provider/provider.dart';

class LeagueSelector extends StatelessWidget {
  const LeagueSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final currentLeague = provider.currentLeagueCode;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Helpers.getLeagueFlag(currentLeague),
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Helpers.getLeagueName(currentLeague),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Tap to change league',
                    style: TextStyle(fontSize: 11, color: AppTheme.lightGray),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _showLeagueDialog(context, provider),
              color: AppTheme.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }

  void _showLeagueDialog(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select League',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: provider.availableLeagues.length,
                  itemBuilder: (context, index) {
                    final league = provider.availableLeagues[index];
                    final isSelected = provider.currentLeagueCode == league['id'];
                    return ListTile(
                      leading: Text(
                        league['flag'] ?? Helpers.getLeagueFlag(league['id']!),
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        league['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
                          : null,
                      onTap: () {
                        provider.setCurrentLeague(league['id']!);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}