import re
import json


def parse_failure_entry(entry, job_name="unknown"):
    """
    Parse a raw failure string from the test runner.
    """
    m = re.match(
        r'\[(\w+)\]:\s*(.+?)\s+in\s+(tests/\S+\.tcl)\s*\n?(.*)',
        entry,
        re.DOTALL
    )
    if m:
        return {
            "test_name": m.group(2).strip(),
            "test_file": m.group(3).strip(),
            "error": m.group(4).strip(),
            "job": job_name,
        }

    # Fallback: couldn't parse, return raw
    return {
        "test_name": entry[:100],
        "test_file": "unknown",
        "error": entry,
        "job": job_name,
    }