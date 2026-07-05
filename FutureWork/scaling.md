# Scaling and deployment

Current: one server, databases on the host, API under systemd, nginx in front.

- Containerize with Docker and docker-compose so the stack is reproducible.
- Sandbox each code run in its own Docker container (network off, memory and CPU
  limits) instead of the current in-process / transaction / subprocess isolation.
- Run multiple API replicas and a separate worker pool behind a load balancer.
- Move MongoDB and Redis to managed services.
- Replace BullMQ with a durable broker (for example Kafka) only if submission
  volume needs it.
- Migrate to AWS once free credits are sorted.
