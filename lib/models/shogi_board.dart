import 'shogi_piece.dart';

class ShogiBoard {
  // 9x9の将棋盤
  static const int boardSize = 9;
  static const int cellCount = boardSize * boardSize;

  // 盤面の状態（空の場合はnull）
  final List<String?> _board;

  // 持ち駒（キャプチャした駒）
  final Map<PieceColor, List<String>> _capturedPieces = {
    PieceColor.black: [],
    PieceColor.white: [],
  };

  ShogiBoard() : _board = List.filled(cellCount, null);

  ShogiBoard.fromImagePaths(List<String> imagePaths)
    : _board = List.generate(
        cellCount,
        (index) => imagePaths[index].isEmpty ? null : imagePaths[index],
      );

  // 新しいボードを作成（ディープコピー）
  ShogiBoard copy() {
    final newBoard = ShogiBoard();
    // 盤面のコピー
    for (int i = 0; i < cellCount; i++) {
      newBoard._board[i] = _board[i];
    }
    // 持ち駒のコピー
    newBoard._capturedPieces[PieceColor.black] = List.from(
      _capturedPieces[PieceColor.black]!,
    );
    newBoard._capturedPieces[PieceColor.white] = List.from(
      _capturedPieces[PieceColor.white]!,
    );
    return newBoard;
  }

  // インデックスから行と列を計算
  static (int row, int col) indexToPosition(int index) {
    return (index ~/ boardSize, index % boardSize);
  }

  // 行と列からインデックスを計算
  static int positionToIndex(int row, int col) {
    return row * boardSize + col;
  }

  // 特定のマスの駒を取得
  String? getPieceImagePath(int index) {
    if (index < 0 || index >= cellCount) return null;
    return _board[index];
  }

  // 特定のマスに駒を配置
  void setPiece(int index, String? imagePath) {
    if (index < 0 || index >= cellCount) return;
    _board[index] = imagePath;
  }

  // 駒を移動（駒を取る場合は持ち駒に追加）
  // 相手の王を取った場合はtrueを返す
  bool movePiece(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= cellCount ||
        toIndex < 0 ||
        toIndex >= cellCount) {
      return false;
    }

    final movingPiece = _board[fromIndex];
    if (movingPiece == null) {
      return false;
    }

    bool capturedKing = false;

    // 移動先に駒があれば取る（持ち駒に追加）
    final capturedPiece = _board[toIndex];
    if (capturedPiece != null) {
      final movingPieceColor =
          movingPiece.contains('black') ? PieceColor.black : PieceColor.white;

      // 王を取ったかどうかチェック
      if (capturedPiece.contains('king')) {
        capturedKing = true;
      }

      // 駒の向きを変える（白→黒、黒→白）
      String convertedPiece;
      if (capturedPiece.contains('black')) {
        // 黒駒を取った場合は白駒に変換
        convertedPiece = capturedPiece.replaceAll('black', 'white');
      } else {
        // 白駒を取った場合は黒駒に変換
        convertedPiece = capturedPiece.replaceAll('white', 'black');
      }

      // 成り駒の場合は、元の駒に戻す（持ち駒は成っていない状態になる）
      if (convertedPiece.contains('prom_')) {
        convertedPiece = convertedPiece.replaceAll('prom_', '');
      }

      _capturedPieces[movingPieceColor]!.add(convertedPiece);
    }

    // 駒を移動
    String pieceToPlace = movingPiece;

    // 成りの処理：駒が相手の陣地に入った場合や、すでに相手の陣地にある場合
    final piece = ShogiPiece.fromImagePath(movingPiece);
    if (piece != null && piece.canPromote) {
      final (fromRow, _) = indexToPosition(fromIndex);
      final (toRow, _) = indexToPosition(toIndex);

      // 黒駒が上位3段（相手陣地）に入った、または既にある場合
      bool isInPromotionZone = false;
      if (piece.isBlack && (toRow < 3 || fromRow < 3)) {
        isInPromotionZone = true;
      }
      // 白駒が下位3段（相手陣地）に入った、または既にある場合
      else if (piece.isWhite && (toRow > 5 || fromRow > 5)) {
        isInPromotionZone = true;
      }

      // 成りの条件を満たす場合
      if (isInPromotionZone) {
        // 自動的に成る条件: 歩・香・桂が動けなくなる場所に移動する場合
        bool mustPromote = false;

        // 歩・香が最奥の段に進んだ場合
        if ((piece.type == PieceType.pawn || piece.type == PieceType.lance) &&
            ((piece.isBlack && toRow == 0) ||
                (piece.isWhite && toRow == boardSize - 1))) {
          mustPromote = true;
        }
        // 桂馬が奥から2段目までに進んだ場合
        else if (piece.type == PieceType.knight &&
            ((piece.isBlack && toRow <= 1) ||
                (piece.isWhite && toRow >= boardSize - 2))) {
          mustPromote = true;
        }

        if (mustPromote) {
          // 成り駒に変換
          final promotedPiece = piece.promote();
          pieceToPlace = promotedPiece.imagePath;
        }
      }
    }

    _board[toIndex] = pieceToPlace;
    _board[fromIndex] = null;

