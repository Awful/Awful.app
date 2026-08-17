#!/bin/bash
# scrub-lists.sh <udid> [release]
#
# Rewrites list-view content in the app's Core Data cache to deterministic
# fake data from scrub-data/*.txt, so real bookmark titles, private-forum
# thread titles, PM subjects and usernames don't leak into screenshots.
# Also stamps every relevant refresh timestamp to "just refreshed" so the
# app doesn't re-scrape the real data mid-capture. Cache-only: any later
# network refresh restores real data.
#
# Kept real: thread $THREAD_ID, poll thread $POLL_THREAD_ID, the forum's own
# name, and user $OWN_USER_ID (all from common.sh, env-overridable).
#
# Runs inside set-theme.sh's terminated window (app dead, cfprefsd stopped);
# the preamble repeats both preconditions so it's safe standalone too.
#
# "release" mode deletes the bumped timestamps so the next real launch
# refreshes (and un-fakes the lists) promptly.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

UDID="${1:?usage: scrub-lists.sh <udid> [release]}"
MODE="${2:-scrub}"
DATA_DIR="$SCRIPT_DIR/scrub-data"

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null) \
    || { echo "!! scrub: no data container for $BUNDLE_ID on $UDID"; exit 1; }
PLIST="$CONTAINER/Library/Preferences/$BUNDLE_ID.plist"
DB="$CONTAINER/Library/Application Support/CachedForumData/AwfulCache.sqlite"

xcrun simctl spawn "$UDID" launchctl stop com.apple.cfprefsd.xpc.daemon 2>/dev/null || true

# The keys RefreshMinder consults before re-scraping each list (bookmarks and
# PM inbox: 10 min; forums list: 6 h; announcements: 20 h). The background PM
# refresher also checks the inbox key 20-110s after every launch.
REFRESH_KEYS=(
    com.awfulapp.Awful.LastBookmarksRefreshDate
    LastPrivateMessageInboxRefreshDate
    com.awfulapp.Awful.LastForumRefreshDate
    com.awfulapp.Awful.LastAnnouncementsRefreshDate
)

# plutil treats "." in key paths as dict nesting; escape to address flat keys.
escape_keypath() { printf '%s' "${1//./\\.}"; }

if [ "$MODE" = "release" ]; then
    for k in "${REFRESH_KEYS[@]}"; do
        plutil -remove "$(escape_keypath "$k")" "$PLIST" 2>/dev/null || true
    done
    if [ -f "$DB" ]; then
        sqlite3 "$DB" >/dev/null "PRAGMA busy_timeout=5000;
            UPDATE ZFORUM SET ZLASTREFRESH=NULL, ZLASTFILTEREDREFRESH=NULL
            WHERE ZFORUMID='$FORUM_ID';"
    fi
    echo "  scrub released: next real launch will refresh"
    exit 0
fi

if [ ! -f "$DB" ]; then
    echo "!! scrub: cache store missing at $DB"
    echo "!! a fresh container would fetch REAL titles on launch — refusing to capture"
    exit 1
fi

# ---- Load the wordlists ----------------------------------------------------
# Comment/blank lines skipped; single quotes doubled for SQL.

count_entries() {
    local n=0 line
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in \#*|"") continue ;; esac
        n=$((n+1))
    done < "$1"
    echo "$n"
}

emit_table() { # emit_table <temp-table> <file>
    local tbl="$1" file="$2" i=0 line esc
    echo "CREATE TEMP TABLE $tbl (i INTEGER PRIMARY KEY, w TEXT NOT NULL);"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in \#*|"") continue ;; esac
        esc=$(printf '%s' "$line" | sed "s/'/''/g")
        echo "INSERT INTO $tbl VALUES($i, '$esc');"
        i=$((i+1))
    done < "$file"
}

for f in titles usernames subjects announcements tags; do
    [ -f "$DATA_DIR/$f.txt" ] || { echo "!! scrub: missing $DATA_DIR/$f.txt"; exit 1; }
done
for f in titles usernames subjects; do
    if [ "$(count_entries "$DATA_DIR/$f.txt")" = "0" ]; then
        echo "!! scrub: $DATA_DIR/$f.txt has no entries — refusing to capture real data"
        exit 1
    fi
done

# The forums enforce their own maximums, so a fake longer than these renders a
# cell that no real account can produce — the screenshot then "tests" wrapping
# or truncation that will never happen. Warn rather than fail: the captures are
# still usable, they just overstate one case.
check_len() { # check_len <file> <max>
    awk -v max="$2" -v f="$1" '
        !/^[[:space:]]*#/ && NF && length($0) > max {
            printf "!! scrub: %s line %d is %d chars, over the %d limit: %s\n",
                   f, NR, length($0), max, $0
        }' "$1"
}
check_len "$DATA_DIR/titles.txt" 75      # thread titles
check_len "$DATA_DIR/subjects.txt" 85    # PM subjects
check_len "$DATA_DIR/usernames.txt" 18   # account names

