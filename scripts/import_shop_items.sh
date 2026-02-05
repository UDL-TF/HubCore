#!/bin/bash
# ============================================================================
# Quick Shop Item Batch Import Script
# ============================================================================
# This script adds all default items to your shop database.
# Run this once after setting up your database.
#
# Usage: ./import_shop_items.sh
#
# Make sure to configure your .env file first!
# ============================================================================

set -e

# Load .env file
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
else
    echo "Error: .env file not found!"
    echo "Copy .env.example to .env and configure it first."
    exit 1
fi

MANAGER="$(dirname "$0")/shop_manager.sh"

echo "========================================"
echo "HubCore Shop Item Import"
echo "========================================"
echo ""

# Initialize categories first
echo "Step 1: Initializing categories..."
$MANAGER init-categories
echo ""

# Add Tags (matching configs/hub/tags.cfg)
echo "Step 2: Adding Tags..."
$MANAGER add-item "Tags" "[VIP]" 500 "VIP chat tag"
$MANAGER add-item "Tags" "[MVP]" 750 "MVP chat tag"
$MANAGER add-item "Tags" "[Pro]" 1000 "Pro player tag"
$MANAGER add-item "Tags" "[Elite]" 1500 "Elite player tag"
$MANAGER add-item "Tags" "[Legend]" 2000 "Legendary player tag"
$MANAGER add-item "Tags" "[Champion]" 3000 "Champion tag"
$MANAGER add-item "Tags" "[Noob]" 100 "Noob tag"
$MANAGER add-item "Tags" "[Rookie]" 250 "Rookie tag"
echo ""

# Add Trails (matching configs/hub/trails.cfg)
echo "Step 3: Adding Trails..."
$MANAGER add-item "Trails" "Spectrum Cycle" 1000 "Rainbow cycling trail"
$MANAGER add-item "Trails" "Color Wave" 1500 "Smooth color wave effect"
$MANAGER add-item "Trails" "Velocity Based" 2000 "Color changes with speed"
$MANAGER add-item "Trails" "Breathing Green" 1200 "Pulsing green trail"
$MANAGER add-item "Trails" "Flashing Red" 1500 "Rapid flashing red trail"
$MANAGER add-item "Trails" "Yellow Bow" 1800 "Yellow bow-width effect"
echo ""

# Add Footprints (matching hardcoded g_Footprints[] in footprints.sp)
echo "Step 4: Adding Footprints..."
$MANAGER add-item "Footprints" "Blue" 500 "Blue footsteps"
$MANAGER add-item "Footprints" "Light Blue" 500 "Light blue footsteps"
$MANAGER add-item "Footprints" "Yellow" 500 "Yellow footsteps"
$MANAGER add-item "Footprints" "Corrupted Green" 750 "Corrupted green footsteps"
$MANAGER add-item "Footprints" "Dark Green" 500 "Dark green footsteps"
$MANAGER add-item "Footprints" "Lime" 600 "Lime green footsteps"
$MANAGER add-item "Footprints" "Brown" 400 "Brown footsteps"
$MANAGER add-item "Footprints" "Oak Tree Brown" 450 "Oak brown footsteps"
$MANAGER add-item "Footprints" "Flames" 1500 "Flaming footsteps"
$MANAGER add-item "Footprints" "Cream" 400 "Cream colored footsteps"
$MANAGER add-item "Footprints" "Pink" 600 "Pink footsteps"
$MANAGER add-item "Footprints" "Satan's Blue" 1000 "Dark satanic blue footsteps"
$MANAGER add-item "Footprints" "Purple" 700 "Purple footsteps"
$MANAGER add-item "Footprints" "4 8 15 16 23 42" 2000 "Lost numbers footsteps"
$MANAGER add-item "Footprints" "Ghost In The Machine" 1500 "Ghostly tech footsteps"
$MANAGER add-item "Footprints" "Holy Flame" 2000 "Holy flame footsteps"
echo ""

# Add Spawn Particles (matching hardcoded g_ParticleNames[] in spawn_particles.sp)
echo "Step 5: Adding Spawn Particles..."
$MANAGER add-item "Spawn Particles" "Achievement" 500 "Achievement unlock effect"
$MANAGER add-item "Spawn Particles" "Big Explosion" 750 "Large explosion on spawn"
$MANAGER add-item "Spawn Particles" "Biggest Explosion" 1000 "Massive explosion effect"
$MANAGER add-item "Spawn Particles" "Debris" 400 "Debris scatter effect"
$MANAGER add-item "Spawn Particles" "One Balloon" 300 "Single balloon spawn"
$MANAGER add-item "Spawn Particles" "Blood Fountain" 800 "Blood fountain effect"
$MANAGER add-item "Spawn Particles" "Bonk!" 600 "Bonk text effect"
$MANAGER add-item "Spawn Particles" "Burning Blue" 700 "Blue fire effect"
$MANAGER add-item "Spawn Particles" "Burning Red" 700 "Red fire effect"
$MANAGER add-item "Spawn Particles" "Gold Explosion" 1500 "Golden explosion"
$MANAGER add-item "Spawn Particles" "Coin Blue" 500 "Blue coin effect"
$MANAGER add-item "Spawn Particles" "Coin Large Blue" 750 "Large blue coin effect"
$MANAGER add-item "Spawn Particles" "Electric Blue" 900 "Electric shock effect"
$MANAGER add-item "Spawn Particles" "Bubbles" 400 "Bubble effect"
$MANAGER add-item "Spawn Particles" "Explosive Bubbles" 600 "Exploding bubbles"
$MANAGER add-item "Spawn Particles" "Purple Explosion" 1000 "Purple ghost explosion"
$MANAGER add-item "Spawn Particles" "Purple Firepit" 800 "Purple fire pit"
$MANAGER add-item "Spawn Particles" "Purple Small Firepit" 600 "Small purple fire"
$MANAGER add-item "Spawn Particles" "Purple Plate" 500 "Purple plate effect"
$MANAGER add-item "Spawn Particles" "Legendary Summon" 2500 "Boss summon effect"
$MANAGER add-item "Spawn Particles" "Small Ghosts" 1200 "Ghost spawn effect"
$MANAGER add-item "Spawn Particles" "Wood Explosion" 400 "Wood break effect"
$MANAGER add-item "Spawn Particles" "Wood Dust" 300 "Wood dust puff"
echo ""

# Sync Chat Colors from config
echo "Step 6: Syncing Chat Colors from config..."
$MANAGER sync-colors "$(dirname "$0")/../configs/hub/colors.cfg"
echo ""

echo "========================================"
echo "Import Complete!"
echo "========================================"
echo ""
echo "Summary by Category:"
$MANAGER list-cats
echo ""
echo "Chat Colors Summary:"
$MANAGER list-colors
