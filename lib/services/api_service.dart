import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket.dart';

class ApiService {
  static const String baseUrl = 'https://mern-back-comptag-sam.vercel.app/api/tickets';

  // GET: Fetch all tickets
  static Future<List<Ticket>> fetchTickets() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Ticket.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load tickets');
    }
  }

  // POST: Create ticket
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

  // PUT: Update ticket
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

  // POST: Batch Checkout using only 'quoi' and the count of checked tickets
  static Future<void> batchCheckout({
    required List<String> ticketIds,
    required String quoi,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'ticketIds': ticketIds,
        'quoi': quoi,
        'count': ticketIds.length,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    // Fallback logic if backend expects individual updates
    if (response.statusCode == 404) {
      for (final id in ticketIds) {
        await http.put(
          Uri.parse('$baseUrl/$id'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'quoi': quoi,
            'dateOutput': DateTime.now().toIso8601String(),
          }),
        );
      }
      return;
    }

    String message = 'Failed to execute checkout';
    try {
      final data = json.decode(response.body);
      if (data is Map && data['message'] != null) {
        message = data['message'];
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    throw Exception(message);
  }

  // DELETE: Delete ticket
  static Future<void> deleteTicket(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete ticket');
    }
  }
}