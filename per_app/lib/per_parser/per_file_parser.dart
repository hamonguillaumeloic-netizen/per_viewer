import 'dart:io';
import 'dart:typed_data';
import 'binary_reader.dart';

class PerSignal {
  final String name;
  final List<double> values;
  PerSignal(this.name, this.values);
}

class PerFile {
  final double periodSeconds;
  final List<PerSignal> signals;
  final int nbRecData;
  PerFile(this.periodSeconds, this.signals, this.nbRecData);
}

class HeaderInfo {
  int nbvar = 0;
  int nbrec = 0;
  int perPeriod = 0;
  int nbDaughter = 0;
  int nbrecFile = 0;
}

class VarInfo {
  String mnemo = '';
  int enreg = 0;
  int valide = 0;
  String vType = '';
  int index = 0;
  String k = '';
  String kPrime = '';
}

class PerFileParser {
  static Map<String, dynamic> diagnoseHeader(Uint8List bytes) {
    final magicCheck = peekMagic(bytes);
    final reader = BinaryReader(bytes);

    HeaderInfo header;
    String perType;

    if (magicCheck == 'PER2') {
      perType = 'PER2';
      header = readHeaderPER2(reader);
    } else if (magicCheck == 'PER3') {
      perType = 'PER3';
      header = readHeaderPER3(reader);
    } else {
      return {
        'magic': magicCheck,
        'error': 'Format non reconnu',
      };
    }

    return {
      'magic': magicCheck,
      'perType': perType,
      'nbvar': header.nbvar,
      'nbrec': header.nbrec,
      'perPeriod': header.perPeriod,
      'nbDaughter': header.nbDaughter,
      'nbrecFile': header.nbrecFile,
      'positionApresHeader': reader.position,
      'tailleFichier': bytes.length,
    };
  }

