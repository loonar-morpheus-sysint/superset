# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
import json
import logging
import os
from typing import Any, Optional

logger = logging.getLogger(__name__)

# Global caching for JSON language packs
ALL_LANGUAGE_PACKS: dict[str, dict[str, Any]] = {"en": {}}

DIR = os.path.dirname(os.path.abspath(__file__))


def normalize_locale(locale: str) -> str:
    """Normalize locale codes to Superset's on-disk format.

    Superset translation assets are stored under directories like:
        superset/translations/pt_BR/LC_MESSAGES/messages.json

    But various clients and integrations may use BCP-47 style locale tags
    (eg. ``pt-BR``). Normalize these to a safe, canonical form.

    Examples:
        - ``pt-BR`` -> ``pt_BR``
        - ``pt_br`` -> ``pt_BR``
        - ``PT-br`` -> ``pt_BR``
        - ``en`` -> ``en``
    """
    if not locale:
        return ""

    normalized = locale.strip().replace("-", "_")
    if "_" in normalized:
        language, territory = normalized.split("_", 1)
        return f"{language.lower()}_{territory.upper()}"
    return normalized.lower()


def get_language_pack(locale: str) -> Optional[dict[str, Any]]:
    """Get/cache a language pack

    Returns the language pack from cache if it exists, caches otherwise

    >>> get_language_pack('fr')['Dashboards']
    "Tableaux de bords"
    """
    normalized_locale = normalize_locale(locale)
    pack = ALL_LANGUAGE_PACKS.get(normalized_locale)
    if not pack:
        filename = DIR + f"/{normalized_locale}/LC_MESSAGES/messages.json"
        if not normalized_locale or normalized_locale == "en":
            # Forcing a dummy, quasi-empty language pack for English since the
            # file in the en directory contains data with empty mappings.
            filename = DIR + "/empty_language_pack.json"
        try:
            with open(filename, encoding="utf8") as f:
                pack = json.load(f)
                ALL_LANGUAGE_PACKS[normalized_locale] = pack or {}
        except Exception:  # pylint: disable=broad-except
            logger.error(
                "Error loading language pack for %s (normalized to %s), "
                "falling back on en",
                locale,
                normalized_locale,
            )
            pack = get_language_pack("en")
    return pack
