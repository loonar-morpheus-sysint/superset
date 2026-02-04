/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
import { setConfig as setHotLoaderConfig } from 'react-hot-loader';
import dayjs from 'dayjs';
// eslint-disable-next-line no-restricted-imports
import {
  configure,
  makeApi,
  initFeatureFlags,
  SupersetClient,
  LanguagePack,
} from '@superset-ui/core';
import setupClient from './setup/setupClient';
import setupColors from './setup/setupColors';
import setupFormatters from './setup/setupFormatters';
import setupDashboardComponents from './setup/setupDashboardComponents';
import { User } from './types/bootstrapTypes';
import getBootstrapData, { applicationRoot } from './utils/getBootstrapData';
import './hooks/useLocale';

configure();

// Set hot reloader config
if (process.env.WEBPACK_MODE === 'development') {
  setHotLoaderConfig({ logLevel: 'debug', trackTailUpdates: false });
}

// Grab initial bootstrap data
const bootstrapData = getBootstrapData();

// Resolve number format: prefer server `d3_format`, otherwise fall back to locale-specific mappings
const LOCALE_D3_NUMBER_FORMATS: Record<string, Partial<import('d3-format').FormatLocaleDefinition>> = {
  // Brazilian Portuguese uses comma as decimal and dot as thousands separator
  pt_BR: { decimal: ',', thousands: '.', grouping: [3], currency: ['R$', ''] },
  pt: { decimal: ',', thousands: '.', grouping: [3], currency: ['R$', ''] },
};

const effectiveD3NumberFormat =
  bootstrapData.common.d3_format && Object.keys(bootstrapData.common.d3_format).length
    ? bootstrapData.common.d3_format
    : LOCALE_D3_NUMBER_FORMATS[bootstrapData.common.locale] || {};

setupFormatters(effectiveD3NumberFormat, bootstrapData.common.d3_time_format);

// Setup SupersetClient early so we can fetch language pack
setupClient({ appRoot: applicationRoot() });

// Load language pack before anything else
const languagePackReady: Promise<void> = (async () => {
  const lang = bootstrapData.common.locale || 'en';
  if (lang !== 'en') {
    try {
      // Second call to configure to set the language pack
      const { json } = await SupersetClient.get({
        endpoint: `/superset/language_pack/${lang}/`,
      });
      configure({ languagePack: json as LanguagePack });
      dayjs.locale(lang);
      return;
    } catch (err) {
      console.warn(
        'Failed to fetch language pack, falling back to default.',
        err,
      );
      configure();
      dayjs.locale('en');
    }
  }
})();

window.__languagePackReady = languagePackReady;

languagePackReady.then(() => {

  // Continue with rest of setup
  initFeatureFlags(bootstrapData.common.feature_flags);

  setupColors(
    bootstrapData.common.extra_categorical_color_schemes,
    bootstrapData.common.extra_sequential_color_schemes,
  );

  setupDashboardComponents();

  const getMe = makeApi<void, User>({
    method: 'GET',
    endpoint: '/api/v1/me/',
  });

  if (bootstrapData.user?.isActive) {
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        getMe().catch(() => {
          // SupersetClient will redirect to login on 401
        });
      }
    });
  }
});
