import 'package:intl/intl.dart';

class Manutencao {
  final int? id;
  final int viaturaId;
  final String descricao;
  final String data; // Data de criação ou registro
  final int km; // Quilometragem atual da viatura no momento do registro
  final int kmAlvo; // Quilometragem alvo para manutenção
  final String dataAlvo; // Data futura limite para manutenção
  String status; // ex: 'pendente', 'definir', 'vencida', 'concluída'

  String? local;
  String? observacao;

  String? responsavelNome;
  String? responsavelMatricula;
  String? dataHoraConclusao;

  Manutencao({
    this.id,
    required this.viaturaId,
    required this.descricao,
    required this.data,
    required this.km,
    required this.kmAlvo,
    required this.dataAlvo,
    required this.status,
    this.local,
    this.observacao,
    this.responsavelNome,
    this.responsavelMatricula,
    this.dataHoraConclusao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'viaturaId': viaturaId,
      'descricao': descricao,
      'data': data,
      'km': km,
      'kmAlvo': kmAlvo,
      'dataAlvo': dataAlvo,
      'status': status,
      'local': local,
      'observacao': observacao,
      'responsavelNome': responsavelNome,
      'responsavelMatricula': responsavelMatricula,
      'dataHoraConclusao': dataHoraConclusao,
    };
  }

  factory Manutencao.fromMap(Map<String, dynamic> map) {
    String dataAlvo = map['dataAlvo'];
    try {
      DateTime parsed = DateTime.parse(dataAlvo);
      dataAlvo = DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {}

    return Manutencao(
      id: map['id'],
      viaturaId: map['viaturaId'],
      descricao: map['descricao'],
      data: map['data'],
      km: map['km'],
      kmAlvo: map['kmAlvo'],
      dataAlvo: dataAlvo,
      status: map['status'],
      local: map['local'],
      observacao: map['observacao'],
      responsavelNome: map['responsavelNome'],
      responsavelMatricula: map['responsavelMatricula'],
      dataHoraConclusao: map['dataHoraConclusao'],
    );
  }
}
