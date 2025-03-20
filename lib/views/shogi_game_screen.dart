import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../viewmodels/shogi_game_viewmodel.dart';
import '../models/shogi_piece.dart';
import 'widgets/shogi_board_widget.dart';
import 'widgets/captured_pieces_widget.dart';

class ShogiGameScreen extends StatelessWidget {
  const ShogiGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShogiGameViewModel(),
      child: const _ShogiGameScreenContent(),
    );
  }
}

class _ShogiGameScreenContent extends StatefulWidget {
  const _ShogiGameScreenContent();

  @override
  State<_ShogiGameScreenContent> createState() =>
      _ShogiGameScreenContentState();
}

class _ShogiGameScreenContentState extends State<_ShogiGameScreenContent> {
  StreamSubscription? _promotionSubscription;

  @override
  void initState() {
    super.initState();

    // 画面構築後に実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = Provider.of<ShogiGameViewModel>(context, listen: false);

      // 成り判定のストリームを購読
      _promotionSubscription = viewModel.promotionStream.listen((data) {
        if (!mounted) return;
        final (fromIndex, toIndex) = data;
        _showPromotionDialog(context, viewModel, fromIndex, toIndex);
      });
    });
  }

  @override
  void dispose() {
    _promotionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ShogiGameViewModel>(context);

    // ゲームが終了したら勝敗ダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.isGameOver) {
        _showGameResultDialog(context, viewModel);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // 背景と内容
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(viewModel.backgroundImagePath),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.matrix([
                  1.2, 0, 0, 0, 15, // 赤チャンネル: 明るさとコントラスト調整
                  0, 1.2, 0, 0, 15, // 緑チャンネル: 明るさとコントラスト調整
                  0, 0, 1.2, 0, 15, // 青チャンネル: 明るさとコントラスト調整
                  0, 0, 0, 1, 0, // アルファチャンネル: 変更なし
                ]),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // 相手（白）の持ち駒
                    const SizedBox(height: 8),
                    CapturedPiecesWidget(
                      capturedPieces: viewModel.whiteCapturedPieces,
                      selectedPiece: null, // コンピュータの持ち駒は選択できない
                      onSelectPiece: (_) {}, // 何もしない
                      isSelectable: false,
                      label: '相手の持ち駒',
                    ),

                    // ステータスの表示
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.brown[700]?.withAlpha(204),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        viewModel.isComputerThinking
                            ? 'コンピュータの思考中...'
                            : viewModel.isUserTurn
                            ? 'あなたの番です'
                            : 'コンピュータの番です',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // 将棋盤
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (
                          BuildContext context,
                          BoxConstraints constraints,
                        ) {
                          // 利用可能な幅と高さを取得
                          final availableWidth = constraints.maxWidth;
                          final availableHeight = constraints.maxHeight;

                          // 将棋盤のサイズを計算
                          final boardSize = math.min(
                            math.min(availableWidth, availableHeight * 0.8),
                            600.0,
                          );

                          return ShogiBoardWidget(
                            pieceImages: viewModel.pieceImages,
                            selectedPieceIndex: viewModel.selectedPieceIndex,
                            validMoves: viewModel.validMoves,
                            onTapCell: viewModel.selectOrMovePiece,
                            size: boardSize,
                            lastComputerMoveFrom:
                                viewModel.lastComputerMoveFrom,
                            lastComputerMoveTo: viewModel.lastComputerMoveTo,
                          );
                        },
                      ),
                    ),

                    // 自分（黒）の持ち駒
                    const SizedBox(height: 8),
                    CapturedPiecesWidget(
                      capturedPieces: viewModel.blackCapturedPieces,
                      selectedPiece: viewModel.selectedCapturedPiece,
                      onSelectPiece: viewModel.selectCapturedPiece,
                      isSelectable:
                          viewModel.isUserTurn && !viewModel.isComputerThinking,
                      label: 'あなたの持ち駒',
                    ),
                    const SizedBox(height: 80), // ボタン用のスペースを確保
                  ],
                ),
              ),
            ),
          ),

          // 操作ボタン（画面の最下部に固定）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0, // 端末の最下端に合わせる
            child: Container(
              decoration: BoxDecoration(
                color: Colors.brown[800],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Padding(
                // セーフエリアを考慮したパディングを適用
                padding: EdgeInsets.only(
                  top: 12.0,
                  left: 8.0,
                  right: 8.0,
                  bottom:
                      12.0 +
                      MediaQuery.of(context).padding.bottom, // セーフエリア分の余白を追加
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MaterialButton(
                      onPressed: viewModel.canUndo ? viewModel.undoMove : null,
                      disabledColor: Colors.grey[600],
                      color: Colors.brown[600],
                      textColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.undo, size: 24),
                            SizedBox(height: 4),
                            Text('待った', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    MaterialButton(
                      onPressed:
                          !viewModel.isComputerThinking
                              ? () => _showMenuDialog(context, viewModel)
                              : null,
                      disabledColor: Colors.grey[600],
                      color: Colors.brown[600],
                      textColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.menu, size: 24),
                            SizedBox(height: 4),
                            Text('メニュー', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // メニューダイアログを表示
  void _showMenuDialog(BuildContext context, ShogiGameViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('メニュー'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  viewModel.resetGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('リセット'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('キャンセル'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ゲーム結果ダイアログを表示
  void _showGameResultDialog(
    BuildContext context,
    ShogiGameViewModel viewModel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外をタップしても閉じない
      builder: (BuildContext context) {
        final isPlayerWon = viewModel.gameStatus == GameStatus.playerWon;

        return AlertDialog(
          title: Text(
            isPlayerWon ? '勝利！' : '敗北...',
            style: TextStyle(
              color: isPlayerWon ? Colors.orange[700] : Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlayerWon
                    ? Icons.emoji_events
                    : Icons.sentiment_very_dissatisfied,
                size: 64,
                color: isPlayerWon ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                isPlayerWon
                    ? '相手の王を取りました！\nおめでとうございます！'
                    : 'あなたの王が取られました...\nまた挑戦してください。',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('閉じる'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                viewModel.resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('新しいゲーム'),
            ),
          ],
        );
      },
    );
  }

  // 成り選択ダイアログを表示
  void _showPromotionDialog(
    BuildContext context,
    ShogiGameViewModel viewModel,
    int fromIndex,
    int toIndex,
  ) {
    // 移動する駒の情報を取得
    final pieceImagePath = viewModel.pieceImages[fromIndex];
    final piece = ShogiPiece.fromImagePath(pieceImagePath);
    if (piece == null) return;

    // 成った場合のプレビュー画像を取得
    final promotedPiece = piece.promote();

    showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外をタップしても閉じない
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('成りますか？'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 元の駒
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(piece.imagePath, width: 60, height: 60),
                  const SizedBox(height: 8),
                  Text('成らない（${piece.typeName}）'),
                ],
              ),

              const Icon(Icons.arrow_forward, size: 24),

              // 成り駒
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(promotedPiece.imagePath, width: 60, height: 60),
                  const SizedBox(height: 8),
                  Text('成る（${promotedPiece.typeName}）'),
                ],
              ),
            ],
          ),
          actions: [
            // 成らない選択
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                viewModel.confirmPromotion(fromIndex, toIndex, false);
              },
              child: const Text('成らない'),
            ),
            // 成る選択
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                viewModel.confirmPromotion(fromIndex, toIndex, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('成る'),
            ),
          ],
        );
      },
    );
  }
}
