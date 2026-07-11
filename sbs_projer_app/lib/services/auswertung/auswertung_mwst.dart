/// MwSt-Faktor für die Auswertung (brutto = netto × faktor).
///
/// Schweizer Normalsatz: 7.7 % bis und mit 2023, 8.1 % ab 2024. Die Excel-
/// „Auswertung" rechnet inkl. MWST ebenfalls netto × diesem Faktor
/// (2019: ×1.077, 2025: ×1.081 — verifiziert).
double mwstFaktor(int jahr) => jahr >= 2024 ? 1.081 : 1.077;
