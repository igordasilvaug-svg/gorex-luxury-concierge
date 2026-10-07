import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Catégories de clientèle VIP
enum ClientCategory {
  individualVip('Individual VIP'),
  executive('Executive'),
  family('Family'),
  artist('Artist'),
  corporate('Corporate'),
  diplomatic('Diplomatic'),
  delegation('Delegation');

  final String label;
  const ClientCategory(this.label);

  static ClientCategory fromName(String name) =>
      ClientCategory.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ClientCategory.individualVip,
      );
}

/// Statut d'envoi d'une facture via le réseau Peppol
enum PeppolStatus {
  notApplicable('Non applicable', ''),
  ready('Prêt à envoyer', 'READY'),
  sent('Envoyé', 'SENT'),
  delivered('Distribué', 'DELIVERED'),
  failed('Échec', 'FAILED');

  final String label;
  final String code;
  const PeppolStatus(this.label, this.code);

  static PeppolStatus fromName(String name) => PeppolStatus.values.firstWhere(
    (e) => e.name == name,
    orElse: () => PeppolStatus.notApplicable,
  );
}

/// Niveaux de confidentialité
enum ConfidentialityLevel {
  standard('Standard', 1),
  elevated('Elevated', 2),
  restricted('Restricted', 3),
  topSecret('Top Secret', 4);

  final String label;
  final int level;
  const ConfidentialityLevel(this.label, this.level);

  static ConfidentialityLevel fromName(String name) =>
      ConfidentialityLevel.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ConfidentialityLevel.standard,
      );
}

/// Rôles de l'équipe
enum UserRole {
  ceo('CEO', 'Direction'),
  conciergeManager('Luxury Concierge Manager', 'Conciergerie'),
  seniorConcierge('Senior Concierge', 'Conciergerie'),
  concierge('Concierge', 'Conciergerie'),
  travelManager('Travel Manager', 'Travel'),
  lifestyleManager('Lifestyle Manager', 'Lifestyle'),
  securityCoordinator('Security Coordinator', 'Security'),
  finance('Finance', 'Finance'),
  vipClient('Client VIP', 'Client');

  final String label;
  final String department;
  const UserRole(this.label, this.department);

  static UserRole fromName(String name) => UserRole.values.firstWhere(
    (e) => e.name == name,
    orElse: () => UserRole.concierge,
  );

  bool get isStaff => this != UserRole.vipClient;
}

/// Statuts d'une demande
enum RequestStatus {
  new_('NEW', 'Nouvelle', AppColors.statusNew),
  underReview('UNDER REVIEW', 'En analyse', AppColors.statusReview),
  inProgress('IN PROGRESS', 'En cours', AppColors.statusProgress),
  waitingClient('WAITING CLIENT', 'Attente client', AppColors.statusWaiting),
  confirmed('CONFIRMED', 'Confirmée', AppColors.statusConfirmed),
  completed('COMPLETED', 'Terminée', AppColors.statusCompleted),
  cancelled('CANCELLED', 'Annulée', AppColors.statusCancelled);

  final String code;
  final String label;
  final Color color;
  const RequestStatus(this.code, this.label, this.color);

  static RequestStatus fromName(String name) => RequestStatus.values.firstWhere(
    (e) => e.name == name,
    orElse: () => RequestStatus.new_,
  );
}

/// Niveau d'urgence
enum UrgencyLevel {
  standard('Standard', AppColors.grey, 0),
  priority('Priority', AppColors.statusWaiting, 1),
  urgent('Urgent', AppColors.urgent, 2),
  critical('Critical', Color(0xFF7A1F1F), 3);

  final String label;
  final Color color;
  final int weight;
  const UrgencyLevel(this.label, this.color, this.weight);

  static UrgencyLevel fromName(String name) => UrgencyLevel.values.firstWhere(
    (e) => e.name == name,
    orElse: () => UrgencyLevel.standard,
  );
}

