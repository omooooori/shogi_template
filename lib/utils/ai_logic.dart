import 'dart:math' as math;

import '../models/shogi_board.dart';
import '../models/shogi_piece.dart';
import 'move_validator.dart';

// 移動候補と評価値のペア
class MoveCandidate {
  final int fromIndex; // 移動元（持ち駒の場合は-1）
  final int toIndex; // 移動先
  final String? piece; // 持ち駒の場合は駒の種類、盤上の駒の場合はnull
  final int score; // 評価値

  MoveCandidate({
    required this.fromIndex,
    required this.toIndex,
    this.piece,
    required this.score,
  });
}

class AILogic {
  // 駒の価値（一般的な将棋の駒の価値を簡略化したもの）
  static const Map<PieceType, int> pieceValues = {
    PieceType.pawn: 1, // 歩兵
    PieceType.lance: 3, // 香車
    PieceType.knight: 4, // 桂馬
    PieceType.silver: 5, // 銀将
    PieceType.gold: 6, // 金将
    PieceType.bishop: 8, // 角行
    PieceType.rook: 10, // 飛車
    PieceType.king: 100, // 王将/玉将
    // 成り駒の価値
    PieceType.promotedPawn: 6, // と金（≒金）
    PieceType.promotedLance: 6, // 成香（≒金）
    PieceType.promotedKnight: 6, // 成桂（≒金）
    PieceType.promotedSilver: 6, // 成銀（≒金）
    PieceType.promotedBishop: 12, // 龍馬（角行の価値+4）
    PieceType.promotedRook: 14, // 龍王（飛車の価値+4）
  };

  // 最善手を見つける
  static (int fromIndex, int toIndex, String? piece) findBestMove(
    ShogiBoard board,
    PieceColor color,
  ) {
    // すべての可能な手と評価値を計算
    List<MoveCandidate> candidates = [];

    // 1. 盤上の駒の移動による手を検討
    final pieces = board.getPieces(color: color);
    for (final (pieceIndex, _) in pieces) {
      // 駒の移動可能なマスを取得
      final validMoves = MoveValidator.getValidMoves(board, pieceIndex);

      // 各移動先を評価
      for (final toIndex in validMoves) {
        final score = _evaluateMove(board, pieceIndex, toIndex);
        candidates.add(
          MoveCandidate(
            fromIndex: pieceIndex,
            toIndex: toIndex,
            piece: null,
            score: score,
          ),
        );
      }
    }

    // 2. 持ち駒を打つ手を検討
    final capturedPieces = board.getCapturedPieces(color);
    for (final piecePath in capturedPieces) {
      // 駒の種類を取得
      final piece = ShogiPiece.fromImagePath(piecePath);
      if (piece == null) continue;

      // その駒が打てる場所を検討
      for (int i = 0; i < ShogiBoard.cellCount; i++) {
        // 空マスかどうか、および駒の種類に応じた打ち込み制限を考慮
        if (_canDropPiece(board, piece, i)) {
          // 打ち駒の評価（打ち駒は基本的に駒を取る手より価値が低い）
          final score = _evaluateDropPiece(board, piece, i);
          candidates.add(
            MoveCandidate(
              fromIndex: -1, // 持ち駒からの手は-1とする
              toIndex: i,
              piece: piecePath,
              score: score,
            ),
          );
        }
      }
    }

    // 候補がない場合はランダムな手を返す（ほぼありえないが、安全のため）
    if (candidates.isEmpty) {
      return _getRandomMove(board, color);
    }

    // スコアでソートして最善手を選択（複数ある場合はランダム）
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 最高スコアの手をすべて抽出
    final highestScore = candidates.first.score;
    final bestCandidates =
        candidates.where((c) => c.score == highestScore).toList();

    // 最善手からランダムに1つ選択（同じ評価値の手が複数ある場合）
    final random = math.Random();
    final selected = bestCandidates[random.nextInt(bestCandidates.length)];

    return (selected.fromIndex, selected.toIndex, selected.piece);
  }

  // 駒打ちが可能かチェック（二歩や打ち込み制限を考慮）
  static bool _canDropPiece(ShogiBoard board, ShogiPiece piece, int toIndex) {
    // 空マスでなければ打てない
    if (board.getPieceImagePath(toIndex) != null) return false;

    // 行と列の計算
    final (row, col) = ShogiBoard.indexToPosition(toIndex);

    // 歩兵の場合、二歩のチェック
    if (piece.type == PieceType.pawn) {
      // 同じ列に自分の歩兵があるかチェック
      for (int r = 0; r < ShogiBoard.boardSize; r++) {
        int checkIndex = ShogiBoard.positionToIndex(r, col);
        final checkPiece = board.getPieceImagePath(checkIndex);
        if (checkPiece != null &&
            ((piece.isBlack && checkPiece.contains('black_pawn')) ||
                (piece.isWhite && checkPiece.contains('white_pawn')))) {
          return false; // 二歩になるので打てない
        }
      }

      // 歩兵は相手の最前列には打てない
      if ((piece.isBlack && row == 0) ||
          (piece.isWhite && row == ShogiBoard.boardSize - 1)) {
        return false;
      }
    }

    // 香車の場合、相手の最前列には打てない
    if (piece.type == PieceType.lance) {
      if ((piece.isBlack && row == 0) ||
          (piece.isWhite && row == ShogiBoard.boardSize - 1)) {
        return false;
      }
    }

    // 桂馬の場合、相手の最前列と2列目には打てない
    if (piece.type == PieceType.knight) {
      if ((piece.isBlack && (row == 0 || row == 1)) ||
          (piece.isWhite &&
              (row == ShogiBoard.boardSize - 1 ||
                  row == ShogiBoard.boardSize - 2))) {
        return false;
      }
    }

    return true;
  }

