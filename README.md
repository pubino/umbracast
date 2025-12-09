# UmbraCast

UmbraCast generates a web page of links for students to share their screens with a presenter, powered by [VDO.ninja](https://vdo.ninja).

## Features

- Single page with student list showing Share and View buttons
- Screen-only sharing (no webcam)
- High quality video with audio disabled
- CSV import for student roster
- CLI tool for generating static deployments

## Installation

```bash
# Clone with VDO.ninja submodule
git clone --recurse-submodules https://github.com/YOUR_USERNAME/umbracast.git

# Or if already cloned without submodules:
git submodule update --init --recursive
```

## Quick Start

### Option 1: Use the Interactive Page

1. Open `index.html` in a browser
2. (Optional) Import a CSV file with student names
3. Share the page URL with students
4. Students click **Share** next to their name
5. Presenter clicks **View** to display on projector

### Option 2: Generate Static Files with CLI

```bash
./umbracast.sh generate -c students.csv -o ./public
```

Then deploy the `./public` folder to your web server.

## CLI Usage

```
./umbracast.sh <command> [OPTIONS]
```

### Commands

| Command | Description |
|---------|-------------|
| `generate` | Generate ready-to-use HTML/CSS files |
| `init-vdo` | Initialize VDO.ninja submodule for self-hosting |
| `help` | Show help message |

### Generate Options

| Option | Description | Default |
|--------|-------------|---------|
| `-u, --url URL` | VDO.ninja base URL | `https://vdo.ninja` |
| `-r, --room PREFIX` | Room prefix for stream IDs | `classroom_` |
| `-t, --title TITLE` | Page title | `UmbraCast` |
| `-s, --subtitle TEXT` | Page subtitle | Click your name... |
| `-o, --output DIR` | Output directory | `./dist` |
| `-c, --csv FILE` | CSV file with student names | - |
| `-n, --no-header` | CSV has no header row | has header |
| `--column NUM` | Column index for names (0-based) | `0` |
| `--students "A,B,C"` | Comma-separated student names | - |
| `-p, --password PASS` | Room password (prevents interlopers) | - |
| `-h, --help` | Show help | - |

### Examples

```bash
# Generate with default synthetic students
./umbracast.sh generate -o ./public

# Custom VDO.ninja URL and room prefix
./umbracast.sh generate -u https://myserver.edu/vdo -r "math101_"

# From CSV file (first column = names, has header)
./umbracast.sh generate -c students.csv -o ./public

# From CSV with names in second column, no header
./umbracast.sh generate -c roster.csv --column 1 -n

# Inline student list
./umbracast.sh generate --students "Alice,Bob,Carol,David"

# Initialize VDO.ninja submodule for self-hosting
./umbracast.sh init-vdo

# Full example for deployment with password protection
./umbracast.sh generate \
  -u https://yourserver.edu/present/vdo.ninja \
  -r "orf309_" \
  -t "ORF 309 Screen Share" \
  -c roster.csv \
  -p "ClassSecret123" \
  -o ./deploy
```

## CSV Format

The importer accepts standard CSV files:

**Single column:**
```
Alice Chen
Bob Martinez
Carol Johnson
```

**With header:**
```
Name,Email,Section
Alice Chen,alice@univ.edu,001
Bob Martinez,bob@univ.edu,002
```

**Multi-column (use `--column` to select):**
```
ID,Student Name,Major
1,Alice Chen,Math
2,Bob Martinez,CS
```

## Web Interface Features

The interactive `index.html` page includes:

- **Base URL configuration** - Change VDO.ninja server on the fly
- **CSV import** - Drag and drop or file picker
- **Header toggle** - For CSVs with/without headers
- **Column selector** - Auto-detects "name" columns

## Self-Hosting VDO.ninja

VDO.ninja is included as a git submodule. To use it:

```bash
# Ensure submodule is initialized
git submodule update --init --recursive

# Copy to your web server
cp -r vdo.ninja /path/to/webserver/vdo.ninja

# Generate with your server URL
./umbracast.sh generate -u https://yourserver.com/vdo.ninja -o ./public
```

VDO.ninja is purely client-side and uses public TURN/STUN servers by default, so it works without server-side configuration.
