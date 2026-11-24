package lab.orders;

import java.net.SocketTimeoutException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

/**
 * Cliente de price-service protegido con:
 *  - TIMEOUT: el cliente HTTP espera como máximo 2 s por la respuesta.
 *  - CIRCUIT BREAKER: @CircuitBreaker (instancia "price").
 *  - RETRY: @Retry (instancia "price"), que envuelve al circuit breaker.
 *  - FALLBACK: precio base si todo falla.
 */
@Component
public class PriceClient {

    private static final Logger log = LoggerFactory.getLogger(PriceClient.class);
    private static final double BASE_PRICE = 10.0;

    private final RestClient client;

    public PriceClient(@Value("${price.url}") String baseUrl) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(1000); // 1 s para conectar
        factory.setReadTimeout(2000);    // 2 s para recibir la respuesta (TIMEOUT)
        this.client = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    @Retry(name = "price", fallbackMethod = "fallback")
    @CircuitBreaker(name = "price")
    public PriceResponse getPrice() {
        log.info("Llamando a price-service...");
        try {
            PriceDto dto = client.get().uri("/price").retrieve().body(PriceDto.class);
            return new PriceResponse(dto.price(), "PRICE_SERVICE");
        } catch (ResourceAccessException e) {
            if (e.getCause() instanceof SocketTimeoutException) {
                log.warn("TIMEOUT: price-service tardó más de 2 s");
                throw new PriceTimeoutException(e);
            }
            throw e;
        }
    }

    /** Se ejecuta cuando se agotan los reintentos, hay timeout o el circuito está ABIERTO. */
    public PriceResponse fallback(Throwable t) {
        log.warn("FALLBACK: usando precio base ({}). Motivo: {}", BASE_PRICE, t.getClass().getSimpleName());
        return new PriceResponse(BASE_PRICE, "FALLBACK");
    }
}
