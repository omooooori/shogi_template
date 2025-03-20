import 'package:flutter/material.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final List<String> capturedPieces;
  final String? selectedPiece;
  final Function(String) onSelectPiece;
  final bool isSelectable;
  final String label;

  const CapturedPiecesWidget({
    super.key,
    required this.capturedPieces,
    required this.selectedPiece,
    required this.onSelectPiece,
    required this.isSelectable,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // 持ち駒をグループ化する
    final Map<String, int> groupedPieces = {};
    for (final piece in capturedPieces) {
      if (groupedPieces.containsKey(piece)) {
        groupedPieces[piece] = groupedPieces[piece]! + 1;
      } else {
        groupedPieces[piece] = 1;
      }
    }

    return Container(
      width: double.infinity,
      height: 80, // 固定高さを設定
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.brown[700]?.withAlpha(179),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child:
                groupedPieces.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'なし',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            groupedPieces.entries.map((entry) {
                              return _buildPieceItem(entry.key, entry.value);
                            }).toList(),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceItem(String piecePath, int count) {
    final isSelected = selectedPiece == piecePath;

    return GestureDetector(
      onTap: isSelectable ? () => onSelectPiece(piecePath) : null,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.yellow.withAlpha(77) : Colors.transparent,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Stack(
          children: [
            Image.asset(piecePath, width: 40, height: 40),
            if (count > 1)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
