# Traffic Management (Istio)

This document describes how traffic is routed to the **stable (v1)** and **canary (v2)** versions of the frontend using Istio.
It also explains how **sticky sessions** ensure users consistently hit the same version.

## What we support

1. **Weighted canary routing (default)**  
   Split traffic between v1 and v2 using weights (e.g., 90/10).

2. **Header override routing (for testing)**  
   Force requests to a specific version by setting the `x-version` header to `v1` or `v2`.

3. **Sticky sessions (version consistency per user)**  
   Enforced via `DestinationRule` `consistentHash`, with two modes:
    - **Cookie-based** (default in our values)
    - **Header-based** (optional)

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