# ---- Rewrite the store -----------------------------------------------------
# Core Data timestamps are seconds since 2001-01-01. Touched rows get
# lastModifiedDate=now so CachePruner's 7-day sweep can't delete them
# mid-session (list sort orders never use lastModifiedDate, so no reordering).
NOW_CD=$(( $(date +%s) - 978307200 ))
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

sqlite3 "$DB" >/dev/null <<SQL
PRAGMA busy_timeout = 5000;
BEGIN IMMEDIATE;

$(emit_table t_titles "$DATA_DIR/titles.txt")
$(emit_table t_usernames "$DATA_DIR/usernames.txt")
$(emit_table t_subjects "$DATA_DIR/subjects.txt")
$(emit_table t_ann "$DATA_DIR/announcements.txt")
$(emit_table t_tags "$DATA_DIR/tags.txt")

-- Threads shown in the Bookmarks and forum-$FORUM_ID lists, minus the
-- deliberately-shown detail threads. Rank by threadID for determinism.
CREATE TEMP TABLE t_thread_rank AS
SELECT Z_PK AS pk,
       ROW_NUMBER() OVER (ORDER BY CAST(ZTHREADID AS INTEGER)) - 1 AS rn
FROM ZTHREAD
WHERE (ZBOOKMARKED = 1
       OR ZFORUM IN (SELECT Z_PK FROM ZFORUM WHERE ZFORUMID = '$FORUM_ID'))
  AND ZTHREADID NOT IN ('$THREAD_ID', '$POLL_THREAD_ID');

UPDATE ZTHREAD SET
    ZTITLE = (SELECT w FROM t_titles WHERE i =
        (SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK)
        % (SELECT COUNT(*) FROM t_titles)),
    ZLASTPOSTAUTHORNAME = (SELECT w FROM t_usernames WHERE i =
        ((SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK) * 7 + 3)
        % (SELECT COUNT(*) FROM t_usernames)),
    ZSECONDARYTHREADTAG = NULL,
    -- Rating squares render from bundled Vote<n> images keyed on the digits
    -- in ratingImageBasename; spread 0-5 stars across the list.
    ZRATING = ((SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK) * 5 + 2) % 6,
    ZRATINGIMAGEBASENAME = CASE
        ((SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK) * 5 + 2) % 6
        WHEN 0 THEN NULL
        ELSE ((((SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK) * 5 + 2) % 6) || 'stars')
    END,
    -- Unread variety: unseen rows show "Posted by <author>" and no badge;
    -- seen rows show "Killed by" and a badge of totalReplies+1-seenPosts
    -- (gray when 0). Buckets give a mix of unseen / fully-read / 1 / a few /
    -- dozens / huge, clamped so seenPosts stays within 1..totalReplies+1.
    ZSEENPOSTS = CASE (SELECT rn FROM t_thread_rank WHERE pk = ZTHREAD.Z_PK) % 8
        WHEN 0 THEN 0
        WHEN 3 THEN 0
        WHEN 1 THEN ZTOTALREPLIES + 1
        WHEN 2 THEN MAX(1, ZTOTALREPLIES)
        WHEN 4 THEN MAX(1, ZTOTALREPLIES + 1 - 12)
        WHEN 5 THEN MAX(1, ZTOTALREPLIES + 1 - 99)
        WHEN 6 THEN MAX(1, ZTOTALREPLIES + 1 - 1206)
        ELSE MAX(1, ZTOTALREPLIES + 1 - 6)
    END,
    ZLASTMODIFIEDDATE = $NOW_CD
WHERE Z_PK IN (SELECT pk FROM t_thread_rank);

-- Keep the stored unread flag consistent with the model's derivation
-- (anyUnreadPosts = seenPosts > 0 && unreadPosts > 0); it drives the
-- "unread only" bookmark filter.
UPDATE ZTHREAD SET
    ZANYUNREADPOSTS = (ZSEENPOSTS > 0 AND ZTOTALREPLIES + 1 - ZSEENPOSTS > 0)
WHERE Z_PK IN (SELECT pk FROM t_thread_rank);

-- Swap tags by repointing at tag rows already cached in THIS store (tag
-- images load from the network by name; unknown names render as the empty
-- placeholder). tags.txt narrows the pool when it intersects the cache.
CREATE TEMP TABLE t_tag_pool AS
SELECT Z_PK AS pk,
       ROW_NUMBER() OVER (ORDER BY ZIMAGENAME) - 1 AS rn
