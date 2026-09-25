part of '../main.dart';

// ---------------- CLIENT ENTRY (quotation contact autocomplete) ----------------
// Mirrors SiteEntry's "grows as you type" pattern (lib/models/site.dart): a client typed
// once on a quotation gets saved here so every later quotation can just pick it from a
// dropdown instead of re-typing the same name/company for the hundredth time that day.
class ClientEntry {
  final String id;
  final String name;
  final String company;

  ClientEntry({required this.id, required this.name, required this.company});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'company': company};

  static ClientEntry fromMap(Map<String, dynamic> m) => ClientEntry(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        company: m['company'] ?? '',
      );
}

int _clientCounter = 1;
final List<ClientEntry> sampleClients = [];
