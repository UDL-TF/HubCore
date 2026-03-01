#!/bin/bash
# ============================================================================
# HubCore Shop Management Script
# ============================================================================
# Usage: ./shop_manager.sh <command> [options]
#
# Commands:
#   add-item      Add a new item to the shop
#   give-item     Give an item to a player
#   list-items    List items in a category
#   list-cats     List all categories
#   update-price  Update item price
#   give-credits  Give credits to a player
#   sync-colors   Sync colors.cfg prices with database
#
# Environment Variables (or use .env file):
#   DB_HOST       - MySQL host (default: localhost)
#   DB_PORT       - MySQL port (default: 3306)
#   DB_NAME       - Database name
#   DB_USER       - Database user
#   DB_PASS       - Database password
#   DB_PREFIX     - Table prefix (default: hub_)
# ============================================================================

set -e

# Load .env file if exists (check same directory first, then parent)
if [ -f "$(dirname "$0")/.env" ]; then
    source "$(dirname "$0")/.env"
elif [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
fi

# Default values
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-}"
DB_PASS="${DB_PASS:-}"
DB_PREFIX="${DB_PREFIX:-hub_}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run MySQL query
mysql_query() {
    if [ -z "$DB_PASS" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" -e "$1"
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1"
    fi
}

mysql_query_silent() {
    if [ -z "$DB_PASS" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" -sN -e "$1"
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "$1"
    fi
}

# Check database connection
check_db() {
    if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
        echo -e "${RED}Error: Database configuration not set${NC}"
        echo "Set DB_NAME, DB_USER, DB_PASS environment variables or create .env file"
        exit 1
    fi
    
    if ! mysql_query "SELECT 1" &>/dev/null; then
        echo -e "${RED}Error: Cannot connect to database${NC}"
        exit 1
    fi
}

# Print usage
usage() {
    echo -e "${BLUE}HubCore Shop Manager${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add-item <category> <name> <price> [description] [type]"
    echo "      Add a new item to the shop"
    echo "      Categories: Tags, Trails, Footprints, 'Spawn Particles', 'Chat Colors', 'Name Colors'"
    echo ""
    echo "  give-item <steamid> <item_name>"
    echo "      Give an item to a player for free"
    echo ""
    echo "  remove-item <steamid> <item_name>"
    echo "      Remove an item from a player (soft delete)"
    echo ""
    echo "  list-items [category]"
    echo "      List all items or items in a specific category"
    echo ""
    echo "  list-colors"
    echo "      List all chat/name colors with prices"
    echo ""
    echo "  list-cats"
    echo "      List all categories"
    echo ""
    echo "  update-price <item_name> <new_price>"
    echo "      Update an item's price"
    echo ""
    echo "  give-credits <steamid> <amount>"
    echo "      Give credits to a player"
    echo ""
    echo "  check-player <steamid>"
    echo "      Check a player's inventory and credits"
    echo ""
    echo "  init-categories"
    echo "      Initialize default shop categories"
    echo ""
    echo "  sync-colors [colors.cfg path]"
    echo "      Sync colors.cfg costs with database prices"
    echo ""
    echo "Examples:"
    echo "  $0 add-item Tags '[Premium]' 500 'Premium tag'"
    echo "  $0 give-item 'STEAM_0:1:12345678' Gold"
    echo "  $0 give-credits 'STEAM_0:1:12345678' 1000"
    echo "  $0 sync-colors ../configs/hub/colors.cfg"
}

# Add an item
cmd_add_item() {
    local category="$1"
    local name="$2"
    local price="$3"
    local description="${4:-$name item}"
    local type="${5:-}"
    
    if [ -z "$category" ] || [ -z "$name" ] || [ -z "$price" ]; then
        echo -e "${RED}Usage: $0 add-item <category> <name> <price> [description] [type]${NC}"
        exit 1
    fi
    
    # Auto-detect type from category if not provided
    if [ -z "$type" ]; then
        case "$category" in
            "Tags") type="tag";;
            "Trails") type="trail";;
            "Footprints") type="footprint";;
            "Spawn Particles") type="spawn_particle";;
            "Chat Colors") type="chat_color";;
            "Name Colors") type="name_color";;
            *) type="item";;
        esac
    fi
    
    # Escape single quotes in name and description
    local escaped_name=$(echo "$name" | sed "s/'/''/g")
    local escaped_desc=$(echo "$description" | sed "s/'/''/g")
    
    # Check if item already exists
    local exists=$(mysql_query_silent "SELECT COUNT(*) FROM ${DB_PREFIX}items_v2 i
                   JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                   WHERE c.name = '$category' AND i.name = '$escaped_name';")
    
    if [ "$exists" -gt "0" ]; then
        echo -e "${YELLOW}~ Item '$name' already exists in $category (skipped)${NC}"
        return 0
    fi
    
    local query="INSERT INTO ${DB_PREFIX}items_v2 (category_id, name, description, type, price, is_active) 
                 SELECT id, '$escaped_name', '$escaped_desc', '$type', $price, TRUE 
                 FROM ${DB_PREFIX}categories_v2 WHERE name = '$category';"
    
    if mysql_query "$query" 2>/dev/null; then
        echo -e "${GREEN}✓ Added item '$name' to $category for $price credits${NC}"
    else
        echo -e "${RED}✗ Failed to add item '$name'${NC}"
    fi
}

