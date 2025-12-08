#!/bin/bash
#
# UmbraCast - Classroom Screen Sharing
# https://github.com/steveseguin/vdo.ninja
#
# Usage: ./umbracast.sh <command> [OPTIONS]
#
set -e

VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values for generate command
BASE_URL="https://vdo.ninja"
ROOM_PREFIX="classroom_"
TITLE="UmbraCast"
SUBTITLE="Click your name to share your screen with the class"
OUTPUT_DIR="./dist"
CSV_FILE=""
HAS_HEADER=true
NAME_COLUMN=0
STUDENTS_INLINE=""
PASSWORD=""

show_banner() {
    echo -e "${BLUE}"
    echo "  _   _           _                ____          _   "
    echo " | | | |_ __ ___ | |__  _ __ __ _ / ___|__ _ ___| |_ "
    echo " | | | | '_ \` _ \| '_ \| '__/ _\` | |   / _\` / __| __|"
    echo " | |_| | | | | | | |_) | | | (_| | |__| (_| \__ \ |_ "
    echo "  \___/|_| |_| |_|_.__/|_|  \__,_|\____\__,_|___/\__|"
    echo -e "${NC}"
    echo "  Classroom Screen Sharing v${VERSION}"
    echo ""
}

usage() {
    show_banner
    cat << EOF
Usage: $(basename "$0") <command> [OPTIONS]

Commands:
  generate    Generate ready-to-use HTML/CSS files
  init-vdo    Initialize VDO.ninja submodule for self-hosting
  help        Show this help message

Run '$(basename "$0") <command> --help' for command-specific options.

Examples:
  $(basename "$0") generate -c students.csv -o ./public
  $(basename "$0") init-vdo
  $(basename "$0") generate --students "Alice,Bob,Carol"

EOF
    exit 0
}

usage_generate() {
    cat << EOF
Usage: $(basename "$0") generate [OPTIONS]

Generate ready-to-use HTML/CSS for classroom screen sharing.

Options:
  -u, --url URL           VDO.ninja base URL (default: https://vdo.ninja)
  -r, --room PREFIX       Room prefix for stream IDs (default: classroom_)
  -t, --title TITLE       Page title (default: "UmbraCast")
  -s, --subtitle TEXT     Page subtitle
  -o, --output DIR        Output directory (default: ./dist)
  -c, --csv FILE          CSV file with student names
  -n, --no-header         CSV has no header row (default: has header)
  --column NUM            Column index for names in CSV, 0-based (default: 0)
  --students "N1,N2,..."  Comma-separated list of student names
  -p, --password PASS     Room password (share with class to prevent interlopers)
  -h, --help              Show this help message

Examples:
  # Generate with default synthetic students
  $(basename "$0") generate -o ./public

  # Generate with custom URL and room prefix
  $(basename "$0") generate -u https://myserver.edu/vdo -r "math101_"

  # Generate from CSV file
  $(basename "$0") generate -c students.csv -o ./public

  # Generate from CSV with names in column 2 (0-indexed), no header
  $(basename "$0") generate -c roster.csv --column 1 -n

  # Generate with inline student list
  $(basename "$0") generate --students "Alice,Bob,Carol,David"

EOF
    exit 0
}

usage_init() {
    cat << EOF
Usage: $(basename "$0") init-vdo

Initialize the VDO.ninja git submodule for self-hosting.

Options:
  -h, --help   Show this help message

Example:
  $(basename "$0") init-vdo

The VDO.ninja files will be available in ./vdo.ninja after initialization.

EOF
    exit 0
}

# Function to convert name to URL-safe ID
name_to_id() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//' | cut -c1-30
}

# Function to parse CSV and extract names
parse_csv() {
    local file="$1"
    local col="$2"
    local skip_header="$3"
    local start_line=1

    if [[ "$skip_header" == "true" ]]; then
        start_line=2
    fi

    tail -n +$start_line "$file" | while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *\"* ]]; then
            echo "$line" | awk -v col="$col" '
            BEGIN { FPAT = "([^,]*)|\"[^\"]*\"" }
            {
                gsub(/^"|"$/, "", $(col+1))
                print $(col+1)
            }'
        else
            echo "$line" | cut -d',' -f$((col + 1))
        fi
    done | sed '/^[[:space:]]*$/d'
}

