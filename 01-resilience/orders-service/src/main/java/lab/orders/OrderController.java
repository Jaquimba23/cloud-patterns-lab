package lab.orders;

import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class OrderController {

    private final PriceClient priceClient;

    public OrderController(PriceClient priceClient) {
        this.priceClient = priceClient;
    }

    @GetMapping("/order")
    public Map<String, Object> createOrder() {
        PriceResponse p = priceClient.getPrice();
        return Map.of(
                "orderId", UUID.randomUUID().toString(),
                "price", p.price(),
                "source", p.source());
    }
}