  // 移動の評価（スコアが高いほど良い手）
  static int _evaluateMove(ShogiBoard board, int fromIndex, int toIndex) {
    int score = 0;

    // 移動元の駒を取得
    final movingPiecePath = board.getPieceImagePath(fromIndex);
    if (movingPiecePath == null) return -100; // ありえないケース

    // 移動先の駒を取得（あれば）
    final targetPiecePath = board.getPieceImagePath(toIndex);

    // 移動先に相手の駒があれば、その価値を評価に加える
    if (targetPiecePath != null) {
      final targetPiece = ShogiPiece.fromImagePath(targetPiecePath);
      if (targetPiece != null) {
        // 相手の王を取る手は最高評価
        if (targetPiece.type == PieceType.king) {
          return 1000; // 王を取る手は最優先
        }

        // それ以外の駒を取る手は駒の価値に応じて評価
        score += pieceValues[targetPiece.type] ?? 0;
      }
    }

    // 盤面の中央に向かう手を少し高く評価
    final (fromRow, fromCol) = ShogiBoard.indexToPosition(fromIndex);
    final (toRow, toCol) = ShogiBoard.indexToPosition(toIndex);

    // 中央に近づくほど評価が高くなる
    final centerRow = ShogiBoard.boardSize ~/ 2;
    final centerCol = ShogiBoard.boardSize ~/ 2;

    // 中央との距離の差（マイナスなら中央に近づいている）
    final rowDistanceDiff =
        (fromRow - centerRow).abs() - (toRow - centerRow).abs();
    final colDistanceDiff =
        (fromCol - centerCol).abs() - (toCol - centerCol).abs();

    // 中央に近づく手にボーナス
    score += (rowDistanceDiff + colDistanceDiff);

    // 相手の陣地に進む手を評価
    final movingPiece = ShogiPiece.fromImagePath(movingPiecePath);
    if (movingPiece != null) {
      if (movingPiece.isBlack && toRow < 3) {
        // 黒駒が上部へ進出
        score += 3 - toRow; // 進出度合いに応じてスコア加算
      } else if (movingPiece.isWhite && toRow > 5) {
        // 白駒が下部へ進出
        score += toRow - 5; // 進出度合いに応じてスコア加算
      }
    }

    return score;
  }

  // 持ち駒を打つ手の評価
  static int _evaluateDropPiece(
    ShogiBoard board,
    ShogiPiece piece,
    int toIndex,
  ) {
    int score = 0;

    // 持ち駒の基本評価値（打ち込む価値）
    score += pieceValues[piece.type]! ~/ 2; // 通常の駒価値の半分

    // 行と列の計算
    final (row, col) = ShogiBoard.indexToPosition(toIndex);

    // 盤面中央への打ち込みを評価
    final centerRow = ShogiBoard.boardSize ~/ 2;
    final centerCol = ShogiBoard.boardSize ~/ 2;

    // 中央との距離（小さいほど中央に近い）
    final rowDistance = (row - centerRow).abs();
    final colDistance = (col - centerCol).abs();

    // 中央に近いほど高評価
    score += 4 - math.min(4, rowDistance + colDistance);

    // 相手の陣地への打ち込みを評価
    if (piece.isBlack && row < 3) {
      // 黒駒を上部へ
      score += 3 - row; // 奥にあるほど高評価

      // 金や銀を相手陣地に打ち込むのはさらに良い
      if (piece.type == PieceType.gold || piece.type == PieceType.silver) {
        score += 2;
      }
    } else if (piece.isWhite && row > 5) {
      // 白駒を下部へ
      score += row - 5; // 奥にあるほど高評価

      // 金や銀を相手陣地に打ち込むのはさらに良い
      if (piece.type == PieceType.gold || piece.type == PieceType.silver) {
        score += 2;
      }
    }

    return score;
  }

  // ランダムな手を生成（候補がない場合の緊急用）
  static (int fromIndex, int toIndex, String? piece) _getRandomMove(
    ShogiBoard board,
    PieceColor color,
  ) {
    final random = math.Random();

    // 盤上の駒の移動を試みる
    final pieces = board.getPieces(color: color);
    if (pieces.isNotEmpty) {
      for (int attempt = 0; attempt < 10; attempt++) {
        // ランダムに駒を選択
        final (pieceIndex, _) = pieces[random.nextInt(pieces.length)];

        // 移動可能なマスを取得
        final validMoves = MoveValidator.getValidMoves(board, pieceIndex);
        if (validMoves.isNotEmpty) {
          // ランダムに移動先を選択
          final toIndex = validMoves[random.nextInt(validMoves.length)];
          return (pieceIndex, toIndex, null);
        }
      }
    }

    // 持ち駒を打つ手を試みる
    final capturedPieces = board.getCapturedPieces(color);
    if (capturedPieces.isNotEmpty) {
      // ランダムに持ち駒を選択
      final piecePath = capturedPieces[random.nextInt(capturedPieces.length)];

      // ランダムな空きマスを探す
      List<int> emptySquares = [];
      for (int i = 0; i < ShogiBoard.cellCount; i++) {
        if (board.getPieceImagePath(i) == null) {
          emptySquares.add(i);
        }
      }

      if (emptySquares.isNotEmpty) {
        return (
          -1,
          emptySquares[random.nextInt(emptySquares.length)],
          piecePath,
        );
      }
    }

    // 最終手段：何も動かせない場合
    return (-1, -1, null);
  }
}
