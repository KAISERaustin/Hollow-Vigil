# Tower equipment

Campaign bosses award equipment sets described in [Boss equipment](GEAR.md). Each tower has one equipment slot. Equipment can be assigned, removed or transferred through the tower collection picker without spending gold. Selling a tower returns its equipment to the collection; upgrading and relocating retain ownership.

Equipment effects use reusable attribute components with state belonging to each equipped tower. Primary attacks trigger equipment; secondary projectiles cannot recursively activate it. Ownership validation rejects unknown pieces and duplicate assignments. Temporary combat effects reset between waves and attempts.

See [Campaign](CAMPAIGN.md) for attempt and configuration persistence, and [Node system](NODE_SYSTEM.md) for attaching reusable effects.
