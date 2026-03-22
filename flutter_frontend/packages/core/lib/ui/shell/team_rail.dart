import 'package:flutter/material.dart';

import 'package:core/ui/theme/msgr_theme.dart';

import 'shell_models.dart';

/// Vertical team icon rail (56 px wide).
///
/// Shows one [CircleAvatar] per team with an accent border on the active team,
/// a small red dot for unread activity, and a divider before a `+` button at
/// the bottom.
class TeamRail extends StatelessWidget {
  const TeamRail({
    super.key,
    required this.teams,
    required this.selectedIndex,
    required this.onTeamSelected,
    this.onAddTeam,
  });

  final List<MockTeam> teams;
  final int selectedIndex;
  final ValueChanged<int> onTeamSelected;
  final VoidCallback? onAddTeam;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return Container(
      width: MsgrDimensions.teamRailWidth,
      color: t.teamRailBg,
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...List.generate(teams.length, (index) {
            final team = teams[index];
            final isSelected = index == selectedIndex;
            return _TeamIcon(
              team: team,
              isSelected: isSelected,
              onTap: () => onTeamSelected(index),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Divider(color: t.sidebarText, thickness: 0.5),
          ),
          _AddTeamButton(onTap: () => onAddTeam?.call()),
          const Spacer(),
        ],
      ),
    );
  }
}

class _TeamIcon extends StatelessWidget {
  const _TeamIcon({
    required this.team,
    required this.isSelected,
    required this.onTap,
  });

  final MockTeam team;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: MsgrDimensions.teamRailWidth,
          height: 48,
          child: Row(
            children: [
              // Active indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: isSelected ? 28 : 0,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        isSelected ? t.sidebarItemActive : t.sidebarItemHover,
                    child: Text(
                      team.iconEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  if (team.unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: t.unreadBadge,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTeamButton extends StatelessWidget {
  const _AddTeamButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: MsgrDimensions.teamRailWidth,
        height: 48,
        child: Center(
          child: CircleAvatar(
            radius: 18,
            backgroundColor: t.sidebarItemHover,
            child: Icon(Icons.add, color: t.sidebarText, size: 20),
          ),
        ),
      ),
    );
  }
}
