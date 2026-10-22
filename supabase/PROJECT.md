# FoodTrack backend

- Supabase project: `FoodTrack`
- Project ref: `itzdbziwfwnhqbnhlczy`
- Region: `eu-west-1`
- Project URL: `https://itzdbziwfwnhqbnhlczy.supabase.co`
- Cost quote at creation: `0 EUR/month`

The database schema and the follow-up indexes/policy migration were applied to this dedicated project and verified through the Supabase table listing.

The frontend has **not yet been connected** to this backend. Do not treat the app as ready for real orders until login, onboarding/invitations, tenant membership management, server-side price and order-total validation, order state transitions, and authorization tests are implemented.

Only a Supabase publishable/anon key may be used in public frontend code, and only after RLS is enabled and verified. Never place a service-role/secret key in the repository. The public app must not expose an open signup path that lets visitors assign themselves privileged roles.

The free plan has usage quotas and may pause projects after inactivity. A zero-cost quote at creation does not guarantee unlimited availability. Do not enable paid plans or automatic upgrades.
