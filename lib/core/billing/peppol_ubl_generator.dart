import '../../models/client.dart';
import '../../models/company_profile.dart';
import '../../models/enums.dart';
import '../../models/finance.dart';
import 'vat_service.dart';

/// Résultat de la génération d'un document UBL.
class UblResult {
  final String xml;
  final String filename;
  const UblResult(this.xml, this.filename);
}

/// Générateur de factures électroniques au format
/// **UBL 2.1 — Peppol BIS Billing 3.0** (norme EN 16931).
///
/// Ce document est celui qui est transmis à un Access Point Peppol.
class PeppolUblGenerator {
  PeppolUblGenerator._();

  /// Codes catégorie de TVA (BT-118) selon la norme EN 16931.
  /// S = taux standard, Z = taux zéro, E = exonéré, AE = autoliquidation,
  /// G = exportation hors UE.
  static String vatCategoryCode(FinanceDocument f, Client? client) {
    if (f.type == FinanceDocType.credit) return 'S';
    final isBusiness = client?.isBusiness ?? false;
    final vat = VatService.validateVat(client?.vatNumber ?? '');
    if (isBusiness && vat.valid && vat.isBelgian) return 'AE';
    if (isBusiness && vat.valid && vat.isEu && !vat.isBelgian) return 'E';
    if (isBusiness && !vat.isEu) return 'G';
    if (f.taxPercent == 0) return 'Z';
    return 'S';
  }

  /// Échappe les caractères réservés XML.
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _money(double v) => v.toStringAsFixed(2);

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _typeCode(FinanceDocType t) {
    switch (t) {
      case FinanceDocType.invoice:
        return '380'; // Commercial invoice
      case FinanceDocType.credit:
        return '381'; // Credit note
      case FinanceDocType.quote:
        return '381';
      case FinanceDocType.deposit:
        return '380';
    }
  }

  static String _formatPeppolId(String scheme, String id) {
    final clean = id.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    return '$scheme:$clean';
  }