# Build student list as JSON
build_student_json() {
    local names=()

    if [[ -n "$CSV_FILE" ]]; then
        if [[ ! -f "$CSV_FILE" ]]; then
            echo -e "${RED}Error: CSV file not found: $CSV_FILE${NC}" >&2
            exit 1
        fi
        while IFS= read -r name; do
            [[ -n "$name" ]] && names+=("$name")
        done < <(parse_csv "$CSV_FILE" "$NAME_COLUMN" "$HAS_HEADER")
    elif [[ -n "$STUDENTS_INLINE" ]]; then
        IFS=',' read -ra names <<< "$STUDENTS_INLINE"
    else
        names=(
            "Alice Chen" "Bob Martinez" "Carol Johnson" "David Kim"
            "Emma Wilson" "Frank Brown" "Grace Lee" "Henry Davis"
            "Iris Patel" "Jack Thompson" "Katie Moore" "Liam Garcia"
            "Maya Anderson" "Noah Taylor" "Olivia White"
        )
    fi

    local id_list=""
    local json="["
    local first=true

    for name in "${names[@]}"; do
        name=$(echo "$name" | xargs)
        [[ -z "$name" ]] && continue

        local base_id=$(name_to_id "$name")
        [[ -z "$base_id" ]] && base_id="student"

        local count=$(echo "$id_list" | grep -c "^${base_id}$" || true)
        local id="$base_id"
        if [[ "$count" -gt 0 ]]; then
            id="${base_id}_$((count + 1))"
        fi
        id_list="${id_list}${base_id}"$'\n'

        [[ "$first" != "true" ]] && json+=","
        first=false

        local escaped_name="${name//\"/\\\"}"
        json+="\n            { \"name\": \"$escaped_name\", \"id\": \"$id\" }"
    done

    json+="\n        ]"
    echo -e "$json"
}

