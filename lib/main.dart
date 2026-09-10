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
                    final newTicket = Ticket(
                      id: ticket?.id,
                      dateInput: dateInput,
                      dateOutput: dateOutput,
                      qui: selectedQui,
                      quoi: isEditing ? (ticket!.quoi.isNotEmpty ? ticket.quoi : '') : '',
                      combien: int.tryParse(combienController.text) ?? 1,
                      lanaGarde: lanaGarde,
                    );

                    try {
                      if (isEditing) {
                        await ApiService.updateTicket(ticket.id!, newTicket);
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

          return RefreshIndicator(
            onRefresh: () async => _refreshTickets(),
            child: CustomScrollView(
              slivers: [
                const SliverPersistentHeader(
                  pinned: true,
                  delegate: _GreyDashboardHeaderDelegate(),
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
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: ticket.dateOutput != null ? Colors.red : (ticket.lanaGarde ? Colors.orange : Colors.blue),
                                    child: Text(
                                      '${ticket.combien}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${ticket.qui} — ${ticket.quoi}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text('In: ${dateFormat.format(ticket.dateInput)}'),
                                        if (ticket.dateOutput != null)
                                          Text('Out: ${dateFormat.format(ticket.dateOutput!)}', style: const TextStyle(color: Colors.green))
                                        else
                                          const Text('Out: En cours...', style: TextStyle(color: Colors.grey)),
                                        if (ticket.lanaGarde)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: const Chip(
                                              label: Text('Lana Garde', style: TextStyle(fontSize: 10)),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showTicketDialog(ticket: ticket),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteTicket(ticket.id!),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checkout')),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTicketDialog(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _GreyDashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _GreyDashboardHeaderDelegate();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey.shade200,
      height: 24,
      margin: const EdgeInsets.only(bottom: 8),
    );
  }

  @override
  double get maxExtent => 24;

  @override
  double get minExtent => 24;

  @override
  bool shouldRebuild(covariant _GreyDashboardHeaderDelegate oldDelegate) => false;
}