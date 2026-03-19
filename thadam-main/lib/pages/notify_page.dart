import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────
class _T {
  static const navy      = Color(0xFF0D1B2A);
  static const navyLight = Color(0xFF1B2E42);
  static const teal      = Color(0xFF0A9396);
  static const tealLight = Color(0xFFD9F0F1);
  static const accent    = Color(0xFF94D2BD);
  static const surface   = Color(0xFFF8FAFB);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF0);
  static const textPri   = Color(0xFF0D1B2A);
  static const textSub   = Color(0xFF6B7A8D);
  static const red       = Color(0xFFE63946);
  static const orange    = Color(0xFFF4A261);
  static const green     = Color(0xFF2DC653);
}

class NotifyPage extends StatefulWidget {
  const NotifyPage({super.key});

  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  final firestore = FirebaseFirestore.instance;
  String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _markRead(DocumentReference ref) async {
    try {
      await ref.update({'isRead': true});
    } catch (e) {
      _showSnackBar('Error marking notification as read');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _T.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        backgroundColor: _T.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _T.navy,
          foregroundColor: Colors.white,
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _T.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: _T.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Not Logged In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _T.textPri,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please log in to view notifications',
                  style: TextStyle(
                    fontSize: 13,
                    color: _T.textSub,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          // ── Error State ──
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _T.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: _T.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _T.textPri,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: TextStyle(
                        fontSize: 13,
                        color: _T.textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Loading State ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _T.teal),
            );
          }

          // ── Empty State ──
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _T.tealLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.notifications_off_rounded,
                        size: 48,
                        color: _T.teal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _T.textPri,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up! Check back later for updates.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _T.textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Sort Notifications ──
          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final da = (a['date'] as Timestamp?)?.toDate();
            final db = (b['date'] as Timestamp?)?.toDate();
            if (da == null || db == null) return 0;
            return db.compareTo(da);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final title = data['title'] ?? 'Notification';
              final message = data['message'] ?? '';
              final sender = data['senderName'] ?? 'Unknown';
              final receiver = data['receiverName'] ?? 'You';
              final date = (data['date'] as Timestamp?)?.toDate();

              String formattedDate = '';
              if (date != null) {
                final now = DateTime.now();
                final diff = now.difference(date);

                if (diff.inMinutes < 1) {
                  formattedDate = 'Just now';
                } else if (diff.inHours < 1) {
                  formattedDate = '${diff.inMinutes}m ago';
                } else if (diff.inDays < 1) {
                  formattedDate = '${diff.inHours}h ago';
                } else if (diff.inDays < 7) {
                  formattedDate = '${diff.inDays}d ago';
                } else {
                  formattedDate =
                      DateFormat('MMM dd').format(date);
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _markRead(docs[index].reference),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? _T.card : _T.tealLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead ? _T.border : _T.teal.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isRead ? 0.04 : 0.06,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Icon Badge ──
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? _T.surface
                                  : _T.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 16,
                              color: isRead ? _T.textSub : _T.teal,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // ── Content ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.w700,
                                          color: _T.textPri,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _T.teal,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Message
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _T.textSub,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),

                                // Sender/Receiver Info
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 12,
                                      color: _T.textSub,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'From: $sender',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _T.textSub,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // ── Date & Status ──
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _T.textSub,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? _T.surface
                                      : _T.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isRead ? 'Read' : 'New',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isRead ? _T.textSub : _T.teal,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}