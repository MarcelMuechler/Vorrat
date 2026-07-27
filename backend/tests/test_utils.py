import pytest

from app.utils import (
    escape_csv_formula_injection,
    normalize_barcode,
    unescape_csv_formula_injection,
)


@pytest.mark.parametrize(
    "code,expected",
    [
        # UPC-A -> EAN-13 is just the leading zero.
        ("049000006346", "0049000006346"),
        ("012345000065", "0012345000065"),
        # UPC-E -> its expanded EAN-13 (same physical barcode).
        ("01234565", "0012345000065"),
        ("04252614", "0042100005264"),
        # Already EAN-13, or not a GTIN at all: untouched apart from trimming.
        ("  4006381333931 ", "4006381333931"),
        ("VORRAT-17", "VORRAT-17"),
        # EAN-8 is 8 digits too -- a non-0/1 prefix or a check digit that
        # doesn't survive the UPC-E expansion means it isn't a UPC-E.
        ("40170725", "40170725"),
        ("01234560", "01234560"),
        ("", None),
        (None, None),
    ],
)
def test_normalize_barcode_folds_upc_into_ean13(code, expected):
    assert normalize_barcode(code) == expected


@pytest.mark.parametrize(
    "value",
    ["=SUM(A1:A10)", "+1+1", "-2", "@SUM(A1:A10)", "'Nduja", "plain name", "", None],
)
def test_csv_formula_injection_escape_unescape_round_trips(value):
    assert unescape_csv_formula_injection(escape_csv_formula_injection(value)) == value


def test_escape_csv_formula_injection_prefixes_a_leading_apostrophe_too():
    # A name that's already apostrophe-prefixed must itself be escaped (by
    # doubling the apostrophe) -- otherwise unescape, which always strips
    # exactly one leading apostrophe, would corrupt it back to "Nduja".
    assert escape_csv_formula_injection("'Nduja") == "''Nduja"