  /// Génère le XML UBL d'une facture.
  static UblResult generate({
    required FinanceDocument f,
    required Client? client,
    required CompanyProfile company,
  }) {
    final vat = VatService.computeVat(client);
    final category = vatCategoryCode(f, client);
    final currency = f.currency.isEmpty ? 'EUR' : f.currency;
    final issueDate = _date(f.date);
    final dueDate = _date(f.dueDate ?? f.date.add(const Duration(days: 30)));

    // Identifiants Peppol (émetteur / destinataire)
    final supplierPeppol = company.peppolId.trim().isNotEmpty
        ? company.peppolId.trim()
        : _formatPeppolId('0208', company.vatNumber.replaceFirst('BE', ''));
    final customerPeppol = (client != null)
        ? (VatService.peppolIdFor(client) ?? '')
        : '';

    // Adresse émetteur
    final supplierAddr = _addr(
      street: company.addressLine,
      city: company.city,
      postal: company.postalCode,
      country: company.countryCode,
    );

    // Adresse client
    final custCity = client?.city ?? '';
    final custCountry = _countryCode(client?.country ?? 'BE');
    final custStreet = client?.billingAddress ?? custCity;
    final customerAddr = _addr(
      street: custStreet,
      city: custCity,
      postal: '',
      country: custCountry,
    );

    final vatMention = f.vatMention ?? vat.mention;

    final lines = StringBuffer();
    for (var i = 0; i < f.lines.length; i++) {
      final l = f.lines[i];
      lines.write('''
    <cac:InvoiceLine>
      <cbc:ID>${i + 1}</cbc:ID>
      <cbc:InvoicedQuantity unitCode="C62">${_money(l.quantity)}</cbc:InvoicedQuantity>
      <cbc:LineExtensionAmount currencyID="$currency">${_money(l.total)}</cbc:LineExtensionAmount>
      <cac:Item>
        <cbc:Name>${_esc(l.description)}</cbc:Name>
        <cac:ClassifiedTaxCategory>
          <cbc:ID>$category</cbc:ID>
          <cbc:Percent>${_money(f.taxPercent)}</cbc:Percent>
          <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
        </cac:ClassifiedTaxCategory>
      </cac:Item>
      <cac:Price>
        <cbc:PriceAmount currencyID="$currency">${_money(l.unitPrice)}</cbc:PriceAmount>
      </cac:Price>
    </cac:InvoiceLine>''');
    }

    final xml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>
  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>
  <cbc:ID>${_esc(f.reference)}</cbc:ID>
  <cbc:IssueDate>$issueDate</cbc:IssueDate>
  <cbc:DueDate>$dueDate</cbc:DueDate>
  <cbc:InvoiceTypeCode>${_typeCode(f.type)}</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>$currency</cbc:DocumentCurrencyCode>
  <cbc:Note>${_esc(vatMention)}</cbc:Note>
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cbc:EndpointID schemeID="0208">${_esc(supplierPeppol)}</cbc:EndpointID>
      <cac:PartyName><cbc:Name>${_esc(company.brandName)}</cbc:Name></cac:PartyName>
      <cac:PostalAddress>$supplierAddr</cac:PostalAddress>
      <cac:PartyTaxScheme>
        <cbc:CompanyID>${_esc(company.vatNumber)}</cbc:CompanyID>
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:PartyTaxScheme>
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>${_esc(company.legalName)}</cbc:RegistrationName>
        <cbc:CompanyID>${_esc(company.companyNumber)}</cbc:CompanyID>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cac:Party>
      ${customerPeppol.isNotEmpty ? '<cbc:EndpointID schemeID="0208">${_esc(customerPeppol)}</cbc:EndpointID>' : ''}
      <cac:PartyName><cbc:Name>${_esc(f.clientName)}</cbc:Name></cac:PartyName>
      <cac:PostalAddress>$customerAddr</cac:PostalAddress>
      ${(f.clientVatNumber ?? '').isNotEmpty ? '''<cac:PartyTaxScheme>
        <cbc:CompanyID>${_esc(f.clientVatNumber!)}</cbc:CompanyID>
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:PartyTaxScheme>''' : ''}
      <cac:PartyLegalEntity>
        <cbc:RegistrationName>${_esc(client?.companyName ?? f.clientName)}</cbc:RegistrationName>
      </cac:PartyLegalEntity>
    </cac:Party>
  </cac:AccountingCustomerParty>
  <cac:PaymentMeans>
    <cbc:PaymentMeansCode>30</cbc:PaymentMeansCode>
    ${(f.structuredCommunication ?? '').isNotEmpty ? '<cbc:PaymentID>${_esc(f.structuredCommunication!)}</cbc:PaymentID>' : ''}
    <cac:PayeeFinancialAccount>
      <cbc:ID>${_esc(company.iban)}</cbc:ID>
      <cac:FinancialInstitutionBranch><cbc:ID>${_esc(company.bic)}</cbc:ID></cac:FinancialInstitutionBranch>
    </cac:PayeeFinancialAccount>
  </cac:PaymentMeans>
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="$currency">${_money(f.taxAmount)}</cbc:TaxAmount>
    <cac:TaxSubtotal>
      <cbc:TaxableAmount currencyID="$currency">${_money(f.subtotal)}</cbc:TaxableAmount>
      <cbc:TaxAmount currencyID="$currency">${_money(f.taxAmount)}</cbc:TaxAmount>
      <cac:TaxCategory>
        <cbc:ID>$category</cbc:ID>
        <cbc:Percent>${_money(f.taxPercent)}</cbc:Percent>
        ${category != 'S' ? '<cbc:TaxExemptionReason>${_esc(vatMention)}</cbc:TaxExemptionReason>' : ''}
        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>
      </cac:TaxCategory>
    </cac:TaxSubtotal>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="$currency">${_money(f.subtotal)}</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="$currency">${_money(f.subtotal)}</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="$currency">${_money(f.total)}</cbc:TaxInclusiveAmount>
    <cbc:PayableAmount currencyID="$currency">${_money(f.balance)}</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>$lines
</Invoice>''';

    return UblResult(xml, '${f.reference}.xml');
  }

  static String _addr({
    required String street,
    required String city,
    required String postal,
    required String country,
  }) => '''
        <cbc:StreetName>${_esc(street)}</cbc:StreetName>
        ${postal.isNotEmpty ? '<cbc:PostalZone>${_esc(postal)}</cbc:PostalZone>' : ''}
        <cbc:CityName>${_esc(city)}</cbc:CityName>
        <cac:Country><cbc:IdentificationCode>${_esc(_countryCode(country))}</cbc:IdentificationCode></cac:Country>''';

  static String _countryCode(String c) {
    final t = c.trim().toUpperCase();
    if (t.length == 2) return t;
    const map = {
      'BELGIQUE': 'BE',
      'BELGIUM': 'BE',
      'BELGIE': 'BE',
      'BELGIË': 'BE',
      'FRANCE': 'FR',
      'ROYAUME-UNI': 'GB',
      'UNITED KINGDOM': 'GB',
      'ITALIE': 'IT',
      'ITALY': 'IT',
      'ITALIA': 'IT',
      'LUXEMBOURG': 'LU',
      'PAYS-BAS': 'NL',
      'NETHERLANDS': 'NL',
      'ALLEMAGNE': 'DE',
      'GERMANY': 'DE',
      'ESPAGNE': 'ES',
      'SPAIN': 'ES',
    };
    return map[t] ?? (t.length >= 2 ? t.substring(0, 2) : 'BE');
  }
}