# Generate HTML
generate_html() {
    local student_json=$(build_student_json)

    cat << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$TITLE</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <h1>$TITLE</h1>
    <p class="subtitle">$SUBTITLE</p>

    <div class="student-list" id="studentList"></div>

    <div class="instructions">
        <h3>Instructions</h3>
        <ul>
            <li><strong>Students:</strong> Click the green <em>Share</em> button next to your name, then select your screen to share</li>
            <li><strong>Presenter:</strong> Click the blue <em>View</em> button to display a student's screen on the projector</li>
            <li>Audio is disabled - use your voice in the room</li>
            <li>Only screen sharing is enabled (no webcam)</li>
        </ul>
    </div>

    <script>
        const students = $student_json;

        const baseUrl = "$BASE_URL";

        // Room prefix with random slug generated at build time
        const roomPrefix = "${ROOM_PREFIX}${SESSION_ID}_";

        const password = "$PASSWORD";

        function generateShareUrl(studentId) {
            const streamId = roomPrefix + studentId;
            const pwParam = password ? \`&password=\${encodeURIComponent(password)}\` : '';
            return \`\${baseUrl}/?push=\${streamId}&screenshare&quality=2&audiobitrate=0&noaudio\${pwParam}\`;
        }

        function generateViewUrl(studentId) {
            const streamId = roomPrefix + studentId;
            const pwParam = password ? \`&password=\${encodeURIComponent(password)}\` : '';
            return \`\${baseUrl}/?view=\${streamId}&scene&codec=h264\${pwParam}\`;
        }

        function renderStudentList() {
            const container = document.getElementById('studentList');
            container.innerHTML = students.map(student => \`
                <div class="student-row">
                    <span class="student-name">
                        \${student.name}
                        <span class="student-id">#\${student.id}</span>
                    </span>
                    <a href="\${generateShareUrl(student.id)}" target="_blank" class="btn btn-share">Share</a>
                    <a href="\${generateViewUrl(student.id)}" target="_blank" class="btn btn-view">View</a>
                </div>
            \`).join('');
        }

        renderStudentList();
    </script>
</body>
</html>
HTMLEOF
}

# Generate CSS
generate_css() {
    cat << 'CSSEOF'
/* UmbraCast - Dark theme with planetary shadow aesthetics */

:root {
    --bg-primary: #0d0d1a;
    --bg-secondary: #121225;
    --bg-card: #1a1a2e;
    --text-primary: #ffffff;
    --text-secondary: #b8c5d6;
    --text-muted: #6b7a8f;
    --accent-primary: #e94560;
    --accent-secondary: #d4a574;
    --accent-share: #27ae60;
    --accent-view: #3498db;
    --border-color: #2a3f5f;
    --shadow: rgba(0, 0, 0, 0.4);
    --ring-gold: rgba(212, 165, 116, 0.15);
    --ring-silver: rgba(184, 197, 214, 0.1);
    --umbra: rgba(0, 0, 0, 0.7);
    --penumbra: rgba(0, 0, 0, 0.3);
}

* { box-sizing: border-box; }

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    max-width: 1000px;
    margin: 0 auto;
    padding: 30px 20px;
    background:
        radial-gradient(ellipse 200% 100% at 50% -50%, var(--ring-silver) 0%, transparent 50%),
        radial-gradient(ellipse 150% 80% at 50% -30%, var(--ring-gold) 0%, transparent 40%),
        linear-gradient(180deg, transparent 0%, var(--umbra) 10%, var(--penumbra) 20%, transparent 35%),
        linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
    min-height: 100vh;
    color: var(--text-primary);
    position: relative;
}

body::before {
    content: '';
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 200px;
    background: radial-gradient(ellipse 120% 200% at 50% 0%, transparent 45%, var(--umbra) 50%, transparent 55%);
    pointer-events: none;
    z-index: 0;
    opacity: 0.6;
}

h1 {
    text-align: center;
    color: var(--text-primary);
    margin-bottom: 8px;
    font-weight: 600;
    font-size: 2rem;
    letter-spacing: 2px;
    text-transform: uppercase;
    position: relative;
    z-index: 1;
    text-shadow: 0 2px 20px rgba(212, 165, 116, 0.3);
}

.subtitle {
    text-align: center;
    color: var(--text-secondary);
    margin-bottom: 30px;
    font-size: 1.1rem;
    position: relative;
    z-index: 1;
}

.student-list {
    background: var(--bg-card);
    border-radius: 12px;
    box-shadow: 0 8px 32px var(--shadow), inset 0 60px 60px -60px var(--umbra), inset 0 1px 0 rgba(255,255,255,0.05);
    overflow: hidden;
    border: 1px solid var(--border-color);
    position: relative;
    z-index: 1;
}

.student-list::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, transparent 0%, var(--ring-gold) 20%, var(--accent-secondary) 50%, var(--ring-gold) 80%, transparent 100%);
    opacity: 0.6;
}

.student-row {
    display: flex;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-color);
    transition: background 0.2s, box-shadow 0.2s;
    position: relative;
}

.student-row:last-child { border-bottom: none; }
.student-row:hover { background: rgba(212, 165, 116, 0.03); box-shadow: inset 4px 0 0 var(--accent-secondary); }

.student-name {
    flex: 1;
    font-size: 16px;
    font-weight: 500;
    color: var(--text-primary);
}

.student-id {
    color: var(--text-muted);
    font-size: 12px;
    margin-left: 10px;
    font-weight: normal;
    font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
}

.btn {
    padding: 10px 18px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
    text-decoration: none;
    margin-left: 10px;
    transition: transform 0.15s, box-shadow 0.2s;
    display: inline-block;
    position: relative;
}

.btn:hover { transform: translateY(-2px); }
.btn:active { transform: translateY(0); }

.btn-share {
    background: linear-gradient(135deg, #27ae60 0%, #2ecc71 100%);
    color: white;
    box-shadow: 0 4px 15px rgba(39, 174, 96, 0.3);
}

.btn-share:hover {
    background: linear-gradient(135deg, #219a52 0%, #27ae60 100%);
    box-shadow: 0 6px 20px rgba(39, 174, 96, 0.4);
}

.btn-view {
    background: linear-gradient(135deg, #2980b9 0%, #3498db 100%);
    color: white;
    box-shadow: 0 4px 15px rgba(52, 152, 219, 0.3);
}

.btn-view:hover {
    background: linear-gradient(135deg, #2472a4 0%, #2980b9 100%);
    box-shadow: 0 6px 20px rgba(52, 152, 219, 0.4);
}

.instructions {
    margin-top: 30px;
    padding: 20px 24px;
    background: rgba(212, 165, 116, 0.08);
    border-radius: 12px;
    border-left: 4px solid var(--accent-secondary);
    box-shadow: 0 4px 20px var(--shadow);
    position: relative;
    z-index: 1;
}

.instructions h3 {
    margin: 0 0 12px 0;
    color: var(--accent-secondary);
    font-size: 1rem;
}

.instructions ul {
    margin: 0;
    padding-left: 20px;
    color: var(--text-secondary);
    line-height: 1.7;
}

.instructions li { margin-bottom: 8px; }
.instructions strong { color: var(--text-primary); }
.instructions em { font-style: normal; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }

@media (max-width: 600px) {
    body { padding: 20px 15px; }
    body::before { height: 150px; }
    h1 { font-size: 1.6rem; letter-spacing: 1px; }
    h1 { font-size: 1.6rem; }
    .student-row { flex-wrap: wrap; padding: 14px 16px; }
    .student-name { width: 100%; margin-bottom: 12px; }
    .btn { margin-left: 0; margin-right: 10px; padding: 10px 16px; }
}
CSSEOF
}

# Command: generate
cmd_generate() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url) BASE_URL="$2"; shift 2 ;;
            -r|--room) ROOM_PREFIX="$2"; shift 2 ;;
            -t|--title) TITLE="$2"; shift 2 ;;
            -s|--subtitle) SUBTITLE="$2"; shift 2 ;;
            -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
            -c|--csv) CSV_FILE="$2"; shift 2 ;;
            -n|--no-header) HAS_HEADER=false; shift ;;
            --column) NAME_COLUMN="$2"; shift 2 ;;
            --students) STUDENTS_INLINE="$2"; shift 2 ;;
            -p|--password) PASSWORD="$2"; shift 2 ;;
            -h|--help) usage_generate ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; usage_generate ;;
        esac
    done

    # Generate random session ID at build time
    SESSION_ID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8)

    show_banner
    echo -e "Generating files..."
    echo -e "  Base URL:    ${YELLOW}$BASE_URL${NC}"
    echo -e "  Room prefix: ${YELLOW}${ROOM_PREFIX}${SESSION_ID}_${NC}"
    echo -e "  Output:      ${YELLOW}$OUTPUT_DIR${NC}"

    if [[ -n "$CSV_FILE" ]]; then
        echo -e "  CSV file:    ${YELLOW}$CSV_FILE${NC}"
    elif [[ -n "$STUDENTS_INLINE" ]]; then
        echo -e "  Students:    ${YELLOW}(inline list)${NC}"
    else
        echo -e "  Students:    ${YELLOW}(default synthetic)${NC}"
    fi
    echo ""

    mkdir -p "$OUTPUT_DIR"

    generate_html > "$OUTPUT_DIR/index.html"
    echo -e "${GREEN}✓${NC} Generated $OUTPUT_DIR/index.html"

    generate_css > "$OUTPUT_DIR/styles.css"
    echo -e "${GREEN}✓${NC} Generated $OUTPUT_DIR/styles.css"

    local count=$(grep -c '"name"' "$OUTPUT_DIR/index.html" || echo "0")

    echo ""
    echo -e "${GREEN}Done!${NC} Generated files for ${YELLOW}$count${NC} students."
    echo ""
    echo "To use:"
    echo "  1. Copy $OUTPUT_DIR/* to your web server"
    echo "  2. Open index.html in a browser"
    echo "  3. Students click Share, presenter clicks View"
}

# Command: init-vdo
cmd_init_vdo() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage_init ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; usage_init ;;
        esac
    done

    show_banner
    echo -e "Initializing VDO.ninja submodule..."
    echo ""

    if [[ -d "./vdo.ninja" ]] && [[ -n "$(ls -A ./vdo.ninja 2>/dev/null)" ]]; then
        echo -e "${YELLOW}VDO.ninja submodule already initialized.${NC}"
        echo ""
    else
        git submodule update --init --recursive
        echo ""
        echo -e "${GREEN}Done!${NC} VDO.ninja initialized in ${YELLOW}./vdo.ninja${NC}"
    fi

    echo "To deploy with your server:"
    echo "  1. Copy ./vdo.ninja contents to your web server"
    echo "  2. Use the -u option when generating:"
    echo "     ./umbracast.sh generate -u https://yourserver.com/vdo.ninja"
    echo ""
    echo "Note: VDO.ninja is client-side only and uses public TURN/STUN servers"
    echo "by default, so it works without server-side configuration."
}

# Main entry point
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        generate) cmd_generate "$@" ;;
        init-vdo|init) cmd_init_vdo "$@" ;;
        help|-h|--help) usage ;;
        --version|-v) echo "UmbraCast v${VERSION}"; exit 0 ;;
        *) echo -e "${RED}Unknown command: $cmd${NC}"; usage ;;
    esac
}

main "$@"
