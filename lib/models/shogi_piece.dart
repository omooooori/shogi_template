
enum PieceColor { black, white }

enum PieceType {
  pawn,
  lance,
  knight,
  silver,
  gold,
  king,
  rook,
  bishop,
  // 成駒のタイプ
  promotedPawn, // と金
  promotedLance, // 成香
  promotedKnight, // 成桂
  promotedSilver, // 成銀
  promotedRook, // 龍王
  promotedBishop, // 龍馬
}

class ShogiPiece {
  final PieceType type;
  final PieceColor color;
  final String imagePath;
  final bool isPromoted; // 成り駒かどうか

  const ShogiPiece({
    required this.type,
    required this.color,
    required this.imagePath,
    this.isPromoted = false,
  });

  bool get isBlack => color == PieceColor.black;
  bool get isWhite => color == PieceColor.white;

  // 駒が成れるかどうか判定
  bool get canPromote {
    switch (type) {
      case PieceType.pawn:
      case PieceType.lance:
      case PieceType.knight:
      case PieceType.silver:
      case PieceType.bishop:
      case PieceType.rook:
        return !isPromoted; // すでに成っていなければ成れる
      default:
        return false; // 金・王は成れない、すでに成っている駒も成れない
    }
  }

  // 成った駒を返す
  ShogiPiece promote() {
    if (!canPromote) return this;

    PieceType promotedType;
    String promotedImagePath = imagePath.replaceAll(
      color == PieceColor.black ? 'black_' : 'white_',
      color == PieceColor.black ? 'black_prom_' : 'white_prom_',
    );

    switch (type) {
      case PieceType.pawn:
        promotedType = PieceType.promotedPawn;
        break;
      case PieceType.lance:
        promotedType = PieceType.promotedLance;
        break;
      case PieceType.knight:
        promotedType = PieceType.promotedKnight;
        break;
      case PieceType.silver:
        promotedType = PieceType.promotedSilver;
        break;
      case PieceType.rook:
        promotedType = PieceType.promotedRook;
        break;
      case PieceType.bishop:
        promotedType = PieceType.promotedBishop;
        break;
      default:
        return this;
    }

    return ShogiPiece(
      type: promotedType,
      color: color,
      imagePath: promotedImagePath,
      isPromoted: true,
    );
  }

  // 駒の種類に応じた文字列を返す
  String get typeName {
    switch (type) {
      case PieceType.pawn:
        return '歩';
      case PieceType.lance:
        return '香';
      case PieceType.knight:
        return '桂';
      case PieceType.silver:
        return '銀';
      case PieceType.gold:
        return '金';
      case PieceType.king:
        return color == PieceColor.black ? '玉' : '王';
      case PieceType.rook:
        return '飛';
      case PieceType.bishop:
        return '角';
      case PieceType.promotedPawn:
        return 'と';
      case PieceType.promotedLance:
        return '成香';
      case PieceType.promotedKnight:
        return '成桂';
      case PieceType.promotedSilver:
        return '成銀';
      case PieceType.promotedRook:
        return '龍';
      case PieceType.promotedBishop:
        return '馬';
    }
  }

  // 画像パスから駒のオブジェクトを作成する
  static ShogiPiece? fromImagePath(String imagePath) {
    if (imagePath.isEmpty) return null;

    PieceColor color;
    bool isPromoted = false;

    if (imagePath.contains('black')) {
      color = PieceColor.black;
    } else if (imagePath.contains('white')) {
      color = PieceColor.white;
    } else {
      return null;
    }

    // 成り駒のチェック
    if (imagePath.contains('prom_')) {
      isPromoted = true;
    }

    PieceType type;
    if (isPromoted) {
      if (imagePath.contains('pawn')) {
        type = PieceType.promotedPawn;
      } else if (imagePath.contains('lance')) {
        type = PieceType.promotedLance;
      } else if (imagePath.contains('knight')) {
        type = PieceType.promotedKnight;
      } else if (imagePath.contains('silver')) {
        type = PieceType.promotedSilver;
      } else if (imagePath.contains('rook')) {
        type = PieceType.promotedRook;
      } else if (imagePath.contains('bishop')) {
        type = PieceType.promotedBishop;
      } else {
        return null;
      }
    } else {
      if (imagePath.contains('pawn')) {
        type = PieceType.pawn;
      } else if (imagePath.contains('lance')) {
        type = PieceType.lance;
      } else if (imagePath.contains('knight')) {
        type = PieceType.knight;
      } else if (imagePath.contains('silver')) {
        type = PieceType.silver;
      } else if (imagePath.contains('gold')) {
        type = PieceType.gold;
      } else if (imagePath.contains('king')) {
        type = PieceType.king;
      } else if (imagePath.contains('rook')) {
        type = PieceType.rook;
      } else if (imagePath.contains('bishop')) {
        type = PieceType.bishop;
      } else {
        return null;
      }
    }

    return ShogiPiece(
      type: type,
      color: color,
      imagePath: imagePath,
      isPromoted: isPromoted,
    );
  }
}
