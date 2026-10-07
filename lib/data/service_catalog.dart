import '../models/enums.dart';

/// Taxonomie complète des services GOREX LUXURY CONCIERGE
class ServiceCatalog {
  ServiceCatalog._();

  static const Map<ServiceDomain, List<String>> services = {
    ServiceDomain.travel: [
      'Réservation hôtel',
      'Réservation villa',
      'Réservation vols',
      'Jet privé',
      'Hélicoptère',
      'Transferts',
      'Chauffeurs',
      'Voyages internationaux',
      'Itinéraires personnalisés',
      'Assistance aéroportuaire',
    ],
    ServiceDomain.lifestyle: [
      'Réservation restaurant',
      'Table VIP',
      'Événements',
      'Shopping',
      'Personal shopping',
      'Expériences privées',
      'Clubs privés',
      'Spectacles',
      'Activités exclusives',
    ],
    ServiceDomain.business: [
      'Déplacements professionnels',
      'Organisation de réunions',
      'Salles privées',
      'Secrétariat',
      'Interprètes',
      'Traduction',
      'Assistants',
      'Coordination de délégations',
      'Événements corporate',
    ],
    ServiceDomain.security: [
      'Protection rapprochée',
      'Chauffeur sécurisé',
      'Accompagnement',
      'Sécurité événementielle',
      'Analyse de risques',
      'Sécurisation d\'itinéraire',
      'Coordination sécurité',
    ],
    ServiceDomain.medical: [
      'Assistance médicale',
      'Médecin',
      'Ambulance',
      'Pharmacie',
      'Coordination médicale',
      'Assistance voyage',
    ],
  };

  static List<String> forDomain(ServiceDomain d) => services[d] ?? const [];

  static String domainDescription(ServiceDomain d) {
    switch (d) {
      case ServiceDomain.travel:
        return 'Travel & Mobility — vols, jets privés, hôtels, villas, transferts et itinéraires sur mesure.';
      case ServiceDomain.lifestyle:
        return 'Lifestyle & Experiences — gastronomie, événements privés, shopping et accès exclusifs.';
      case ServiceDomain.business:
        return 'Business & Executive Support — déplacements, réunions, interprétation et délégations.';
      case ServiceDomain.security:
        return 'Security & Protection — géré comme service distinct, coordonné avec GOREX SECURITY.';
      case ServiceDomain.medical:
        return 'Medical Assistance — coordination médicale via prestataires agréés partenaires.';
    }
  }
}
