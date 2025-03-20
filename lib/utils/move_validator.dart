import '../models/shogi_board.dart';
import '../models/shogi_piece.dart';

class MoveValidator {
  // 盤面上での移動が有効かをチェック
  static bool isValidMove(ShogiBoard board, int fromIndex, int toIndex) {
    // 移動元に駒がない場合は無効
    final pieceImagePath = board.getPieceImagePath(fromIndex);
    if (pieceImagePath == null || pieceImagePath.isEmpty) {
      return false;
    }

    // 移動先に自分の駒がある場合は無効
    final targetImagePath = board.getPieceImagePath(toIndex);
    if (targetImagePath != null &&
        targetImagePath.isNotEmpty &&
        ((pieceImagePath.contains('black') &&
                targetImagePath.contains('black')) ||
            (pieceImagePath.contains('white') &&
                targetImagePath.contains('white')))) {
      return false;
    }

    // 移動元と移動先のマスの座標を計算
    final (fromRow, fromCol) = ShogiBoard.indexToPosition(fromIndex);
    final (toRow, toCol) = ShogiBoard.indexToPosition(toIndex);

    // 駒の種類を取得
    final piece = ShogiPiece.fromImagePath(pieceImagePath);
    if (piece == null) return false;

    // 駒の種類に応じた移動ルールを適用
    switch (piece.type) {
      // 歩兵（前方1マス）
      case PieceType.pawn:
        if (piece.isBlack) {
          return toRow == fromRow - 1 && toCol == fromCol;
        } else {
          return toRow == fromRow + 1 && toCol == fromCol;
        }

      // 香車（前方任意マス）
      case PieceType.lance:
        if (piece.isBlack) {
          return toCol == fromCol &&
              toRow < fromRow &&
              isPathClear(board, fromIndex, toIndex);
        } else {
          return toCol == fromCol &&
              toRow > fromRow &&
              isPathClear(board, fromIndex, toIndex);
        }

      // 桂馬（前方斜め2マス）
      case PieceType.knight:
        if (piece.isBlack) {
          return (toRow == fromRow - 2 &&
              (toCol == fromCol - 1 || toCol == fromCol + 1));
        } else {
          return (toRow == fromRow + 2 &&
              (toCol == fromCol - 1 || toCol == fromCol + 1));
        }

      // 銀将（斜め前方3マス、斜め後方2マス）
      case PieceType.silver:
        if (piece.isBlack) {
          return (toRow == fromRow - 1 &&
                  (toCol == fromCol - 1 ||
                      toCol == fromCol ||
                      toCol == fromCol + 1)) ||
              (toRow == fromRow + 1 &&
                  (toCol == fromCol - 1 || toCol == fromCol + 1));
        } else {
          return (toRow == fromRow + 1 &&
                  (toCol == fromCol - 1 ||
                      toCol == fromCol ||
                      toCol == fromCol + 1)) ||
              (toRow == fromRow - 1 &&
                  (toCol == fromCol - 1 || toCol == fromCol + 1));
        }

      // 金将（前方3マス、横1マス、後方1マス）
      case PieceType.gold:
        if (piece.isBlack) {
          return (toRow == fromRow - 1 &&
                  (toCol == fromCol - 1 ||
                      toCol == fromCol ||
                      toCol == fromCol + 1)) ||
              (toRow == fromRow &&
                  (toCol == fromCol - 1 || toCol == fromCol + 1)) ||
              (toRow == fromRow + 1 && toCol == fromCol);
        } else {
          return (toRow == fromRow + 1 &&
                  (toCol == fromCol - 1 ||
                      toCol == fromCol ||
                      toCol == fromCol + 1)) ||
              (toRow == fromRow &&
                  (toCol == fromCol - 1 || toCol == fromCol + 1)) ||
              (toRow == fromRow - 1 && toCol == fromCol);
        }

      // 王将・玉将（周囲8マス）
      case PieceType.king:
        return (toRow >= fromRow - 1 &&
                toRow <= fromRow + 1 &&
                toCol >= fromCol - 1 &&
                toCol <= fromCol + 1) &&
            !(toRow == fromRow && toCol == fromCol);

      // 飛車（縦横任意マス）
      case PieceType.rook:
        return ((toRow == fromRow || toCol == fromCol) &&
            isPathClear(board, fromIndex, toIndex));

      // 角行（斜め任意マス）
      case PieceType.bishop:
        return ((toRow - fromRow).abs() == (toCol - fromCol).abs() &&
            isPathClear(board, fromIndex, toIndex));

      // ここから成り駒の動き
      // と金（歩兵の成り駒）- 金と同じ動き
      case PieceType.promotedPawn:
        return _isGoldMovement(piece.isBlack, fromRow, fromCol, toRow, toCol);

      // 成香（香車の成り駒）- 金と同じ動き
      case PieceType.promotedLance:
        return _isGoldMovement(piece.isBlack, fromRow, fromCol, toRow, toCol);

      // 成桂（桂馬の成り駒）- 金と同じ動き
      case PieceType.promotedKnight:
        return _isGoldMovement(piece.isBlack, fromRow, fromCol, toRow, toCol);

      // 成銀（銀将の成り駒）- 金と同じ動き
      case PieceType.promotedSilver:
        return _isGoldMovement(piece.isBlack, fromRow, fromCol, toRow, toCol);

      // 龍王（飛車の成り駒）- 飛車 + 王の動き
      case PieceType.promotedRook:
        // 飛車の動き
        bool rooksMove =
            (toRow == fromRow || toCol == fromCol) &&
            isPathClear(board, fromIndex, toIndex);

        // 王の動き（隣接8マス）
        bool kingsMove =
            (toRow >= fromRow - 1 &&
                toRow <= fromRow + 1 &&
                toCol >= fromCol - 1 &&
                toCol <= fromCol + 1) &&
            !(toRow == fromRow && toCol == fromCol);

        return rooksMove || kingsMove;

      // 龍馬（角行の成り駒）- 角行 + 王の動き
      case PieceType.promotedBishop:
        // 角行の動き
        bool bishopsMove =
            (toRow - fromRow).abs() == (toCol - fromCol).abs() &&
            isPathClear(board, fromIndex, toIndex);

        // 王の動き（隣接8マス）
        bool kingsMove =
            (toRow >= fromRow - 1 &&
                toRow <= fromRow + 1 &&
                toCol >= fromCol - 1 &&
                toCol <= fromCol + 1) &&
            !(toRow == fromRow && toCol == fromCol);

        return bishopsMove || kingsMove;
    }
  }

