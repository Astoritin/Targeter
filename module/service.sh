#!/system/bin/sh
MODDIR=${0%/*}

MOD_DESC="Auto add new user packages to Tricky Store scope and Magisk denylist."

CONFIG_DIR="/data/adb/targeter"
TARGET_LIST="/data/adb/tricky_store/target.txt"
EXCLUDE="$CONFIG_DIR/exclude.txt"
MARK=$(cat "$CONFIG_DIR/mark.txt")

SNAPSHOT_PACKAGES="$CONFIG_DIR/.snapshot_packages"
SNAPSHOT_PACKAGES_NOW="$CONFIG_DIR/.snapshot_packages_now"
PACKAGES_AUTO_ADD="$CONFIG_DIR/.packages_auto_add"
PACKAGES_SKIP_ADD="$CONFIG_DIR/.packages_skip_add"

IS_MAGISK=false
[ -z "$KSU" ] && [ -z "$APATCH" ] && command -v magisk >/dev/null 2>&1 && IS_MAGISK=true

sort_packages() { pm list packages -3 | sed 's/package://' | grep -v '^$' | sort; }

update_description() { [ -n "$1" ] || return 1; sed -i "s/^description=.*/description=$1/" "$MODDIR/module.prop"; }

check_exist_item() { [ -n "$1" ] || return 2; grep -qxF "${1}" "$2" || grep -qxF "${1}?" "$2" || grep -qxF "${1}!" "$2"; }

clean_duplicate_items() {
    [ -f "$1" ] || return 1

    awk '
    NF == 0 { next }
    {
        line = $0
        orig = line
        if (sub(/!$/, "", line)) prio = 3
        else if (sub(/\?$/, "", line)) prio = 2
        else prio = 1
        
        if (!(line in seen)) {
            seen[line] = prio
            order[++n] = line
            full[line] = orig
        } else if (prio > seen[line]) {
            seen[line] = prio
            full[line] = orig
        }
    }
    END { for (i=1; i<=n; i++) print full[order[i]] }
    ' "$1" > "${1}.tmp" && mv "${1}.tmp" "$1"
}

append() {
    value="$1"
    conf="$2"
    
    [ -s "$conf" ] && [ "$(tail -c 1 "$conf" | wc -l)" -eq 0 ] && printf '\n' >> "$conf"
    printf '%s\n' "$value" >> "$conf"
}

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

sort_packages > "$SNAPSHOT_PACKAGES"
[ ! -f "$PACKAGES_AUTO_ADD" ] && touch "$PACKAGES_AUTO_ADD"
[ ! -f "$PACKAGES_SKIP_ADD" ] && touch "$PACKAGES_SKIP_ADD"

update_description "$MOD_DESC"

while true; do

    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ ! -f "$TARGET_LIST" ]; then
        info_status=""
        if [ -f "$MODDIR/disable" ]; then
            info_status="❌Module disabled"
        elif [ -f "$MODDIR/remove" ]; then
            info_status="🗑️Reboot to remove module"
        elif [ ! -f "$TARGET_LIST" ]; then
            info_status="❌target.txt does not exist, wait 5s"
        fi
        update_description "[$info_status] $MOD_DESC"
        sleep 5
        continue
    fi

    sort_packages > "$SNAPSHOT_PACKAGES_NOW"

    NEW_ADD_PACKAGES=$(grep -v -F -x -f "$SNAPSHOT_PACKAGES" "$SNAPSHOT_PACKAGES_NOW")
    REMOVED_PACKAGES=$(grep -v -F -x -f "$SNAPSHOT_PACKAGES_NOW" "$SNAPSHOT_PACKAGES")

    if [ -n "$NEW_ADD_PACKAGES" ]; then
        echo "$NEW_ADD_PACKAGES" | while IFS= read -r package; do
            [ -z "$package" ] && continue
            if check_exist_item "$package" "$TARGET_LIST"; then
                continue
            elif check_exist_item "$package" "$EXCLUDE"; then
                if ! check_exist_item "$package" "$PACKAGES_SKIP_ADD"; then
                    append "$package" "$PACKAGES_SKIP_ADD"
                fi
                clean_duplicate_items "$PACKAGES_SKIP_ADD"
                continue
            else
                package_ts=""
                case "$MARK" in
                    '!' | '?') package_ts="${package}${MARK}" ;;
                    *) package_ts="$package" ;;
                esac
                append "$package_ts" "$TARGET_LIST"
                append "$package" "$PACKAGES_AUTO_ADD"
                [ "$IS_MAGISK" = true ] && magisk --denylist add "$package"
                clean_duplicate_items "$TARGET_LIST"
                clean_duplicate_items "$PACKAGES_AUTO_ADD"
            fi
        done
    fi

    if [ -n "$REMOVED_PACKAGES" ]; then
        echo "$REMOVED_PACKAGES" | while IFS= read -r package; do
            [ -z "$package" ] && continue            
            if grep -qxF "$package" "$PACKAGES_AUTO_ADD"; then
                sed -i "/^${package}$/d" "$PACKAGES_AUTO_ADD"
                [ "$IS_MAGISK" = true ] && magisk --denylist rm "$package"
                if grep -qxF "$package" "$TARGET_LIST"; then
                    sed -i "/^${package}$/d" "$TARGET_LIST"
                else
                    for mark in '!' '?'; do
                        package_marked="${package}${mark}"
                        if grep -qxF "$package_marked" "$TARGET_LIST"; then
                            package_marked=$(printf '%s' "$package_marked" | sed 's/[.!?]/\\&/g')
                            sed -i "/^${package_marked}$/d" "$TARGET_LIST"
                            break
                        fi
                    done
                fi
            fi
            if grep -qxF "$package" "$PACKAGES_SKIP_ADD"; then
                sed -i "/^${package}$/d" "$PACKAGES_SKIP_ADD"
            fi
        done
    fi
    
    total_denylist=0
    total_target_list=0
    total_auto_add=0
    total_skip_add=0
    total_exclude=0

    [ "$IS_MAGISK" = true ] && total_denylist=$(magisk --denylist ls | grep -c '[^[:space:]]')
    [ -f "$TARGET_LIST" ] && total_target_list=$(grep -c '[^[:space:]]' "$TARGET_LIST")
    [ -f "$PACKAGES_AUTO_ADD" ] && total_auto_add=$(grep -c '[^[:space:]]' "$PACKAGES_AUTO_ADD")
    [ -f "$PACKAGES_SKIP_ADD" ] && total_skip_add=$(grep -c '[^[:space:]]' "$PACKAGES_SKIP_ADD")
    [ -f "$EXCLUDE" ] && total_exclude=$(grep -c '[^[:space:]]' "$EXCLUDE")
    total_custom=$((total_target_list - total_auto_add))

    mod_desc="✅Tricky Store: ${total_target_list}"
    
    if [ "$total_auto_add" -gt 0 ] || [ "$total_skip_add" -gt 0 ]; then
        mod_desc="${mod_desc} (auto: ${total_auto_add}, custom: ${total_custom}, skip: ${total_skip_add})"
    fi

    [ "$total_denylist" -gt 0 ] && mod_desc="${mod_desc}, ✅Magisk Denylist: ${total_denylist}"
    [ "$total_exclude" -gt 0 ] && mod_desc="${mod_desc}, ✅Excluded: ${total_exclude}"
    
    update_description "[${mod_desc}] $MOD_DESC"

    mv "$SNAPSHOT_PACKAGES_NOW" "$SNAPSHOT_PACKAGES"
    sleep 5
done
