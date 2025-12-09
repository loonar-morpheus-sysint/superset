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

from flask import Flask

from superset.initialization import SupersetAppInitializer


def init_app(app: Flask) -> None:
    """Register the Loonar template directory for custom security views."""

    if app.jinja_loader is None:
        return

    template_dir = os.path.join(os.path.dirname(__file__), "templates")
    if template_dir not in app.jinja_loader.searchpath:
        app.jinja_loader.searchpath.append(template_dir)


class LoonarAppInitializer(SupersetAppInitializer):
    """Superset initializer wrapper that also wires Loonar templates."""

    def init_app(self) -> None:
        super().init_app()
        init_app(self.superset_app)
