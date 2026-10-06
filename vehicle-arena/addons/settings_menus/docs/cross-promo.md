# Upgrade to the selodev RPG Toolkit

This template is free because the rest of the catalog exists. If you've shipped a settings/menus pass and want the systems underneath, here's the full line.

## The selodev no-code stack

Everything below is pure GDScript, Inspector-first, save-aware, and same-bus integrated.

| System | Tier | Role |
|---|---|---|
| **Save / Load** | Flagship $14.99 | Atomic save + load with migrations. The contract every other system below opts into. |
| **Inventory** | Standard | Shared `ItemResource`, weight + categories, drag-drop, hotbar. Most of the other systems read its items. |
| Equipment | Standard | Paper-doll slots, two-handed conflicts, modifier aggregation. |
| Loot | Standard | Weighted tables, nested tables, conditions, magic find, pity counter. |
| Crafting | Standard | Shaped + shapeless recipes, queue, unlocks. |
| Vendor / Shop | Standard | Multi-currency, buyback, restock timers, conditional offers. |
| Quests | Standard | 8 objective types, chains, prerequisites, log UI, NPC givers. |
| Stats / Skill Trees | Standard | Stat aggregator, visual skill-tree runtime, unlock + respec. |

Pricing: **Save/Load is a flat $14.99**. Every **Standard is Pay-What-You-Want, $4.99 min /
$9.99 suggested**. A $9.99 you see quoted for a standard is the *suggested* price, not a floor.

À la carte total: ~$90 at suggested standards (~$50 at the minimums). Bundle prices:

- **RPG Toolkit** (everything above): $29.99. ~40% off the à-la-carte minimums.
- **Inventory cluster** (Inventory + Equipment + Loot + Crafting): $14.99. ~25% off.

## Why these systems

The systems are designed to compose. Every one of them implements the same save contract, emits modifiers in the same `{stat, op, amount}` shape, and shares a single `Events` autoload bus. You don't write glue code. Drop a component, set a NodePath, you're done.

Most free addons solve one problem. The selodev stack solves the **gap between them**.

## Try the Lite tiers first

Each paid system ships a free **Lite** tier with the working core. Same APIs, same components, just stripped of the production-grade features. If you want to try the wedge before paying, grab a Lite tier first.

## Where to buy

- itch.io: `selodev.itch.io` (primary)
- Godot Asset Library: search "selodev"
- Direct: `selodev.com`

## Stay in the loop

Discord: https://discord.com/invite/vaXGnXHFmC. Roadmap visible. Bug reports welcome. Feature requests go in `#wishlist` and the most-upvoted ones ship.

## License

This template is MIT. The paid systems are also MIT, so you own the code outright, can ship it in commercial games, and modify whatever you want. What you're paying for is **finished, maintained systems** so you don't have to write them yourself, rather than a license.
