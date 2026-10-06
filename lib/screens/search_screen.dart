import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/parts_repository.dart';
import '../models/part.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/chip_row.dart';
import '../widgets/part_photo.dart';
import '../widgets/topbar.dart';
import 'offers_screen.dart';

const _searchCategories = ['GPU', 'CPU', 'RAM', 'SSD', 'Fonte', 'Gabinete'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _category = 'GPU';
  String _query = '';

  // Catálogo de demonstração — numa versão real viria de uma API/scraper.
  List<Part> get _catalog {
    final repo = context.read<PartsRepository>();
    final extra = [
      Part(id: 'x1', name: 'SSD Kingston NV2 1TB NVMe', category: 'SSD', store: '5 lojas', currentPrice: 359.9, targetPrice: 320),
      Part(id: 'x2', name: 'Radeon RX 7800 XT 16GB', category: 'GPU', store: '3 lojas', currentPrice: 3499.9, targetPrice: 3200),
      Part(id: 'x3', name: 'Intel Core i5-14600K', category: 'CPU', store: '6 lojas', currentPrice: 1899.9, targetPrice: 1700),
    ];
    return [...repo.parts, ...extra];
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _catalog.where((p) {
      final matchesCategory = p.category == _category;
      final matchesQuery = p.name.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: TopBar(
        title: 'Buscar',
        eyebrow: 'CATÁLOGO DE PEÇAS',
        action: InkWell(
          onTap: _openFilter,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
            child: const Center(child: AppIcon(AppIconName.settings, size: 15, color: AppColors.text)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                const AppIcon(AppIconName.search, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: AppText.label,
                    decoration: InputDecoration.collapsed(hintText: 'Buscar GPU, CPU, RAM...', hintStyle: AppText.label.copyWith(color: AppColors.mutedDark)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ChipRow(items: _searchCategories, selected: _category, onSelect: (c) => setState(() => _category = c)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${results.length} RESULTADOS', style: AppText.mono.copyWith(fontWeight: FontWeight.w600, color: AppColors.muted)),
              Text('Menor preço primeiro', style: AppText.monoSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const AppIcon(AppIconName.radar, size: 28, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('Nenhum sinal encontrado', style: AppText.cardTitle),
                  const SizedBox(height: 6),
                  Text('Tente outra categoria ou termo de busca.', style: AppText.body),
                ],
              ),
            )
          else
            ...results.map((part) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OffersScreen(part: part))),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lineSoft)),
                      child: Row(
                        children: [
                          PartPhoto(category: part.category, size: 58),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${part.category} • ${part.store}', style: AppText.monoSmall.copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(part.name, style: AppText.cardTitle.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    style: AppText.monoSmall,
                                    children: [
                                      const TextSpan(text: 'a partir de '),
                                      TextSpan(text: currency.format(part.currentPrice), style: AppText.mono.copyWith(color: AppColors.text, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AppIcon(AppIconName.arrow, rotate180: true, size: 16, color: AppColors.mutedDark),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _category = 'GPU';
  String _store = 'Todas';
  bool _onlyAlerts = false;

  static const _stores = ['Todas', 'KaBuM!', 'Pichau', 'Amazon', 'Terabyte'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
            ),
            Text('Filtrar', style: AppText.h2.copyWith(fontSize: 20)),
            const SizedBox(height: 20),
            Text('CATEGORIA', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
            const SizedBox(height: 10),
            ChipRow(items: _searchCategories, selected: _category, onSelect: (c) => setState(() => _category = c)),
            const SizedBox(height: 20),
            Text('LOJA', style: AppText.monoSmall.copyWith(color: AppColors.muted)),
            const SizedBox(height: 10),
            ChipRow(items: _stores, selected: _store, onSelect: (s) => setState(() => _store = s)),
            const SizedBox(height: 20),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
              child: Row(
                children: [
                  const AppIcon(AppIconName.bell, size: 17, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Mostrar só com alerta ativo', style: AppText.body.copyWith(color: AppColors.text, fontSize: 12))),
                  Switch(value: _onlyAlerts, onChanged: (v) => setState(() => _onlyAlerts = v)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _category = 'GPU';
                    _store = 'Todas';
                    _onlyAlerts = false;
                  }),
                  child: Text('Limpar', style: AppText.body.copyWith(color: AppColors.muted, fontSize: 13)),
                ),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Aplicar filtros', style: AppText.title.copyWith(color: AppColors.onAccent, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
