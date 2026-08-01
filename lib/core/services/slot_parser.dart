class SlotParser {
  /// Parses a slot combination string like 'A11+A12+A13' into individual slots.
  static List<String> parse(String slotCombo) {
    if (slotCombo.isEmpty) return [];
    return slotCombo
        .split('+')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Joins individual slot IDs into a combo string (e.g. ['A14','D11','D12'] -> 'A14+D11+D12').
  static String join(List<String> slots) {
    return slots.where((s) => s.isNotEmpty).join('+');
  }

  /// Extracts the base identifier from a slot (e.g., 'A11' -> 'A1').
  static String getBaseSlot(String slot) {
    if (slot.isEmpty) return '';
    if (RegExp(r'^[A-Z][1-2][1-4]$').hasMatch(slot)) {
       return slot.substring(0, 2); // A11 -> A1
    }
    return slot;
  }
}
