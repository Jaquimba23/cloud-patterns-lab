package lab.orders;

/** Se lanza cuando price-service no responde dentro del tiempo límite. */
public class PriceTimeoutException extends RuntimeException {
    public PriceTimeoutException(Throwable cause) {
        super("price-service no respondió a tiempo", cause);
    }
}
