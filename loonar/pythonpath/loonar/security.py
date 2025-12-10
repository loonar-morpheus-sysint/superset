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

from typing import List, Optional

from flask import current_app, flash, redirect, request, Response
from flask_appbuilder import AppBuilder, expose
from flask_appbuilder.security.forms import LoginForm_db
from flask_appbuilder.security.manager import (
    AUTH_DB,
    AUTH_LDAP,
    AUTH_OAUTH,
    AUTH_REMOTE_USER,
)
from flask_appbuilder.security.sqla.models import User
from flask_appbuilder.security.views import AuthDBView
from flask_babel import gettext as _
from flask_login import login_user
from ldap3 import ALL, Connection, Server, SUBTREE
from ldap3.core.exceptions import LDAPException
from ldap3.utils.conv import escape_filter_chars
from sqlalchemy.orm import Session
from wtforms import HiddenField

from superset.security import SupersetSecurityManager

from .ldap_config import get_ldap_setting


class LoonarLoginForm(LoginForm_db):
    auth_provider = HiddenField(default="database")


class LoonarAuthDBView(AuthDBView):
    form = LoonarLoginForm
    template = "loonar/security/login.html"

    @expose("/login/", methods=["GET", "POST"])
    def login(self) -> Response:
        form = self.form()
        if request.method == "POST" and form.validate_on_submit():
            provider = (form.auth_provider.data or "database").lower()
            if provider == "ldap":
                result = self._login_with_ldap(form)
            else:
                result = self._login_with_database(form)
            if result:
                return result
        return self.render_template(
            self.template,
            title=self.title,
            form=form,
            appbuilder=self.appbuilder,
        )

    def _login_with_database(self, form: LoonarLoginForm) -> Optional[Response]:
        user = self.appbuilder.sm.auth_user_db(form.username.data, form.password.data)
        if not user:
            flash(_("Usuário ou senha inválidos."), "danger")
            return None
        remember = getattr(form, "remember_me", None)
        login_user(user, remember=bool(remember.data) if remember else False)
        return redirect(self.get_redirect())

    def _login_with_ldap(self, form: LoonarLoginForm) -> Optional[Response]:
        user = self.appbuilder.sm.auth_user_ldap(form.username.data, form.password.data)
        if not user:
            flash(_("Credenciais inválidas no Active Directory."), "danger")
            return None
        login_user(user, remember=False)
        return redirect(self.get_redirect())


