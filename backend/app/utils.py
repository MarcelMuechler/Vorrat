def escape_like(term: str) -> str:
    """Escape SQL LIKE/ILIKE wildcards so a search term is matched literally.

    Use with `.ilike(f"%{escape_like(term)}%", escape="\\")`.
    """
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def normalize_barcode(code: str | None) -> str | None:
    """Trim whitespace so a scanner/keyboard adding stray leading or trailing
    whitespace doesn't cause an otherwise-identical barcode to mismatch.
    Cross-format (EAN/UPC) normalization is a separate, harder problem --
    not attempted here."""
    if code is None:
        return None
    stripped = code.strip()
    return stripped or None


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
