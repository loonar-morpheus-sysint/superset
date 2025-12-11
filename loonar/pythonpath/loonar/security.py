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
        """
        Corrige o registro das views para garantir que self.auth_view nunca seja None.
        Registra as views padrão primeiro.
        Depois substitui a view de autenticação se necessário.
        """
        if not current_app.config.get("FAB_ADD_SECURITY_VIEWS", True):
            return

        # Chama o registro padrão primeiro (garante que self.auth_view seja válido)
        super().register_views()

        # Substitui a view de autenticação pelo customizado, se necessário
        if self.authdbview is not None:
            custom_auth_view = self.authdbview()
            self.auth_view = custom_auth_view
            self.appbuilder.add_view_no_menu(custom_auth_view)

            # Remove SupersetAuthView se existir
            for view in list(self.appbuilder.baseviews):
                if (
                    view.__class__.__name__ == "SupersetAuthView"
                    and view != custom_auth_view
                ):
                    self.appbuilder.baseviews.remove(view)

        # Remove duplicatas de MENU (não APIs)
        for view in list(self.appbuilder.baseviews):
            if hasattr(view, "route_base") and view.route_base in [
                "/roles",
                "/users",
                "/groups",
                "/registrations",
            ]:
                self.appbuilder.baseviews.remove(view)

        # Limpa itens do menu de segurança
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
