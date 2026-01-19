import 'package:flutter/material.dart';
import '../models/viatura_model.dart';

class HeaderViatura extends StatelessWidget {
  final Viatura viatura;

  const HeaderViatura({super.key, required this.viatura});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF1A2B7B)),
              const SizedBox(width: 8),
              Text(
                'Viatura: ${viatura.numeroViatura} | ${viatura.placa}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2B7B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Modelo: ${viatura.modelo.toUpperCase()}    Tipo: ${viatura.tipo?.toUpperCase() ?? 'N/A'}    KM Atual: ${viatura.kmAtual}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