  // 金将の動きをチェックするヘルパーメソッド（成り駒で共通）
  static bool _isGoldMovement(
    bool isBlack,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) {
    if (isBlack) {
      return (toRow == fromRow - 1 &&
              (toCol == fromCol - 1 ||
                  toCol == fromCol ||
                  toCol == fromCol + 1)) ||
          (toRow == fromRow &&
              (toCol == fromCol - 1 || toCol == fromCol + 1)) ||
          (toRow == fromRow + 1 && toCol == fromCol);
    } else {
      return (toRow == fromRow + 1 &&
              (toCol == fromCol - 1 ||
                  toCol == fromCol ||
                  toCol == fromCol + 1)) ||
          (toRow == fromRow &&
              (toCol == fromCol - 1 || toCol == fromCol + 1)) ||
          (toRow == fromRow - 1 && toCol == fromCol);
    }
  }

  // 駒の移動経路に他の駒がないかチェック
  static bool isPathClear(ShogiBoard board, int fromIndex, int toIndex) {
    final (fromRow, fromCol) = ShogiBoard.indexToPosition(fromIndex);
    final (toRow, toCol) = ShogiBoard.indexToPosition(toIndex);

    // 横方向の移動
    if (fromRow == toRow) {
      final step = toCol > fromCol ? 1 : -1;
      for (int col = fromCol + step; col != toCol; col += step) {
        final index = ShogiBoard.positionToIndex(fromRow, col);
        if (board.getPieceImagePath(index) != null) {
          return false;
        }
      }
      return true;
    }
    // 縦方向の移動
    else if (fromCol == toCol) {
      final step = toRow > fromRow ? 1 : -1;
      for (int row = fromRow + step; row != toRow; row += step) {
        final index = ShogiBoard.positionToIndex(row, fromCol);
        if (board.getPieceImagePath(index) != null) {
          return false;
        }
      }
      return true;
    }
    // 斜め方向の移動
    else if ((toRow - fromRow).abs() == (toCol - fromCol).abs()) {
      final rowStep = toRow > fromRow ? 1 : -1;
      final colStep = toCol > fromCol ? 1 : -1;
      int row = fromRow + rowStep;
      int col = fromCol + colStep;
      while (row != toRow && col != toCol) {
        final index = ShogiBoard.positionToIndex(row, col);
        if (board.getPieceImagePath(index) != null) {
          return false;
        }
        row += rowStep;
        col += colStep;
      }
      return true;
    }

    return false;
  }

  // 指定した駒の移動可能なマスの一覧を取得
  static List<int> getValidMoves(ShogiBoard board, int fromIndex) {
    List<int> validMoves = [];

    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      if (isValidMove(board, fromIndex, i)) {
        validMoves.add(i);
      }
    }

    return validMoves;
  }
}