# Give item to player
cmd_give_item() {
    local steamid="$1"
    local item_name="$2"
    
    if [ -z "$steamid" ] || [ -z "$item_name" ]; then
        echo -e "${RED}Usage: $0 give-item <steamid> <item_name>${NC}"
        exit 1
    fi
    
    local query="INSERT INTO ${DB_PREFIX}player_items_v2 (steamid, item_id, purchase_price)
                 SELECT '$steamid', id, 0 FROM ${DB_PREFIX}items_v2 WHERE name = '$item_name'
                 ON DUPLICATE KEY UPDATE deleted_at = NULL;"
    
    if mysql_query "$query"; then
        echo -e "${GREEN}✓ Gave '$item_name' to $steamid${NC}"
    else
        echo -e "${RED}✗ Failed to give item${NC}"
        exit 1
    fi
}

# Remove item from player
cmd_remove_item() {
    local steamid="$1"
    local item_name="$2"
    
    if [ -z "$steamid" ] || [ -z "$item_name" ]; then
        echo -e "${RED}Usage: $0 remove-item <steamid> <item_name>${NC}"
        exit 1
    fi
    
    local query="UPDATE ${DB_PREFIX}player_items_v2 pi
                 JOIN ${DB_PREFIX}items_v2 i ON pi.item_id = i.id
                 SET pi.deleted_at = CURRENT_TIMESTAMP 
                 WHERE pi.steamid = '$steamid' AND i.name = '$item_name';"
    
    if mysql_query "$query"; then
        echo -e "${GREEN}✓ Removed '$item_name' from $steamid${NC}"
    else
        echo -e "${RED}✗ Failed to remove item${NC}"
        exit 1
    fi
}

# List items
cmd_list_items() {
    local category="$1"
    
    if [ -z "$category" ]; then
        echo -e "${BLUE}All Shop Items:${NC}"
        echo ""
        local query="SELECT i.id, c.name AS category, i.name, i.price, IF(i.is_active, 'Yes', 'No') AS active
                     FROM ${DB_PREFIX}items_v2 i
                     JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                     ORDER BY c.sort_order, i.price;"
    else
        echo -e "${BLUE}Items in $category:${NC}"
        echo ""
        local query="SELECT i.id, i.name, i.price, i.type, IF(i.is_active, 'Yes', 'No') AS active
                     FROM ${DB_PREFIX}items_v2 i
                     JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                     WHERE c.name = '$category'
                     ORDER BY i.price;"
    fi
    
    mysql_query "$query"
    
    echo ""
    echo -e "${BLUE}Item counts per category:${NC}"
    mysql_query "SELECT c.name AS category, COUNT(i.id) AS items, 
                 SUM(CASE WHEN i.is_active THEN 1 ELSE 0 END) AS active
                 FROM ${DB_PREFIX}categories_v2 c
                 LEFT JOIN ${DB_PREFIX}items_v2 i ON c.id = i.category_id
                 GROUP BY c.id ORDER BY c.sort_order;"
}

# List categories
cmd_list_cats() {
    echo -e "${BLUE}Shop Categories:${NC}"
    mysql_query "SELECT id, name, description, sort_order, IF(is_active, 'Yes', 'No') AS active 
                 FROM ${DB_PREFIX}categories_v2 ORDER BY sort_order;"
}

