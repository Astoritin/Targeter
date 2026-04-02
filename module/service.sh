#!/system/bin/sh
MODDIR=${0%/*}

MOD_ID="Targeter"
MOD_DESC="Auto add new user packages to Tricky Store scope."

CONFIG_DIR="/data/adb/targeter"
TARGET_LIST="/data/adb/tricky_store/target.txt"

EXCLUDE="$CONFIG_DIR/exclude.txt"
MARK_FILE="$CONFIG_DIR/mark.txt"

IS_MAGISK=false
[ -z "$KSU" ] && [ -z "$APATCH" ] && command -v magisk >/dev/null 2>&1 && IS_MAGISK=true

SNAPSHOT_PACKAGES="$CONFIG_DIR/.snapshot_packages"
SNAPSHOT_PACKAGES_NOW="$CONFIG_DIR/.snapshot_packages_now"
PACKAGES_AUTO_ADD="$CONFIG_DIR/.packages_auto_add"
PACKAGES_SKIP_ADD="$CONFIG_DIR/.packages_skip_add"

append() {
    if [ -z "$1" ]; then
        msg "Invalid content: $1"
        return 1
    elif [ ! -f "$2" ]; then
        msg "Not a file: $2"
        return 2
    fi

    [ -n "$(tail -c1 "$2")" ] && echo >> "$2"
    echo "$1" >> "$2"
}

remove() {
    if [ -z "$1" ]; then
        msg "Invalid content: $1"
        return 1
    elif [ ! -f "$2" ]; then
        msg "Not a file: $2"
        return 2
    fi

    output_sed=$(sed -i "/^${1}$/d" "$2" 2>&1)
    result_sed=$?

    if [ "$result_sed" -eq 0 ]; then
        msg "Remove $1 from $2 done"
        return 0
    else
        msg "Failed to remove $1 from $2 ($result_sed)" "e"
        [ -n "$output_sed" ] && msg "$output_sed"
    fi
}

sort_packages() { pm list packages -3 | sed 's/package://' | grep -v '^$' | sort; }

update_description() { [ -n "$1" ] || return 1; sed -i "s/^description=.*/description=$1/" "$MODDIR/module.prop"; }

check_exist_in_scope() { [ -n "$1" ] || return 2; grep -qxF "$1" "$2" || grep -qxF "${1}?" "$2" || grep -qxF "${1}!" "$2"; }

check_exist_in_denylist() { [ -n "$1" ] || return 2; magisk --denylist ls | grep "$1"; }

msg() { log -p "${2:-i}" -t "$MOD_ID" "$1"; }

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

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

msg "${MOD_ID} started"

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

    MARK=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$MARK_FILE" 2>/dev/null)

    if [ -n "$NEW_ADD_PACKAGES" ]; then
        msg "Detect new add package(s)"
        echo "$NEW_ADD_PACKAGES" | while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            msg "Process: $pkg"

            if check_exist_in_scope "$pkg" "$EXCLUDE"; then
                msg "${pkg}: exists in exclude list already"
                if [ "$IS_MAGISK" = true ]; then
                    if magisk --denylist rm "$pkg"; then
                        msg "Removed from denylist: ${pkg}"
                    else
                        msg "Failed to remove from denylist: ${pkg} ($?)" "e"
                    fi
                fi
                if check_exist_in_scope "$pkg" "$TARGET_LIST"; then
                    clean_duplicate_items "$TARGET_LIST"
                    if remove "$pkg" "$TARGET_LIST"; then
                        msg "Removed from scope: ${pkg}"
                    else
                        msg "Failed to remove from scope: ${pkg} ($?)" "e"
                    fi
                fi
                if ! check_exist_in_scope "$pkg" "$PACKAGES_SKIP_ADD"; then
                    if append "$pkg" "$PACKAGES_SKIP_ADD"; then
                        msg "Skip record added: ${pkg}"
                    else
                        msg "Failed to add skip record: ${pkg} ($?)" "e"
                    fi
                    clean_duplicate_items "$PACKAGES_SKIP_ADD"
                fi
                continue
            fi

            if check_exist_in_scope "$pkg" "$TARGET_LIST"; then
                msg "${pkg}: exists in scope already"
            else
                pkg_ts=""
                case "$MARK" in
                '!' | '?' ) pkg_ts="${pkg}${MARK}" ;;
                *) pkg_ts="$pkg" ;;
                esac
                if append "$pkg_ts" "$TARGET_LIST"; then
                    msg "Scope added: ${pkg_ts}"
                else
                    msg "Failed to add to scope: ${pkg_ts} ($?)" "e"
                fi
                if append "$pkg" "$PACKAGES_AUTO_ADD"; then
                    msg "Auto add record added: ${pkg}"
                else
                    msg "Failed to add to auto add record: ${pkg} ($?)" "e"
                fi
                clean_duplicate_items "$TARGET_LIST"
                clean_duplicate_items "$PACKAGES_AUTO_ADD"
            fi

            if [ "$IS_MAGISK" = true ]; then
                check_exist_in_denylist "$pkg" && msg "${pkg}: exists in denylist already"
                magisk --denylist add "$pkg" && msg "Denylist added: $pkg"
            fi
        done
    fi

    if [ -n "$REMOVED_PACKAGES" ]; then
        msg "Detect new remove package(s)"
        echo "$REMOVED_PACKAGES" | while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            msg "Process: $pkg"

            if grep -qxF "$pkg" "$PACKAGES_AUTO_ADD"; then
                msg "${pkg}: exists in auto add record already"
                remove "$pkg" "$PACKAGES_AUTO_ADD"
                [ "$IS_MAGISK" = true ] && magisk --denylist rm "$pkg" && msg "Denylist removed: $pkg"
                if grep -qxF "$pkg" "$TARGET_LIST"; then
                    msg "${pkg}: exist in scope already"
                    if remove "$pkg" "$TARGET_LIST";
                        msg "Removed from scope: ${pkg}"
                    else
                        msg "Failed to remove from scope: ${pkg} ($?)" "e"
                    fi
                else
                    for mark in '!' '?'; do
                        pkgm="${pkg}${mark}"
                        if grep -qxF "$pkgm" "$TARGET_LIST"; then
                            msg "Process scope item: ${pkgm}"
                            pkgm=$(echo "$pkgm" | sed 's/[.!?]/\\&/g')
                            if remove "$pkgm" "$TARGET_LIST"; then
                                msg "Removed from scope: ${pkg}"
                            else
                                msg "Failed to remove from scope: ${pkg} ($?)" "e"
                            fi
                            break
                        fi
                    done
                fi
            fi
            if grep -qxF "$pkg" "$PACKAGES_SKIP_ADD"; then
                msg "${pkg}: exists in skip add record already"
                if remove "$pkg" "$PACKAGES_SKIP_ADD"; then
                    msg "Removed from auto add record: ${pkg}"
                else
                    msg "Failed to remove from auto add record: ${pkg} ($?)" "e"
                fi
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

    case "$MARK" in
        '!') desc_mark="Certificate Generate";;
        '?') desc_mark="Leaf Hack";;
        *) desc_mark="N\/A";;
    esac
    
    if [ "$total_auto_add" -gt 0 ] || [ "$total_skip_add" -gt 0 ]; then
        mod_desc="${mod_desc}, auto: ${total_auto_add} (${desc_mark}), skip: ${total_skip_add}/${total_exclude}, custom: ${total_custom}"
    fi

    [ "$total_denylist" -gt 0 ] && mod_desc="${mod_desc}, ✅Denylist: ${total_denylist}"
    
    update_description "[${mod_desc}] $MOD_DESC"

    mv "$SNAPSHOT_PACKAGES_NOW" "$SNAPSHOT_PACKAGES"
    sleep 5
done
