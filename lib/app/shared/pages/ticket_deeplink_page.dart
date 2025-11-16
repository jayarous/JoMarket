import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/moderation/moderation_models.dart';
import '../../admin/moderation/moderation_repository.dart';

class TicketDeepLinkPage extends StatefulWidget {
  const TicketDeepLinkPage({required this.ticketId, super.key});

  final String ticketId;

  @override
  State<TicketDeepLinkPage> createState() => _TicketDeepLinkPageState();
}

class _TicketDeepLinkPageState extends State<TicketDeepLinkPage> {
  late final ModerationRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ModerationRepository(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TicketWithMessages?>(
      future: _repo.getTicketWithMessages(widget.ticketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ticket')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final ticket = snapshot.data;
        if (ticket == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ticket')),
            body: const Center(child: Text('Ticket not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              ticket.subject ?? 'Ticket ${ticket.id.substring(0, 8)}',
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${ticket.status}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Priority: ${ticket.priority}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Messages',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: ticket.messages.length,
                    itemBuilder: (context, index) {
                      final msg = ticket.messages[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            msg.userName ??
                                (msg.isAdmin == true ? 'Admin' : 'User'),
                          ),
                          subtitle: Text(msg.body),
                          trailing: Text(
                            msg.createdAt.toLocal().toString().split('.')[0],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
