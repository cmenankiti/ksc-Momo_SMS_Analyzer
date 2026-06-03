#!/usr/bin/env python3
"""
Parse modified_sms_v2.xml and convert SMS records into JSON objects.

Usage:
    python3 scripts/parse_sms_xml.py                    # writes to modified_sms_v2.json
    python3 scripts/parse_sms_xml.py -o output.json       # writes to output.json
    python3 scripts/parse_sms_xml.py my_backup.xml        # writes to my_backup.json
"""

import json
import sys
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


# Attributes whose string values should be converted to integers
_INT_FIELDS = {
    "protocol", "date", "type", "read", "status",
    "locked", "date_sent", "sub_id",
}

# Attributes whose string value "null" should become None
_NULLABLE_FIELDS = {"subject", "toa", "sc_toa"}


def parse_sms_element(sms: ET.Element) -> dict[str, Any]:
    """Convert an <sms> XML element into a cleaned dictionary."""
    record: dict[str, Any] = {}
    for key, value in sms.attrib.items():
        if key in _NULLABLE_FIELDS and value.lower() == "null":
            record[key] = None
        elif key in _INT_FIELDS:
            try:
                record[key] = int(value)
            except ValueError:
                record[key] = value  # fallback to string
        else:
            record[key] = value
    return record


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse SMS XML backup and output JSON."
    )
    parser.add_argument(
        "input",
        nargs="?",
        default="modified_sms_v2.xml",
        help="Path to the SMS XML file (default: modified_sms_v2.xml)",
    )
    parser.add_argument(
        "-o", "--output",
        help="Output JSON file path (default: <input_name>.json)",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        default=True,
        help="Pretty-print JSON output (default: true)",
    )
    parser.add_argument(
        "--no-pretty",
        action="store_false",
        dest="pretty",
        help="Minify JSON output",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    try:
        tree = ET.parse(input_path)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Error: failed to parse XML: {e}", file=sys.stderr)
        sys.exit(1)

    if root.tag != "smses":
        print(
            f"Warning: expected root element <smses>, got <{root.tag}>",
            file=sys.stderr,
        )

    # Collect metadata from root element
    metadata: dict[str, Any] = {}
    for key in ("count", "backup_set", "backup_date", "type"):
        if key in root.attrib:
            val: Any = root.attrib[key]
            if key == "count":
                try:
                    val = int(val)
                except ValueError:
                    pass
            metadata[key] = val

    # Parse every <sms> child
    records = [parse_sms_element(sms) for sms in root.findall("sms")]

    output: dict[str, Any] = {
        "metadata": metadata,
        "sms_count": len(records),
        "sms": records,
    }

    json_str = json.dumps(
        output,
        indent=2 if args.pretty else None,
        ensure_ascii=False,
    )

    output_path = Path(args.output) if args.output else input_path.with_suffix(".json")
    output_path.write_text(json_str, encoding="utf-8")
    print(f"Wrote {len(records)} SMS records to {output_path}")


if __name__ == "__main__":
    main()
