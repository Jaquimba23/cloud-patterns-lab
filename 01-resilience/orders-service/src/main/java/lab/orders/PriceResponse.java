package lab.orders;

/** Precio que usa orders-service. source = PRICE_SERVICE o FALLBACK. */
public record PriceResponse(double price, String source) {
}
