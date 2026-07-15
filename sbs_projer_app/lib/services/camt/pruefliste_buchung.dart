import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// Baut aus einem Prüflisten-Eintrag die CamtTransaction, die
/// [CamtAusgabeBooker.book] braucht.
///
/// Hintergrund: Eine Transaktion, die einmal in der Prüfliste gelandet ist,
/// wird bei jedem weiteren Import über ihren txKey übersprungen. Eine später
/// angelegte Regel greift für sie also nie — sie muss aus der Prüfliste heraus
/// gebucht werden. Die Prüfliste speichert dafür genau die nötigen Felder
/// (Betrag, Datum, Richtung, Name, IBAN, Beleg-Referenz, txKey).
///
/// Bewusste Vereinfachung: `referenz` hält je nach Transaktion die
/// strukturierte QR-/ESR-Referenz ODER die Mitteilung. Sie landet hier in
/// `strukturierteReferenz` und damit in den Notizen der Buchung — für ein
/// reines Notizfeld ist die Unterscheidung ohne Belang.
CamtTransaction txAusPrueflisteEintrag(CamtPrueflisteEintrag e) =>
    CamtTransaction(
      amount: e.betrag,
      currency: 'CHF',
      isCredit: e.istGutschrift,
      bookingDate: e.bookingDatum,
      accountServiceRef: e.belegRef,
      partyName: e.parteiName,
      partyIban: e.parteiIban,
      strukturierteReferenz: e.referenz,
      txKey: e.txKey,
    );
