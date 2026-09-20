"""Read the specification list of a product page into custom attributes.

Many brands print the technical data of a product as a list of pairs:

    Frequency Response:   40 - 20.000 Hz
    Efficiency:           95 dB / 1W / 1 m
    Dimensions (W x H x D): 33 x 108 x 25 cm / 13 x 42,5 x 10 "
    Weight:               32 kg / 62 lbs each

The label names the attribute, and the value holds a number and a unit. This
module finds such pairs in the text of a stored page, matches the label to one
of a few custom attributes, and reads the value. It uses no language model: it
costs nothing to run, it gives the same answer every time, and every value
keeps the words of the page it was read from.

The rule for a doubtful value is to leave it out. A missing value is filled in
by a person later; a wrong value looks exactly like a right one. So a value is
refused when the unit is missing, when the numbers are outside a plausible
range, when a weight is given for a pair and not for one unit, and when the
order of the three dimensions is not stated.

Only the attributes that apply to the candidate's sub categories are written,
so a "Weight" line on the page of an amplifier is kept and an "Impedance" line
on the same page is not read as the impedance of a loudspeaker.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Tuple

# The source name in the provenance of a value read here.
SOURCE = "spec_list"

# Labels as the brands write them, in the languages of the shops in the first
# crawl. A label is matched as a whole, after the colon and any text in
# brackets are taken off, so "Input impedance" is not read as "Impedance".
LABELS: Dict[str, str] = {
    "frequency_response_range": (
        r"frequency (response|range)|frequenzgang|frequenzbereich|übertragungsbereich"
        r"|réponse en fréquence|reponse en frequence|bande passante"
        r"|risposta in frequenza|respuesta (de|en) frecuencia|frekvensgang|taajuusvaste"
    ),
    "sensitivity": (
        r"(sensitivity|efficiency)( \(.*\))?|empfindlichkeit|wirkungsgrad|kennschalldruck"
        r"|sensibilité|sensibilite|rendement|sensibilità|sensibilidad|herkkyys|känslighet|følsomhed"
    ),
    "nominal_impedance": (
        r"(nominal )?impedance|nennimpedanz|impedanz|impédance( nominale)?|impedenza( nominale)?"
        r"|impedancia( nominal)?|impedanssi|impedans"
    ),
    "loudspeaker_minimum_impedance": r"min(imum|\.)? impedance|minimale impedanz|impédance minimale",
    "weight": (
        r"(net )?weight( each| per (piece|unit|speaker))?|(netto)?gewicht( pro stück)?|poids( net)?"
        r"|peso( netto)?|paino|vikt|vægt"
    ),
    "dimensions": (
        r"dimensions?|size|abmessungen|maße|masse|dimensioni|dimensiones|mitat|mått|mål"
    ),
    "amplifier_output_power": (
        r"(rated |continuous |rms )?(output )?power( output)?|ausgangsleistung|nennleistung"
        r"|puissance( de sortie)?|potenza( di uscita)?|potencia( de salida)?"
    ),
}
LABEL_PATTERNS = {key: re.compile(rf"(?i)^({pattern})$") for key, pattern in LABELS.items()}

# A plausible range for each value, in the unit it is stored in.
RANGES = {
    "frequency_min": (1, 1000),
    "frequency_max": (1000, 200000),
    "loudspeaker_sensitivity": (70, 120),
    "headphone_sensitivity": (70, 140),
    "nominal_impedance": (1, 1000),
    "loudspeaker_minimum_impedance": (1, 64),
    "weight": (0.001, 500),
    "dimensions": (0.5, 400),
    "amplifier_output_power": (0.1, 5000),
}

MAX_LABEL = 60
MAX_VALUE = 160


def spec_pairs(text: str) -> Iterator[Tuple[str, str]]:
    """Every (label, value) pair in the text of a page, in page order.

    Three layouts are read: "Label: value" on one line, "Label:" with the value
    on the next line, and a table row "Label<TAB>value".
    """
    lines = [line.strip() for line in text.split("\n")]
    for index, line in enumerate(lines):
        if not line:
            continue
        if "\t" in line:
            label, _, value = line.partition("\t")
            if label.strip() and value.strip():
                yield label.strip(), value.strip()
                continue
        if line.endswith(":") and index + 1 < len(lines):
            yield line[:-1].strip(), lines[index + 1]
            continue
        label, sep, value = line.partition(":")
        if sep and value.strip() and len(label) <= MAX_LABEL:
            yield label.strip(), value.strip()


def _clean_label(label: str) -> Tuple[str, str]:
    """The label without brackets, and the bracket text, which may give an order."""
    hint = " ".join(re.findall(r"\(([^)]*)\)", label))
    bare = re.sub(r"\([^)]*\)", " ", label)
    bare = re.sub(r"[\s:*•·–—-]+$", "", re.sub(r"\s+", " ", bare)).strip()
    return bare, hint


def number(text: str) -> Optional[float]:
    """A number as a brand writes it: "20.000", "20,000", "42,5", "1.8"."""
    text = text.strip()
    if re.fullmatch(r"\d{1,3}([.,]\d{3})+", text):
        return float(re.sub(r"[.,]", "", text))
    try:
        return float(text.replace(",", "."))
    except ValueError:
        return None


NUMBER = r"\d+(?:[.,]\d+)*"


def _in_range(key: str, value: float) -> bool:
    low, high = RANGES[key]
    return low <= value <= high


def parse_frequency(value: str) -> Optional[dict]:
    """ "40 - 20.000 Hz", "20Hz – 20kHz", "38 Hz to 30 kHz (±3 dB)" """
    value = value.split("(")[0]
    match = re.search(
        rf"({NUMBER})\s*(k?hz)?\s*(?:-|–|—|to|bis|à|a|~)\s*({NUMBER})\s*(k?hz)",
        value, re.IGNORECASE,
    )
    if not match:
        return None
    low, low_unit, high, high_unit = match.groups()
    low_value, high_value = number(low), number(high)
    if low_value is None or high_value is None:
        return None
    high_unit = high_unit.lower()
    low_unit = (low_unit or high_unit).lower()
    if low_unit == "khz":
        low_value *= 1000
    if high_unit == "khz":
        high_value *= 1000
    if not (_in_range("frequency_min", low_value) and _in_range("frequency_max", high_value)):
        return None
    return {"value": {"min": _tidy(low_value), "max": _tidy(high_value)}, "unit": "hz"}


def parse_sensitivity(value: str, headphone: Optional[bool]) -> Optional[Tuple[str, dict]]:
    """ "95 dB / 1W / 1 m", "88 dB (2.83 V/1 m)", "105 dB/mW" """
    if re.search(rf"(?i){NUMBER}\s*(?:db)?\s*(?:/|-|–|to|bis|or)\s*{NUMBER}\s*db|up to|bis zu|max", value):
        # "98/102 dB", "93 to 98 dB", "up to 101 dB": a range or a limit.
        return None
    matches = re.findall(rf"({NUMBER})\s*db", value, re.IGNORECASE)
    if len(matches) != 1:
        # "94 dB / 97 dB": two drivers or two versions, and no way to tell which.
        return None
    amount = number(matches[0])
    if amount is None:
        return None
    lowered = value.lower().replace(" ", "")
    if headphone is None:
        headphone = "mw" in lowered
    if headphone:
        if "mw" not in lowered or "db/v" in lowered:
            return None
        key, unit = "headphone_sensitivity", "db_mw"
    else:
        if "mw" in lowered:
            return None
        key = "loudspeaker_sensitivity"
        # "2.83 V" and the rounded "2.8 V" both mean 1 W into 8 ohms, measured
        # as a voltage; the catalogue keeps it apart from the 1 W figure.
        unit = "db_283v_1m" if re.search(r"2[.,]83?v", lowered) else "db_1w_1m"
    if not _in_range(key, amount):
        return None
    return key, {"value": _tidy(amount), "unit": unit}


# "4-8 Ω", "4 or 8 Ohm", "> 4 ohm": a range, a choice or a limit, and not the
# one value the attribute holds.
AMBIGUOUS = re.compile(
    rf"(?i){NUMBER}\s*(?:ω|Ω|ohms?)?\s*(?:-|–|/|to|bis|or|oder|ou|o)\s*{NUMBER}|[<>≥≤]"
)


def parse_impedance(value: str, key: str) -> Optional[dict]:
    """ "8 Ω", "4 ohms". A range ("4-8 Ω") says two things and is left out."""
    numbers = re.findall(rf"({NUMBER})\s*(?:ω|Ω|ohms?)", value, re.IGNORECASE)
    if len(numbers) != 1 or AMBIGUOUS.search(value):
        return None
    amount = number(numbers[0])
    if amount is None or not _in_range(key, amount):
        return None
    return {"value": _tidy(amount), "unit": "ohm"}


def parse_weight(label: str, value: str) -> Optional[dict]:
    """ "32 kg / 62 lbs each". A weight for a pair, or a shipping weight, is left out."""
    text = f"{label} {value}".lower()
    if re.search(r"pair|paar|paire|coppia|shipping|packed|gross|brutto|versand|emballé", text):
        return None
    found = re.findall(rf"({NUMBER})\s*(kg|kilos?|g|gr|lbs?|pounds?)\b", value, re.IGNORECASE)
    metric = [item for item in found if not item[1].lower().startswith(("lb", "pound"))]
    imperial = [item for item in found if item[1].lower().startswith(("lb", "pound"))]
    # One weight, written once or in both systems ("32 kg / 62 lbs"). Two in
    # one system ("14 lbs - Full Metal Version: 50 lbs") are two products.
    if len(metric) > 1 or len(imperial) > 1 or not found:
        return None
    raw, unit = (metric or imperial)[0]
    amount = number(raw)
    unit = unit.lower()
    if amount is None:
        return None
    if unit in ("g", "gr"):
        amount, unit = amount / 1000, "kg"
    elif unit.startswith("kilo"):
        unit = "kg"
    elif unit.startswith(("lb", "pound")):
        unit = "lb"
    kilograms = amount * 0.45359237 if unit == "lb" else amount
    if not _in_range("weight", kilograms):
        return None
    return {"value": _tidy(amount), "unit": unit}


# The letters a brand uses for width, height and depth, in the languages seen.
# "L" is left out on purpose: it is the width in French (largeur) and the
# length, that is the depth, in English.
AXES = {"w": "w", "b": "w", "h": "h", "d": "l", "t": "l", "p": "l"}


def _axis_order(text: str) -> Optional[List[str]]:
    match = re.search(r"(?i)\b([a-z])\s*[x×*]\s*([a-z])\s*[x×*]\s*([a-z])\b", text)
    if not match:
        return None
    letters = [letter.lower() for letter in match.groups()]
    axes = [AXES.get(letter) for letter in letters]
    if None in axes or len(set(axes)) != 3:
        return None
    return axes


def parse_dimensions(label: str, hint: str, value: str) -> Optional[dict]:
    """ "33 x 108 x 25 cm", with the order from "(W x H x D)" in the label.

    Without a stated order the three numbers could be read in six ways, and
    the value is left out.
    """
    triples = list(re.finditer(
        rf"({NUMBER})\s*(?:mm|cm|in|\"|”)?\s*[x×*]\s*({NUMBER})\s*(?:mm|cm|in|\"|”)?\s*[x×*]\s*"
        rf"({NUMBER})\s*(mm|cm|in|inch(?:es)?|\"|”)",
        value, re.IGNORECASE,
    ))
    if not triples:
        return None
    # Written in both systems, the metric one is the brand's own figure more
    # often, and it needs no rounding.
    metric = [item for item in triples if item.group(4).lower() in ("mm", "cm")]
    if len(metric) > 1 or len(triples) - len(metric) > 1:
        return None
    match = (metric or triples)[0]
    order = _axis_order(hint) or _axis_order(label) or _axis_order(value[: match.start()])
    if not order:
        return None
    numbers = [number(item) for item in match.groups()[:3]]
    if None in numbers:
        return None
    unit = match.group(4).lower()
    if unit == "mm":
        numbers, unit = [item / 10 for item in numbers], "cm"
    elif unit != "cm":
        unit = "in"
    centimetres = [item * 2.54 if unit == "in" else item for item in numbers]
    if not all(_in_range("dimensions", item) for item in centimetres):
        return None
    return {"value": {axis: _tidy(item) for axis, item in zip(order, numbers)}, "unit": unit}


def parse_output_power(value: str) -> Optional[dict]:
    """ "2 x 100 W (8 Ω), 2 x 160 W (4 Ω)". A power without a load is left out."""
    if re.search(r"(?i)(8|4)\s*(?:ω|Ω|ohms?)\s*(?:or|oder|ou|/)\s*(8|4)\s*(?:ω|Ω|ohms?)", value):
        # "120 watts into 4Ω or 8Ω" names one power for two loads.
        return None
    found = {}
    for watts, ohms in re.findall(
        rf"({NUMBER})\s*w(?:atts?)?\b[^,;/]*?\b(8|4)\s*(?:ω|Ω|ohms?)", value, re.IGNORECASE
    ):
        amount = number(watts)
        if amount is not None and _in_range("amplifier_output_power", amount):
            found.setdefault(f"ohm_{ohms}", _tidy(amount))
    return {"value": found, "unit": "w"} if found else None


def _tidy(value: float):
    rounded = round(value, 3)
    return int(rounded) if rounded == int(rounded) else rounded


HEADPHONE_CATEGORIES = {
    "in-ear-monitors", "noise-cancelling-headphones", "on-ear-headphones", "over-ear-headphones",
}


def read_specs(text: str, sub_categories: List[str], applies) -> Dict[str, Tuple[dict, str]]:
    """{attribute label: (value, "Label: value" as the page wrote it)}.

    `applies(label)` answers whether an attribute applies to the candidate's
    sub categories. The first readable pair for an attribute wins: it is the
    one nearest to the top of the page, where the product itself is described.
    """
    # Without sub categories the unit decides: dB/mW is a headphone's.
    headphone = bool(HEADPHONE_CATEGORIES & set(sub_categories)) if sub_categories else None
    found: Dict[str, Tuple[dict, str]] = {}
    for raw_label, value in spec_pairs(text):
        if len(value) > MAX_VALUE or re.match(r"^[-–—•]", value):
            # "Efficiency: – AF-1.9: 95 dB": one line of a list per driver or
            # version, and the first is not the product's value.
            continue
        label, hint = _clean_label(raw_label)
        if len(label) > MAX_LABEL:
            continue
        snippet = f"{raw_label.rstrip(':').strip()}: {value}"
        for key, pattern in LABEL_PATTERNS.items():
            if not pattern.match(label):
                continue
            result: Optional[Tuple[str, dict]] = None
            if key == "frequency_response_range":
                parsed = parse_frequency(value)
                result = (key, parsed) if parsed else None
            elif key == "sensitivity":
                result = parse_sensitivity(value, headphone)
            elif key in ("nominal_impedance", "loudspeaker_minimum_impedance"):
                parsed = parse_impedance(value, key)
                result = (key, parsed) if parsed else None
            elif key == "weight":
                parsed = parse_weight(raw_label, value)
                result = (key, parsed) if parsed else None
            elif key == "dimensions":
                parsed = parse_dimensions(label, hint, value)
                result = (key, parsed) if parsed else None
            elif key == "amplifier_output_power":
                parsed = parse_output_power(value)
                result = (key, parsed) if parsed else None
            if result and applies(result[0]) and result[0] not in found:
                found[result[0]] = (result[1], snippet)
    return found


def mapped_sub_categories(path: Path) -> Dict[Tuple[Optional[str], str], List[str]]:
    """{(brand slug or None, lower-case shop word): sub category slugs} from the mappings file.

    A candidate the review agreed with has its sub categories from a mapping,
    and the mapping is applied in the database (`rake import:map`), not in
    candidates.jsonl. The file is read here with a small reader for its one
    shape -- a list of flat entries -- so the tool stays on the standard library.
    """
    entries: List[dict] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split(" #")[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip() or line.strip() == "---":
            continue
        if line.startswith("- "):
            entries.append({})
            line = line[2:]
        elif not line.startswith("  ") or not entries:
            continue
        key, _, value = line.strip().partition(":")
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            entries[-1][key] = [item.strip().strip("'\"") for item in value[1:-1].split(",") if item.strip()]
        else:
            entries[-1][key] = value.strip("'\"")
    found: Dict[Tuple[Optional[str], str], List[str]] = {}
    for entry in entries:
        slugs = entry.get("sub_categories")
        word = entry.get("source_category")
        if slugs and word and entry.get("out_of_scope") != "true":
            found[(entry.get("brand") or None, word.lower())] = slugs
    return found
