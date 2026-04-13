import re
from pathlib import Path

# ============================================================
# CONFIG
# ============================================================

MODE = "split"  # "split" or "merge"
BLOCK_LIMIT = 50
SOURCE_FILE = "block.txt"
INDEX_FILE = "index.md"

BLOCK_PATTERN = re.compile(r'^block\.(\d+)', re.MULTILINE)
SHARD_PATTERN = re.compile(r'block\.(\d+)-(\d+)\.properties')


# ============================================================
# HELPERS
# ============================================================

def find_comment_start(text, index):
    lines = text[:index].splitlines(keepends=True)
    pos = len(lines) - 1

    while pos >= 0:
        stripped = lines[pos].strip()

        if stripped.startswith("#") or stripped == "":
            pos -= 1
        else:
            break

    return sum(len(line) for line in lines[:pos + 1])


def should_skip_comment(comment: str) -> bool:
    c = comment.strip()

    if not c:
        return True

    lower = c.lower()

    # Skip shader preprocessor
    if lower.startswith(("if", "else", "endif")):
        return True

    # Skip known generic header
    if lower == "this is for minecraft 1.13 up to the current version.":
        return True

    # Skip decorative separators (#### ===== ---- etc)
    if re.search(r'(.)\1\1', c):  # same char repeated 3+ times
        return True

    # Skip ascii art / heavy unicode banners
    if re.search(r'[█╚╔╗╝║]', c):
        return True

    # Skip comments that are mostly symbols
    symbol_ratio = sum(1 for ch in c if not ch.isalnum() and not ch.isspace()) / len(c)
    if symbol_ratio > 0.6:
        return True

    return False


def extract_comments(text, index):
    lines = text[:index].splitlines()
    pos = len(lines) - 1
    comments = []

    while pos >= 0:
        stripped = lines[pos].strip()

        if stripped.startswith("#"):
            comment = stripped[1:].strip()

            if not should_skip_comment(comment):
                comments.append(comment)

            pos -= 1
        elif stripped == "":
            pos -= 1
        else:
            break

    comments.reverse()
    return comments


# ============================================================
# SPLIT MODE
# ============================================================

def split_file(base_dir: Path):
    source_path = base_dir / SOURCE_FILE

    if not source_path.exists():
        print("block.txt not found.")
        return

    text = source_path.read_text(encoding="utf-8")
    matches = list(BLOCK_PATTERN.finditer(text))

    index_entries = []

    current_start_idx = None
    current_start_id = None
    block_count = 0
    shard_comments = []

    for i, match in enumerate(matches):
        block_id = match.group(1)
        block_pos = match.start()

        adjusted_pos = find_comment_start(text, block_pos)
        comments = extract_comments(text, block_pos)

        if block_count == 0:
            current_start_idx = adjusted_pos
            current_start_id = block_id
            shard_comments = []

        # Collect comments
        for c in comments:
            if c not in shard_comments:
                shard_comments.append(c)

        block_count += 1
        is_last = i == len(matches) - 1

        if block_count == BLOCK_LIMIT or is_last:
            if not is_last:
                next_pos = find_comment_start(text, matches[i + 1].start())
                end_idx = next_pos
                end_id = block_id
            else:
                end_idx = len(text)
                end_id = block_id

            chunk = text[current_start_idx:end_idx]

            shard_name = f"block.{current_start_id}-{end_id}.properties"
            (base_dir / shard_name).write_text(chunk, encoding="utf-8")
            print(f"Created {shard_name}")

            index_entries.append((shard_name, shard_comments.copy()))

            block_count = 0

    # Write index.md
    index_path = base_dir / INDEX_FILE
    with index_path.open("w", encoding="utf-8") as f:
        for name, comments in index_entries:
            f.write(f"{name}:\n")
            for c in comments:
                f.write(f"- {c}\n")
            f.write("\n")

    print("Created index.md")


# ============================================================
# MERGE MODE
# ============================================================

def merge_files(base_dir: Path):
    shards = []

    for file in base_dir.glob("block.*-*.properties"):
        m = SHARD_PATTERN.match(file.name)
        if m:
            start_id = int(m.group(1))
            shards.append((start_id, file))

    if not shards:
        print("No shard files found.")
        return

    shards.sort(key=lambda x: x[0])

    merged_text = ""

    for _, file in shards:
        merged_text += file.read_text(encoding="utf-8")

    (base_dir / SOURCE_FILE).write_text(merged_text, encoding="utf-8")
    print("Merged into block.txt")


# ============================================================
# ENTRY
# ============================================================

def main():
    base_dir = Path(__file__).parent.resolve()

    if MODE == "split":
        split_file(base_dir)

    elif MODE == "merge":
        merge_files(base_dir)

    else:
        print("Invalid MODE")


if __name__ == "__main__":
    main()
