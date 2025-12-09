# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to You under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from __future__ import annotations

import os
from typing import Optional


def get_ldap_mode(default: str = "real") -> str:
    """Return the desired LDAP mode (e.g. "real" or "mock")."""

    return os.getenv("LOONAR_LDAP_MODE", default).strip().lower() or default


def get_ldap_setting(key: str, default: Optional[str] = None) -> Optional[str]:
    """Fetch a LDAP-related setting considering the current mode."""

    candidates = []
    if mode := get_ldap_mode():
        mode_upper = mode.upper()
        candidates.append(f"{key}_{mode_upper}_INTERNAL")
        candidates.append(f"{key}_{mode_upper}")
    candidates.append(key)
    for candidate in candidates:
        value = os.getenv(candidate)
        if value:
            return value
    return default
