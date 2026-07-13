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
