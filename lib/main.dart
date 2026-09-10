import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'models/ticket.dart';

// --- API SERVICE ---
class ApiService {
  static const String baseUrl = 'https://mern-back-comptag-sam.vercel.app/api/tickets';

  static Future<List<Ticket>> fetchTickets() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Ticket.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load tickets');
    }
  }

  static Future<Ticket> createTicket(Ticket ticket) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(ticket.toJson()),
    );

    if (response.statusCode == 201) {
      return Ticket.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create ticket');
    }
  }

  static Future<Ticket> updateTicket(String id, Ticket ticket) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(ticket.toJson()),
    );

    if (response.statusCode == 200) {
      return Ticket.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update ticket');
    }
  }

  static Future<void> deleteTicket(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete ticket');
    }
  }
}

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
    final quiController = TextEditingController(text: ticket?.qui ?? '');
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
                    TextField(
                      controller: quiController,
                      decoration: const InputDecoration(labelText: 'Qui (Nom)'),
                    ),
                    TextField(
                      controller: quoiController,
                      decoration: const InputDecoration(labelText: 'Quoi (Objet)'),
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
                      title: Text('Date Entrée: ${DateFormat('dd/MM/yyyy HH:mm').format(dateInput)}'),
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
                      qui: quiController.text,
                      quoi: quoiController.text,
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

  void _markOutput(Ticket ticket) async {
    final updatedTicket = Ticket(
      id: ticket.id,
      dateInput: ticket.dateInput,
      dateOutput: DateTime.now(),
      qui: ticket.qui,
      quoi: ticket.quoi,
      combien: ticket.combien,
      lanaGarde: false,
    );

    try {
      await ApiService.updateTicket(ticket.id!, updatedTicket);
      _refreshTickets();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'actualisation: $e')),
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
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun ticket trouvé.'));
          }

          final tickets = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshTickets(),
            child: ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ticket.lanaGarde ? Colors.orange : Colors.blue,
                      child: Text(
                        '${ticket.combien}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${ticket.qui} — ${ticket.quoi}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('In: ${dateFormat.format(ticket.dateInput)}'),
                        if (ticket.dateOutput != null)
                          Text('Out: ${dateFormat.format(ticket.dateOutput!)}', style: const TextStyle(color: Colors.green))
                        else
                          const Text('Out: En cours...', style: const TextStyle(color: Colors.grey)),
                        if (ticket.lanaGarde)
                          const Chip(
                            label: Text('Lana Garde', style: TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ticket.dateOutput == null)
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.green),
                            tooltip: 'Marquer Sortie',
                            onPressed: () => _markOutput(ticket),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showTicketDialog(ticket: ticket),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTicket(ticket.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTicketDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}