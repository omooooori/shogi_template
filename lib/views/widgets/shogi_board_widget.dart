import 'package:flutter/material.dart';

class ShogiBoardWidget extends StatelessWidget {
  final List<String> pieceImages;
  final int? selectedPieceIndex;
  final List<int> validMoves;
  final Function(int) onTapCell;
  final double size;
  final int? lastComputerMoveFrom;
  final int? lastComputerMoveTo;

  const ShogiBoardWidget({
    super.key,
    required this.pieceImages,
    required this.selectedPieceIndex,
    required this.validMoves,
    required this.onTapCell,
    required this.size,
    this.lastComputerMoveFrom,
    this.lastComputerMoveTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(128),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9, // 将棋盤は9x9
          ),
          itemBuilder: (context, index) {
            // コンピューターの移動を判定
            final isComputerMove =
                index == lastComputerMoveFrom || index == lastComputerMoveTo;

            return GestureDetector(
              onTap: () => onTapCell(index),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // マスの背景
                  Container(
                    decoration: BoxDecoration(
                      color:
                          selectedPieceIndex == index
                              ? Colors.yellow[200] // 選択された駒のマスの色
                              : isComputerMove
                              ? Colors.lightBlue[100] // コンピューターの移動マスの色
                              : Colors.orange[100], // 通常のマスの色
                      border: Border.all(
                        color: isComputerMove ? Colors.blue : Colors.black,
                        width: isComputerMove ? 2.0 : 1.0,
                      ),
                    ),
                  ),
                  // 駒の画像
                  if (pieceImages[index].isNotEmpty)
                    Image.asset(
                      pieceImages[index],
                      width: size / 11, // 駒のサイズも調整
                      height: size / 11,
                      fit: BoxFit.contain,
                    ),
                  // 移動可能なマスの表示（赤丸）
                  if (validMoves.contains(index))
                    Container(
                      width: size / 20,
                      height: size / 20,
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                    ),
                  // コンピューターの移動先のマスに強調表示
                  if (index == lastComputerMoveTo)
                    Container(
                      width: size / 9.5,
                      height: size / 9.5,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.rectangle,
                        border: Border.all(color: Colors.blue, width: 3.0),
                      ),
                    ),
                ],
              ),
            );
          },
          itemCount: 81, // 9x9のマス
        ),
      ),
    );
  }
}
