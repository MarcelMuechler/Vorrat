def escape_like(term: str) -> str:
    """Escape SQL LIKE/ILIKE wildcards so a search term is matched literally.

    Use with `.ilike(f"%{escape_like(term)}%", escape="\\")`.
    """
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _gtin_check_digit(digits: str) -> str:
    """GS1 mod-10 check digit for the payload of a GTIN (i.e. everything but
    the check digit itself). Weights alternate 3/1 from the right."""
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(digits)))
    return str(-total % 10)


def _upce_to_upca(code: str) -> str | None:
    """Expand a UPC-E (8 digits) to its UPC-A (12 digits) form, or None if the
    code isn't a valid UPC-E. The zero-suppression table is fixed by the GS1
    General Specifications."""
    system, data, check = code[0], code[1:7], code[7]
    if system not in ("0", "1"):
        return None
    last = data[5]
    if last in ("0", "1", "2"):
        body = f"{data[:2]}{last}0000{data[2:5]}"
    elif last == "3":
        body = f"{data[:3]}00000{data[3:5]}"
    elif last == "4":
        body = f"{data[:4]}00000{data[4]}"
    else:
        body = f"{data[:5]}0000{last}"
    upca = f"{system}{body}"
    # An EAN-8 is also 8 digits; GS1 reserves leading 0/1 in that space for
    # UPC-E, and requiring the check digit to match on expansion keeps a
    # stray EAN-8 from being mangled into a 13-digit code.
    return upca + check if _gtin_check_digit(upca) == check else None


def normalize_barcode(code: str | None) -> str | None:
    """Trim whitespace, and fold UPC codes into their equivalent EAN-13 form
    so the same physical barcode is one product no matter which format the
    scanner reported (#328): UPC-A is EAN-13 with a leading zero, and UPC-E is
    a zero-suppressed UPC-A. Anything else is returned as-is."""
    if code is None:
        return None
    stripped = code.strip()
    if not stripped:
        return None
    if stripped.isascii() and stripped.isdigit():
        if len(stripped) == 12:
            return "0" + stripped
        if len(stripped) == 8:
            upca = _upce_to_upca(stripped)
            if upca is not None:
                return "0" + upca
    return stripped


def escape_csv_formula_injection(value: str | None) -> str | None:
    """Escape CSV cells that could be interpreted as formulas by spreadsheet applications.

    Spreadsheets interpret cells starting with =, +, -, or @ (or preceding whitespace + one of these)
    as formulas. This escapes by prefixing with a single quote, which prevents formula injection.
    The data value itself is unchanged (spreadsheets display it without the quote).

    A value that already starts with a literal apostrophe is escaped too (by adding a second
    one) -- not because a leading apostrophe is itself dangerous, but so
    unescape_csv_formula_injection, which always strips exactly one leading apostrophe, can
    losslessly round-trip a real name like "'Nduja" through export -> import instead of
    corrupting it into "Nduja".

    Args:
        value: The cell value to escape, or None

    Returns:
        The value with a leading apostrophe if it starts with a formula character (or an
        apostrophe), otherwise unchanged.
    """
    if value is None:
        return value

    stripped = value.lstrip()
    if stripped and stripped[0] in ("=", "+", "-", "@", "'"):
        return "'" + value

    return value


def unescape_csv_formula_injection(value: str | None) -> str | None:
    """Remove the formula injection escape prefix if present.

    Reverses escape_csv_formula_injection by stripping the leading apostrophe that was
    added to prevent spreadsheet formula interpretation.

    Args:
        value: The cell value to unescape, or None

    Returns:
        The value without the leading apostrophe if it was added as an escape, otherwise unchanged.
    """
    if value is None:
        return value

    # Only strip the apostrophe if it's the very first character (escape was applied)
    return value[1:] if value.startswith("'") else value