class LoonarSecurityManager(SupersetSecurityManager):
    authdbview = LoonarAuthDBView

    def __init__(self, appbuilder: AppBuilder) -> None:
        super().__init__(appbuilder)
        self.ldap_group_base = get_ldap_setting("LOONAR_LDAP_GROUP_BASE", "") or ""
        default_user_base = self.ldap_group_base or None
        self.ldap_user_base = get_ldap_setting(
            "LOONAR_LDAP_USER_BASE", default_user_base
        ) or (default_user_base or "")
        self.ldap_uid_attr = (
            get_ldap_setting("LOONAR_LDAP_UID_ATTR", "sAMAccountName")
            or "sAMAccountName"
        )

    def auth_user_ldap(self, username: str, password: str) -> Optional[User]:
        user = super().auth_user_ldap(username, password)
        if user:
            self._sync_roles_from_ldap_groups(user, username)
        return user

    def _sync_roles_from_ldap_groups(self, user: User, username: str) -> None:
        if not self.ldap_group_base:
            return

        connection = self._get_bound_connection()
        if connection is None:
            return

        try:
            user_dn = self._lookup_user_dn(connection, username)
            if not user_dn:
                return

            group_names = self._fetch_group_names(connection, user_dn)
            if not group_names:
                return

            session: Session = self.session
            matching_roles = (
                session.query(self.role_model)
                .filter(self.role_model.name.in_(group_names))
                .all()
            )
            if not matching_roles:
                return

            current_names = {role.name for role in user.roles}
            new_names = {role.name for role in matching_roles}
            if new_names == current_names:
                return

            user.roles = matching_roles
            session.commit()
        finally:
            connection.unbind()

    def register_views(self) -> None:
        """Register security views while keeping Superset's menu customizations."""
        if not current_app.config.get("FAB_ADD_SECURITY_VIEWS", True):
            return

        self._register_base_security_views()
        self._register_auth_view()
        self._register_user_and_role_views()
        self._register_optional_views()
        self._cleanup_duplicate_views()
        self._cleanup_security_menu()

    def _register_base_security_views(self) -> None:
        """Register API and user info views."""
        self.appbuilder.add_api(self.security_api)

        if self.auth_user_registration:
            if self.auth_type == AUTH_DB:
                self.registeruser_view = self.registeruserdbview()
            elif self.auth_type == AUTH_OAUTH:
                self.registeruser_view = self.registeruseroauthview()
            if self.registeruser_view:
                self.appbuilder.add_view_no_menu(self.registeruser_view)

        self.appbuilder.add_view_no_menu(self.userinfoeditview())

    def _register_auth_view(self) -> None:
        """Register authentication view based on auth type."""
        if self.auth_type == AUTH_DB:
            self.user_view = self.userdbmodelview
            self.auth_view = self.authdbview()
            self.appbuilder.add_view_no_menu(self.resetpasswordview())
            self.appbuilder.add_view_no_menu(self.resetmypasswordview())
        elif self.auth_type == AUTH_LDAP:
            self.user_view = self.userldapmodelview
            self.auth_view = self.authldapview()
        elif self.auth_type == AUTH_OAUTH:
            self.user_view = self.useroauthmodelview
            self.auth_view = self.authoauthview()
        elif self.auth_type == AUTH_REMOTE_USER:
            self.user_view = self.userremoteusermodelview
            self.auth_view = self.authremoteuserview()

        self.appbuilder.add_view_no_menu(self.auth_view)

        if self.is_auth_limited:
            self.limiter.limit(self.auth_rate_limit, methods=["POST"])(
                self.auth_view.blueprint
            )

    def _register_user_and_role_views(self) -> None:
        """Register user and role management views."""
        self.user_view = self.appbuilder.add_view(
            self.user_view,
            "List Users",
            icon="fa-user",
            label=_("List Users"),
            category="Security",
            category_icon="fa-cogs",
            category_label=_("Security"),
        )

        role_view = self.appbuilder.add_view(
            self.rolemodelview,
            "List Roles",
            icon="fa-user-gear",
            label=_("List Roles"),
            category="Security",
            category_icon="fa-cogs",
        )
        role_view.related_views = [self.user_view.__class__]

        self.appbuilder.add_view(
            self.groupmodelview,
            "List Groups",
            icon="fa-group",
            label=_("List Groups"),
            category="Security",
            category_icon="fa-cogs",
        )

    def _register_optional_views(self) -> None:
        """Register optional views like user stats and permissions."""
        if self.userstatschartview:
            self.appbuilder.add_view(
                self.userstatschartview,
                "User's Statistics",
                icon="fa-bar-chart-o",
                label=_("User's Statistics"),
                category="Security",
            )
        if self.auth_user_registration:
            self.appbuilder.add_view(
                self.registerusermodelview,
                "User Registrations",
                icon="fa-user-plus",
                label=_("User Registrations"),
                category="Security",
            )
        self.appbuilder.menu.add_separator("Security")
        if current_app.config.get("FAB_ADD_SECURITY_PERMISSION_VIEW", True):
            self.appbuilder.add_view(
                self.permissionmodelview,
                "Base Permissions",
                icon="fa-lock",
                label=_("Base Permissions"),
                category="Security",
            )
        if current_app.config.get("FAB_ADD_SECURITY_VIEW_MENU_VIEW", True):
            self.appbuilder.add_view(
                self.viewmenumodelview,
                "Views/Menus",
                icon="fa-list-alt",
                label=_("Views/Menus"),
                category="Security",
            )

    def _cleanup_duplicate_views(self) -> None:
        """Remove duplicate views from appbuilder."""
        # Removed: This was incorrectly removing views including RoleRestAPI
        # The cleanup is not needed as Flask-AppBuilder handles duplicate routes
        pass

    def _cleanup_security_menu(self) -> None:
        """Clean up security menu items."""
        security_menu = next(
            (m for m in self.appbuilder.menu.get_list() if m.name == "Security"), None
        )
        if security_menu:
            for item in list(security_menu.childs):
                if item.name in [
                    "List Roles",
                    "List Users",
                    "List Groups",
                    "User Registrations",
                ]:
                    security_menu.childs.remove(item)

    def _get_bound_connection(self) -> Optional[Connection]:
        server_uri = get_ldap_setting("LOONAR_LDAP_SERVER")
        bind_dn = get_ldap_setting("LOONAR_LDAP_BIND_DN")
        bind_password = get_ldap_setting("LOONAR_LDAP_BIND_PASSWORD")
        use_ssl = (
            get_ldap_setting("LOONAR_LDAP_USE_SSL", "false") or "false"
        ).lower() == "true"
        if not server_uri or not bind_dn or not bind_password:
            return None

        server = Server(server_uri, use_ssl=use_ssl, get_info=ALL)
        try:
            return Connection(
                server,
                user=bind_dn,
                password=bind_password,
                auto_bind=True,
                check_names=False,
            )
        except LDAPException:
            self.logger.exception(
                "Não foi possível conectar ao servidor LDAP %s", server_uri
            )
            return None

    def _lookup_user_dn(self, connection: Connection, username: str) -> Optional[str]:
        base_dn = self.ldap_user_base or self.ldap_group_base
        if not base_dn:
            return None
        safe_uid = escape_filter_chars(username)
        search_filter = f"(&({self.ldap_uid_attr}={safe_uid})(objectClass=person))"
        connection.search(
            search_base=base_dn,
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=["distinguishedName"],
        )
        if not connection.entries:
            return None
        return connection.entries[0].entry_dn

    def _fetch_group_names(self, connection: Connection, user_dn: str) -> List[str]:
        if not self.ldap_group_base:
            return []
        safe_dn = escape_filter_chars(user_dn)
        connection.search(
            search_base=self.ldap_group_base,
            search_filter=(
                f"(&(member={safe_dn})(|(objectClass=group)(objectClass=groupOfNames)))"
            ),
            search_scope=SUBTREE,
            attributes=["cn"],
        )
        return [entry.cn.value for entry in connection.entries if hasattr(entry, "cn")]