/// Catégories de services
enum ServiceDomain {
  travel('Travel', Icons.flight_takeoff_outlined),
  lifestyle('Lifestyle', Icons.local_dining_outlined),
  business('Business', Icons.business_center_outlined),
  security('Security', Icons.shield_outlined),
  medical('Medical Assistance', Icons.medical_services_outlined);

  final String label;
  final IconData icon;
  const ServiceDomain(this.label, this.icon);

  static ServiceDomain fromName(String name) => ServiceDomain.values.firstWhere(
    (e) => e.name == name,
    orElse: () => ServiceDomain.travel,
  );
}

/// Statuts génériques réservations
enum BookingStatus {
  pending('Pending', AppColors.statusNew),
  confirmed('Confirmed', AppColors.statusConfirmed),
  cancelled('Cancelled', AppColors.statusCancelled),
  completed('Completed', AppColors.statusCompleted);

  final String label;
  final Color color;
  const BookingStatus(this.label, this.color);

  static BookingStatus fromName(String name) => BookingStatus.values.firstWhere(
    (e) => e.name == name,
    orElse: () => BookingStatus.pending,
  );
}

/// Types de réservations
enum BookingType {
  hotel('Hôtel', Icons.hotel_outlined),
  restaurant('Restaurant', Icons.restaurant_outlined),
  transport('Transport', Icons.directions_car_outlined),
  activity('Activité', Icons.local_activity_outlined),
  event('Événement', Icons.celebration_outlined),
  flight('Vol', Icons.flight_outlined),
  driver('Chauffeur', Icons.airline_seat_recline_normal_outlined),
  security('Sécurité', Icons.security_outlined);

  final String label;
  final IconData icon;
  const BookingType(this.label, this.icon);

  static BookingType fromName(String name) => BookingType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => BookingType.hotel,
  );
}

/// Statuts de facturation
enum InvoiceStatus {
  draft('Brouillon', AppColors.grey),
  sent('Envoyée', AppColors.statusProgress),
  paid('Payée', AppColors.statusConfirmed),
  overdue('En retard', AppColors.urgent),
  cancelled('Annulée', AppColors.statusCancelled);

  final String label;
  final Color color;
  const InvoiceStatus(this.label, this.color);

  static InvoiceStatus fromName(String name) => InvoiceStatus.values.firstWhere(
    (e) => e.name == name,
    orElse: () => InvoiceStatus.draft,
  );
}

/// Type de document financier
enum FinanceDocType {
  quote('Devis'),
  invoice('Facture'),
  deposit('Acompte'),
  credit('Note de crédit');

  final String label;
  const FinanceDocType(this.label);

  static FinanceDocType fromName(String name) => FinanceDocType.values
      .firstWhere((e) => e.name == name, orElse: () => FinanceDocType.invoice);
}

/// Étapes du pipeline CRM
enum ProspectStage {
  lead('Lead', AppColors.statusNew),
  contacted('Contacté', AppColors.statusProgress),
  qualified('Qualifié', AppColors.statusReview),
  proposal('Proposition', AppColors.statusWaiting),
  negotiation('Négociation', AppColors.champagne),
  won('Gagné', AppColors.statusConfirmed),
  lost('Perdu', AppColors.statusCancelled);

  final String label;
  final Color color;
  const ProspectStage(this.label, this.color);

  static ProspectStage fromName(String name) => ProspectStage.values.firstWhere(
    (e) => e.name == name,
    orElse: () => ProspectStage.lead,
  );
}

/// Types de rendez-vous agenda
enum AppointmentType {
  meeting('Rendez-vous client', Icons.handshake_outlined),
  travel('Voyage', Icons.flight_takeoff_outlined),
  booking('Réservation', Icons.event_available_outlined),
  event('Événement', Icons.celebration_outlined),
  mission('Mission', Icons.assignment_outlined),
  reminder('Rappel', Icons.alarm_outlined),
  deadline('Échéance', Icons.schedule_outlined);

  final String label;
  final IconData icon;
  const AppointmentType(this.label, this.icon);

  static AppointmentType fromName(String name) => AppointmentType.values
      .firstWhere((e) => e.name == name, orElse: () => AppointmentType.meeting);
}
