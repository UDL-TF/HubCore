-- ============================================================================
-- HubCore Shop Management SQL Queries
-- ============================================================================
-- Replace {PREFIX} with your actual database prefix (e.g., 'hub_')
--
-- Table Structure:
--   {PREFIX}categories_v2  - Item categories (Tags, Trails, Footprints, etc.)
--   {PREFIX}items_v2       - Shop items with prices
--   {PREFIX}player_items_v2 - Player inventory (purchased items)
-- ============================================================================

-- ============================================================================
-- CATEGORY MANAGEMENT
-- ============================================================================

-- View all categories
SELECT id, name, description, sort_order, is_active 
FROM {PREFIX}categories_v2 
ORDER BY sort_order;

-- Create default categories (run once on setup)
INSERT INTO {PREFIX}categories_v2 (name, description, sort_order, is_active) VALUES
('Tags', 'Chat tags displayed before player names', 1, TRUE),
('Trails', 'Trail effects that follow players', 2, TRUE),
('Footprints', 'Footstep effects when walking', 3, TRUE),
('Spawn Particles', 'Particle effects on player spawn', 4, TRUE),
('Chat Colors', 'Custom colors for chat messages', 5, TRUE)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Add a new category
INSERT INTO {PREFIX}categories_v2 (name, description, sort_order, is_active) 
VALUES ('New Category', 'Description here', 99, TRUE);


-- ============================================================================
-- ITEM MANAGEMENT
-- ============================================================================

-- View all items with category names
SELECT 
    i.id,
    c.name AS category,
    i.name AS item_name,
    i.description,
    i.type,
    i.price,
    i.is_active
FROM {PREFIX}items_v2 i
JOIN {PREFIX}categories_v2 c ON i.category_id = c.id
ORDER BY c.sort_order, i.price;

-- View items in a specific category
SELECT id, name, description, price, is_active 
FROM {PREFIX}items_v2 
WHERE category_id = (SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags')
ORDER BY price;

-- ============================================================================
-- ADD TAGS TO SHOP
-- ============================================================================
-- IMPORTANT: Item name MUST match exactly with configs/hub/tags.cfg "name" value

INSERT INTO {PREFIX}items_v2 (category_id, name, description, type, price, is_active) VALUES
-- Get category ID for Tags
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[VIP]', 'VIP chat tag', 'tag', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[MVP]', 'MVP chat tag', 'tag', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Pro]', 'Pro player tag', 'tag', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Elite]', 'Elite player tag', 'tag', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Legend]', 'Legendary player tag', 'tag', 2000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Champion]', 'Champion tag', 'tag', 3000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Noob]', 'Noob tag', 'tag', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags'), '[Rookie]', 'Rookie tag', 'tag', 250, TRUE);


-- ============================================================================
-- ADD TRAILS TO SHOP
-- ============================================================================
-- IMPORTANT: Item name MUST match exactly with configs/hub/trails.cfg "name" value

INSERT INTO {PREFIX}items_v2 (category_id, name, description, type, price, is_active) VALUES
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Spectrum Cycle', 'Rainbow cycling trail', 'trail', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Color Wave', 'Smooth color wave effect', 'trail', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Velocity Based', 'Color changes with speed', 'trail', 2000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Breathing Green', 'Pulsing green trail', 'trail', 1200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Flashing Red', 'Rapid flashing red trail', 'trail', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Trails'), 'Yellow Bow', 'Yellow bow-width effect', 'trail', 1800, TRUE);


-- ============================================================================
-- ADD FOOTPRINTS TO SHOP
-- ============================================================================
-- IMPORTANT: Item name MUST match exactly with g_Footprints[].name in footprints.sp

