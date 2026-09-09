class Ticket {
  final String? id;
  final DateTime dateInput;
  final DateTime? dateOutput;
  final String qui;
  final String quoi;
  final int combien;
  final bool lanaGarde;

  Ticket({
    this.id,
    required this.dateInput,
    this.dateOutput,
    required this.qui,
    required this.quoi,
    required this.combien,
    required this.lanaGarde,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['_id'],
      dateInput: DateTime.parse(json['dateInput']),
      dateOutput: json['dateOutput'] != null ? DateTime.parse(json['dateOutput']) : null,
      qui: json['qui'] ?? '',
      quoi: json['quoi'] ?? '',
      combien: json['combien'] ?? 0,
      lanaGarde: json['lanaGarde'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'dateInput': dateInput.toIso8601String(),
      'dateOutput': dateOutput?.toIso8601String(),
      'qui': qui,
      'quoi': quoi,
      'combien': combien,
      'lanaGarde': lanaGarde,
    };
  }
}