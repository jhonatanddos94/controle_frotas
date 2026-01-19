// lib/utils/criticidade_helper.dart
import 'package:intl/intl.dart';

/// Retorna: 'Crítico' | 'Atenção' | 'No Prazo' | 'Ignorar'
///
/// - Se só houver KM -> calcula por KM
/// - Se só houver data -> calcula por Data
/// - Se houver ambos -> retorna o mais crítico entre os dois
/// - Se não houver nenhum parâmetro válido -> 'Ignorar'
String calcularCriticidade({
  String? dataAlvo, // pode ser null ou ''
  int? kmAlvo, // pode ser null
  required int kmAtual,

  // Limiares (ajustáveis depois se quiser)
  int limiarCriticoKm = 500,
  int limiarAtencaoKm = 1000,
  int limiarPrazoKm = 2000,
  int limiarCriticoDias = 7,
  int limiarAtencaoDias = 30,
  int limiarPrazoDias = 60,
}) {
  // ---------- diasRestantes (ou null se não houver data válida) ----------
  int? diasRestantes;
  final ds = (dataAlvo ?? '').trim();
  if (ds.isNotEmpty) {
    DateTime? d;
    // tenta dd/MM/yyyy primeiro
    try {
      d = DateFormat('dd/MM/yyyy').parseStrict(ds);
    } catch (_) {
      // tenta ISO (yyyy-MM-dd...)
      try {
        d = DateTime.parse(ds);
      } catch (_) {}
    }
    if (d != null) {
      diasRestantes = d.difference(DateTime.now()).inDays;
    }
  }

  // ---------- kmRestante (ou null se kmAlvo ausente) ----------
  int? kmRestante;
  if (kmAlvo != null && kmAlvo > 0) {
    kmRestante = kmAlvo - kmAtual;
  }

  // Se não tem nada para calcular, ignorar
  if (diasRestantes == null && kmRestante == null) {
    return 'Ignorar';
  }

  String? nivelKm;
  if (kmRestante != null) {
    if (kmRestante <= limiarCriticoKm) {
      nivelKm = 'Crítico';
    } else if (kmRestante <= limiarAtencaoKm) {
      nivelKm = 'Atenção';
    } else if (kmRestante <= limiarPrazoKm) {
      nivelKm = 'No Prazo';
    } else {
      nivelKm = 'No Prazo';
    }
  }

  String? nivelData;
  if (diasRestantes != null) {
    if (diasRestantes <= limiarCriticoDias) {
      nivelData = 'Crítico';
    } else if (diasRestantes <= limiarAtencaoDias) {
      nivelData = 'Atenção';
    } else if (diasRestantes <= limiarPrazoDias) {
      nivelData = 'No Prazo';
    } else {
      nivelData = 'No Prazo';
    }
  }

  // Combina (Crítico > Atenção > No Prazo)
  final peso = {'Crítico': 3, 'Atenção': 2, 'No Prazo': 1};
  if (nivelKm != null && nivelData != null) {
    return (peso[nivelKm]! >= peso[nivelData]!) ? nivelKm : nivelData;
  }
  return nivelKm ?? nivelData ?? 'No Prazo';
}
