# Traffic Management (Istio)

This document describes how traffic is routed to the **stable (v1)** and **canary (v2)** versions of the frontend using Istio.
It also explains how **sticky sessions** ensure users consistently hit the same version.

## What we support

1. **Weighted canary routing (default)**  
   Split traffic between v1 and v2 using weights (e.g., 90/10).
These weights are configured in the **frontend** `VirtualService`.  In our Helm chart
you can set `canary.weight` and `stable.weight` values, and the rendered
`VirtualService` will set the `weight` fields accordingly.  For example, a 90/10 split is represented as:

```yaml
http:
    - name: stable
      route:
        - destination:
            host: frontend
            subset: v1
          weight: 90
        - destination:
            host: frontend
            subset: v2
          weight: 10
```

Make sure the weights sum to **100**; otherwise Istio normalizes them.

3. **Sticky sessions (version consistency per user)**  
   Enforced via `DestinationRule` `consistentHash`, with two modes:
   - **Cookie-based** (default in our values)
   - **Header-based** (optional)

The sticky‑session policy is configured in the `DestinationRule`’s `trafficPolicy.consistentHash`.  By default
it uses a cookie named `sms-app-version`; you can switch to header-based stickiness by setting
`stickySession.strategy` to `header` and specifying `stickySession.headerName`, e.g. `x-user-id`.

```yaml
trafficPolicy:
    loadBalancer:
      consistentHash:
        cookie:
          name: sms-app-version
          ttl: 0s
```


---

## Architecture overview

```mermaid
flowchart LR
  U[User] --> IG[Istio IngressGateway]
  IG --> VS[VirtualService: frontend]
  VS -->|weight| V1[Subset v1]
  VS -->|weight| V2[Subset v2]
  V1 --> FE1[Frontend Pods v1]
  V2 --> FE2[Frontend Pods v2]
