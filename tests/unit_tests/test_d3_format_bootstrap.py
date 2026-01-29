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

from tests.conftest import with_config
from superset.views.base import cached_common_bootstrap_data
from superset import app


@with_config(
    {
        "D3_FORMAT": {
            "decimal": ",",
            "thousands": ".",
            "grouping": [3],
            "currency": ["R$", ""],
        }
    }
)
def test_d3_format_in_common_bootstrap_payload() -> None:
    """Assert D3_FORMAT is included in bootstrap payload and matches config"""
    payload = cached_common_bootstrap_data(None, None)
    assert "d3_format" in payload
    assert payload["d3_format"] == app.config.get("D3_FORMAT")
