class Viatura {
  final int? id;
  final String numeroViatura;
  final String placa;
  final String modelo;
  int kmAtual;
  final String tipo;
  final String situacao;

  Viatura({
    this.id,
    required this.numeroViatura,
    required this.placa,
    required this.modelo,
    required this.kmAtual,
    required this.tipo,
    required this.situacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numeroViatura': numeroViatura,
      'placa': placa,
      'modelo': modelo,
      'kmAtual': kmAtual,
      'tipo': tipo,
      'situacao': situacao,
    };
  }

  factory Viatura.fromMap(Map<String, dynamic> map) {
    return Viatura(
      id: map['id'],
      numeroViatura: map['numeroViatura'],
      placa: map['placa'],
      modelo: map['modelo'],
      kmAtual: map['kmAtual'],
      tipo: map['tipo'] ?? '',
      situacao: map['situacao'] ?? '',
    );
  }
}