INSERT INTO {PREFIX}items_v2 (category_id, name, description, type, price, is_active) VALUES
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Blue', 'Blue footsteps', 'footprint', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Light Blue', 'Light blue footsteps', 'footprint', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Yellow', 'Yellow footsteps', 'footprint', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Corrupted Green', 'Corrupted green footsteps', 'footprint', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Dark Green', 'Dark green footsteps', 'footprint', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Lime', 'Lime green footsteps', 'footprint', 600, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Brown', 'Brown footsteps', 'footprint', 400, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Oak Tree Brown', 'Oak brown footsteps', 'footprint', 450, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Flames', 'Flaming footsteps', 'footprint', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Cream', 'Cream colored footsteps', 'footprint', 400, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Pink', 'Pink footsteps', 'footprint', 600, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Satan''s Blue', 'Dark satanic blue footsteps', 'footprint', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Purple', 'Purple footsteps', 'footprint', 700, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), '4 8 15 16 23 42', 'Lost numbers footsteps', 'footprint', 2000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Ghost In The Machine', 'Ghostly tech footsteps', 'footprint', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Footprints'), 'Holy Flame', 'Holy flame footsteps', 'footprint', 2000, TRUE);


-- ============================================================================
-- ADD SPAWN PARTICLES TO SHOP
-- ============================================================================
-- IMPORTANT: Item name MUST match exactly with g_ParticleNames[] in spawn_particles.sp

INSERT INTO {PREFIX}items_v2 (category_id, name, description, type, price, is_active) VALUES
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Achievement', 'Achievement unlock effect', 'spawn_particle', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Big Explosion', 'Large explosion on spawn', 'spawn_particle', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Biggest Explosion', 'Massive explosion effect', 'spawn_particle', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Debris', 'Debris scatter effect', 'spawn_particle', 400, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'One Balloon', 'Single balloon spawn', 'spawn_particle', 300, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Blood Fountain', 'Blood fountain effect', 'spawn_particle', 800, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Bonk!', 'Bonk text effect', 'spawn_particle', 600, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Burning Blue', 'Blue fire effect', 'spawn_particle', 700, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Burning Red', 'Red fire effect', 'spawn_particle', 700, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Gold Explosion', 'Golden explosion', 'spawn_particle', 1500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Coin Blue', 'Blue coin effect', 'spawn_particle', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Coin Large Blue', 'Large blue coin effect', 'spawn_particle', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Electric Blue', 'Electric shock effect', 'spawn_particle', 900, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Bubbles', 'Bubble effect', 'spawn_particle', 400, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Explosive Bubbles', 'Exploding bubbles', 'spawn_particle', 600, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Purple Explosion', 'Purple ghost explosion', 'spawn_particle', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Purple Firepit', 'Purple fire pit', 'spawn_particle', 800, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Purple Small Firepit', 'Small purple fire', 'spawn_particle', 600, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Purple Plate', 'Purple plate effect', 'spawn_particle', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Legendary Summon', 'Boss summon effect', 'spawn_particle', 2500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Small Ghosts', 'Ghost spawn effect', 'spawn_particle', 1200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Wood Explosion', 'Wood break effect', 'spawn_particle', 400, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Spawn Particles'), 'Wood Dust', 'Wood dust puff', 'spawn_particle', 300, TRUE);


-- ============================================================================
-- ADD CHAT COLORS TO SHOP
-- ============================================================================
-- IMPORTANT: Item name MUST match exactly with configs/hub/colors.cfg "name" value
-- The cost in colors.cfg is for display only - the actual price is in this table

INSERT INTO {PREFIX}items_v2 (category_id, name, description, type, price, is_active) VALUES
-- Basic colors (100 credits)
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Alice Blue', 'Alice Blue chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Aqua', 'Aqua chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Beige', 'Beige chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Blue', 'Blue chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Brown', 'Brown chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Coral', 'Coral chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Cyan', 'Cyan chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Green', 'Green chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Pink', 'Pink chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Red', 'Red chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'White', 'White chat color', 'chat_color', 100, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Yellow', 'Yellow chat color', 'chat_color', 150, TRUE),