# List chat colors specifically
cmd_list_colors() {
    echo -e "${BLUE}Chat/Name Colors in Shop:${NC}"
    echo ""
    mysql_query "SELECT i.id, c.name AS category, i.name, i.price, IF(i.is_active, 'Yes', 'No') AS active
                 FROM ${DB_PREFIX}items_v2 i
                 JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                 WHERE c.name IN ('Chat Colors', 'Name Colors')
                 ORDER BY c.name, i.price, i.name;"
    
    local total=$(mysql_query_silent "SELECT COUNT(*) FROM ${DB_PREFIX}items_v2 i
                  JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                  WHERE c.name IN ('Chat Colors', 'Name Colors') AND i.is_active = TRUE;")
    echo ""
    echo -e "${GREEN}Total active chat/name colors: $total${NC}"
}

# Update item price
cmd_update_price() {
    local item_name="$1"
    local new_price="$2"
    
    if [ -z "$item_name" ] || [ -z "$new_price" ]; then
        echo -e "${RED}Usage: $0 update-price <item_name> <new_price>${NC}"
        exit 1
    fi
    
    local query="UPDATE ${DB_PREFIX}items_v2 SET price = $new_price WHERE name = '$item_name';"
    
    if mysql_query "$query"; then
        echo -e "${GREEN}✓ Updated '$item_name' price to $new_price credits${NC}"
    else
        echo -e "${RED}✗ Failed to update price${NC}"
        exit 1
    fi
}

# Give credits to player
cmd_give_credits() {
    local steamid="$1"
    local amount="$2"
    
    if [ -z "$steamid" ] || [ -z "$amount" ]; then
        echo -e "${RED}Usage: $0 give-credits <steamid> <amount>${NC}"
        exit 1
    fi
    
    local query="UPDATE ${DB_PREFIX}players_v2 SET credits = credits + $amount WHERE steamid = '$steamid';"
    
    if mysql_query "$query"; then
        echo -e "${GREEN}✓ Gave $amount credits to $steamid${NC}"
        
        # Show new balance
        local new_balance=$(mysql_query_silent "SELECT credits FROM ${DB_PREFIX}players_v2 WHERE steamid = '$steamid';")
        echo -e "${BLUE}New balance: $new_balance credits${NC}"
    else
        echo -e "${RED}✗ Failed to give credits${NC}"
        exit 1
    fi
}

# Check player inventory
cmd_check_player() {
    local steamid="$1"
    
    if [ -z "$steamid" ]; then
        echo -e "${RED}Usage: $0 check-player <steamid>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Player: $steamid${NC}"
    echo ""
    
    # Get player info
    local credits=$(mysql_query_silent "SELECT credits FROM ${DB_PREFIX}players_v2 WHERE steamid = '$steamid';")
    echo -e "Credits: ${GREEN}$credits${NC}"
    echo ""
    
    echo "Owned Items:"
    mysql_query "SELECT c.name AS category, i.name AS item
                 FROM ${DB_PREFIX}player_items_v2 pi
                 JOIN ${DB_PREFIX}items_v2 i ON pi.item_id = i.id
                 JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                 WHERE pi.steamid = '$steamid' AND pi.deleted_at IS NULL
                 ORDER BY c.sort_order, i.name;"
}

# Initialize categories
cmd_init_categories() {
    echo -e "${BLUE}Initializing shop categories...${NC}"
    
    local query="INSERT IGNORE INTO ${DB_PREFIX}categories_v2 (name, description, sort_order, is_active) VALUES
                 ('Tags', 'Chat tags displayed before player names', 1, TRUE),
                 ('Trails', 'Trail effects that follow players', 2, TRUE),
                 ('Footprints', 'Footstep effects when walking', 3, TRUE),
                 ('Spawn Particles', 'Particle effects on player spawn', 4, TRUE),
                 ('Chat Colors', 'Custom colors for chat messages', 5, TRUE),
                 ('Name Colors', 'Custom colors for player names', 6, TRUE);"
    
    if mysql_query "$query"; then
        echo -e "${GREEN}✓ Categories initialized${NC}"
        cmd_list_cats
    else
        echo -e "${RED}✗ Failed to initialize categories${NC}"
        exit 1
    fi
}

# Sync colors.cfg with database (Chat Colors + Name Colors)
cmd_sync_colors() {
    local config_file="${1:-$(dirname "$0")/../configs/hub/colors.cfg}"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Config file not found: $config_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Syncing colors from $config_file...${NC}"
    
    # Parse the config file and extract name/cost pairs
    local count=0
    local name=""
    local cost=""
    
    while IFS= read -r line; do
        # Remove whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        # Extract name
        if [[ $line =~ ^\"name\"[[:space:]]+\"(.+)\"$ ]]; then
            name="${BASH_REMATCH[1]}"
        fi
        
        # Extract cost
        if [[ $line =~ ^\"cost\"[[:space:]]+\"([0-9]+)\"$ ]]; then
            cost="${BASH_REMATCH[1]}"
        fi
        
        # If we have both name and cost, update/insert
        if [ -n "$name" ] && [ -n "$cost" ]; then
            # Escape single quotes in name
            local escaped_name=$(echo "$name" | sed "s/'/''/g")
            
            # Check if chat color item exists
            local exists=$(mysql_query_silent "SELECT COUNT(*) FROM ${DB_PREFIX}items_v2 i
                           JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                           WHERE c.name = 'Chat Colors' AND i.name = '$escaped_name';")
            
            if [ "$exists" -eq "0" ]; then
                # Insert new item
                local query="INSERT INTO ${DB_PREFIX}items_v2 (category_id, name, description, type, price, is_active)
                             SELECT id, '$escaped_name', '$escaped_name chat color', 'chat_color', $cost, TRUE
                             FROM ${DB_PREFIX}categories_v2 WHERE name = 'Chat Colors';"
                mysql_query "$query" 2>/dev/null
                echo -e "  ${GREEN}+ Added:${NC} $name ($cost credits)"
            else
                # Update existing item price
                local query="UPDATE ${DB_PREFIX}items_v2 i
                             JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                             SET i.price = $cost
                             WHERE c.name = 'Chat Colors' AND i.name = '$escaped_name';"
                mysql_query "$query" 2>/dev/null
                echo -e "  ${YELLOW}~ Updated:${NC} $name ($cost credits)"
            fi

            # Keep Name Colors category in sync with same palette and pricing.
            local exists_name=$(mysql_query_silent "SELECT COUNT(*) FROM ${DB_PREFIX}items_v2 i
                               JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                               WHERE c.name = 'Name Colors' AND i.name = '$escaped_name';")

            if [ "$exists_name" -eq "0" ]; then
                local query="INSERT INTO ${DB_PREFIX}items_v2 (category_id, name, description, type, price, is_active)
                             SELECT id, '$escaped_name', '$escaped_name name color', 'name_color', $cost, TRUE
                             FROM ${DB_PREFIX}categories_v2 WHERE name = 'Name Colors';"
                mysql_query "$query" 2>/dev/null
            else
                local query="UPDATE ${DB_PREFIX}items_v2 i
                             JOIN ${DB_PREFIX}categories_v2 c ON i.category_id = c.id
                             SET i.price = $cost
                             WHERE c.name = 'Name Colors' AND i.name = '$escaped_name';"
                mysql_query "$query" 2>/dev/null
            fi
            
            ((count++))
            name=""
            cost=""
        fi
    done < "$config_file"
    
    echo ""
    echo -e "${GREEN}✓ Synced $count colors${NC}"
}

# Main
main() {
    local command="$1"
    shift 2>/dev/null || true
    
    case "$command" in
        add-item)
            check_db
            cmd_add_item "$@"
            ;;
        give-item)
            check_db
            cmd_give_item "$@"
            ;;
        remove-item)
            check_db
            cmd_remove_item "$@"
            ;;
        list-items)
            check_db
            cmd_list_items "$@"
            ;;
        list-colors)
            check_db
            cmd_list_colors
            ;;
        list-cats)
            check_db
            cmd_list_cats
            ;;
        update-price)
            check_db
            cmd_update_price "$@"
            ;;
        give-credits)
            check_db
            cmd_give_credits "$@"
            ;;
        check-player)
            check_db
            cmd_check_player "$@"
            ;;
        init-categories)
            check_db
            cmd_init_categories
            ;;
        sync-colors)
            check_db
            cmd_sync_colors "$@"
            ;;
        help|--help|-h|"")
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