    return capturedKing;
  }

  // 持ち駒を盤上に打つ
  bool dropCapturedPiece(String piecePath, int toIndex) {
    if (toIndex < 0 || toIndex >= cellCount) return false;
    if (_board[toIndex] != null) return false; // 既に駒がある場所には打てない

    final pieceColor =
        piecePath.contains('black') ? PieceColor.black : PieceColor.white;
    final capturedPieces = _capturedPieces[pieceColor]!;

    // 持ち駒リストから該当する駒を探す
    final pieceIndex = capturedPieces.indexWhere((piece) => piece == piecePath);
    if (pieceIndex == -1) return false; // 持ち駒に該当する駒がない

    // 駒のタイプを取得
    final piece = ShogiPiece.fromImagePath(piecePath);
    if (piece == null) return false;

    // 行と列を計算
    final (row, col) = indexToPosition(toIndex);

    // 歩兵の場合、二歩のチェック
    if (piece.type == PieceType.pawn) {
      // 同じ列に自分の歩兵があるかチェック
      for (int r = 0; r < boardSize; r++) {
        int checkIndex = positionToIndex(r, col);
        final checkPiece = _board[checkIndex];
        if (checkPiece != null &&
            ((piece.isBlack && checkPiece.contains('black_pawn')) ||
                (piece.isWhite && checkPiece.contains('white_pawn')))) {
          return false; // 二歩になるので打てない
        }
      }

      // 歩兵は相手の最前列には打てない
      if ((piece.isBlack && row == 0) ||
          (piece.isWhite && row == boardSize - 1)) {
        return false;
      }
    }

    // 香車の場合、相手の最前列には打てない
    if (piece.type == PieceType.lance) {
      if ((piece.isBlack && row == 0) ||
          (piece.isWhite && row == boardSize - 1)) {
        return false;
      }
    }

    // 桂馬の場合、相手の最前列と2列目には打てない
    if (piece.type == PieceType.knight) {
      if ((piece.isBlack && (row == 0 || row == 1)) ||
          (piece.isWhite && (row == boardSize - 1 || row == boardSize - 2))) {
        return false;
      }
    }

    // 持ち駒を盤上に配置
    _board[toIndex] = piecePath;
    // 持ち駒リストから削除
    capturedPieces.removeAt(pieceIndex);

    return true;
  }

  // 駒のリストを取得
  List<(int index, String imagePath)> getPieces({PieceColor? color}) {
    List<(int index, String imagePath)> pieces = [];

    for (int i = 0; i < cellCount; i++) {
      if (_board[i] == null) continue;

      final imagePath = _board[i]!;

      if (color == null ||
          (color == PieceColor.black && imagePath.contains('black')) ||
          (color == PieceColor.white && imagePath.contains('white'))) {
        pieces.add((i, imagePath));
      }
    }

    return pieces;
  }

  // 持ち駒のリストを取得
  List<String> getCapturedPieces(PieceColor color) {
    return List.from(_capturedPieces[color]!);
  }

  // 持ち駒を追加
  void addCapturedPiece(PieceColor color, String piecePath) {
    _capturedPieces[color]!.add(piecePath);
  }

  // 初期配置に戻す
  void initialize() {
    // 盤面をクリア
    for (int i = 0; i < cellCount; i++) {
      _board[i] = null;
    }

    // 持ち駒をクリア
    _capturedPieces[PieceColor.black]!.clear();
    _capturedPieces[PieceColor.white]!.clear();

    // 白駒（上側）の配置
    _board[0] = 'assets/koma/white_lance.png';
    _board[1] = 'assets/koma/white_knight.png';
    _board[2] = 'assets/koma/white_silver.png';
    _board[3] = 'assets/koma/white_gold.png';
    _board[4] = 'assets/koma/white_king.png';
    _board[5] = 'assets/koma/white_gold.png';
    _board[6] = 'assets/koma/white_silver.png';
    _board[7] = 'assets/koma/white_knight.png';
    _board[8] = 'assets/koma/white_lance.png';
    _board[10] = 'assets/koma/white_bishop.png';
    _board[16] = 'assets/koma/white_rook.png';

    // 白の歩兵
    for (int i = 0; i < boardSize; i++) {
      _board[positionToIndex(2, i)] = 'assets/koma/white_pawn.png';
    }

    // 黒駒（下側）の配置
    final lastRow = boardSize - 1;
    _board[positionToIndex(lastRow, 0)] = 'assets/koma/black_lance.png';
    _board[positionToIndex(lastRow, 1)] = 'assets/koma/black_knight.png';
    _board[positionToIndex(lastRow, 2)] = 'assets/koma/black_silver.png';
    _board[positionToIndex(lastRow, 3)] = 'assets/koma/black_gold.png';
    _board[positionToIndex(lastRow, 4)] = 'assets/koma/black_king.png';
    _board[positionToIndex(lastRow, 5)] = 'assets/koma/black_gold.png';
    _board[positionToIndex(lastRow, 6)] = 'assets/koma/black_silver.png';
    _board[positionToIndex(lastRow, 7)] = 'assets/koma/black_knight.png';
    _board[positionToIndex(lastRow, 8)] = 'assets/koma/black_lance.png';
    _board[positionToIndex(lastRow - 1, 1)] = 'assets/koma/black_bishop.png';
    _board[positionToIndex(lastRow - 1, 7)] = 'assets/koma/black_rook.png';

    // 黒の歩兵
    for (int i = 0; i < boardSize; i++) {
      _board[positionToIndex(lastRow - 2, i)] = 'assets/koma/black_pawn.png';
    }
  }

  // 盤面の状態をリストとして取得
  List<String> toImagePathsList() {
    return _board.map((piece) => piece ?? '').toList();
  }
}
