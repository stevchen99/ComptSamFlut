import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/ticket.dart';
import 'services/api_service.dart';

// --- FLUTTER APPLICATION ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Tickets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TicketListScreen(),
    );
  }
}

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  late Future<List<Ticket>> _ticketsFuture;
  List<Ticket> _currentTickets = [];

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  void _refreshTickets() {
    setState(() {
      _ticketsFuture = ApiService.fetchTickets();
    });
  }

  void _showTicketDialog({Ticket? ticket}) {
    final isEditing = ticket != null;
    const fixedQuiOptions = ['Stev', 'Bee', 'Lana'];
    String selectedQui = fixedQuiOptions.contains(ticket?.qui) ? ticket!.qui : fixedQuiOptions.first;
    final quoiController = TextEditingController(text: ticket?.quoi ?? '');
    final combienController = TextEditingController(text: ticket?.combien.toString() ?? '1');
    bool lanaGarde = ticket?.lanaGarde ?? false;
    DateTime dateInput = ticket?.dateInput ?? DateTime.now();
    DateTime? dateOutput = ticket?.dateOutput;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Modifier Ticket' : 'Nouveau Ticket'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: fixedQuiOptions.contains(selectedQui) ? selectedQui : fixedQuiOptions.first,
                      decoration: const InputDecoration(labelText: 'Qui (Nom)'),
                      items: fixedQuiOptions
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedQui = value);
                        }
                      },
                    ),
                    TextField(
                      controller: quoiController,
                      decoration: const InputDecoration(labelText: 'Quoi'),
                    ),
                    TextField(
                      controller: combienController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Combien'),
                    ),
                    SwitchListTile(
                      title: const Text('Lana Garde'),
                      value: lanaGarde,
                      onChanged: (val) => setDialogState(() => lanaGarde = val),
                    ),
                    ListTile(
                      title: Text('Date Entrée: ${DateFormat('dd/MM/yyyy').format(dateInput)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dateInput,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => dateInput = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final finalQuoi = quoiController.text.trim();
                    final finalCombien = int.tryParse(combienController.text) ?? 1;

                    final newTicket = Ticket(
                      id: ticket?.id,
                      dateInput: dateInput,
                      dateOutput: dateOutput,
                      qui: selectedQui,
                      quoi: finalQuoi,
                      combien: finalCombien,
                      lanaGarde: lanaGarde,
                    );

                    try {
                      if (isEditing) {
                        await ApiService.checkAndUpdateTicket(
                          ticketId: ticket.id!,
                          quoi: finalQuoi,
                          combien: finalCombien,
                        );
                      } else {
                        await ApiService.createTicket(newTicket);
                      }
                      if (context.mounted) Navigator.pop(context);
                      _refreshTickets();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Sauvegarder' : 'Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteTicket(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le ticket ?'),
          content: const Text('Voulez-vous vraiment supprimer ce ticket ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteTicket(id);
      _refreshTickets();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de suppression: $e')),
      );
    }
  }

  void _markOutput(Ticket ticket) {
    final quoiController = TextEditingController(text: ticket.quoi);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sortie Ticket'),
          content: TextField(
            controller: quoiController,
            decoration: const InputDecoration(labelText: 'Quoi (Objet)'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final finalQuoi = quoiController.text.trim();
                final updatedTicket = Ticket(
                  id: ticket.id,
                  dateInput: ticket.dateInput,
                  dateOutput: DateTime.now(),
                  qui: ticket.qui,
                  quoi: finalQuoi,
                  combien: ticket.combien,
                  lanaGarde: false,
                );

                try {
                  await ApiService.updateTicket(ticket.id!, updatedTicket);
                  if (context.mounted) Navigator.pop(context);
                  _refreshTickets();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur d\'actualisation: $e')),
                  );
                }
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  void _handleCheckout(List<Ticket> tickets) {
    final activeTicket = tickets.isNotEmpty
        ? tickets.firstWhere(
            (ticket) => ticket.dateOutput == null && !ticket.lanaGarde,
            orElse: () => tickets.first,
          )
        : null;

    if (activeTicket != null) {
      _markOutput(activeTicket);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun ticket disponible pour checkout')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ComptagSAM - Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTickets,
          )
        ],
      ),
      body: FutureBuilder<List<Ticket>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final tickets = snapshot.data ?? <Ticket>[];
          _currentTickets = tickets;

          final availableCount = tickets.where((ticket) => ticket.dateOutput == null && !ticket.lanaGarde).length;
          final lanaCount = tickets.where((ticket) => ticket.lanaGarde).length;
          final usedCount = tickets.where((ticket) => ticket.dateOutput != null).length;

          return RefreshIndicator(
            onRefresh: () async => _refreshTickets(),
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _GreyDashboardHeaderDelegate(
                    availableCount: availableCount,
                    lanaCount: lanaCount,
                    usedCount: usedCount,
                  ),
                ),
                if (tickets.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Aucun ticket trouvé.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ticket = tickets[index];
                          final dateFormat = DateFormat('dd/MM/yyyy');

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: ticket.dateOutput != null ? Colors.red : (ticket.lanaGarde ? Colors.orange : Colors.green),
                                    child: Text(
                                      '${ticket.combien}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${ticket.qui} — ${ticket.quoi}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('In: ${dateFormat.format(ticket.dateInput)}', style: const TextStyle(fontSize: 12)),
                                        if (ticket.dateOutput != null)
                                          Text('Out: ${dateFormat.format(ticket.dateOutput!)}', style: const TextStyle(color: Colors.green, fontSize: 12))
                                        else
                                          const Text('Out: En cours...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 38,
                                    padding: EdgeInsets.zero,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                          onPressed: () => _showTicketDialog(ticket: ticket),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          onPressed: () => _deleteTicket(ticket.id!),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: tickets.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 32,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: ElevatedButton(
                onPressed: () => _handleCheckout(_currentTickets),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Checkout'),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FloatingActionButton(
                onPressed: () => _showTicketDialog(),
                tooltip: 'Nouveau ticket',
                heroTag: 'add_ticket_fab',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _GreyDashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int availableCount;
  final int lanaCount;
  final int usedCount;

  const _GreyDashboardHeaderDelegate({
    required this.availableCount,
    required this.lanaCount,
    required this.usedCount,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey.shade200,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          _StatusPill(label: 'Available', count: availableCount, color: Colors.green),
          _StatusPill(label: 'Lana', count: lanaCount, color: Colors.orange),
          _StatusPill(label: 'Used', count: usedCount, color: Colors.red),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 54;

  @override
  double get minExtent => 54;

  @override
  bool shouldRebuild(covariant _GreyDashboardHeaderDelegate oldDelegate) =>
      availableCount != oldDelegate.availableCount ||
      lanaCount != oldDelegate.lanaCount ||
      usedCount != oldDelegate.usedCount;
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}