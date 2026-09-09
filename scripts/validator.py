import os
import re
import sys

# Folder containing your unpacked Power Apps solution
SOURCE_FOLDER = sys.argv[1] if len(sys.argv) > 1 else "."

# Required publisher prefix
REQUIRED_PREFIX = "cmdspp_"

# Match Power Platform style names (prefix_name)
OBJECT_PATTERN = r"\b[a-zA-Z][a-zA-Z0-9]*_[a-zA-Z0-9_]+\b"

invalid_objects = []

for root, dirs, files in os.walk(SOURCE_FOLDER):

    for file in files:

        # Scan only text-based files
        if not file.endswith((".json", ".xml", ".yaml", ".yml", ".txt")):
            continue

        file_path = os.path.join(root, file)

        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

            matches = set(re.findall(OBJECT_PATTERN, content))

            for name in matches:

                # Skip valid prefix
                if name.startswith(REQUIRED_PREFIX):
                    continue

                # Flag everything else
                invalid_objects.append((name, file_path))

        except Exception as e:
            print(f"Could not read: {file_path}")
            print(e)

# Remove duplicates
invalid_objects = sorted(set(invalid_objects))

if invalid_objects:

    print("\n❌ PREFIX VALIDATION FAILED")
    print(f"Expected prefix: {REQUIRED_PREFIX}\n")

    for name, file_path in invalid_objects:
        print(f"  ❌ {name}")
        print(f"     {file_path}")

    print(f"\nFound {len(invalid_objects)} invalid object(s).")
    sys.exit(1)

else:

    print("\n✅ PREFIX VALIDATION PASSED")
    print(f"All detected objects use the '{REQUIRED_PREFIX}' prefix.")
    sys.exit(0)