-- Premium colors (150-300 credits)
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Blue Violet', 'Blue Violet chat color', 'chat_color', 150, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Chartreuse', 'Chartreuse chat color', 'chat_color', 150, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Crimson', 'Crimson chat color', 'chat_color', 150, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Deep Pink', 'Deep Pink chat color', 'chat_color', 200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Fuchsia', 'Fuchsia chat color', 'chat_color', 200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Gold', 'Gold chat color', 'chat_color', 300, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Hot Pink', 'Hot Pink chat color', 'chat_color', 200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Lime', 'Lime chat color', 'chat_color', 150, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Magenta', 'Magenta chat color', 'chat_color', 200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Orange', 'Orange chat color', 'chat_color', 150, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Orange Red', 'Orange Red chat color', 'chat_color', 200, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Turquoise', 'Turquoise chat color', 'chat_color', 150, TRUE),

-- Rare/TF2 quality colors (500+ credits)
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Community', 'TF2 Community quality color', 'chat_color', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Genuine', 'TF2 Genuine quality color', 'chat_color', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Strange', 'TF2 Strange quality color', 'chat_color', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Vintage', 'TF2 Vintage quality color', 'chat_color', 500, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Haunted', 'TF2 Haunted quality color', 'chat_color', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Unique', 'TF2 Unique quality color', 'chat_color', 750, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Selfmade', 'TF2 Selfmade quality color', 'chat_color', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Unusual', 'TF2 Unusual quality color', 'chat_color', 1000, TRUE),
((SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors'), 'Valve', 'TF2 Valve quality color', 'chat_color', 2000, TRUE);


-- ============================================================================
-- PLAYER ITEM MANAGEMENT
-- ============================================================================

-- Give an item to a player (by SteamID)
INSERT INTO {PREFIX}player_items_v2 (steamid, item_id, purchase_price)
SELECT 'STEAM_0:1:12345678', id, 0
FROM {PREFIX}items_v2 
WHERE name = 'Gold' AND category_id = (SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Chat Colors');

-- Give all items in a category to a player
INSERT INTO {PREFIX}player_items_v2 (steamid, item_id, purchase_price)
SELECT 'STEAM_0:1:12345678', id, 0
FROM {PREFIX}items_v2 
WHERE category_id = (SELECT id FROM {PREFIX}categories_v2 WHERE name = 'Tags');

-- Remove an item from a player (soft delete)
UPDATE {PREFIX}player_items_v2 
SET deleted_at = CURRENT_TIMESTAMP 
WHERE steamid = 'STEAM_0:1:12345678' 
AND item_id = (SELECT id FROM {PREFIX}items_v2 WHERE name = 'Gold');

-- Check what a player owns
SELECT i.name, i.type, c.name AS category, pi.purchased_at
FROM {PREFIX}player_items_v2 pi
JOIN {PREFIX}items_v2 i ON pi.item_id = i.id
JOIN {PREFIX}categories_v2 c ON i.category_id = c.id
WHERE pi.steamid = 'STEAM_0:1:12345678' AND pi.deleted_at IS NULL
ORDER BY c.sort_order, i.name;


-- ============================================================================
-- UTILITY QUERIES
-- ============================================================================

-- Update item price
UPDATE {PREFIX}items_v2 SET price = 1500 WHERE name = 'Gold';

-- Deactivate an item (won't show in shop but owners keep it)
UPDATE {PREFIX}items_v2 SET is_active = FALSE WHERE name = 'Old Item';

-- Count items per category
SELECT c.name, COUNT(i.id) AS item_count
FROM {PREFIX}categories_v2 c
LEFT JOIN {PREFIX}items_v2 i ON c.id = i.category_id AND i.is_active = TRUE
GROUP BY c.id
ORDER BY c.sort_order;

-- Find items not in config files (orphaned)
SELECT i.* FROM {PREFIX}items_v2 i
JOIN {PREFIX}categories_v2 c ON i.category_id = c.id
WHERE c.name = 'Tags' AND i.is_active = TRUE;

-- Give credits to a player
UPDATE {PREFIX}players_v2 SET credits = credits + 1000 WHERE steamid = 'STEAM_0:1:12345678';

-- View top credit holders
SELECT steamid, name, credits FROM {PREFIX}players_v2 ORDER BY credits DESC LIMIT 10;