FROM ZTHREADTAG
WHERE ZIMAGENAME IS NOT NULL AND ZIMAGENAME <> ''
  AND ((SELECT COUNT(*) FROM ZTHREADTAG z JOIN t_tags t ON z.ZIMAGENAME = t.w) = 0
       OR ZIMAGENAME IN (SELECT w FROM t_tags));

UPDATE ZTHREAD SET ZTHREADTAG = (
    SELECT pk FROM t_tag_pool
    WHERE rn = CAST(ZTHREAD.ZTHREADID AS INTEGER)
               % (SELECT COUNT(*) FROM t_tag_pool))
WHERE Z_PK IN (SELECT pk FROM t_thread_rank)
  AND EXISTS (SELECT 1 FROM t_tag_pool);

-- Usernames that can surface in list cells: PM senders (the cell reads
-- User.username via the from-relationship first, rawFromUsername only as
-- fallback) and authors of scrubbed threads (unseen rows show "Posted by
-- <author.username>"). Rename the User rows — never the account's own.
CREATE TEMP TABLE t_user_rank AS
SELECT Z_PK AS pk,
       ROW_NUMBER() OVER (ORDER BY CAST(ZUSERID AS INTEGER)) - 1 AS rn
FROM ZUSER
WHERE ZUSERID <> '$OWN_USER_ID'
  AND (Z_PK IN (SELECT ZFROM FROM ZPRIVATEMESSAGE WHERE ZFROM IS NOT NULL)
       OR Z_PK IN (SELECT ZAUTHOR FROM ZTHREAD
                   WHERE Z_PK IN (SELECT pk FROM t_thread_rank)
                     AND ZAUTHOR IS NOT NULL));

UPDATE ZUSER SET
    ZUSERNAME = (SELECT w FROM t_usernames WHERE i =
        (SELECT rn FROM t_user_rank WHERE pk = ZUSER.Z_PK)
        % (SELECT COUNT(*) FROM t_usernames)),
    ZLASTMODIFIEDDATE = $NOW_CD
WHERE Z_PK IN (SELECT pk FROM t_user_rank);

CREATE TEMP TABLE t_pm_rank AS
SELECT Z_PK AS pk,
       ROW_NUMBER() OVER (ORDER BY CAST(ZMESSAGEID AS INTEGER)) - 1 AS rn
FROM ZPRIVATEMESSAGE;

UPDATE ZPRIVATEMESSAGE SET
    ZSUBJECT = (SELECT w FROM t_subjects WHERE i =
        (SELECT rn FROM t_pm_rank WHERE pk = ZPRIVATEMESSAGE.Z_PK)
        % (SELECT COUNT(*) FROM t_subjects)),
    ZRAWFROMUSERNAME = COALESCE(
        (SELECT ZUSERNAME FROM ZUSER WHERE Z_PK = ZPRIVATEMESSAGE.ZFROM),
        (SELECT w FROM t_usernames WHERE i =
            ((SELECT rn FROM t_pm_rank WHERE pk = ZPRIVATEMESSAGE.Z_PK) * 5 + 1)
            % (SELECT COUNT(*) FROM t_usernames))),
    ZLASTMODIFIEDDATE = $NOW_CD;

-- Announcements render atop thread lists.
UPDATE ZANNOUNCEMENT SET
    ZTITLE = (SELECT w FROM t_ann
              WHERE i = ZANNOUNCEMENT.ZLISTINDEX % (SELECT COUNT(*) FROM t_ann)),
    ZAUTHORUSERNAME = 'ForumStaff'
WHERE EXISTS (SELECT 1 FROM t_ann);

-- Forum thread-list staleness lives in the store itself (15-min window).
UPDATE ZFORUM SET ZLASTREFRESH = $NOW_CD, ZLASTFILTEREDREFRESH = $NOW_CD
WHERE ZFORUMID = '$FORUM_ID';

COMMIT;
SQL

N=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ZTHREAD
    WHERE (ZBOOKMARKED=1 OR ZFORUM IN (SELECT Z_PK FROM ZFORUM WHERE ZFORUMID='$FORUM_ID'))
      AND ZTHREADID NOT IN ('$THREAD_ID','$POLL_THREAD_ID');")
M=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ZPRIVATEMESSAGE;")
if [ "$N" = "0" ]; then
    echo "!! scrub: ZERO threads matched — bookmark/forum lists will refresh and show LIVE data"
fi
echo "  scrubbed: $N threads, $M PMs"

# Stamp "refreshed just now" so viewDidAppear refreshes and the background PM
# refresher stay quiet for the whole theme cycle. cfprefsd is stopped, so
# these writes stick (same dance as set-theme.sh).
for k in "${REFRESH_KEYS[@]}"; do
    kp=$(escape_keypath "$k")
    plutil -replace "$kp" -date "$NOW_ISO" "$PLIST" 2>/dev/null \
        || plutil -insert "$kp" -date "$NOW_ISO" "$PLIST"
done
