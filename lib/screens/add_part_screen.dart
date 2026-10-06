import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/topbar.dart';

const _categories = ['GPU', 'CPU', 'RAM', 'SSD'];
const _categoryIcons = {
  'GPU': AppIconName.gpu,
  'CPU': AppIconName.cpu,
  'RAM': AppIconName.memory,
  'SSD': AppIconName.ssd,
};

class AddPartScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const AddPartScreen({super.key, required this.onSaved});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _currentPriceCtrl = TextEditingController();
  final _targetPriceCtrl = TextEditingController();
  String _category = 'GPU';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storeCtrl.dispose();
    _currentPriceCtrl.dispose();
    _targetPriceCtrl.dispose();
    super.dispose();
  }

  double? _parsePrice(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<PartsRepository>();
    await repo.addPart(
      name: _nameCtrl.text.trim(),
      category: _category,
      store: _storeCtrl.text.trim(),
      currentPrice: _parsePrice(_currentPriceCtrl.text)!,
      targetPrice: _parsePrice(_targetPriceCtrl.text)!,
    );
    _nameCtrl.clear();
    _storeCtrl.clear();
    _currentPriceCtrl.clear();
    _targetPriceCtrl.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monitoramento ativado!')));
    widget.onSaved();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;
  String? _priceReq(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obrigatório';
    if (_parsePrice(v) == null) return 'Preço inválido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'Nova peça', eyebrow: 'CONFIGURAR RADAR'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.1), AppColors.surface]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green.withOpacity(0.14)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                    child: const Center(child: AppIcon(AppIconName.radar, color: AppColors.green, size: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crie um novo monitor', style: AppText.cardTitle),
                        const SizedBox(height: 4),
                        Text('Defina o alvo e nós varremos as lojas por você.', style: AppText.body, maxLines: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Field(label: 'NOME DA PEÇA', icon: AppIconName.search, controller: _nameCtrl, hint: 'Ex: RTX 4070 Super', validator: _req),
            const SizedBox(height: 18),
            Text('CATEGORIA', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
            const SizedBox(height: 8),
            Row(
              children: _categories.map((c) {
                final selected = c == _category;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: c == _categories.last ? 0 : 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _category = c),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.greenSoft : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? AppColors.green.withOpacity(0.4) : AppColors.line),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(_categoryIcons[c]!, size: 17, color: selected ? AppColors.green : AppColors.muted),
                              const SizedBox(height: 4),
                              Text(c, style: AppText.monoSmall.copyWith(color: selected ? AppColors.green : AppColors.muted, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _Field(label: 'LOJA', icon: AppIconName.box, controller: _storeCtrl, hint: 'Nome da loja', validator: _req),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MoneyField(label: 'PREÇO ATUAL', controller: _currentPriceCtrl, validator: _priceReq),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MoneyField(label: 'PREÇO ALVO', controller: _targetPriceCtrl, validator: _priceReq, accent: true),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.purpleSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.purple.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const AppIcon(AppIconName.target, size: 18, color: AppColors.purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Você será alertado quando o preço atingir ou ficar abaixo do alvo.',
                      style: AppText.body.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppButton(label: 'Ativar monitoramento', icon: AppIconName.radar, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final AppIconName icon;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;

  const _Field({required this.label, required this.icon, required this.controller, required this.hint, required this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.monoSmall.copyWith(color: AppColors.muted)),
        const SizedBox(height: 7),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 16, color: AppColors.mutedDark),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  style: AppText.label,
                  decoration: InputDecoration.collapsed(hintText: hint, hintStyle: AppText.label.copyWith(color: AppColors.mutedDark)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool accent;

  const _MoneyField({required this.label, required this.controller, required this.validator, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.green : AppColors.mutedDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.monoSmall.copyWith(color: AppColors.muted)),
        const SizedBox(height: 7),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent ? AppColors.green.withOpacity(0.2) : AppColors.line),
          ),
          child: Row(
            children: [
              Text('R\$', style: AppText.mono.copyWith(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.label,
                  decoration: InputDecoration.collapsed(hintText: '0,00', hintStyle: AppText.label.copyWith(color: AppColors.mutedDark)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
