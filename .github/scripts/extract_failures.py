import re
import json


def parse_failure_entry(entry, job_name="unknown"):
    """
    Parse a raw failure string from the test runner.
    
    Input:  "[err]: test name in tests/unit/foo.tcl\nerror message"
    Output: {"test_name": "test name", "test_file": "tests/unit/foo.tcl", "error": "error message", "job": "..."}
    """
    m = re.match(
        r'\[err\]:\s*(.+?)\s+in\s+(tests/\S+\.tcl)\s*\n?(.*)',
        entry,
        re.DOTALL
    )
    if m:
        return {
            "test_name": m.group(1).strip(),
            "test_file": m.group(2).strip(),
            "error": m.group(3).strip(),
            "job": job_name,
        }

    # Fallback: couldn't parse, return raw
    return {
        "test_name": entry[:100],
        "test_file": "unknown",
        "error": entry,
        "job": job_name,
    }