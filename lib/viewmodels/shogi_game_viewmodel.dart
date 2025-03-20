import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/shogi_board.dart';
import '../models/shogi_piece.dart';
import '../utils/move_validator.dart';
import '../utils/ai_logic.dart';

// ゲームの状態を表す列挙型
enum GameStatus {
  playing, // ゲーム進行中
  playerWon, // プレイヤーの勝利
  computerWon, // コンピュータの勝利
  draw, // 引き分け（将棋では稀だが、実装のために追加）
}

class ShogiGameViewModel extends ChangeNotifier {
  // 将棋盤
  late ShogiBoard _board;

  // ゲームの状態
  final List<ShogiBoard> _boardHistory = [];

  int? _selectedPieceIndex;
  List<int> _validMoves = [];
  bool _isUserTurn = true;
  bool _isComputerThinking = false;
  late String _backgroundImagePath;

  // 持ち駒選択状態
  String? _selectedCapturedPiece;

  // 成り判定用のコントローラ
  final _promotionController = StreamController<(int, int)>.broadcast();

  // コンピューターの最後の移動を記録
  int? _lastComputerMoveFrom;
  int? _lastComputerMoveTo;
  Timer? _highlightTimer;

  // ゲームの勝敗状態
  GameStatus _gameStatus = GameStatus.playing;

  // コンストラクタ
  ShogiGameViewModel() {
    _board = ShogiBoard();
    _board.initialize();
    _selectRandomBackground();
  }

  // ゲッター
  List<String> get pieceImages => _board.toImagePathsList();
  int? get selectedPieceIndex => _selectedPieceIndex;
  List<int> get validMoves => _validMoves;
  bool get isUserTurn => _isUserTurn;
  bool get isComputerThinking => _isComputerThinking;
  String get backgroundImagePath => _backgroundImagePath;
  bool get canUndo =>
      _boardHistory.isNotEmpty && _isUserTurn && !_isComputerThinking;

  // コンピューターの最後の移動を取得
  int? get lastComputerMoveFrom => _lastComputerMoveFrom;
  int? get lastComputerMoveTo => _lastComputerMoveTo;

  // 成り判定のストリーム
  Stream<(int, int)> get promotionStream => _promotionController.stream;

  // ゲームの勝敗状態
  GameStatus get gameStatus => _gameStatus;
  bool get isGameOver => _gameStatus != GameStatus.playing;

  // 持ち駒の取得
  List<String> get blackCapturedPieces =>
      _board.getCapturedPieces(PieceColor.black);
  List<String> get whiteCapturedPieces =>
      _board.getCapturedPieces(PieceColor.white);
  String? get selectedCapturedPiece => _selectedCapturedPiece;

  // ランダムな背景画像を選択
  void _selectRandomBackground() {
    final random = math.Random();
    final backgrounds = [
      'assets/images/bg1.webp',
      'assets/images/bg2.webp',
      'assets/images/bg3.webp',
    ];
    _backgroundImagePath = backgrounds[random.nextInt(backgrounds.length)];
    notifyListeners();
  }

  // 持ち駒を選択
  void selectCapturedPiece(String piecePath) {
    // ゲームが終了しているか、コンピュータの思考中やコンピュータのターン中は操作できない
    if (isGameOver || _isComputerThinking || !_isUserTurn) return;

    // 盤上の駒の選択状態をリセット
    _selectedPieceIndex = null;

    // 持ち駒の選択状態を切り替え
    if (_selectedCapturedPiece == piecePath) {
      // 同じ持ち駒を再選択した場合は選択解除
      _selectedCapturedPiece = null;
      _validMoves = [];
    } else {
      // 黒駒（プレイヤー側）のみ選択可能
      if (piecePath.contains('black')) {
        _selectedCapturedPiece = piecePath;
        // 持ち駒が置ける場所を計算（空きマスすべて）
        _calculateDroppableSquares();
      }
    }

    notifyListeners();
  }

