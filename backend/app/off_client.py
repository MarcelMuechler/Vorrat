import httpx

from app.config import settings


async def lookup_off(barcode: str) -> dict | None:
    """Look up a barcode on Open Food Facts. Returns a Product-shaped dict or None.

    Never raises: any network error, timeout, or "not found" response from OFF
    is treated the same way as a genuine miss.
    """
    url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
    headers = {"User-Agent": settings.off_user_agent}
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError):
        # ValueError covers response.json() raising JSONDecodeError, e.g. OFF
        # returning a 200 with an HTML rate-limit/maintenance page instead of
        # JSON — should be treated as a miss too, not an unhandled 500.
        return None

    if data.get("status") != 1:
        return None

    off_product = data.get("product", {})
    name = off_product.get("product_name") or off_product.get("product_name_en")
    if not name:
        return None

    category = (off_product.get("categories") or "").split(",")[0].strip() or None
    image_url = off_product.get("image_front_small_url") or off_product.get("image_url")

    # OFF already normalizes the free-text "quantity" field (e.g. "33 cl")
    # into a numeric product_quantity + unit when its data is populated --
    # no need to parse the free-text version ourselves. Both are frequently
    # missing/empty for a given product, hence the permissive fallback to
    # omitting them entirely rather than guessing.
    amount = off_product.get("product_quantity")
    quantity_unit = off_product.get("product_quantity_unit") or None

    return {
        "barcode": barcode,
        "name": name,
        "category": category,
        "image_url": image_url,
        "amount": float(amount) if amount else None,
        "quantity_unit": quantity_unit,
    }
