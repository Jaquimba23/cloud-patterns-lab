package lab.price;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Servicio "de mentira" que devuelve un precio y puede simular fallos.
 * Modos: ok | error | flaky | slow
 */
@RestController
public class PriceController {

    private static final Logger log = LoggerFactory.getLogger(PriceController.class);
    private static final Set<String> MODES = Set.of("ok", "error", "flaky", "slow");

    private final AtomicReference<String> mode = new AtomicReference<>("ok");
    private final AtomicInteger flakyCalls = new AtomicInteger();

    @GetMapping("/price")
    public ResponseEntity<Map<String, Object>> price() throws InterruptedException {
        String m = mode.get();
        log.info("GET /price (modo={})", m);
        switch (m) {
            case "error":
                return ResponseEntity.status(503).body(Map.of("error", "price-service en modo error"));
            case "slow":
                Thread.sleep(5000); // 5 segundos de demora
                break;
            case "flaky":
                // falla las 2 primeras llamadas y luego responde bien
                if (flakyCalls.incrementAndGet() <= 2) {
                    return ResponseEntity.status(503).body(Map.of("error", "fallo temporal"));
                }
                break;
            default:
                break;
        }
        return ResponseEntity.ok(Map.of("price", 12.5, "source", "price-service", "mode", m));
    }

    @PostMapping("/admin/mode/{newMode}")
    public ResponseEntity<Map<String, String>> setMode(@PathVariable String newMode) {
        if (!MODES.contains(newMode)) {
            return ResponseEntity.badRequest().body(Map.of("error", "modos validos: ok, error, flaky, slow"));
        }
        mode.set(newMode);
        flakyCalls.set(0);
        log.info("Modo cambiado a: {}", newMode);
        return ResponseEntity.ok(Map.of("mode", newMode));
    }
}
