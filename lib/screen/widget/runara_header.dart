import 'package:flutter/material.dart';

/// ====== PALETTE (khusus header + notif)
const kRunaraCardBlue = Color(0xFF152449);
const kRunaraAccent   = Color(0xFF9AA6FF);
const kRunaraSubtle   = Color(0xFFBFC3D9);
const kRunaraDivider  = Color(0xFF2A3C6C);

/// (opsional) helper: greeting Indonesia + emoji
String runaraGreetingIndo(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return 'Selamat pagi';
  if (h >= 11 && h < 15) return 'Selamat siang';
  if (h >= 15 && h < 18) return 'Selamat sore';
  return 'Selamat malam';
}
String runaraGreetingEmoji(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return '☀️';
  if (h >= 11 && h < 15) return '🌤️';
  if (h >= 15 && h < 18) return '🌇';
  return '🌙';
}

/// ====== MODEL NOTIF
class AppNotification {
  final String title;
  final String body;
  final DateTime time;
  bool read;
  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
}

/// ====== HEADER (public)
class RunaraHeader extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String userName;
  final String roleLabel;
  final int level;
  final double progress;
  final bool hasUnread;
  final VoidCallback onTapBell;

  const RunaraHeader({
    super.key,
    required this.greeting,
    required this.emoji,
    required this.userName,
    required this.roleLabel,
    required this.level,
    required this.progress,
    required this.hasUnread,
    required this.onTapBell,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kRunaraCardBlue.withOpacity(.7),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/avatar.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: kRunaraDivider,
                alignment: Alignment.center,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(greeting, style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(userName, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
                  const SizedBox(width: 6),
                  _Badge(text: roleLabel),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.shield_moon, size: 16, color: kRunaraSubtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(children: [
                      Container(height: 8, decoration: BoxDecoration(
                          color: Colors.white12, borderRadius: BorderRadius.circular(20))),
                      LayoutBuilder(
                        builder: (ctx, c) => Container(
                          height: 8,
                          width: c.maxWidth * progress.clamp(0, 1),
                          decoration: BoxDecoration(
                              color: kRunaraAccent, borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text('LV.$level', style: const TextStyle(
                      color: kRunaraSubtle, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 10),
          // bell
          InkWell(
            onTap: onTapBell,
            borderRadius: BorderRadius.circular(12),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
              if (hasUnread)
                Positioned(
                  right: -3, top: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class RunaraHeaderSection extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String userName;
  final String roleLabel;
  final int level;
  final double progress;
  final bool hasUnread;
  final VoidCallback onTapBell;

  const RunaraHeaderSection({
    super.key,
    required this.greeting,
    required this.emoji,
    required this.userName,
    required this.roleLabel,
    required this.level,
    required this.progress,
    required this.hasUnread,
    required this.onTapBell,
  });

  @override
  Widget build(BuildContext context) {
    // padding seragam untuk SEMUA page
    final top = MediaQuery.of(context).padding.top;
    final pad = EdgeInsets.fromLTRB(16, top > 0 ? 8 : 16, 16, 12);

    return Padding(
      padding: pad,
      child: RunaraHeader(
        greeting: greeting,
        emoji: emoji,
        userName: userName,
        roleLabel: roleLabel,
        level: level,
        progress: progress,
        hasUnread: hasUnread,
        onTapBell: onTapBell,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF3A4C86), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1)),
    );
  }
}

/// ====== SHEET NOTIF (public)
class RunaraNotificationSheet extends StatelessWidget {
  final List<AppNotification> notifs;
  final VoidCallback onMarkAllRead;
  final void Function(int index) onTapItem;

  const RunaraNotificationSheet({
    super.key,
    required this.notifs,
    required this.onMarkAllRead,
    required this.onTapItem,
  });

  static Future<bool?> show(
      BuildContext context, {
        required List<AppNotification> notifs,
        required VoidCallback onMarkAllRead,
        required void Function(int index) onTapItem,
      }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kRunaraCardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RunaraNotificationSheet(
        notifs: notifs,
        onMarkAllRead: onMarkAllRead,
        onTapItem: onTapItem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    final hasWelcomeUnread = notifs.any(
            (n) => !n.read && n.title.toLowerCase().contains('selamat datang'));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(width: 44, height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 12),

              // header
              Row(children: [
                const Expanded(child: Text('Notifikasi', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton(
                  onPressed: () {
                    onMarkAllRead();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Tandai semua dibaca'),
                ),
              ]),

              if (hasWelcomeUnread) ...[
                _WelcomeBanner(onTap: () {
                  Navigator.of(context).pop(true);
                  Navigator.of(context).pushNamed('/features');
                }),
                const SizedBox(height: 10),
              ],

              // list
              Expanded(
                child: notifs.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Tidak ada notifikasi.', style: TextStyle(color: Colors.white70)),
                  ),
                )
                    : ListView.separated(
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (ctx, i) {
                    final n = notifs[i];
                    final icon = n.read ? Icons.notifications_none : Icons.circle_notifications;
                    final color = n.read ? Colors.white60 : kRunaraAccent;

                    return ListTile(
                      onTap: () {
                        onTapItem(i);
                        Navigator.pop(ctx, true);
                      },
                      leading: Icon(icon, color: color),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(n.body, style: const TextStyle(color: kRunaraSubtle)),
                      trailing: Text(_fmtTime(n.time),
                          style: const TextStyle(color: kRunaraSubtle, fontSize: 12)),
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

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _WelcomeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _WelcomeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              colors: [Color(0xFF5B6CFF), Color(0xFF9AA6FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            CircleAvatar(
                radius: 22, backgroundColor: Colors.white24,
                child: Text('🎉', style: TextStyle(fontSize: 20))),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Selamat datang di RUNARA!\nKetuk untuk melihat semua fitur.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
