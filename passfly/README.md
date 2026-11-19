# PassFly ✈️

Generador de contraseñas seguras y aleatorias. Monolito Node.js (Express) que sirve la interfaz web y la API. Sin login, sin base de datos: las contraseñas **nunca se almacenan ni se registran**.

## Ejecutar

```bash
npm ci
npm start            # http://localhost:3000
npm test             # tests unitarios y de API
npm run lint         # ESLint
npm run sbom         # SBOM CycloneDX (sbom.cdx.json)
```

Con Docker:

```bash
docker compose up --build   # desde la raíz del monorepo (incluye Prometheus y Grafana)
```

## API

`POST /api/v1/passwords`

| Campo | Tipo | Por defecto | Rango |
|---|---|---|---|
| `length` | entero | 16 | 8–128 |
| `lowercase`, `uppercase`, `numbers`, `symbols` | booleano | `true` | al menos uno activo |
| `excludeAmbiguous` | booleano | `false` | excluye `O 0 I l 1 \|` |
| `count` | entero | 1 | 1–10 |

```bash
curl -s localhost:3000/api/v1/passwords -H 'Content-Type: application/json' \
  -d '{"length":24,"symbols":false}'
# {"passwords":["..."],"entropyBits":143,"strength":"muy fuerte"}
```

Otros endpoints: `GET /health` y `GET /metrics` (Prometheus).

## Seguridad

- Aleatoriedad criptográfica (`crypto.randomInt`) y mezcla Fisher-Yates.
- Garantiza al menos un carácter de cada tipo seleccionado.
- `helmet`, rate limiting por IP, validación estricta y respuestas `Cache-Control: no-store`.
- Imagen Docker multi-stage, ejecutada como usuario no root.

## Métricas

- `passfly_passwords_generated_total`
- `passfly_http_request_duration_seconds`
- Métricas por defecto del proceso Node.js

