package lab.orders;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryRegistry;

/** Escribe en el log cada reintento y cada cambio de estado del circuito (sirve de evidencia). */
@Component
public class ResilienceLogger {

    private static final Logger log = LoggerFactory.getLogger(ResilienceLogger.class);

    public ResilienceLogger(CircuitBreakerRegistry cbRegistry, RetryRegistry retryRegistry) {
        var cb = cbRegistry.circuitBreaker("price");
        cb.getEventPublisher()
                .onStateTransition(e -> log.info(">>> CIRCUIT BREAKER: {} -> {}",
                        e.getStateTransition().getFromState(), e.getStateTransition().getToState()))
                .onCallNotPermitted(e -> log.info(">>> CIRCUIT BREAKER ABIERTO: llamada rechazada sin contactar a price-service"));

        retryRegistry.retry("price").getEventPublisher()
                .onRetry(e -> log.info(">>> RETRY: reintento #{} tras fallo", e.getNumberOfRetryAttempts()));
    }
}