  static Future<PerFile> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes);
  }

  static PerFile parseBytes(Uint8List bytes) {
    final magicCheck = peekMagic(bytes);

    final reader = BinaryReader(bytes);

    HeaderInfo header;
    String perType;

    if (magicCheck == 'PER2') {
      perType = 'PER2';
      header = readHeaderPER2(reader);
    } else if (magicCheck == 'PER3') {
      perType = 'PER3';
      header = readHeaderPER3(reader);
    } else {
      throw FormatException(
          "Format non reconnu (magic='$magicCheck'). Fichier .per attendu.");
    }

    final int nbRecData =
        (header.nbDaughter > 0 && header.nbrecFile > 0)
            ? header.nbrecFile
            : header.nbrec;

    final List<PerSignal> signals = [];

    for (int iVar = 1; iVar <= header.nbvar; iVar++) {
      final v = perType == 'PER2' ? readCfgVar2(reader) : readCfgVar3(reader);

      final typeChar = v.vType.isNotEmpty ? v.vType[0] : '?';

      if (v.enreg == 1) {
        List<double> buf;
        switch (typeChar) {
          case 'R':
            buf = reader.readSingleArray(nbRecData);
            break;
          case 'L':
          case 'B':
          case 'S':
            buf = reader.readLongArray(nbRecData);
            break;
          case 'D':
            buf = reader.readDoubleArray(nbRecData);
            break;
          default:
            throw FormatException(
                "Type de variable inconnu : '$typeChar' (variable n°$iVar, mnemo='${v.mnemo}')");
        }

        if (v.valide >= 1) {
          final reordered = List<double>.filled(nbRecData, 0.0);
          for (int k = 0; k < nbRecData; k++) {
            reordered[k] = buf[(v.index + k) % nbRecData];
          }
          signals.add(PerSignal(buildVarName(v.k, v.kPrime, v.mnemo), reordered));
        }
      } else {
        switch (typeChar) {
          case 'R':
            reader.readSingleArray(nbRecData);
            break;
          case 'L':
          case 'B':
          case 'S':
            reader.readLongArray(nbRecData);
            break;
          case 'D':
            reader.readDoubleArray(nbRecData);
            break;
          default:
            throw FormatException(
                "Type de variable inconnu : '$typeChar' (variable n°$iVar, mnemo='${v.mnemo}', non enregistree)");
        }
      }
    }

    final periodSeconds = header.perPeriod / 1000000.0;
    return PerFile(periodSeconds, signals, nbRecData);
  }

  static String peekMagic(Uint8List bytes) {
    final buf = StringBuffer();
    for (int i = 0; i < 4; i++) {
      if (bytes[i] == 0) break;
      buf.writeCharCode(bytes[i]);
    }
    return buf.toString();
  }

  static HeaderInfo readHeaderPER2(BinaryReader r) {
    final h = HeaderInfo();

    r.skip(4); // magic
    r.skip(4); // old_magic
    r.skip(16); // node
    r.skip(16); // appli
    r.skip(254); // filename
    r.skip(254); // mapname
    r.skip(2); // num_pert
    r.skip(2); // num_task
    r.skip(4); // modif
    r.skip(4); // size
    h.nbvar = r.readInt32();
    h.nbrec = r.readInt32();
    r.skip(4); // nbpost
    r.skip(2); // mode
    r.skip(2); // m_auto
    r.skip(4); // rearm_auto
    h.perPeriod = r.readInt32();
    r.skip(4); // periode
    r.skip(4); // startrec
    r.skip(2); // stat
    r.skip(1); // automode
    r.skip(1); // progress
    r.skip(16); // mnemo
    r.skip(4); // trigger
    r.skip(8); // timedec[2]
    r.skip(4); // record_mode
    r.skip(4); // CheckSum
    r.skip(4); // nb_channel
    r.skip(4); // pt_channel
    r.skip(4); // old_index
    r.skip(4); // pid
    r.skip(4); // maxi
    r.skip(2); // ScaleManu
    r.skip(2); // GradManu
    r.skip(4); // scroll
    r.skip(4); // Tmp
    r.skip(8); // Echelle_x
    r.skip(8); // Echelle_y
    r.skip(8); // Min_y
    r.skip(8); // Max_y
    r.skip(8); // Grad_x
    r.skip(8); // Grad_y
    r.skip(4); // Origine_x
    r.skip(4); // Origine_y
    r.skip(4); // ModeTexte
    r.skip(4); // AvecGraduation
    r.skip(4); // AfficheTemps
    r.skip(4); // TileLog
    r.skip(44); // wp
    r.skip(80); // Titre
    r.skip(4); // Titre_x
    r.skip(4); // Titre_y
    r.skip(4); // Titre_coul
    r.skip(12); // mnemoK
    r.skip(12); // mnemoKp
    r.skip(4); // ratio
    r.skip(4); // nb_rem
    r.skip(4); // pt_rem
    r.skip(1); // m_VarInfo_Addr
    r.skip(1); // m_VarInfo_Comment
    r.skip(1); // m_VarInfo_Mnemo
    r.skip(1); // m_VarInfo_Value
    r.skip(4); // synchro
    h.nbDaughter = r.readInt32();
    r.skip(64); // DaughterPert[16]
    r.skip(4); // compressed
    h.nbrecFile = r.readInt32();
    r.skip(4); // curec_file
    r.skip(4); // index
    r.skip(4); // total_index
    r.skip(4); // min_index
    r.skip(4); // ref_time
    r.skip(4); // CWnd
    r.skip(4); // isagraf
    r.skip(4); // configuration
    r.skip(4); // pt_config
    r.skip(4); // BkColor
    r.skip(4); // AxeColor
    r.skip(4); // GridColor
    r.skip(4); // TextColor
    r.skip(4); // Text2Color
    r.skip(4); // OverView
    r.skip(4); // memo_nbrec_file
    r.skip(212); // reserve[53]
    r.skip(4); // nb_channel (final)

    return h;
  }

  static HeaderInfo readHeaderPER3(BinaryReader r) {
    final h = HeaderInfo();

    r.skip(4); // magic
    r.skip(4); // old_magic
    r.skip(16); // node
    r.skip(16); // appli
    r.skip(254); // filename
    r.skip(254); // mapname
    r.skip(2); // num_pert
    r.skip(2); // num_task
    r.skip(4); // modif
    r.skip(4); // size
    h.nbvar = r.readInt32();
    h.nbrec = r.readInt32();
    r.skip(4); // nbpost
    r.skip(2); // mode
    r.skip(2); // m_auto
    r.skip(4); // rearm_auto
    h.perPeriod = r.readInt32();
    r.skip(4); // periode
    r.skip(4); // startrec
    r.skip(2); // stat
    r.skip(1); // automode
    r.skip(1); // progress
    r.skip(16); // res_mnemo
    r.skip(4); // trigger
    r.skip(8); // timedec[2]
    r.skip(4); // record_mode
    r.skip(4); // CheckSum
    r.skip(4); // sd
    r.skip(4); // pt_channel
    r.skip(4); // old_index
    r.skip(4); // pid
    r.skip(4); // maxi
    r.skip(2); // ScaleManu
    r.skip(2); // GradManu
    r.skip(4); // scroll
    r.skip(4); // reserv8
    r.skip(8); // Echelle_x
    r.skip(8); // Echelle_y
    r.skip(8); // Min_y
    r.skip(8); // Max_y
    r.skip(8); // Grad_x
    r.skip(8); // Grad_y
    r.skip(4); // Origine_x
    r.skip(4); // Origine_y
    r.skip(4); // ModeTexte
    r.skip(4); // AvecGraduation
    r.skip(4); // AfficheTemps
    r.skip(4); // TileLog
    r.skip(44); // wp
    r.skip(80); // Titre
    r.skip(4); // Titre_x
    r.skip(4); // Titre_y
    r.skip(4); // Titre_coul
    r.skip(12); // mnemoK
    r.skip(12); // mnemoKp
    r.skip(4); // ratio
    r.skip(4); // nb_rem
    r.skip(4); // pt_rem
    r.skip(1); // m_VarInfo_Addr
    r.skip(1); // m_VarInfo_Comment
    r.skip(1); // m_VarInfo_Mnemo
    r.skip(1); // m_VarInfo_Value
    r.skip(4); // synchro
    h.nbDaughter = r.readInt32();
    r.skip(64); // DaughterPert[16]
    r.skip(4); // compressed
    h.nbrecFile = r.readInt32();
    r.skip(4); // curec_file
    r.skip(4); // index
    r.skip(4); // total_index
    r.skip(4); // min_index
    r.skip(4); // ref_time
    r.skip(4); // CWnd
    r.skip(4); // isagraf
    r.skip(4); // configuration
    r.skip(4); // pt_config
    r.skip(20); // old_coul[5]
    r.skip(4); // OverView
    r.skip(4); // memo_nbrec_file
    r.skip(4); // compress
    r.skip(4); // can_be_scrolled
    r.skip(4); // ExitProtection
    r.skip(64); // mnemo[64]
    r.skip(20); // ud_ident[10]
    r.skip(2); // slot
    r.skip(4); // height_screen
    r.skip(4); // nb_channel
    r.skip(4); // ReticuleVertical
    r.skip(4); // ModeJLS
    r.skip(4); // Delay
    r.skip(2); // FFT
    r.skip(2); // FFT0
    r.skip(564); // reserve[141]

    return h;
  }

  static VarInfo readCfgVar2(BinaryReader r) {
    final v = VarInfo();

    r.skip(16); // node
    r.skip(4); // cpu
    r.skip(16); // appli
    v.mnemo = r.readChars(16);
    r.skip(4); // addr
    r.skip(4); // couleur
    v.enreg = r.readInt32();
    v.valide = r.readInt32();
    v.vType = r.readChars(4);
    v.index = r.readInt32();
    r.skip(40); // remarque
    r.skip(4); // rem_x
    r.skip(4); // rem_y
    r.skip(4); // rem_coul
    r.skip(4); // num_rec
    r.skip(4); // scale_auto
    r.skip(4); // offset
    r.skip(4); // ratio
    v.k = r.readChars(12);
    v.kPrime = r.readChars(12);
    r.skip(16); // reserve[4]

    return v;
  }

  static VarInfo readCfgVar3(BinaryReader r) {
    final v = VarInfo();

    r.skip(16); // node
    r.skip(4); // order
    r.skip(16); // appli
    v.mnemo = r.readChars(64);
    r.skip(4); // addr
    r.skip(4); // couleur
    v.enreg = r.readInt32();
    v.valide = r.readInt32();
    v.vType = r.readChars(4);
    v.index = r.readInt32();
    r.skip(40); // remarque
    r.skip(4); // rem_x
    r.skip(4); // rem_y
    r.skip(4); // rem_coul
    r.skip(4); // num_rec
    r.skip(4); // scale_auto
    r.skip(4); // offset
    r.skip(4); // ratio
    v.k = r.readChars(12);
    v.kPrime = r.readChars(12);
    r.skip(2); // num_pert
    r.skip(2); // num_task
    r.skip(4); // periode
    r.skip(2); // mother_index
    r.skip(2); // old_index
    r.skip(2); // daughter
    r.skip(20); // ud_ident[10]
    r.skip(2); // slot
    r.skip(16); // unit
    r.skip(40); // reserve2[10]

    return v;
  }

  static String buildVarName(String k, String kPrime, String mnemo) {
    final sK = k.trim();
    final sKp = kPrime.trim();
    final sMnemo = mnemo.trim();

    String result = '';
    if (sMnemo.isNotEmpty) result = sanitize(sMnemo);
    if (sKp.isNotEmpty) result = '${sKp}_$result';
    if (sK.isNotEmpty) result = '${sK}_$result';
    if (result.isEmpty) result = 'Var';

    return result;
  }

  static String sanitize(String s) {
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      final isAlnum = RegExp(r'[A-Za-z0-9]').hasMatch(c);
      buf.write(isAlnum ? c : '_');
    }
    return buf.toString();
  }
}