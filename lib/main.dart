import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/ticket.dart';
import 'services/api_service.dart';

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
  final Set<String> _selectedTicketIds = {};

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  void _refreshTickets() {
    setState(() {
      _selectedTicketIds.clear();
      _ticketsFuture = ApiService.fetchTickets();
    });
  }

  // Helper method to assign a priority rank for ordering:
  // 0 -> Available (dateOutput == null && !lanaGarde)
  // 1 -> Lana Garde (dateOutput == null && lanaGarde)
  // 2 -> Used (dateOutput != null)
  int _getTicketPriority(Ticket ticket) {
    if (ticket.dateOutput != null) return 2;
    if (ticket.lanaGarde) return 1;
    return 0;
  }

  void _showTicketDialog({Ticket? ticket}) {
    final bool isEditing = ticket != null && ticket.id != null && ticket.id!.isNotEmpty;

    const fixedQuiOptions = ['Stev', 'Bee', 'Lana'];
    String selectedQui = fixedQuiOptions.contains(ticket?.qui) ? ticket!.qui : fixedQuiOptions.first;

    const combienOptions = [7, 10];
    int selectedCombien = (ticket != null && combienOptions.contains(ticket.combien))
        ? ticket.combien
        : 7;

    final quoiController = TextEditingController(text: ticket?.quoi ?? '');
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
                          setDialogState(() {
                            selectedQui = value;
                            if (selectedQui != 'Lana') {
                              lanaGarde = false;
                            }
                          });
                        }
                      },
                    ),
                    if (isEditing)
                      TextField(
                        controller: quoiController,
                        decoration: const InputDecoration(labelText: 'Quoi'),
                      ),
                    DropdownButtonFormField<int>(
                      value: selectedCombien,
                      decoration: const InputDecoration(labelText: 'Combien'),
                      items: combienOptions
                          .map((value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCombien = value);
                        }
                      },
                    ),
                    if (selectedQui == 'Lana')
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
                    final finalQuoi = isEditing ? quoiController.text.trim() : null;

                    if (isEditing && (finalQuoi == null || finalQuoi.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Le champ "Quoi" est obligatoire en modification.')),
                      );
                      return;
                    }

                    final ticketToSave = Ticket(
                      id: ticket?.id,
                      dateInput: dateInput,
                      dateOutput: dateOutput,
                      qui: selectedQui,
                      quoi: finalQuoi ?? '',
                      combien: selectedCombien,
                      lanaGarde: selectedQui == 'Lana' ? lanaGarde : false,
                    );

                    try {
                      if (isEditing) {
                        await ApiService.updateTicket(ticket!.id!, ticketToSave);
                      } else {
                        await ApiService.createTicket(ticketToSave);
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

  void _showCheckoutDialog(List<String> checkedTicketIds) {
    final quoiController = TextEditingController();
    final int count = checkedTicketIds.length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Checkout ($count ticket${count > 1 ? 's' : ''})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre à valider: $count',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quoiController,
                decoration: const InputDecoration(
                  labelText: 'Quoi',
                  hintText: 'Saisissez le motif de sortie',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final finalQuoi = quoiController.text.trim();

                if (finalQuoi.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le champ "Quoi" est obligatoire.')),
                  );
                  return;
                }

                try {
                  await ApiService.batchCheckout(
                    ticketIds: checkedTicketIds,
                    quoi: finalQuoi,
                  );
                  if (context.mounted) Navigator.pop(context);
                  _refreshTickets();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors du checkout: $e')),
                  );
                }
              },
              child: const Text('Valider Checkout'),
            ),
          ],
        );
      },
    );
  }

  void _handleCheckout() {
    if (_selectedTicketIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez cocher au moins 1 ticket pour effectuer le checkout.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showCheckoutDialog(_selectedTicketIds.toList());
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

          final rawTickets = snapshot.data ?? <Ticket>[];

          // Compute Counts and Sums
          final availableTickets = rawTickets.where((t) => t.dateOutput == null && !t.lanaGarde);
          final lanaTickets = rawTickets.where((t) => t.lanaGarde);
          final usedTickets = rawTickets.where((t) => t.dateOutput != null);

          final availableCount = availableTickets.length;
          final availableSum = availableTickets.fold<int>(0, (sum, t) => sum + t.combien);

          final lanaCount = lanaTickets.length;
          final lanaSum = lanaTickets.fold<int>(0, (sum, t) => sum + t.combien);

          final usedCount = usedTickets.length;
          final usedSum = usedTickets.fold<int>(0, (sum, t) => sum + t.combien);

          // Order list:
          // 1. Priority: Available (0) -> Lana (1) -> Used (2)
          // 2. Combien: Ascending (7 before 10)
          // 3. Date Input: Ascending (Oldest first)
          final sortedTickets = List<Ticket>.from(rawTickets)
            ..sort((a, b) {
              int priorityA = _getTicketPriority(a);
              int priorityB = _getTicketPriority(b);
              if (priorityA != priorityB) {
                return priorityA.compareTo(priorityB);
              }
              if (a.combien != b.combien) {
                return a.combien.compareTo(b.combien);
              }
              return a.dateInput.compareTo(b.dateInput);
            });

          _currentTickets = sortedTickets;

          return RefreshIndicator(
            onRefresh: () async => _refreshTickets(),
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _GreyDashboardHeaderDelegate(
                    availableCount: availableCount,
                    availableSum: availableSum,
                    lanaCount: lanaCount,
                    lanaSum: lanaSum,
                    usedCount: usedCount,
                    usedSum: usedSum,
                  ),
                ),
                if (sortedTickets.isEmpty)
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
                          final ticket = sortedTickets[index];
                          final dateFormat = DateFormat('dd/MM/yyyy');
                          final displayQuoi = (ticket.quoi != null && ticket.quoi!.isNotEmpty) ? ticket.quoi : '—';

                          final bool isUsed = ticket.dateOutput != null;
                          final bool isAvailableForCheckout = !isUsed && !ticket.lanaGarde;
                          final bool isChecked = ticket.id != null && _selectedTicketIds.contains(ticket.id);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isUsed
                                        ? Colors.red
                                        : (ticket.lanaGarde ? Colors.orange : Colors.green),
                                    child: Text(
                                      '${ticket.combien}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isAvailableForCheckout)
                                    Checkbox(
                                      value: isChecked,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true && ticket.id != null) {
                                            _selectedTicketIds.add(ticket.id!);
                                          } else {
                                            _selectedTicketIds.remove(ticket.id);
                                          }
                                        });
                                      },
                                    )
                                  else
                                    const SizedBox(width: 12),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${ticket.qui} — $displayQuoi',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('In: ${dateFormat.format(ticket.dateInput)}', style: const TextStyle(fontSize: 12)),
                                        if (ticket.dateOutput != null)
                                          Text('Out: ${dateFormat.format(ticket.dateOutput!)}',
                                              style: const TextStyle(color: Colors.green, fontSize: 12))
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
                        childCount: sortedTickets.length,
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
                onPressed: _handleCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Checkout (${_selectedTicketIds.length})'),
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
  final int availableSum;
  final int lanaCount;
  final int lanaSum;
  final int usedCount;
  final int usedSum;

  const _GreyDashboardHeaderDelegate({
    required this.availableCount,
    required this.availableSum,
    required this.lanaCount,
    required this.lanaSum,
    required this.usedCount,
    required this.usedSum,
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
          _StatusPill(count: availableCount, sum: availableSum, color: Colors.green),
          _StatusPill(count: lanaCount, sum: lanaSum, color: Colors.orange),
          _StatusPill(count: usedCount, sum: usedSum, color: Colors.red),
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
      availableSum != oldDelegate.availableSum ||
      lanaCount != oldDelegate.lanaCount ||
      lanaSum != oldDelegate.lanaSum ||
      usedCount != oldDelegate.usedCount ||
      usedSum != oldDelegate.usedSum;
}

class _StatusPill extends StatelessWidget {
  final int count;
  final int sum;
  final Color color;

  const _StatusPill({
    required this.count,
    required this.sum,
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
            '$count : $sum€',
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