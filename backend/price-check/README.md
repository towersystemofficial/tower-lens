# Price Check backend

This small Node 20 service keeps the Anthropic key out of the Android app and
exposes the staged `/price-check/identify`, `/research`, `/buyer`, `/seller`,
and `/compare` endpoints. It never writes uploaded photos to disk; JPEG EXIF
and common application metadata are removed in memory before identification.

Configure `ANTHROPIC_API_KEY`, `PRICE_CHECK_BEARER_TOKEN`, and optionally
`ANTHROPIC_MODEL`/`PORT`, then run `npm start`. Configure the Flutter build with
`PRICE_CHECK_BACKEND_URL` and the matching `PRICE_CHECK_BEARER_TOKEN` using
`--dart-define`. Production deployment should inject both server secrets from
the hosting platform rather than committing them.
