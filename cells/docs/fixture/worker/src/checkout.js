// checkout — cart + totals.
const PROMOS = { SAVE10: 0.10, HALF: 0.50 }; // promo code -> fraction off the subtotal

export function create() {
  return new Cart([], null, 0, false);
}

class Cart {
  constructor(items, promo, taxBps, sealed) {
    this._items = items;
    this._promo = promo;
    this._taxBps = taxBps;
    this._sealed = sealed;
  }
  add(name, unitCents, qty = 1) {
    return new Cart([...this._items, { name, unitCents, qty }], this._promo, this._taxBps, this._sealed);
  }
  applyPromo(code) {
    return new Cart([...this._items], code, this._taxBps, this._sealed);
  }
  setTax(rateBps) {
    return new Cart([...this._items], this._promo, rateBps, this._sealed);
  }
  seal() {
    return new Cart([...this._items], this._promo, this._taxBps, true);
  }
  total() {
    const subtotalCents = this._items.reduce((s, i) => s + i.unitCents * i.qty, 0);
    if (!this._sealed) {
      return { subtotalCents, discountCents: 0, taxCents: 0, totalCents: subtotalCents };
    }
    const frac = this._promo && PROMOS[this._promo] ? PROMOS[this._promo] : 0;
    const discountCents = Math.round(subtotalCents * frac);
    const taxableCents = subtotalCents - discountCents;
    const taxCents = Math.round((taxableCents * this._taxBps) / 10000);
    return { subtotalCents, discountCents, taxCents, totalCents: taxableCents + taxCents };
  }
}