  // 持ち駒が置ける場所を計算
  void _calculateDroppableSquares() {
    _validMoves = [];

    // 選択された持ち駒の種類を特定
    final piece = ShogiPiece.fromImagePath(_selectedCapturedPiece!);
    if (piece == null) return;

    // 歩兵の場合の特別ルール
    if (piece.type == PieceType.pawn) {
      _calculatePawnDroppableSquares();
      return;
    }

    // 香車の場合の特別ルール
    if (piece.type == PieceType.lance) {
      _calculateLanceDroppableSquares();
      return;
    }

    // 桂馬の場合の特別ルール
    if (piece.type == PieceType.knight) {
      _calculateKnightDroppableSquares();
      return;
    }

    // その他の駒は基本的に空きマスすべてに置ける
    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      if (_board.getPieceImagePath(i) == null) {
        _validMoves.add(i);
      }
    }
  }

  // 歩兵が置ける場所を計算（二歩の禁止）
  void _calculatePawnDroppableSquares() {
    // 各列ごとに歩兵があるかをチェック
    List<bool> columnHasPawn = List.filled(ShogiBoard.boardSize, false);

    // 盤面上の自分の歩兵をチェック
    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      final piece = _board.getPieceImagePath(i);
      if (piece != null && piece.contains('black_pawn')) {
        // 同じ列に既に歩がある場合は記録
        final (_, col) = ShogiBoard.indexToPosition(i);
        columnHasPawn[col] = true;
      }
    }

    // 空きマスのうち、二歩にならないマスを計算
    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      if (_board.getPieceImagePath(i) == null) {
        final (row, col) = ShogiBoard.indexToPosition(i);

        // 二歩の確認：同じ列に既に歩があるマスには打てない
        if (columnHasPawn[col]) continue;

        // 最奥の段（相手の陣地の最前列）には打てない
        if (row == 0) continue;

        _validMoves.add(i);
      }
    }
  }

  // 香車が置ける場所を計算
  void _calculateLanceDroppableSquares() {
    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      if (_board.getPieceImagePath(i) == null) {
        final (row, _) = ShogiBoard.indexToPosition(i);

        // 香車は最奥の段には打てない（動けないため）
        if (row == 0) continue;

        _validMoves.add(i);
      }
    }
  }

  // 桂馬が置ける場所を計算
  void _calculateKnightDroppableSquares() {
    for (int i = 0; i < ShogiBoard.cellCount; i++) {
      if (_board.getPieceImagePath(i) == null) {
        final (row, _) = ShogiBoard.indexToPosition(i);

        // 桂馬は上から1段目と2段目には打てない（動けないため）
        if (row == 0 || row == 1) continue;

        _validMoves.add(i);
      }
    }
  }

  // 駒を選択または移動する
  void selectOrMovePiece(int index) {
    // ゲームが終了しているか、コンピュータの思考中やコンピュータのターン中は操作できない
    if (isGameOver || _isComputerThinking || !_isUserTurn) return;

    // 持ち駒が選択されている場合
    if (_selectedCapturedPiece != null) {
      // 持ち駒を盤上に打つ
      if (_validMoves.contains(index)) {
        // 現在の状態を保存
        _boardHistory.add(_board.copy());

        // 持ち駒を配置
        bool success = _board.dropCapturedPiece(_selectedCapturedPiece!, index);
        if (success) {
          // 選択をリセット
          _selectedCapturedPiece = null;
          _validMoves = [];

          // ユーザーのターン終了
          _isUserTurn = false;
          notifyListeners();

          // 少し遅延してコンピュータの手番を実行
          _executeComputerTurn();
          return;
        }
      }

      // 選択をリセット
      _selectedCapturedPiece = null;
      _validMoves = [];
      notifyListeners();
      return;
    }

    // 駒が選択されていない場合
    if (_selectedPieceIndex == null) {
      // 空のマスでなければ選択
      final piece = _board.getPieceImagePath(index);
      if (piece != null && piece.isNotEmpty) {
        // ユーザーは黒駒のみ選択可能
        if (!piece.contains('black')) return;

        _selectedPieceIndex = index;
        _calculateValidMoves(index);
        notifyListeners();
      }
    }
    // 駒が既に選択されている場合
    else {
      // 同じ駒を選んだ場合は選択解除
      if (_selectedPieceIndex == index) {
        _selectedPieceIndex = null;
        _validMoves = [];
        notifyListeners();
        return;
      }

      // 自分の駒（黒駒）を選んでいる場合は、選択を変更
      final piece = _board.getPieceImagePath(index);
      if (piece != null && piece.isNotEmpty && piece.contains('black')) {
        _selectedPieceIndex = index;
        _calculateValidMoves(index);
        notifyListeners();
        return;
      }

      // 駒の移動が有効かチェック
      if (_validMoves.contains(index)) {
        // 現在の状態を保存
        _boardHistory.add(_board.copy());

        // 移動前に成りの条件をチェック
        final movingPiecePath = _board.getPieceImagePath(_selectedPieceIndex!);
        if (movingPiecePath != null) {
          final piece = ShogiPiece.fromImagePath(movingPiecePath);
          if (piece != null && piece.canPromote) {
            final (fromRow, _) = ShogiBoard.indexToPosition(
              _selectedPieceIndex!,
            );
            final (toRow, _) = ShogiBoard.indexToPosition(index);

            // 成りの条件チェック：相手の陣地に入るか、既に陣地内にいる駒が移動する
            bool isInPromotionZone = false;

            // 黒駒は上位3段が相手陣地
            if (piece.isBlack && (toRow < 3 || fromRow < 3)) {
              isInPromotionZone = true;
            }

            if (isInPromotionZone) {
              // 必ず成らなければならない場合（最奥への歩・香・桂の移動）
              bool mustPromote = false;

              // 歩・香が最奥の段に進んだ場合
              if ((piece.type == PieceType.pawn ||
                      piece.type == PieceType.lance) &&
                  piece.isBlack &&
                  toRow == 0) {
                mustPromote = true;
              }
              // 桂馬が奥から2段目までに進んだ場合
              else if (piece.type == PieceType.knight &&
                  piece.isBlack &&
                  toRow <= 1) {
                mustPromote = true;
              }

              if (mustPromote) {
                // 必ず成る場合は直接成り駒にして移動
                final promotedPiece = piece.promote();
                _board.setPiece(_selectedPieceIndex!, null);
                _board.setPiece(index, promotedPiece.imagePath);

                // 王を取った場合の確認
                final capturedPiece = _board.getPieceImagePath(index);
                if (capturedPiece != null && capturedPiece.contains('king')) {
                  _gameStatus = GameStatus.playerWon;
                }
              } else {
                // 成るか成らないか選択可能な場合はストリームで通知
                _promotionController.add((_selectedPieceIndex!, index));

                // 選択されるまでここで保留
                return;
              }
            } else {
              // 成りの条件を満たさない場合は通常の移動
              bool capturedKing = _board.movePiece(_selectedPieceIndex!, index);

              // 王を取った場合は勝利
              if (capturedKing) {
                _gameStatus = GameStatus.playerWon;
              }
            }
          } else {
            // 成れない駒の場合は通常の移動
            bool capturedKing = _board.movePiece(_selectedPieceIndex!, index);

            // 王を取った場合は勝利
            if (capturedKing) {
              _gameStatus = GameStatus.playerWon;
            }
          }
        }

        // 選択をリセット
        _selectedPieceIndex = null;
        _validMoves = [];

        // 勝利判定
        if (_gameStatus == GameStatus.playerWon) {
          notifyListeners();
          return;
        }

        // ユーザーのターン終了
        _isUserTurn = false;
        notifyListeners();

        // 少し遅延してコンピュータの手番を実行
        _executeComputerTurn();
      } else {
        // 選択をリセット
        _selectedPieceIndex = null;
        _validMoves = [];
        notifyListeners();
      }
    }
  }

  // 選択された駒の移動可能なマスを計算
  void _calculateValidMoves(int fromIndex) {
    _validMoves = MoveValidator.getValidMoves(_board, fromIndex);
  }

  // 一手前に戻す（待った）
  void undoMove() {
    if (_boardHistory.isNotEmpty &&
        _isUserTurn &&
        !_isComputerThinking &&
        !isGameOver) {
      _board = _boardHistory.removeLast();
      _selectedPieceIndex = null;
      _selectedCapturedPiece = null;
      _validMoves = [];

      // ゲームが終了していた場合は、プレイ中に戻す
      if (_gameStatus != GameStatus.playing) {
        _gameStatus = GameStatus.playing;
      }

      notifyListeners();
    }
  }

  // ゲームをリセットする
  void resetGame() {
    _board.initialize();
    _selectedPieceIndex = null;
    _selectedCapturedPiece = null;
    _validMoves = [];
    _boardHistory.clear();
    _isUserTurn = true;
    _isComputerThinking = false;
    _gameStatus = GameStatus.playing;

    // ハイライトをクリア
    _lastComputerMoveFrom = null;
    _lastComputerMoveTo = null;
    _highlightTimer?.cancel();

    _selectRandomBackground();
    notifyListeners();
  }

  // コンピュータの手番を実行
  void _executeComputerTurn() {
    _isComputerThinking = true;
    notifyListeners();

    // 少し遅延してコンピュータの動きを実行（思考中の演出）
    Timer(Duration(milliseconds: 800), () {
      _makeComputerMove();
    });
  }

  // コンピュータの移動を計算して実行
  void _makeComputerMove() {
    // ゲームが終了している場合は何もしない
    if (isGameOver) {
      _isComputerThinking = false;
      notifyListeners();
      return;
    }

    // 現在の状態を保存（コンピュータの手の前の状態として）
    _boardHistory.add(_board.copy());

    // 前回のハイライトをクリア
    _lastComputerMoveFrom = null;
    _lastComputerMoveTo = null;
    _highlightTimer?.cancel();

    // AIを使用して最善手を計算
    final (fromIndex, toIndex, piecePath) = AILogic.findBestMove(
      _board,
      PieceColor.white,
    );

    // 有効な手が見つからなかった場合
    if (fromIndex == -1 && toIndex == -1) {
      // コンピュータが何も動かせない場合は、履歴から直前の状態を削除
      if (_boardHistory.isNotEmpty) {
        _boardHistory.removeLast();
      }

      _isComputerThinking = false;
      _isUserTurn = true;
      notifyListeners();
      return;
    }

    bool capturedKing = false;

    // 移動を記録（持ち駒の場合は-1）
    _lastComputerMoveFrom = fromIndex;
    _lastComputerMoveTo = toIndex;

    // 持ち駒を打つ場合
    if (fromIndex == -1 && piecePath != null) {
      _board.dropCapturedPiece(piecePath, toIndex);
    }
    // 通常の駒移動
    else if (fromIndex >= 0 && toIndex >= 0) {
      // 駒を移動（王を取った場合はtrueが返る）
      capturedKing = _board.movePiece(fromIndex, toIndex);
    }

    // 王を取った場合はコンピュータの勝利
    if (capturedKing) {
      _gameStatus = GameStatus.computerWon;
      _isComputerThinking = false;
      notifyListeners();
      return;
    }

    // コンピュータのターン終了
    _isComputerThinking = false;
    _isUserTurn = true;
    notifyListeners();

    // 一定時間後にハイライトを消す（3秒後）
    _highlightTimer = Timer(Duration(seconds: 3), () {
      _lastComputerMoveFrom = null;
      _lastComputerMoveTo = null;
      notifyListeners();
    });
  }

  // 成りを確定する
  void confirmPromotion(int fromIndex, int toIndex, bool promote) {
    final piece = ShogiPiece.fromImagePath(
      _board.getPieceImagePath(fromIndex)!,
    );
    if (piece == null) return;

    String newPiecePath;
    if (promote) {
      // 成る場合
      newPiecePath = piece.promote().imagePath;
    } else {
      // 成らない場合
      newPiecePath = piece.imagePath;
    }

    // 移動先の駒を記録（キャプチャー判定用）
    final capturedPiecePath = _board.getPieceImagePath(toIndex);

    // 移動元の駒を削除し、新しい駒を配置
    _board.setPiece(fromIndex, null);
    _board.setPiece(toIndex, newPiecePath);

    // 持ち駒の処理
    if (capturedPiecePath != null) {
      // 持ち駒の追加処理（既存のコードと同様）
      String convertedPiece;
      if (capturedPiecePath.contains('black')) {
        convertedPiece = capturedPiecePath.replaceAll('black', 'white');
      } else {
        convertedPiece = capturedPiecePath.replaceAll('white', 'black');
      }

      // 成り駒の場合は、元の駒に戻す
      if (convertedPiece.contains('prom_')) {
        convertedPiece = convertedPiece.replaceAll('prom_', '');
      }

      // 持ち駒リストに追加
      _board.addCapturedPiece(PieceColor.black, convertedPiece);

      // 王を取った場合は勝利
      if (capturedPiecePath.contains('king')) {
        _gameStatus = GameStatus.playerWon;
        notifyListeners();
        return;
      }
    }

    // 選択をリセット
    _selectedPieceIndex = null;
    _validMoves = [];

    // ユーザーのターン終了
    _isUserTurn = false;
    notifyListeners();

    // 少し遅延してコンピュータの手番を実行
    _executeComputerTurn();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _promotionController.close();
    super.dispose();
  }
}
