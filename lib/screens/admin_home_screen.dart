import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // Priority color helper
  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // Change priority of a ticket
  void _showPriorityDialog(
    BuildContext context,
    String ticketId,
    String currentPriority,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['high', 'medium', 'low'].map((level) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _priorityColor(level),
                radius: 8,
              ),
              title: Text(level.toUpperCase()),
              trailing: currentPriority == level
                  ? const Icon(Icons.check, color: Colors.indigo)
                  : null,
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('tickets')
                    .doc(ticketId)
                    .update({'priority': level});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Saves a log entry to Firestore
  Future<void> _saveLog({
    required String ticketTitle,
    required String ticketDescription,
    required String action,
    required String adminEmail,
  }) async {
    final now = DateTime.now();

    // Format the date nicely — "06 May 2026"
    final date =
        '${now.day.toString().padLeft(2, '0')} '
        '${_monthName(now.month)} '
        '${now.year}';

    // Format the time — "2:30 PM"
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    // Month for grouping — "May 2026"
    final month = '${_monthName(now.month)} ${now.year}';

    await FirebaseFirestore.instance.collection('logs').add({
      'ticketTitle': ticketTitle,
      'ticketDescription': ticketDescription,
      'action': action,
      'adminEmail': adminEmail,
      'date': date,
      'time': time,
      'month': month,
      'timestamp': now.millisecondsSinceEpoch,
    });
  }

  // Helper to convert month number to name
  String _monthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  // Resolve a ticket
  void _resolveTicket(
    BuildContext context,
    String ticketId,
    String ticketTitle,
    String ticketDescription,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolve Ticket'),
        content: const Text(
          'Mark this ticket as resolved? The user will see it as resolved in green.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('tickets')
                  .doc(ticketId)
                  .update({'status': 'resolved'});

              // Save log entry
              await _saveLog(
                ticketTitle: ticketTitle,
                ticketDescription: ticketDescription,
                action: 'resolved',
                adminEmail: FirebaseAuth.instance.currentUser!.email ?? 'admin',
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ticket marked as resolved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  // Delete a ticket
  void _deleteTicket(
    BuildContext context,
    String ticketId,
    String ticketTitle,
    String ticketDescription,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Ticket'),
        content: const Text(
          'Are you sure you want to delete this ticket? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('tickets')
                  .doc(ticketId)
                  .delete();

              // Save log entry
              await _saveLog(
                ticketTitle: ticketTitle,
                ticketDescription: ticketDescription,
                action: 'deleted',
                adminEmail: FirebaseAuth.instance.currentUser!.email ?? 'admin',
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ticket deleted!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 208, 2, 2),
        foregroundColor: Colors.white,
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 242, 242, 242),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tickets yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;
              final ticketId = tickets[index].id;
              final status = ticket['status'] ?? 'pending';
              final priority = ticket['priority'] ?? 'medium';
              final isResolved = status == 'resolved';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket['title'] ?? 'No title',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isResolved
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isResolved ? '✓ Resolved' : '⏳ Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isResolved
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(
                        ticket['description'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),

                      // Priority badge
                      Row(
                        children: [
                          const Text(
                            'Priority: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          GestureDetector(
                            onTap: () => _showPriorityDialog(
                              context,
                              ticketId,
                              priority,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _priorityColor(
                                  priority,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _priorityColor(priority),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _priorityColor(priority),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: _priorityColor(priority),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        children: [
                          // Chat button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      ticketId: ticketId,
                                      ticketTitle: ticket['title'] ?? 'Ticket',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                              ),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color.fromARGB(
                                  255,
                                  225,
                                  1,
                                  1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Resolve button
                          if (!isResolved)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _resolveTicket(
                                  context,
                                  ticketId,
                                  ticket['title'] ?? '',
                                  ticket['description'] ?? '',
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Resolve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),

                          // Delete button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _deleteTicket(
                                context,
                                ticketId,
                                ticket['title'] ?? '',
                                ticket['description'] ?? '',
                              ),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  0,
                                  0,
                                  0,
                                ),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
