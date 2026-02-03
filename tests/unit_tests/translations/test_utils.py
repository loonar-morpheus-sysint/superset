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

import pytest

from superset.translations.utils import normalize_locale


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("", ""),
        ("en", "en"),
        ("EN", "en"),
        ("pt", "pt"),
        ("pt_BR", "pt_BR"),
        ("pt_br", "pt_BR"),
        ("pt-BR", "pt_BR"),
        ("PT-br", "pt_BR"),
        (" zh-TW ", "zh_TW"),
        ("zh_tw", "zh_TW"),
    ],
)
def test_normalize_locale(raw: str, expected: str) -> None:
    assert normalize_locale(raw) == expected
