/// Uma oferta de uma loja específica pra uma peça — usado só na tela de
/// Comparador (gerado na hora a partir do preço base da peça, não
/// persistido, igual ao protótipo web).
class Offer {
  final String store;
  final double price;
  final String shipping;

  const Offer({required this.store, required this.price, required this.shipping});
}

List<Offer> buildOffersFor(double basePrice) {
  return [
    Offer(store: 'KaBuM!', price: basePrice, shipping: 'Frete grátis · 3 dias'),
    Offer(store: 'Pichau', price: basePrice + 129.9, shipping: 'Frete R\$ 24,90 · 5 dias'),
    Offer(store: 'Amazon', price: basePrice + 210, shipping: 'Frete grátis · Amanhã'),
    Offer(store: 'Terabyte', price: basePrice + 275.5, shipping: 'Frete R\$ 18,40 · 4 dias'),
  ]..sort((a, b) => a.price.compareTo(b.price));
}
