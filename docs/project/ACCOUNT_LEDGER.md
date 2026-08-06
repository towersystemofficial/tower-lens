# Production account and credit ledger contract

Hosting is intentionally undecided. The production implementation must keep
the account, purchase verification, balance, reservations, and settlement
behind a host-neutral service boundary so Tower Lens can move between managed
hosting and Tower Systems infrastructure without changing the app contract.

## One spreadsheet per account

Each account has an append-only, spreadsheet-compatible ledger (CSV is the
portable baseline). A row represents a verified purchase, tool reservation,
completed usage settlement, released reservation, refund, or administrator
adjustment. The running balance is derived from ledger rows; it is never
authoritative on the device.

Required columns:

| Column | Purpose |
| --- | --- |
| `occurred_at_utc` | Server timestamp |
| `transaction_id` | Globally unique, idempotent transaction identifier |
| `entry_type` | `purchase`, `reservation`, `settlement`, `release`, `refund`, or `adjustment` |
| `credit_delta` | Signed credit change |
| `balance_after` | Auditable running balance |
| `tool_type` | Stable tool identifier for usage rows; blank for unrelated purchases |
| `estimated_max_credits` | Highest pre-run estimate before thousand-credit rounding |
| `reserved_credits` | Amount reserved before the tool starts |
| `provider_input_tokens` | Provider-reported input usage after a usable result |
| `provider_output_tokens` | Provider-reported output usage after a usable result |
| `purchase_product_id` | Play product identifier for purchase rows |
| `purchase_quantity` | Backend-verified Play quantity |
| `purchase_token_hash` | One-way hash for purchase reconciliation; never the raw token |
| `note_code` | Non-content operational reason code |

The ledger must never store tool input, tool output, prompts, extracted text,
photos, filenames, document titles, or user-authored instructions. Operational
logs must follow the same rule.

## Tool authorization

Before a production tool request starts, the backend must:

1. Calculate the displayed highest credit estimate.
2. Round that value up to the next 1,000 credits.
3. Atomically reject the request if the available balance is lower.
4. Otherwise reserve that rounded amount in the account ledger.
5. On usable output, settle the reservation against
   `ceil((input_tokens + output_tokens) * 3.5)` and release the remainder.
6. On failed, empty, invalid, or unusable output, release the full reservation
   and charge zero credits.

The app performs the same balance check for immediate feedback, but the
backend check and reservation are authoritative. This prevents two concurrent
requests from spending the same balance.

Google Play purchase verification remains an adapter behind this contract.
It cannot be completed until a Play developer account and app are configured.
