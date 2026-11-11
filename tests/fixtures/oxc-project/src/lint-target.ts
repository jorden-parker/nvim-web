export function describeCart(productCount: number): string {
  debugger
  var cartLabel = 'Cart'
  if (productCount == 0) {
    return `${cartLabel} is empty`
  }
  return `${cartLabel} has ${productCount} products`
}
