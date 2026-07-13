def escape_like(term: str) -> str:
    """Escape SQL LIKE/ILIKE wildcards so a search term is matched literally.

    Use with `.ilike(f"%{escape_like(term)}%", escape="\\")`.
    """
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
